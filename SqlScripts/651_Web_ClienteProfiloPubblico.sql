-- ============================================================================
-- Il sito smette di consegnare la scheda a chiunque conosca un'email
--
-- IL DIFETTO, aperto da circa due anni. Una sola richiesta, senza alcuna
-- autenticazione:
--
--     GET /api/cliente/dati-per-email?email=<email di un cliente>
--
-- rispondeva con ventiquattro campi, dodici dei quali personali: codice
-- fiscale, indirizzo, telefono, data e comune di nascita, e il documento con
-- numero, ente che l'ha rilasciato e scadenza. ⛔️ Non e' un elenco anagrafico:
-- e' esattamente cio' che serve per registrare una persona in albergo o per
-- spendere la sua identita' altrove. Senza limite di tentativi, chi possiede
-- una lista di indirizzi — quella del club, una qualunque — li interrogava
-- tutti.
--
-- PERCHE' ERA SUCCESSO. L'email e' nata come chiave di comodita': non far
-- riscrivere tutto a chi torna. La stessa comodita', vista da fuori, e' un
-- archivio aperto. ⚠️ E l'email non ha mai identificato nessuno: chiunque puo'
-- digitare qualunque indirizzo e nessuno lo verifica. Chi identifica davvero e'
-- il documento, obbligatorio per tutti dallo script 563.
--
-- IL PRINCIPIO. **Per completare un'iscrizione il browser non ha bisogno dei
-- dati personali: ne ha bisogno il server, che li possiede gia'.** Al browser
-- servono VERDETTI, non dati:
--
--   invece di   numero_documento + scadenza   ->  «il documento va bene per
--                                                  questa partenza» / «e' scaduto»
--   invece di   indirizzo, codice fiscale...  ->  «mancano: l'indirizzo di
--                                                  residenza, il tipo di documento»
--                                                  (i NOMI dei campi, non i valori)
--
-- Restano cognome e nome, per il saluto e la conferma visiva: e' stato deciso
-- esplicitamente, perche' sapere che una persona e' cliente di SFT non e' il
-- dato da proteggere. Il valore da difendere e' il CONTENUTO della scheda.
--
-- ⚠️ La regola sta qui e non nel Python, per la stessa ragione di tutte le
-- altre: il giorno in cui si aggiunge una colonna personale a `ana_clienti`,
-- questa funzione continua a non restituirla. Un endpoint che costruisce la
-- risposta con `SELECT *` invece la regalerebbe da solo — ed e' letteralmente
-- cio' che e' successo.
--
-- Riferimento: Documents/Progetti/Estensione_Web/2026-09-05-Analisi_Protezione_
-- Dati_Personali_Sito.md
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_web_cliente_profilo_pubblico(
    p_azienda_id      INTEGER,
    p_email           VARCHAR,
    p_data_viaggio_id INTEGER DEFAULT NULL,
    p_pilota          BOOLEAN DEFAULT TRUE
)
RETURNS JSON
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_cliente        ana_clienti%ROWTYPE;
    v_campi_mancanti JSON;
    v_documento      JSON;
BEGIN
    IF p_email IS NULL OR btrim(p_email) = '' THEN
        RETURN json_build_object('esiste', FALSE);
    END IF;

    SELECT * INTO v_cliente
    FROM ana_clienti c
    WHERE c.azienda_fk = p_azienda_id
      AND lower(btrim(c.cliente_email)) = lower(btrim(p_email))
    ORDER BY c.cliente_id
    LIMIT 1;

    IF NOT FOUND THEN
        -- Chi non c'e' non produce alcun dettaglio: nemmeno la differenza fra
        -- «non esiste» e «esiste ma e' di un'altra azienda».
        RETURN json_build_object('esiste', FALSE);
    END IF;

    -- I NOMI dei campi ancora vuoti, non i valori di quelli pieni. La regola di
    -- cosa sia obbligatorio resta dove e' sempre stata (script 563).
    SELECT COALESCE(json_agg(json_build_object('campo', m.campo, 'etichetta', m.etichetta)
                             ORDER BY m.campo), '[]'::json)
      INTO v_campi_mancanti
      FROM fn_ana_clienti_campi_mancanti(to_jsonb(v_cliente), p_pilota) m;

    -- Il verdetto sul documento: la scadenza la legge il database, non la manda
    -- a nessuno. Serve la partenza, perche' «valido» dipende da quando si parte.
    IF p_data_viaggio_id IS NOT NULL AND p_data_viaggio_id > 0 THEN
        SELECT json_build_object('gravita', d.gravita, 'esito', d.esito, 'messaggio', d.messaggio)
          INTO v_documento
          FROM fn_documento_esito_per_partenza(
                   p_data_viaggio_id,
                   v_cliente.cliente_documento_rilasciato_scadenza,
                   NULL) d
         LIMIT 1;
    END IF;

    RETURN json_build_object(
        'esiste',                 TRUE,
        'cliente_id',             v_cliente.cliente_id,
        -- Cognome, nome e titolo: il saluto e la conferma visiva. Nient'altro.
        'cognome',                v_cliente.cliente_cognome,
        'nome',                   v_cliente.cliente_nome,
        'titolo_fk',              v_cliente.cliente_titolo_fk,
        -- Serve al codice usa e getta: su una scheda senza email in archivio il
        -- codice non prova nulla, perche' andrebbe all'indirizzo che chi chiede
        -- ha appena digitato.
        'ha_email_in_archivio',   btrim(COALESCE(v_cliente.cliente_email, '')) <> '',
        -- ⚠️ L'email e il consenso NON sono un'eccezione al principio, sono la
        -- condizione perche' il principio non faccia danni:
        --   * l'email e' quella che chi chiede ha appena digitato — non rivela nulla
        --     che non sappia gia';
        --   * il consenso alla newsletter deve tornare indietro com'e', altrimenti il
        --     modulo lo rimanda a FALSE e **spegne un consenso che nessuno ha
        --     revocato**. Registrare una revoca mai chiesta e' falsificare un dato, e
        --     sarebbe un danno peggiore di quello che questa funzione evita.
        'email',                  v_cliente.cliente_email,
        'consenso_marketing',     COALESCE(v_cliente.consenso_marketing, FALSE),
        'campi_mancanti',         v_campi_mancanti,
        'scheda_completa',        json_array_length(v_campi_mancanti) = 0,
        'documento',              v_documento
    );
END;
$$;

COMMENT ON FUNCTION fn_web_cliente_profilo_pubblico(INTEGER, VARCHAR, INTEGER, BOOLEAN) IS
    'Cio'' che il sito puo'' dire a chi digita un''email: esiste, come si chiama, quali campi mancano (i NOMI) e se il documento va bene per quella partenza. ⛔️ Nessun dato personale: e'' la funzione che sostituisce le risposte complete di /api/cliente/dati e /dati-per-email (script 651).';

COMMIT;

-- ============================================================================
-- Verifica: la risposta non deve contenere codice fiscale, indirizzo, telefono,
-- data di nascita ne' alcun campo del documento.
--
--   SELECT jsonb_pretty(fn_web_cliente_profilo_pubblico(
--       2, (SELECT cliente_email FROM ana_clienti
--            WHERE azienda_fk = 2 AND cliente_email IS NOT NULL LIMIT 1))::jsonb);
-- ============================================================================
