-- =============================================================================
-- 616 — La capienza vale per chiunque scriva, non solo per le due interfacce
-- =============================================================================
--
-- Decisione di Adriano del 2026-09-06: «le camere vanno assegnate in modo rigoroso
-- sul rapporto persone/capienza e non ci devono essere scappatoie. Se poi con
-- l'albergo si verificheranno situazioni particolari rimarranno offline».
--
-- Lo script 614 aveva messo il controllo in `fn_alloggi_salva_camera`, cioe' sulla
-- strada che usa il gestionale. ⚠️ La prova G1e ha mostrato il buco: scrivendo a
-- mano — o da qualunque altra strada — una tenda da 2 con un occupante solo passa,
-- perche' il trigger guarda il GENERE e non la capienza. Ora la guarda.
--
-- ⚠️ **Il genere NESSUNA resta escluso, e non e' una scappatoia**: «nessuna
-- sistemazione» ha capienza 0 con un occupante — e' il modo in cui si registra chi
-- dorme nel proprio mezzo. Una regola secca le romperebbe tutte.
--
-- ⚠️ **Cancellare qualcuno da una camera condivisa lascia la camera sotto capienza**,
-- e con questo controllo la cancellazione verrebbe RIFIUTATA: non si potrebbe piu'
-- togliere nessuno da una doppia. Per questo la cancellazione ora accetta di sapere
-- che cosa diventa la camera di chi resta, e lo applica NELLA STESSA UPDATE.
-- Chi lo chiede e' il gestionale; la scelta e' dell'operatore, non del software:
-- «rischi di mettere in matrimoniale due amici che vogliono letti separati».
--
-- ⚠️ **Le righe storiche gia' incoerenti non vengono toccate**, ma da qui in poi non
-- saranno piu' modificabili finche' non si sistemano. Misurate il 2026-09-06:
-- 11 in locale (9 azienda 2, 2 azienda 6), 7 su PROD azienda 2. La bonifica e' nello
-- script 617, separato perche' cambia dati veri e la decisione e' di Adriano.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Il controllo, dentro la guardia che c'e' gia'
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_guardia_alloggio_coerente()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_genere      INTEGER;
    v_codice      VARCHAR;
    v_tipo_desc   VARCHAR;
    v_capienza    INTEGER;
    v_occupanti   INTEGER;
    v_pern_fk     INTEGER;
    v_pern_desc   VARCHAR;
    v_ammessi     TEXT;
BEGIN
    SELECT t.genere_fk, g.genere_codice, t.tipo_alloggio_descrizione, t.tipo_alloggio_numero_occupanti
      INTO v_genere, v_codice, v_tipo_desc, v_capienza
    FROM ana_tipo_alloggio t
    JOIN ana_alloggio_generi g ON g.genere_id = t.genere_fk
    WHERE t.tipo_alloggio_id = NEW.tipo_alloggio_id_fk;

    -- Tipo sconosciuto: non e' questa guardia a doverlo dire, ci pensa la chiave esterna.
    IF v_genere IS NULL THEN
        RETURN NEW;
    END IF;

    -- «Nessuna sistemazione» vale sempre, su qualunque viaggio, e ha capienza 0 con un
    -- occupante: e' il modo in cui si registra chi dorme nel proprio mezzo.
    IF v_codice = 'NESSUNA' THEN
        RETURN NEW;
    END IF;

    -- -----------------------------------------------------------------------
    -- La capienza deve corrispondere agli occupanti
    -- -----------------------------------------------------------------------
    v_occupanti := (SELECT count(*) FROM unnest(ARRAY[
                        NEW.cliente_id1_fk, NEW.cliente_id2_fk, NEW.cliente_id3_fk,
                        NEW.cliente_id4_fk, NEW.cliente_id5_fk, NEW.cliente_id6_fk]) x
                    WHERE x IS NOT NULL);

    IF v_occupanti <> v_capienza THEN
        RAISE EXCEPTION
            '«%» ospita % persone, ne %. La capienza deve corrispondere: cambia il tipo di sistemazione, oppure gli occupanti.',
            v_tipo_desc, v_capienza,
            CASE WHEN v_occupanti = 0 THEN 'è stata indicata nessuna'
                 WHEN v_occupanti = 1 THEN 'è stata indicata 1'
                 ELSE 'sono state indicate ' || v_occupanti END
            USING ERRCODE = 'check_violation';
    END IF;

    -- -----------------------------------------------------------------------
    -- Il genere deve essere previsto dal viaggio
    -- -----------------------------------------------------------------------
    SELECT v.viaggio_tipo_pernottamento_fk, p.ana_tipo_pernottamento_descrizione
      INTO v_pern_fk, v_pern_desc
    FROM ana_viaggi v
    LEFT JOIN ana_tipo_pernottamento p ON p.ana_tipo_pernottamento_id = v.viaggio_tipo_pernottamento_fk
    WHERE v.viaggio_id = NEW.viaggio_id_fk;

    IF EXISTS (SELECT 1 FROM ana_tipo_pernottamento_generi pg
               WHERE pg.pernottamento_fk = v_pern_fk AND pg.genere_fk = v_genere) THEN
        RETURN NEW;
    END IF;

    SELECT string_agg(g.genere_descrizione, ', ' ORDER BY g.genere_ordine)
      INTO v_ammessi
    FROM ana_tipo_pernottamento_generi pg
    JOIN ana_alloggio_generi g ON g.genere_id = pg.genere_fk
    WHERE pg.pernottamento_fk = v_pern_fk;

    RAISE EXCEPTION
        '«%» non e'' una sistemazione prevista da questo viaggio (pernottamento: %). Ammesse: %.',
        v_tipo_desc,
        COALESCE(v_pern_desc, 'non indicato'),
        COALESCE(v_ammessi, 'nessuna, oltre a «nessuna sistemazione»')
        USING ERRCODE = 'check_violation';
END;
$$;

COMMENT ON FUNCTION fn_guardia_alloggio_coerente() IS
'Guardia su mov_clienti_alloggi: il genere dev''essere previsto dal viaggio e la capienza
deve corrispondere agli occupanti. ⚠️ Il genere NESSUNA e'' escluso da entrambi i controlli —
capienza 0 con un occupante e'' come si registra chi dorme nel proprio mezzo.
⛔️ Nessuna scappatoia: vale per il gestionale, per il sito e per una UPDATE a mano.';


-- ---------------------------------------------------------------------------
-- 2. Che cosa resta scoperto se cancello questa persona
-- ---------------------------------------------------------------------------
-- Serve a CHIEDERE prima: quali sistemazioni resterebbero con meno gente, e con chi.
-- ⚠️ Tiene conto della cascata: cancellando un pilota se ne vanno anche i suoi
-- passeggeri, e le camere toccate possono essere piu' di una.
CREATE OR REPLACE FUNCTION fn_mov_clienti_viaggi_cancellazione_camere(
    p_data_viaggio_id INTEGER,
    p_cliente_id      INTEGER
)
RETURNS TABLE(alloggio_pk INTEGER, tipo_descrizione VARCHAR, chi_esce TEXT, restano TEXT, quanti_restano INTEGER)
LANGUAGE sql STABLE AS $$
    WITH escono AS (
        SELECT e.cliente_id FROM fn_mov_clienti_viaggi_cancellazione_effetti(p_data_viaggio_id, p_cliente_id) e
    ),
    camere AS (
        SELECT a.mov_clienti_alloggio_pk AS pk,
               t.tipo_alloggio_descrizione AS tipo,
               ARRAY(SELECT c FROM unnest(ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                                                a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk]) c
                     WHERE c IS NOT NULL) AS dentro
        FROM mov_clienti_alloggi a
        JOIN ana_tipo_alloggio t ON t.tipo_alloggio_id = a.tipo_alloggio_id_fk
        JOIN ana_alloggio_generi g ON g.genere_id = t.genere_fk
        WHERE a.data_viaggio_id_fk = p_data_viaggio_id
          AND g.genere_codice <> 'NESSUNA'
    )
    SELECT c.pk, c.tipo,
           (SELECT string_agg(cl.cliente_cognome || ' ' || cl.cliente_nome, ', ')
              FROM ana_clienti cl WHERE cl.cliente_id = ANY(c.dentro)
               AND cl.cliente_id IN (SELECT cliente_id FROM escono))::TEXT,
           (SELECT string_agg(cl.cliente_cognome || ' ' || cl.cliente_nome, ', ')
              FROM ana_clienti cl WHERE cl.cliente_id = ANY(c.dentro)
               AND cl.cliente_id NOT IN (SELECT cliente_id FROM escono))::TEXT,
           (SELECT count(*)::INTEGER FROM unnest(c.dentro) x
             WHERE x NOT IN (SELECT cliente_id FROM escono))
    FROM camere c
    WHERE EXISTS (SELECT 1 FROM unnest(c.dentro) x WHERE x IN (SELECT cliente_id FROM escono))
      -- Solo quelle che restano abitate: se si svuotano vengono eliminate, non c'e' niente da chiedere.
      AND EXISTS (SELECT 1 FROM unnest(c.dentro) x WHERE x NOT IN (SELECT cliente_id FROM escono));
$$;

COMMENT ON FUNCTION fn_mov_clienti_viaggi_cancellazione_camere(INTEGER, INTEGER) IS
'Le sistemazioni che resterebbero con meno persone cancellando questo partecipante (e, se
guida, i suoi passeggeri). Serve a CHIEDERE con quale sistemazione sostituirle prima di
cancellare: il software non lo decide da solo.';


-- ---------------------------------------------------------------------------
-- 3. Togliere una persona dal letto, adeguando la sistemazione di chi resta
-- ---------------------------------------------------------------------------
-- ⚠️ Il tipo nuovo e gli occupanti si scrivono NELLA STESSA UPDATE. Farlo in due
-- passi non funzionerebbe affatto: fra l'uno e l'altro la camera sarebbe sotto
-- capienza, e il trigger la rifiuterebbe.
-- ⚠️ La firma vecchia va TOLTA, non affiancata: con entrambe presenti una chiamata a tre
-- parametri diventa ambigua e PostgreSQL la rifiuta, oppure — peggio — chi chiama continua a
-- usare la vecchia e salta l'adeguamento senza che nessuno se ne accorga.
DROP FUNCTION IF EXISTS fn_mov_clienti_alloggi_togli_cliente(INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION fn_mov_clienti_alloggi_togli_cliente(
    p_data_viaggio_id INTEGER,
    p_cliente_id      INTEGER,
    -- [{"alloggio_pk": 123, "tipo_id": 4}, …] — che cosa diventa ogni sistemazione
    -- che resta abitata. Deciso dall'operatore, non da qui.
    p_adeguamenti     JSONB DEFAULT '[]'::jsonb
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_righe INTEGER; v_uno INTEGER;
BEGIN
    -- La camera in cui era SOLO lui si elimina, non si svuota: c'e' un vincolo
    -- (`chk_almeno_un_cliente`) che vieta una camera senza occupanti, ed e' giusto
    -- cosi' — una camera prenotata e vuota falserebbe il conto verso l'albergo.
    DELETE FROM mov_clienti_alloggi
    WHERE data_viaggio_id_fk = p_data_viaggio_id
      AND p_cliente_id IN (cliente_id1_fk, cliente_id2_fk, cliente_id3_fk,
                           cliente_id4_fk, cliente_id5_fk, cliente_id6_fk)
      AND 1 = (SELECT count(*) FROM unnest(ARRAY[cliente_id1_fk, cliente_id2_fk,
                    cliente_id3_fk, cliente_id4_fk, cliente_id5_fk, cliente_id6_fk]) x
               WHERE x IS NOT NULL);
    GET DIAGNOSTICS v_righe = ROW_COUNT;

    -- Dove restano altri occupanti si libera il suo posto E si adegua il tipo, insieme.
    UPDATE mov_clienti_alloggi a SET
        cliente_id1_fk = NULLIF(a.cliente_id1_fk, p_cliente_id),
        cliente_id2_fk = NULLIF(a.cliente_id2_fk, p_cliente_id),
        cliente_id3_fk = NULLIF(a.cliente_id3_fk, p_cliente_id),
        cliente_id4_fk = NULLIF(a.cliente_id4_fk, p_cliente_id),
        cliente_id5_fk = NULLIF(a.cliente_id5_fk, p_cliente_id),
        cliente_id6_fk = NULLIF(a.cliente_id6_fk, p_cliente_id),
        tipo_alloggio_id_fk = COALESCE(
            (SELECT (x->>'tipo_id')::INTEGER
               FROM jsonb_array_elements(COALESCE(p_adeguamenti, '[]'::jsonb)) x
              WHERE (x->>'alloggio_pk')::INTEGER = a.mov_clienti_alloggio_pk),
            a.tipo_alloggio_id_fk)
    WHERE a.data_viaggio_id_fk = p_data_viaggio_id
      AND p_cliente_id IN (a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                           a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk);
    GET DIAGNOSTICS v_uno = ROW_COUNT;

    RETURN v_righe + v_uno;
END;
$$;

COMMENT ON FUNCTION fn_mov_clienti_alloggi_togli_cliente(INTEGER, INTEGER, JSONB) IS
'Toglie una persona dalle sistemazioni di una partenza: quella in cui era solo si elimina,
quelle che restano abitate perdono il suo posto e ⚠️ prendono il tipo indicato in
p_adeguamenti — nella stessa UPDATE, perche'' altrimenti resterebbero un istante sotto
capienza e il trigger le rifiuterebbe. Senza adeguamento il tipo resta com''e'', e se non
corrisponde piu'' agli occupanti la scrittura viene rifiutata: e'' voluto, cosi'' chi cancella
non lascia dietro una sistemazione incoerente.';


-- ---------------------------------------------------------------------------
-- 4. La cancellazione porta con se' le scelte fatte
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_mov_clienti_viaggi_delete(INTEGER, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION fn_mov_clienti_viaggi_delete(
    p_viaggio_id      INTEGER,
    p_data_viaggio_id INTEGER,
    p_cliente_id      INTEGER,
    p_adeguamenti     JSONB DEFAULT '[]'::jsonb
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_righe INTEGER := 0;
    v_uno   INTEGER;
    r       RECORD;
BEGIN
    -- Chi esce: la stessa risposta che l'operatore ha appena visto e confermato.
    -- Una funzione sola decide, cosi' quello che gli e' stato mostrato e quello che
    -- succede non possono divergere.
    FOR r IN SELECT e.cliente_id
             FROM fn_mov_clienti_viaggi_cancellazione_effetti(p_data_viaggio_id, p_cliente_id) e
    LOOP
        -- Prima il letto, poi l'iscrizione: cosi' non resta mai, nemmeno per un
        -- istante, un occupante che non risulta iscritto.
        PERFORM fn_mov_clienti_alloggi_togli_cliente(p_data_viaggio_id, r.cliente_id, p_adeguamenti);

        DELETE FROM mov_clienti_viaggi
        WHERE viaggio_id_fk = p_viaggio_id
          AND data_viaggio_id_fk = p_data_viaggio_id
          AND cliente_id_fk = r.cliente_id;
        GET DIAGNOSTICS v_uno = ROW_COUNT;
        v_righe := v_righe + v_uno;
    END LOOP;

    RETURN v_righe;
END;
$$;
