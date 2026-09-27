-- ============================================================================
-- 671 — Il promemoria all'apertura (L2)
--
-- Disegno: Documents/Progetti/Promemoria_Apertura/2026-09-27-promemoria-apertura-design.md
--
--   fn_promemoria_giorni_newsletter(azienda) → integer
--     quanti giorni avanti guardare per le partenze senza newsletter; dal
--     parametro 'giorni_newsletter' della funzione 'promemoria' (linguetta
--     Funzioni Web dell'azienda). Senza riga o senza parametro: 90.
--   fn_promemoria_apertura(azienda) → una riga per caso in sospeso
--     Il gestionale la disegna e basta: voci, testi, urgenza e cosa aprire
--     stanno qui. La mail del lunedi' la richiamera' cosi' com'e'.
--
-- Clienti e documenti: le STESSE regole del sito e dell'iscrizione
-- (fn_cliente_iscrivibile, fn_documento_esito_per_partenza), non una copia.
--
-- Solo per il gestionale: nessun GRANT (script 659). search_path fissato (655).
-- Rigiocabile.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_promemoria_giorni_newsletter(p_azienda_id integer)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path = public, pg_temp
AS $$
    SELECT COALESCE(
        (SELECT CASE WHEN f.parametri->>'giorni_newsletter' ~ '^\d+$'
                     THEN (f.parametri->>'giorni_newsletter')::integer END
           FROM web_aziende_funzioni f
          WHERE f.azienda_id = p_azienda_id AND f.funzione = 'promemoria'),
        90);
$$;

CREATE OR REPLACE FUNCTION fn_promemoria_apertura(p_azienda_id integer)
 RETURNS TABLE(voce varchar, voce_titolo varchar, perche text, oggetto text, urgenza integer,
               data_rif date, viaggio_id integer, data_viaggio_id integer, cliente_id integer)
 LANGUAGE sql
 STABLE
 SET search_path = public, pg_temp
AS $$
    WITH partenze AS (
        SELECT d.data_viaggio_id, d.viaggio_id_fk, d.data_viaggio_data_inizio AS inizio,
               d.data_viaggio_data_fine AS fine, d.data_viaggio_effettuato_sino AS effettuato,
               upper(v.viaggio_descrizione_breve) || ' · ' || to_char(d.data_viaggio_data_inizio, 'DD/MM/YYYY') AS etichetta
          FROM ana_date_viaggi d
          JOIN ana_viaggi v ON v.viaggio_id = d.viaggio_id_fk
         WHERE d.azienda_id = p_azienda_id
    ), future AS (
        SELECT * FROM partenze WHERE inizio >= current_date
    ), iscritti AS (
        SELECT m.cliente_id_fk, f.data_viaggio_id, f.viaggio_id_fk, f.inizio, f.etichetta,
               c.cliente_cognome || ' ' || c.cliente_nome AS nome,
               c.cliente_documento_rilasciato_scadenza AS scadenza,
               COALESCE(tp.tipo_partecipante_pilota, false) AS guida
          FROM mov_clienti_viaggi m
          JOIN future f ON f.data_viaggio_id = m.data_viaggio_id_fk
          JOIN ana_clienti c ON c.cliente_id = m.cliente_id_fk AND c.azienda_fk = p_azienda_id
          LEFT JOIN ana_tipo_partecipante tp ON tp.tipo_partecipante_id = m.tipo_partecipante_id_fk
    )
    -- Correzioni proposte dal sito (L12-bis): un cliente aspetta la risposta
    SELECT 'PROPOSTA_DAL_SITO'::varchar, 'Correzione dal sito da approvare'::varchar,
           'Il cliente aspetta la mail per completare l''iscrizione'::text,
           p.cognome || ' ' || p.nome, 10, p.creata_il::date, NULL::integer, NULL::integer, p.cliente_id
      FROM fn_web_proposte_in_attesa(p_azienda_id) p
    UNION ALL
    -- Documento scaduto o in scadenza per una partenza futura
    SELECT DISTINCT ON (i.cliente_id_fk, i.data_viaggio_id)
           'DOCUMENTO', 'Documento da controllare', e.messaggio,
           i.nome || ' — ' || i.etichetta, 20, i.inizio, i.viaggio_id_fk, i.data_viaggio_id, i.cliente_id_fk
      FROM iscritti i
     CROSS JOIN LATERAL fn_documento_esito_per_partenza(i.data_viaggio_id, i.scadenza, i.nome) e
     WHERE upper(e.gravita) IN ('ERRORE', 'AVVISO')
    UNION ALL
    -- Iscritto che oggi non potrebbe iscriversi: blocca iscrizione e schedina alloggiati
    SELECT DISTINCT ON (i.cliente_id_fk)
           'CLIENTE_INCOMPLETO', 'Scheda cliente incompleta', e.messaggio,
           i.nome || ' — ' || i.etichetta, 30, i.inizio, i.viaggio_id_fk, i.data_viaggio_id, i.cliente_id_fk
      FROM iscritti i
     CROSS JOIN LATERAL fn_cliente_iscrivibile(i.cliente_id_fk, p_azienda_id, i.guida) e
     WHERE upper(e.gravita) = 'ERRORE'
    UNION ALL
    SELECT 'SENZA_SCHEDA_WEB', 'Partenza senza scheda web', 'Senza scheda il tour non esiste per il sito',
           f.etichetta, 40, f.inizio, f.viaggio_id_fk, f.data_viaggio_id, NULL
      FROM future f
     WHERE NOT EXISTS (SELECT 1 FROM web_tour_contenuti c WHERE c.data_viaggio_id_fk = f.data_viaggio_id)
    UNION ALL
    SELECT 'SCHEDA_IN_BOZZA', 'Scheda web in bozza', 'Pronta ma invisibile sul sito',
           f.etichetta, 41, f.inizio, f.viaggio_id_fk, f.data_viaggio_id, NULL
      FROM future f
      JOIN web_tour_contenuti c ON c.data_viaggio_id_fk = f.data_viaggio_id
     WHERE c.stato_pubblicazione = 'bozza'
    UNION ALL
    SELECT 'SCHEDA_SENZA_FOTO', 'Scheda web senza foto', 'Non pubblicabile: sul sito sarebbe una casella grigia',
           f.etichetta, 42, f.inizio, f.viaggio_id_fk, f.data_viaggio_id, NULL
      FROM future f
      JOIN web_tour_contenuti c ON c.data_viaggio_id_fk = f.data_viaggio_id
     WHERE NOT EXISTS (SELECT 1 FROM web_tour_immagini i WHERE i.web_tour_contenuti_id_fk = c.web_tour_contenuti_id)
    UNION ALL
    SELECT 'SENZA_CAPIENZA', 'Viaggio senza capienza o soglia', 'Il sito non può scrivere «rimangono N posti»',
           upper(v.viaggio_descrizione_breve), 50, min(f.inizio), v.viaggio_id, NULL, NULL
      FROM future f
      JOIN ana_viaggi v ON v.viaggio_id = f.viaggio_id_fk
     WHERE v.viaggio_capienza_max IS NULL OR v.viaggio_capienza_alert IS NULL
     GROUP BY v.viaggio_id, v.viaggio_descrizione_breve
    UNION ALL
    SELECT 'SENZA_NEWSLETTER', 'Partenza senza newsletter', 'Un viaggio che nessuno sa che esiste non si riempie',
           f.etichetta, 60, f.inizio, f.viaggio_id_fk, f.data_viaggio_id, NULL
      FROM future f
     WHERE f.inizio < current_date + fn_promemoria_giorni_newsletter(p_azienda_id)
       AND NOT EXISTS (
           SELECT 1 FROM web_newsletter_blocchi b
             JOIN web_newsletter_invii n ON n.web_newsletter_invii_id = b.invio_id_fk
            WHERE b.data_viaggio_id_fk = f.data_viaggio_id
              AND n.stato IN ('inviata', 'in_invio') AND NOT n.is_modello)
    UNION ALL
    SELECT 'PARTENZA_NON_EFFETTUATA', 'Partenza passata non segnata come effettuata',
           'Falsa i conti e le statistiche, e resta lì per sempre',
           p.etichetta, 70, p.fine, p.viaggio_id_fk, p.data_viaggio_id, NULL
      FROM partenze p
     WHERE p.fine < current_date AND COALESCE(p.effettuato, 'N') <> 'Y';
$$;

-- La riga del parametro per ogni azienda, attiva, 90 giorni (non tocca chi l'ha gia')
INSERT INTO web_aziende_funzioni (azienda_id, funzione, attiva, parametri, created_by)
SELECT a.azienda_id, 'promemoria', true, '{"giorni_newsletter": 90}'::jsonb, 'script 671'
  FROM ana_aziende a
ON CONFLICT (azienda_id, funzione) DO NOTHING;

COMMIT;
