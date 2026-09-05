-- =============================================================================
-- 586 — Cancellare un partecipante si porta dietro ciò che dipendeva da lui
-- =============================================================================
--
-- Verificato il 2026-09-05 eseguendo la cancellazione vera dentro una transazione
-- annullata. `fn_mov_clienti_viaggi_delete` cancellava UNA riga e nient'altro,
-- lasciando indietro due cose:
--
-- 1. I PASSEGGERI DEL PILOTA. Nella prova, cancellando un pilota, tre passeggeri
--    sono rimasti iscritti con `cliente_pilota_id_fk` che punta a una persona non
--    più sul viaggio. Nessun errore: il vincolo punta ad `ana_clienti` — cioè
--    all'anagrafica, dove il cliente continua a esistere — non all'iscrizione.
--    Senza pilota quei passeggeri non hanno un mezzo, e restare iscritti non ha
--    senso: vanno via con lui.
--
-- 2. IL LETTO. La cancellazione dal gestionale passa da
--    `chk_room_consistency_on_delete`, che si ferma solo se nella camera RESTANO
--    altri occupanti in numero insufficiente. Se il cancellato era l'unico
--    occupante non c'era violazione, la cancellazione procedeva, e la camera
--    restava con dentro il suo nome — perché nessuna funzione la ripuliva. Il
--    commento nel codice («DB procedure updated to be safe and clean old rooms»)
--    diceva il falso.
--    Una persona che occupa un letto senza essere iscritta falsa il conto dei
--    posti verso l'albergo.
--
-- La regola decisa: i passeggeri di un pilota cancellato si cancellano tutti, e
-- chi non è più iscritto non occupa più un letto. Sta qui e non nel C# perché la
-- stessa cancellazione la fanno il gestionale e — un domani — il sito.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Che cosa succederebbe: da chiedere PRIMA, per poterlo mostrare all'operatore
-- ---------------------------------------------------------------------------
-- Cancellare un pilota puo' togliere dal viaggio persone che l'operatore non ha
-- nominato. Deve poterlo sapere prima di confermare, non scoprirlo dopo.
CREATE OR REPLACE FUNCTION fn_mov_clienti_viaggi_cancellazione_effetti(
    p_data_viaggio_id INTEGER,
    p_cliente_id      INTEGER
)
RETURNS TABLE(
    cliente_id  INTEGER,
    nominativo  TEXT,
    ruolo       VARCHAR,
    motivo      VARCHAR,   -- RICHIESTO | PASSEGGERO_DEL_PILOTA
    email       VARCHAR
)
LANGUAGE sql
STABLE
AS $$
    SELECT m.cliente_id_fk,
           (c.cliente_cognome || ' ' || c.cliente_nome)::TEXT,
           tp.tipo_partecipante_descrizione,
           CASE WHEN m.cliente_id_fk = p_cliente_id
                THEN 'RICHIESTO' ELSE 'PASSEGGERO_DEL_PILOTA' END::VARCHAR,
           NULLIF(btrim(c.cliente_email), '')::VARCHAR
    FROM mov_clienti_viaggi m
    JOIN ana_clienti c                ON c.cliente_id = m.cliente_id_fk
    LEFT JOIN ana_tipo_partecipante tp ON tp.tipo_partecipante_id = m.tipo_partecipante_id_fk
    WHERE m.data_viaggio_id_fk = p_data_viaggio_id
      AND (
            m.cliente_id_fk = p_cliente_id
            -- I passeggeri agganciati a lui: solo se lui e' davvero un pilota,
            -- altrimenti un passeggero che punta a se stesso si trascinerebbe via
            -- i compagni di mezzo.
            OR (m.cliente_pilota_id_fk = p_cliente_id
                AND m.cliente_id_fk <> p_cliente_id
                AND EXISTS (SELECT 1 FROM mov_clienti_viaggi pil
                            JOIN ana_tipo_partecipante tpp
                              ON tpp.tipo_partecipante_id = pil.tipo_partecipante_id_fk
                            WHERE pil.data_viaggio_id_fk = p_data_viaggio_id
                              AND pil.cliente_id_fk = p_cliente_id
                              AND tpp.tipo_partecipante_pilota))
          )
    ORDER BY CASE WHEN m.cliente_id_fk = p_cliente_id THEN 0 ELSE 1 END,
             c.cliente_cognome, c.cliente_nome;
$$;

COMMENT ON FUNCTION fn_mov_clienti_viaggi_cancellazione_effetti(INTEGER, INTEGER) IS
'Chi esce dal viaggio se si cancella questo partecipante: lui, e — se e'' un pilota — i
suoi passeggeri, che senza di lui non hanno un mezzo. Da chiamare PRIMA di cancellare,
per mostrare all''operatore chi altro sta per togliere.';


-- ---------------------------------------------------------------------------
-- Togliere una persona dalle camere
-- ---------------------------------------------------------------------------
-- Le sei colonne `cliente_idN_fk` sono posizioni, non un elenco: si azzera quella
-- giusta. Se la camera resta senza nessuno la riga sparisce, altrimenti resterebbe
-- una camera prenotata e vuota nel conto verso l'albergo.
CREATE OR REPLACE FUNCTION fn_mov_clienti_alloggi_togli_cliente(
    p_data_viaggio_id INTEGER,
    p_cliente_id      INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE v_righe INTEGER; v_uno INTEGER;
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

    -- Dove restano altri occupanti si libera il suo posto e basta.
    UPDATE mov_clienti_alloggi SET
        cliente_id1_fk = NULLIF(cliente_id1_fk, p_cliente_id),
        cliente_id2_fk = NULLIF(cliente_id2_fk, p_cliente_id),
        cliente_id3_fk = NULLIF(cliente_id3_fk, p_cliente_id),
        cliente_id4_fk = NULLIF(cliente_id4_fk, p_cliente_id),
        cliente_id5_fk = NULLIF(cliente_id5_fk, p_cliente_id),
        cliente_id6_fk = NULLIF(cliente_id6_fk, p_cliente_id)
    WHERE data_viaggio_id_fk = p_data_viaggio_id
      AND p_cliente_id IN (cliente_id1_fk, cliente_id2_fk, cliente_id3_fk,
                           cliente_id4_fk, cliente_id5_fk, cliente_id6_fk);
    GET DIAGNOSTICS v_uno = ROW_COUNT;
    v_righe := v_righe + v_uno;

    RETURN v_righe;
END;
$$;

COMMENT ON FUNCTION fn_mov_clienti_alloggi_togli_cliente(INTEGER, INTEGER) IS
'Libera il posto letto di un cliente su una partenza. Se la camera resta vuota la riga
viene eliminata: una camera prenotata e senza occupanti falserebbe il conto verso
l''albergo.';


-- ---------------------------------------------------------------------------
-- La cancellazione, ora completa
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_mov_clienti_viaggi_delete(
    p_viaggio_id      INTEGER,
    p_data_viaggio_id INTEGER,
    p_cliente_id      INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
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
        PERFORM fn_mov_clienti_alloggi_togli_cliente(p_data_viaggio_id, r.cliente_id);

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

COMMENT ON FUNCTION fn_mov_clienti_viaggi_delete(INTEGER, INTEGER, INTEGER) IS
'Cancella un partecipante e cio'' che dipendeva da lui: i passeggeri, se e'' un pilota, e
il posto letto di ognuno. Prima cancellava una riga sola, lasciando passeggeri agganciati
a un pilota non piu'' iscritto e persone in camera senza iscrizione. Restituisce quante
iscrizioni sono state cancellate.';


-- ---------------------------------------------------------------------------
-- I dati gia' sporchi
-- ---------------------------------------------------------------------------
-- Chi occupa un letto su una partenza a cui non risulta iscritto viene tolto: la
-- riga non descrive nessuno che partira'. ⚠️ Su PROD (azienda 2) e' UN caso solo.
-- Le iscrizioni non si toccano: togliere qualcuno da un viaggio e' una decisione,
-- non una pulizia.
-- Un posto vuoto (NULL) e' regolare: non c'e' nessuno da controllare.
CREATE OR REPLACE FUNCTION fn_e_iscritto(p_data_viaggio_id INTEGER, p_cliente_id INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT p_cliente_id IS NULL
        OR EXISTS (SELECT 1 FROM mov_clienti_viaggi m
                   WHERE m.data_viaggio_id_fk = p_data_viaggio_id
                     AND m.cliente_id_fk = p_cliente_id);
$$;

-- Prima le camere in cui NESSUNO degli occupanti risulta iscritto: si eliminano,
-- perche' svuotarle violerebbe `chk_almeno_un_cliente`.
DELETE FROM mov_clienti_alloggi a
WHERE NOT EXISTS (
    SELECT 1 FROM unnest(ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                               a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk]) x
    WHERE x IS NOT NULL AND fn_e_iscritto(a.data_viaggio_id_fk, x));

-- Poi, dove almeno un iscritto resta, si liberano i posti di chi iscritto non e'.
UPDATE mov_clienti_alloggi a SET
    cliente_id1_fk = CASE WHEN fn_e_iscritto(a.data_viaggio_id_fk, a.cliente_id1_fk) THEN a.cliente_id1_fk END,
    cliente_id2_fk = CASE WHEN fn_e_iscritto(a.data_viaggio_id_fk, a.cliente_id2_fk) THEN a.cliente_id2_fk END,
    cliente_id3_fk = CASE WHEN fn_e_iscritto(a.data_viaggio_id_fk, a.cliente_id3_fk) THEN a.cliente_id3_fk END,
    cliente_id4_fk = CASE WHEN fn_e_iscritto(a.data_viaggio_id_fk, a.cliente_id4_fk) THEN a.cliente_id4_fk END,
    cliente_id5_fk = CASE WHEN fn_e_iscritto(a.data_viaggio_id_fk, a.cliente_id5_fk) THEN a.cliente_id5_fk END,
    cliente_id6_fk = CASE WHEN fn_e_iscritto(a.data_viaggio_id_fk, a.cliente_id6_fk) THEN a.cliente_id6_fk END
WHERE NOT (
    fn_e_iscritto(a.data_viaggio_id_fk, a.cliente_id1_fk) AND
    fn_e_iscritto(a.data_viaggio_id_fk, a.cliente_id2_fk) AND
    fn_e_iscritto(a.data_viaggio_id_fk, a.cliente_id3_fk) AND
    fn_e_iscritto(a.data_viaggio_id_fk, a.cliente_id4_fk) AND
    fn_e_iscritto(a.data_viaggio_id_fk, a.cliente_id5_fk) AND
    fn_e_iscritto(a.data_viaggio_id_fk, a.cliente_id6_fk));

