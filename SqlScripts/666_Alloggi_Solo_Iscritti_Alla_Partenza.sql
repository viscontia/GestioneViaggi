-- ============================================================================
-- 666 — In camera solo chi e' iscritto alla partenza
--
-- Trovato il 2026-09-26 nella revisione finale del lavoro L4/L13 sul sito Flask:
-- /api/session/assegna-alloggio accettava qualunque lista di id, e il finalizza
-- la passava a fn_alloggi_salva_camera, che non controllava ne' l'iscrizione ne'
-- l'azienda. Il blocco «Chi arriva da un'altra sistemazione, ne esce» toglieva
-- cosi' dalle loro camere persone iscritte da altri, e cancellava le camere
-- rimaste vuote. Il sito ora rifiuta id estranei alla sessione; qui la stessa
-- regola la fa rispettare il database, a chiunque chiami.
--
-- VERIFICATO prima di scrivere, in PROD: 765 occupanti di camera, 0 non iscritti
-- alla loro partenza, 0 di un'altra azienda. Il gestionale
-- (QuickAddParticipantDialog, MovClientiAlloggiService) e il sito iscrivono
-- prima di sistemare in camera.
--
-- Indipendente da 660–663. ⏳ Applicato in locale; PROD con il rilascio L4/L13.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_alloggi_salva_camera(p_alloggio_pk integer, p_viaggio_id integer, p_data_viaggio_id integer, p_tipo_alloggio_id integer, p_clienti integer[], p_adeguamenti jsonb DEFAULT '[]'::jsonb, p_created_by character varying DEFAULT NULL::character varying)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
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

    -- ⛔️ In camera solo chi e' iscritto a QUESTA partenza, e cliente della stessa
    -- azienda del viaggio (script 666). Senza, un id qualunque mandato dal sito
    -- pubblico veniva tolto dalla sua camera, e la camera rimasta vuota cancellata.
    -- Il gestionale e il sito iscrivono PRIMA di sistemare in camera, quindi a chi
    -- lavora bene questa regola non cambia niente.
    IF EXISTS (
        SELECT 1 FROM unnest(v_clienti) c
         WHERE NOT EXISTS (SELECT 1 FROM mov_clienti_viaggi m
                            WHERE m.data_viaggio_id_fk = p_data_viaggio_id
                              AND m.cliente_id_fk = c)
            OR NOT EXISTS (SELECT 1 FROM ana_clienti k
                             JOIN ana_viaggi v ON v.viaggio_id = v_viaggio
                            WHERE k.cliente_id = c AND k.azienda_fk = v.azienda_id)) THEN
        RAISE EXCEPTION 'In una sistemazione possono stare solo persone iscritte a questa partenza.'
            USING ERRCODE = 'check_violation';
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
$function$;
