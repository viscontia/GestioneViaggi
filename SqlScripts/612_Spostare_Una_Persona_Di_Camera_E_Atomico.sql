-- =============================================================================
-- 612 — Spostare una persona di sistemazione è UNA operazione, non due
-- =============================================================================
--
-- Rilievo di Adriano il 2026-09-06: «se fai 2 operazioni sul DB di cui una potrebbe
-- non essere eseguita per ragioni non di codice, dobbiamo renderle atomiche: o
-- tutto o nulla».
--
-- Ha ragione. Lo spostamento appena introdotto scriveva la camera di destinazione e
-- poi liberava quella di partenza, con DUE chiamate separate dal gestionale. Fra
-- l'una e l'altra ci puo' stare qualunque cosa che non dipende dal codice: la rete
-- che cade, il portatile che si chiude, PgBouncer che chiude la connessione, l'app
-- che va giu' (⚠️ e qui l'app che si chiude da sola e' successa davvero — vedi la
-- diagnosi WebKit del 2026-08-18). Il risultato sarebbe:
--
--   • una persona in DUE camere, che e' proprio cio' che la validazione vieta;
--   • oppure una camera vuota mai eliminata — una prenotazione che qualcuno paga.
--
-- ⚠️ Nessuna delle due si vede: non sono errori, sono dati che sembrano buoni. Si
-- scoprirebbero in albergo, davanti al cliente.
--
-- Ora e' una chiamata sola. Il corpo di una funzione PL/pgSQL e' una transazione:
-- o vale tutto, o non e' successo niente.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_alloggi_salva_camera(
    p_alloggio_pk      INTEGER,      -- 0 o NULL per una sistemazione nuova
    p_viaggio_id       INTEGER,
    p_data_viaggio_id  INTEGER,
    p_tipo_alloggio_id INTEGER,
    p_clienti          INTEGER[]     -- gli occupanti, nell'ordine in cui vanno scritti
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_pk        INTEGER;
    v_clienti   INTEGER[] := COALESCE(p_clienti, ARRAY[]::INTEGER[]);
    r           RECORD;
    v_restano   INTEGER[];
BEGIN
    IF array_length(v_clienti, 1) IS DISTINCT FROM cardinality(ARRAY(SELECT DISTINCT unnest(v_clienti))) THEN
        RAISE EXCEPTION 'La stessa persona è indicata due volte nella stessa sistemazione.'
            USING ERRCODE = 'check_violation';
    END IF;

    -- ---------------------------------------------------------------------
    -- 1. La sistemazione di destinazione
    -- ---------------------------------------------------------------------
    IF COALESCE(p_alloggio_pk, 0) = 0 THEN
        -- ⚠️ La chiave la assegna la sequenza a mano: questa tabella NON ha un default
        -- sulla colonna e non ha trigger. Lo fa cosi' anche sp_mov_clienti_alloggi_create,
        -- e omettendola l'inserimento fallisce su NOT NULL.
        INSERT INTO mov_clienti_alloggi (
            mov_clienti_alloggio_pk,
            viaggio_id_fk, data_viaggio_id_fk, tipo_alloggio_id_fk,
            cliente_id1_fk, cliente_id2_fk, cliente_id3_fk,
            cliente_id4_fk, cliente_id5_fk, cliente_id6_fk)
        VALUES (nextval('mov_clienti_alloggi_seq'),
                p_viaggio_id, p_data_viaggio_id, p_tipo_alloggio_id,
                v_clienti[1], v_clienti[2], v_clienti[3],
                v_clienti[4], v_clienti[5], v_clienti[6])
        RETURNING mov_clienti_alloggio_pk INTO v_pk;
    ELSE
        UPDATE mov_clienti_alloggi
           SET tipo_alloggio_id_fk = p_tipo_alloggio_id,
               cliente_id1_fk = v_clienti[1], cliente_id2_fk = v_clienti[2],
               cliente_id3_fk = v_clienti[3], cliente_id4_fk = v_clienti[4],
               cliente_id5_fk = v_clienti[5], cliente_id6_fk = v_clienti[6]
         WHERE mov_clienti_alloggio_pk = p_alloggio_pk
        RETURNING mov_clienti_alloggio_pk INTO v_pk;

        IF v_pk IS NULL THEN
            RAISE EXCEPTION 'La sistemazione % non esiste più: forse qualcun altro l''ha eliminata mentre la stavi modificando.', p_alloggio_pk
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    -- ---------------------------------------------------------------------
    -- 2. Chi arriva da un'altra sistemazione, ne esce
    -- ---------------------------------------------------------------------
    -- ⚠️ Solo sulla STESSA partenza: la stessa persona su un altro viaggio non c'entra.
    IF array_length(v_clienti, 1) > 0 THEN
        FOR r IN
            SELECT a.mov_clienti_alloggio_pk AS pk,
                   ARRAY(SELECT c FROM unnest(ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                                                    a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk]) c
                          WHERE c IS NOT NULL AND NOT (c = ANY (v_clienti))) AS restano
            FROM mov_clienti_alloggi a
            WHERE a.data_viaggio_id_fk = p_data_viaggio_id
              AND a.mov_clienti_alloggio_pk <> v_pk
              AND ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                        a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk] && v_clienti
        LOOP
            v_restano := r.restano;

            IF cardinality(v_restano) = 0 THEN
                -- Una sistemazione senza nessuno non e' una sistemazione: e' una
                -- prenotazione che qualcuno paga. Si elimina.
                DELETE FROM mov_clienti_alloggi WHERE mov_clienti_alloggio_pk = r.pk;
            ELSE
                -- ⚠️ Gli occupanti si ricompattano: lasciare un buco in mezzo alle sei
                -- colonne significa che chi legge «il primo occupante» trova NULL.
                UPDATE mov_clienti_alloggi
                   SET cliente_id1_fk = v_restano[1], cliente_id2_fk = v_restano[2],
                       cliente_id3_fk = v_restano[3], cliente_id4_fk = v_restano[4],
                       cliente_id5_fk = v_restano[5], cliente_id6_fk = v_restano[6]
                 WHERE mov_clienti_alloggio_pk = r.pk;
            END IF;
        END LOOP;
    END IF;

    RETURN v_pk;
END;
$$;

COMMENT ON FUNCTION fn_alloggi_salva_camera(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER[]) IS
'Salva una sistemazione e, nella stessa transazione, toglie i suoi occupanti dalle altre
sistemazioni della STESSA partenza, eliminando quelle che restano vuote.
⚠️ Deve restare UNA chiamata: separando la scrittura dallo spostamento, un''interruzione fra
le due lascerebbe una persona in due camere o una camera vuota mai eliminata — e nessuna
delle due si vede, perche'' non sono errori ma dati che sembrano buoni.';
