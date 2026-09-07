-- =============================================================================
-- 619 — Una sola scrittura per le sistemazioni, per il gestionale e per il sito
-- =============================================================================
--
-- Adriano, 2026-09-07: «dobbiamo avere regole uniche e validazioni uniche e CRUD
-- unici sia per MAUI che per Flask. E' un lavoro molto importante».
--
-- ⚠️ Misurato prima di toccare: **NOVE funzioni scrivevano su `mov_clienti_alloggi`**.
-- Il gestionale ne usava tre strade diverse, il sito una quarta, e le altre erano
-- rimaste indietro senza che nessuno le chiamasse piu'. Ogni strada ha le sue
-- regole — o non ne ha — e sono le stesse righe.
--
-- Ne resta UNA per creare e modificare: `fn_alloggi_salva_camera` (615), che
-- controlla la capienza, deriva il viaggio dalla partenza, sposta chi arriva da
-- un'altra sistemazione e chiede che cosa diventa quella di chi resta.
--
-- Restano a parte, e devono restare:
--   • `fn_mov_clienti_alloggi_togli_cliente` — toglie una persona, la chiama la
--     cancellazione (616);
--   • `sp_remove_client_from_room` — usata da altre tre funzioni;
--   • `fn_silos_rimappa_movimenti` — bonifica una tantum dei silos (587-589).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Chi ha scritto la riga: serviva al sito, e adesso serve alla funzione unica
-- ---------------------------------------------------------------------------
-- ⚠️ Senza questo parametro il sito perderebbe l'unica traccia di chi ha creato la
-- sistemazione — oggi la scrive `fn_wizard_insert_alloggio_assegnato`, che sta per
-- sparire. Il gestionale non lo passa e la colonna resta com'era.
DROP FUNCTION IF EXISTS fn_alloggi_salva_camera(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER[], JSONB);

CREATE OR REPLACE FUNCTION fn_alloggi_salva_camera(
    p_alloggio_pk      INTEGER,
    p_viaggio_id       INTEGER,
    p_data_viaggio_id  INTEGER,
    p_tipo_alloggio_id INTEGER,
    p_clienti          INTEGER[],
    p_adeguamenti      JSONB   DEFAULT '[]'::jsonb,
    p_created_by       VARCHAR DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_pk         INTEGER;
    v_clienti    INTEGER[] := COALESCE(p_clienti, ARRAY[]::INTEGER[]);
    v_quanti     INTEGER   := cardinality(COALESCE(p_clienti, ARRAY[]::INTEGER[]));
    v_capienza   INTEGER;
    v_tipo       VARCHAR;
    v_genere     VARCHAR;
    r            RECORD;
    v_restano    INTEGER[];
    v_tipo_nuovo INTEGER;
    v_cap_nuova  INTEGER;
    v_viaggio    INTEGER;
BEGIN
    -- ⚠️ Solo se c'e' qualcuno: con l'elenco vuoto questo confronto era vero (NULL contro 0)
    -- e usciva «la stessa persona due volte», che non c'entra niente.
    IF v_quanti > 0
       AND array_length(v_clienti, 1) IS DISTINCT FROM cardinality(ARRAY(SELECT DISTINCT unnest(v_clienti))) THEN
        RAISE EXCEPTION 'La stessa persona è indicata due volte nella stessa sistemazione.'
            USING ERRCODE = 'check_violation';
    END IF;

    -- ⚠️ Il viaggio NON si prende da chi chiama: lo sa gia' la partenza.
    SELECT dv.viaggio_id_fk INTO v_viaggio FROM ana_date_viaggi dv
     WHERE dv.data_viaggio_id = p_data_viaggio_id;

    IF v_viaggio IS NULL THEN
        RAISE EXCEPTION 'La partenza indicata non esiste.' USING ERRCODE = 'check_violation';
    END IF;

    IF COALESCE(p_viaggio_id, 0) <> 0 AND p_viaggio_id <> v_viaggio THEN
        RAISE EXCEPTION 'La partenza % appartiene al viaggio %, non al %.',
            p_data_viaggio_id, v_viaggio, p_viaggio_id USING ERRCODE = 'check_violation';
    END IF;

    SELECT t.tipo_alloggio_numero_occupanti, t.tipo_alloggio_descrizione, g.genere_codice
      INTO v_capienza, v_tipo, v_genere
    FROM ana_tipo_alloggio t
    JOIN ana_alloggio_generi g ON g.genere_id = t.genere_fk
    WHERE t.tipo_alloggio_id = p_tipo_alloggio_id;

    IF v_capienza IS NULL THEN
        RAISE EXCEPTION 'La sistemazione indicata non esiste.' USING ERRCODE = 'check_violation';
    END IF;

    -- ⚠️ «Nessuna sistemazione» ha capienza 0 e un occupante.
    IF v_genere <> 'NESSUNA' AND v_quanti <> v_capienza THEN
        RAISE EXCEPTION
            '«%» ospita % persone, ne %. La capienza deve corrispondere: se serve una sistemazione diversa, cambia il tipo.',
            v_tipo, v_capienza,
            CASE WHEN v_quanti = 0 THEN 'è stata indicata nessuna'
                 WHEN v_quanti = 1 THEN 'è stata indicata 1'
                 ELSE 'sono state indicate ' || v_quanti END
            USING ERRCODE = 'check_violation';
    END IF;

    IF COALESCE(p_alloggio_pk, 0) = 0 THEN
        INSERT INTO mov_clienti_alloggi (
            mov_clienti_alloggio_pk,
            viaggio_id_fk, data_viaggio_id_fk, tipo_alloggio_id_fk,
            cliente_id1_fk, cliente_id2_fk, cliente_id3_fk,
            cliente_id4_fk, cliente_id5_fk, cliente_id6_fk, created_by)
        VALUES (nextval('mov_clienti_alloggi_seq'),
                v_viaggio, p_data_viaggio_id, p_tipo_alloggio_id,
                v_clienti[1], v_clienti[2], v_clienti[3],
                v_clienti[4], v_clienti[5], v_clienti[6], p_created_by)
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

    -- Chi arriva da un'altra sistemazione, ne esce.
    IF array_length(v_clienti, 1) > 0 THEN
        FOR r IN
            SELECT a.mov_clienti_alloggio_pk AS pk,
                   t.tipo_alloggio_descrizione AS descrizione,
                   ARRAY(SELECT c FROM unnest(ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                                                    a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk]) c
                          WHERE c IS NOT NULL AND NOT (c = ANY (v_clienti))) AS restano
            FROM mov_clienti_alloggi a
            JOIN ana_tipo_alloggio t ON t.tipo_alloggio_id = a.tipo_alloggio_id_fk
            WHERE a.data_viaggio_id_fk = p_data_viaggio_id
              AND a.mov_clienti_alloggio_pk <> v_pk
              AND ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                        a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk] && v_clienti
        LOOP
            v_restano := r.restano;

            IF cardinality(v_restano) = 0 THEN
                DELETE FROM mov_clienti_alloggi WHERE mov_clienti_alloggio_pk = r.pk;
                CONTINUE;
            END IF;

            SELECT (x->>'tipo_id')::INTEGER INTO v_tipo_nuovo
            FROM jsonb_array_elements(COALESCE(p_adeguamenti, '[]'::jsonb)) x
            WHERE (x->>'alloggio_pk')::INTEGER = r.pk;

            IF v_tipo_nuovo IS NULL THEN
                RAISE EXCEPTION
                    'In «%» %: va scelto con quale sistemazione sostituirla.',
                    r.descrizione,
                    CASE WHEN cardinality(v_restano) = 1 THEN 'resterebbe 1 persona'
                         ELSE 'resterebbero ' || cardinality(v_restano) || ' persone' END
                    USING ERRCODE = 'check_violation';
            END IF;

            SELECT t.tipo_alloggio_numero_occupanti INTO v_cap_nuova
            FROM ana_tipo_alloggio t WHERE t.tipo_alloggio_id = v_tipo_nuovo;

            IF v_cap_nuova IS DISTINCT FROM cardinality(v_restano) THEN
                RAISE EXCEPTION
                    'La sistemazione scelta per chi resta in «%» non ha la capienza giusta: servono % posti.',
                    r.descrizione, cardinality(v_restano)
                    USING ERRCODE = 'check_violation';
            END IF;

            UPDATE mov_clienti_alloggi
               SET tipo_alloggio_id_fk = v_tipo_nuovo,
                   cliente_id1_fk = v_restano[1], cliente_id2_fk = v_restano[2],
                   cliente_id3_fk = v_restano[3], cliente_id4_fk = v_restano[4],
                   cliente_id5_fk = v_restano[5], cliente_id6_fk = v_restano[6]
             WHERE mov_clienti_alloggio_pk = r.pk;
        END LOOP;
    END IF;

    RETURN v_pk;
END;
$$;

COMMENT ON FUNCTION fn_alloggi_salva_camera(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER[], JSONB, VARCHAR) IS
'⛔️ **L''unica scrittura** di mov_clienti_alloggi per il gestionale e per il sito. Salva una
sistemazione e, nella stessa transazione, toglie i suoi occupanti dalle altre della stessa
partenza: quelle che restano vuote si eliminano, quelle che restano con meno persone prendono
il tipo indicato in p_adeguamenti — che va DETTO, perche'' il software non sceglie da solo.
La capienza deve corrispondere agli occupanti, tranne per il genere NESSUNA.
p_created_by serve al sito, che traccia chi ha creato la riga.';


-- ---------------------------------------------------------------------------
-- 2. Le strade vecchie, che nessuno deve poter prendere piu'
-- ---------------------------------------------------------------------------
-- ⚠️ Non basta smettere di chiamarle: finche' esistono, la prossima persona che
-- deve scrivere una sistemazione ne trova cinque e sceglie a caso — e quattro non
-- controllano niente. Verificato prima di eliminarle che nessuno le usi piu', ne'
-- il gestionale, ne' il sito, ne' altre funzioni.
DROP FUNCTION IF EXISTS fn_wizard_insert_alloggio_assegnato(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, VARCHAR);
DROP FUNCTION IF EXISTS sp_mov_clienti_alloggi_create(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS sp_mov_clienti_alloggi_update(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS sp_assign_to_first_free_slot(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS sp_resolve_room_violation_move(INTEGER, INTEGER, INTEGER[]);
