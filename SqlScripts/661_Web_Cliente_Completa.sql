-- ============================================================================
-- Completare una scheda esistente senza poterla sovrascrivere
--
-- Disegno: Iscrizione-Viaggi-Offroad PostgreSQL/docs/plans/2026-09-25-cliente-
-- riconosciuto-otp-design.md (approvato il 2026-09-25). Voce L4 delle due liste.
--
-- Il sito, per un cliente che NON ha superato il codice usa e getta, puo' solo
-- COMPLETARE la scheda: scrivere dove il campo e' vuoto. Riscrivere un dato che
-- c'e' gia' e' MODIFICARE, e senza codice non e' ammesso — altrimenti chi conosce
-- un'email riscrive residenza e documento di un altro (lo faceva /api/cliente/save
-- fino al 2026-09-25).
--
-- ⚠️ Cambia la decisione del 2026-09-05 (script 594), che lasciava sovrascrivere
-- recapiti, indirizzo e documento: da ora quella e' una modifica, e passa dall'OTP.
--
-- ⚠️ SI COMPLETANO SOLO I CAMPI DEL MODULO, elencati uno per uno (una whitelist,
-- non una lista di esclusi). Una lista di esclusi si allarga da sola il giorno in
-- cui ana_clienti prende una colonna nuova, e nessuno se ne accorge; una whitelist
-- no. Fuori restano, apposta:
--   - email e consenso: hanno la loro strada (fn_ana_clienti_aggancia_email,
--     fn_consenso_registra_risposta), e un consenso «completato» sarebbe falso;
--   - cognome e nome: sono l'identita', e in archivio non sono mai vuoti;
--   - note, IBAN, lingua, controparte, foto e file del documento, azienda, audit:
--     il modulo non li manda, quindi dal sito non devono poter arrivare.
-- La stessa lista da' l'etichetta per l'avviso al cliente: una fonte sola.
--
-- Vuoto e assente sono la stessa cosa, come in fn_ana_clienti_campi_mancanti:
-- NULL, stringa di soli spazi e, per le chiavi esterne, lo zero. Vale per il dato
-- in archivio (e' vuoto, si puo' riempire) e per quello ricevuto (e' vuoto, non
-- riempie e non svuota niente).
--
-- Le regole di validazione restano in fn_ana_clienti_update: questa funzione filtra
-- i dati e poi la chiama, con le conferme a FALSE. Riempire una data o un comune
-- di nascita VUOTI non e' cambiarli (fn_ana_clienti_nascita_modificata, 594),
-- quindi non chiede conferma.
--
-- ⚠️ La riga del cliente si legge FOR UPDATE: due completamenti insieme (doppio
-- clic, due schede aperte) non devono vedere tutti e due il campo vuoto e
-- riempirlo due volte con valori diversi. Il secondo aspetta il primo e poi
-- trova il campo pieno. E' una scrittura breve del sito: il lucchetto qui e'
-- quello giusto, a differenza della lettura dello script 660.
--
-- Permessi: nessun GRANT. Nasce chiusa ad anon (script 659); la chiama solo Flask,
-- che si connette come postgres, proprietario. search_path fissato (script 655).
--
-- Test: Test_661_Web_Cliente_Completa.sql (gira in una transazione annullata).
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_web_cliente_completa(p_cliente_id INTEGER, p_azienda_id INTEGER, p_dati JSONB)
RETURNS TABLE(campo VARCHAR, etichetta TEXT)
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
    v_attuale  JSONB;
    v_filtrati JSONB := '{}'::jsonb;
    r          RECORD;
BEGIN
    SELECT to_jsonb(c) INTO v_attuale
      FROM ana_clienti c
     WHERE c.cliente_id = p_cliente_id AND c.azienda_fk = p_azienda_id
       FOR UPDATE;
    IF v_attuale IS NULL THEN
        RAISE EXCEPTION 'Cliente non trovato.';
    END IF;

    -- ⚠️ Le colonne della lista si chiamano `colonna` e `testo`, non `campo` ed
    -- `etichetta`: quei due nomi sono gia' le variabili di uscita della funzione,
    -- e in una query sarebbero ambigui.
    FOR r IN
        SELECT w.colonna, w.testo, p_dati -> w.colonna AS nuovo
          FROM (VALUES
                    ( 1, 'cliente_titolo_fk',                     'il titolo'),
                    ( 2, 'cliente_data_nascita',                  'la data di nascita'),
                    ( 3, 'cliente_comune_nascita_fk',             'il comune di nascita'),
                    ( 4, 'cliente_codicefiscale',                 'il codice fiscale'),
                    ( 5, 'cliente_comune_residenza_fk',           'il comune di residenza'),
                    ( 6, 'cliente_indirizzo_residenza',           'l''indirizzo di residenza'),
                    ( 7, 'cliente_preftelint',                    'il prefisso internazionale'),
                    ( 8, 'cliente_telefono',                      'il numero di telefono'),
                    ( 9, 'cliente_intolleranza',                  'le allergie o intolleranze'),
                    (10, 'cliente_tipodoc_identita',              'il tipo di documento'),
                    (11, 'cliente_documento_numero',              'il numero del documento'),
                    (12, 'cliente_documento_rilasciato_da',       'l''ente che ha rilasciato il documento'),
                    (13, 'cliente_documento_rilasciato_data',     'la data di rilascio del documento'),
                    (14, 'cliente_documento_rilasciato_scadenza', 'la data di scadenza del documento')
               ) AS w(ordine, colonna, testo)
         WHERE COALESCE(p_dati, '{}'::jsonb) ? w.colonna
         ORDER BY w.ordine
    LOOP
        -- Il dato ricevuto e' vuoto: non riempie niente (e non svuota niente).
        CONTINUE WHEN btrim(COALESCE(r.nuovo #>> '{}', '')) = ''
                   OR (r.colonna LIKE '%\_fk' AND (r.nuovo #>> '{}') = '0');
        -- Il dato in archivio c'e': cambiarlo e' una modifica, e senza codice no.
        CONTINUE WHEN NOT (btrim(COALESCE(v_attuale ->> r.colonna, '')) = ''
                           OR (r.colonna LIKE '%\_fk' AND (v_attuale ->> r.colonna) = '0'));

        v_filtrati := v_filtrati || jsonb_build_object(r.colonna, r.nuovo);
        -- RETURN NEXT accoda soltanto: le righe escono a funzione finita. Se la
        -- validazione qui sotto rifiuta, non esce nulla e non si scrive nulla.
        campo     := r.colonna;
        etichetta := r.testo;
        RETURN NEXT;
    END LOOP;

    IF v_filtrati <> '{}'::jsonb THEN
        PERFORM fn_ana_clienti_update(p_cliente_id, v_filtrati, FALSE);
    END IF;
END;
$$;

COMMENT ON FUNCTION fn_web_cliente_completa(INTEGER, INTEGER, JSONB) IS
    'Scrive sulla scheda SOLO i campi del modulo oggi vuoti e restituisce quali, con un''etichetta per l''avviso al cliente. E'' l''unica scrittura che il sito puo'' fare su una scheda esistente senza codice usa e getta (script 661).';

COMMIT;
