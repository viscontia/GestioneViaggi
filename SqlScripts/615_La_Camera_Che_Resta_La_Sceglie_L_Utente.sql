-- =============================================================================
-- 615 — Anche la sistemazione di chi RESTA la sceglie chi lavora
-- =============================================================================
--
-- Adriano, 2026-09-06: «bisogna fargli scegliere all'utente che sta operando quale
-- tipo di camera = capienza vuole assegnare. Nel tuo esempio rischi di mettere in
-- matrimoniale due amici che vogliono letti separati».
--
-- Ha ragione, ed e' la stessa obiezione di mezz'ora prima: il programma non sa se
-- due persone sono una coppia o due amici. Lo script 614 adeguava da solo il tipo
-- della sistemazione di partenza — una tripla con due dentro diventava matrimoniale —
-- ⚠️ e lo faceva in SILENZIO, su una camera che l'operatore non stava nemmeno
-- guardando.
--
-- Ora la funzione non sceglie: se una sistemazione resta con meno persone e non le
-- e' stato detto che cosa diventa, RIFIUTA e dice quale. Chi chiama deve chiedere.
--
-- ⚠️ Il rifiuto e' preferibile al silenzio anche perche' non c'e' modo di correggere
-- dopo: una matrimoniale assegnata a due amici non lascia traccia di essere stata
-- decisa dal programma. Si scoprirebbe in albergo.
-- =============================================================================

DROP FUNCTION IF EXISTS fn_alloggi_salva_camera(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER[]);

CREATE OR REPLACE FUNCTION fn_alloggi_salva_camera(
    p_alloggio_pk      INTEGER,
    p_viaggio_id       INTEGER,
    p_data_viaggio_id  INTEGER,
    p_tipo_alloggio_id INTEGER,
    p_clienti          INTEGER[],
    -- [{"alloggio_pk": 123, "tipo_id": 4}, …] — che cosa diventa ogni sistemazione
    -- che resta con meno persone. Vuoto se nessuno si sposta.
    p_adeguamenti      JSONB DEFAULT '[]'::jsonb
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
    -- e usciva «la stessa persona due volte», che non c'entra niente. Una sistemazione senza
    -- occupanti la rifiuta il controllo di capienza qui sotto, con il messaggio giusto.
    IF v_quanti > 0
       AND array_length(v_clienti, 1) IS DISTINCT FROM cardinality(ARRAY(SELECT DISTINCT unnest(v_clienti))) THEN
        RAISE EXCEPTION 'La stessa persona è indicata due volte nella stessa sistemazione.'
            USING ERRCODE = 'check_violation';
    END IF;

    -- ⚠️ Il viaggio NON si prende da chi chiama: lo sa gia' la partenza. Passandolo si puo'
    -- sbagliare — provato il 2026-09-06, una camera finiva agganciata a un viaggio diverso da
    -- quello della sua partenza, e nessuno se ne sarebbe accorto. Il parametro resta per
    -- compatibilita' con le firme precedenti, ma se non coincide si rifiuta: e' un difetto di
    -- chi chiama, e va visto subito invece di lasciare dati storti.
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

    -- ⚠️ «Nessuna sistemazione» ha capienza 0 e un occupante: e' il modo in cui si
    -- registra chi dorme nel proprio mezzo, non un'eccezione alla regola.
    IF v_genere <> 'NESSUNA' AND v_quanti <> v_capienza THEN
        RAISE EXCEPTION
            '«%» ospita % persone, ne %. La capienza deve corrispondere: se serve una sistemazione diversa, cambia il tipo.',
            v_tipo, v_capienza,
            CASE WHEN v_quanti = 0 THEN 'è stata indicata nessuna'
                 WHEN v_quanti = 1 THEN 'è stata indicata 1'
                 ELSE 'sono state indicate ' || v_quanti END
            USING ERRCODE = 'check_violation';
    END IF;

    -- ---------------------------------------------------------------------
    -- 1. La sistemazione di destinazione
    -- ---------------------------------------------------------------------
    IF COALESCE(p_alloggio_pk, 0) = 0 THEN
        INSERT INTO mov_clienti_alloggi (
            mov_clienti_alloggio_pk,
            viaggio_id_fk, data_viaggio_id_fk, tipo_alloggio_id_fk,
            cliente_id1_fk, cliente_id2_fk, cliente_id3_fk,
            cliente_id4_fk, cliente_id5_fk, cliente_id6_fk)
        VALUES (nextval('mov_clienti_alloggi_seq'),
                v_viaggio, p_data_viaggio_id, p_tipo_alloggio_id,
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
                -- Una sistemazione senza nessuno non e' una sistemazione: e' una
                -- prenotazione che qualcuno paga. Si elimina, e non c'e' niente da chiedere.
                DELETE FROM mov_clienti_alloggi WHERE mov_clienti_alloggio_pk = r.pk;
                CONTINUE;
            END IF;

            -- ⛔️ Che cosa diventa lo decide CHI LAVORA, non questa funzione: due persone
            -- possono volere una matrimoniale o due letti singoli, e da qui non si sa.
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

            -- ⚠️ Gli occupanti si ricompattano: lasciare un buco in mezzo alle sei colonne
            -- significa che chi legge «il primo occupante» trova NULL.
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

COMMENT ON FUNCTION fn_alloggi_salva_camera(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER[], JSONB) IS
'Salva una sistemazione e, nella stessa transazione, toglie i suoi occupanti dalle altre
sistemazioni della STESSA partenza. Quelle che restano vuote si eliminano; ⛔️ per quelle che
restano con meno persone il tipo nuovo va INDICATO in p_adeguamenti — la funzione non sceglie
da sola, perche'' due persone possono volere una matrimoniale o due letti singoli e da qui non
si sa. La capienza deve sempre corrispondere agli occupanti, tranne per il genere NESSUNA.';
