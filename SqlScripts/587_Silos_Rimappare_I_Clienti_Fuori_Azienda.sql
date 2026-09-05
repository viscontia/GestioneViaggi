-- =============================================================================
-- 587 — Chi è iscritto ai viaggi di un'azienda dev'essere un cliente DI QUELL'AZIENDA
-- =============================================================================
--
-- Trovato il 2026-09-05 cercando i riferimenti PROD del difetto 81. Le aziende sono
-- silos rigidi — gli unici dati condivisi sono `ana_tipo_viaggi` e
-- `web_tipi_viaggio_descrizioni` — ma nei movimenti il confine non è mai stato
-- imposto: `mov_clienti_viaggi` e `mov_clienti_alloggi` puntano ad `ana_clienti` e
-- basta, senza guardare a quale azienda appartenga il cliente o il viaggio.
--
-- ⚠️ Il residuo è dell'importazione da Oracle (confermato dall'utente il 2026-09-05):
-- di lì sono entrate iscrizioni a viaggi SFT (azienda 2) fatte con l'anagrafica
-- dell'azienda 6.
--
-- Misura su PROD, 2026-09-05:
--   26 iscrizioni (25 persone) su viaggi dell'azienda 2 con cliente di un'altra
--   29 riferimenti al pilota che escono dal silo
--
-- ⚠️ MA il rimappaggio «prendi il suo codice nell'azienda 2» si può fare solo dove
-- quel codice esiste, e su PROD **esiste per 1 persona su 25**. Per le altre 24
-- l'anagrafica nell'azienda 2 non c'è: andrebbe creata, che è un'altra decisione.
-- Questo script quindi fa la parte sicura e **lascia intatto il resto**, elencandolo.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Il gemello: la stessa persona nell'altra azienda
-- ---------------------------------------------------------------------------
-- Deve essere UNO e non ambiguo. Se i candidati sono zero o più d'uno la funzione
-- non risponde: su un'anagrafica si preferisce non fare, che fare a caso.
CREATE OR REPLACE FUNCTION fn_cliente_gemello_in_azienda(
    p_cliente_id INTEGER,
    p_azienda_id INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_orig  ana_clienti%ROWTYPE;
    v_ids   INTEGER[];
BEGIN
    SELECT * INTO v_orig FROM ana_clienti WHERE cliente_id = p_cliente_id;
    IF NOT FOUND OR v_orig.azienda_fk = p_azienda_id THEN
        RETURN NULL;
    END IF;

    -- 1) Il codice fiscale, quando c'e': identifica la persona da solo.
    IF nullif(btrim(v_orig.cliente_codicefiscale), '') IS NOT NULL THEN
        SELECT array_agg(g.cliente_id) INTO v_ids FROM ana_clienti g
        WHERE g.azienda_fk = p_azienda_id
          AND upper(btrim(g.cliente_codicefiscale)) = upper(btrim(v_orig.cliente_codicefiscale));
        IF array_length(v_ids, 1) = 1 THEN RETURN v_ids[1]; END IF;
    END IF;

    -- 2) Altrimenti cognome, nome e data di nascita. La data e' obbligatoria: senza,
    --    due omonimi diventerebbero la stessa persona.
    IF v_orig.cliente_data_nascita IS NOT NULL THEN
        SELECT array_agg(g.cliente_id) INTO v_ids FROM ana_clienti g
        WHERE g.azienda_fk = p_azienda_id
          AND upper(btrim(g.cliente_cognome)) = upper(btrim(v_orig.cliente_cognome))
          AND upper(btrim(g.cliente_nome))    = upper(btrim(v_orig.cliente_nome))
          AND g.cliente_data_nascita = v_orig.cliente_data_nascita;
        IF array_length(v_ids, 1) = 1 THEN RETURN v_ids[1]; END IF;
    END IF;

    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION fn_cliente_gemello_in_azienda(INTEGER, INTEGER) IS
'La stessa persona nell''anagrafica di un''altra azienda: per codice fiscale, o per
cognome+nome+data di nascita. NULL se non esiste o se i candidati sono piu'' d''uno —
su un''anagrafica si preferisce non fare, che fare a caso.';


-- ---------------------------------------------------------------------------
-- Il referto: chi sta fuori dal proprio silo, e se è rimappabile
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_silos_movimenti_fuori_azienda()
RETURNS TABLE(
    tabella          VARCHAR,
    azienda_viaggio  INTEGER,
    partenza         INTEGER,
    cliente_id       INTEGER,
    nominativo       TEXT,
    azienda_cliente  INTEGER,
    gemello_id       INTEGER,
    rimediabile      VARCHAR   -- RIMAPPABILE | GEMELLO_ASSENTE | GEMELLO_GIA_ISCRITTO
)
LANGUAGE sql
STABLE
AS $$
    WITH righe AS (
        SELECT 'mov_clienti_viaggi.cliente_id_fk'::VARCHAR AS tabella,
               v.azienda_id, m.data_viaggio_id_fk, m.cliente_id_fk AS cli
        FROM mov_clienti_viaggi m
        JOIN ana_viaggi v ON v.viaggio_id = m.viaggio_id_fk
        JOIN ana_clienti c ON c.cliente_id = m.cliente_id_fk
        WHERE c.azienda_fk <> v.azienda_id
        UNION ALL
        SELECT 'mov_clienti_viaggi.cliente_pilota_id_fk',
               v.azienda_id, m.data_viaggio_id_fk, m.cliente_pilota_id_fk
        FROM mov_clienti_viaggi m
        JOIN ana_viaggi v ON v.viaggio_id = m.viaggio_id_fk
        JOIN ana_clienti p ON p.cliente_id = m.cliente_pilota_id_fk
        WHERE p.azienda_fk <> v.azienda_id
        UNION ALL
        SELECT 'mov_clienti_alloggi', v.azienda_id, a.data_viaggio_id_fk, u.cli
        FROM mov_clienti_alloggi a
        JOIN ana_viaggi v ON v.viaggio_id = a.viaggio_id_fk
        CROSS JOIN LATERAL unnest(ARRAY[a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                                        a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk]) AS u(cli)
        JOIN ana_clienti c ON c.cliente_id = u.cli
        WHERE c.azienda_fk <> v.azienda_id
    )
    SELECT DISTINCT r.tabella, r.azienda_id, r.data_viaggio_id_fk, r.cli,
           (c.cliente_cognome || ' ' || c.cliente_nome)::TEXT, c.azienda_fk,
           g.gem,
           CASE
               WHEN g.gem IS NULL THEN 'GEMELLO_ASSENTE'
               WHEN EXISTS (SELECT 1 FROM mov_clienti_viaggi q
                            WHERE q.data_viaggio_id_fk = r.data_viaggio_id_fk
                              AND q.cliente_id_fk = g.gem)
                    AND r.tabella = 'mov_clienti_viaggi.cliente_id_fk'
                    THEN 'GEMELLO_GIA_ISCRITTO'
               ELSE 'RIMAPPABILE'
           END::VARCHAR
    FROM righe r
    JOIN ana_clienti c ON c.cliente_id = r.cli
    CROSS JOIN LATERAL (SELECT fn_cliente_gemello_in_azienda(r.cli, r.azienda_id) AS gem) g
    ORDER BY 1, 2, 3, 5;
$$;

COMMENT ON FUNCTION fn_silos_movimenti_fuori_azienda() IS
'I movimenti in cui il cliente appartiene a un''azienda diversa da quella del viaggio,
con l''esito possibile: RIMAPPABILE (esiste il gemello), GEMELLO_ASSENTE (l''anagrafica
nell''azienda del viaggio non c''e'' e andrebbe creata), GEMELLO_GIA_ISCRITTO (rimappare
creerebbe un doppione). Referto: non modifica niente.';


-- ---------------------------------------------------------------------------
-- Il rimappaggio, solo dove è sicuro
-- ---------------------------------------------------------------------------
-- ⚠️ Si tocca SOLO cio' che e' RIMAPPABILE. GEMELLO_ASSENTE e GEMELLO_GIA_ISCRITTO
-- restano come sono: creare un'anagrafica o fondere due iscrizioni sono decisioni
-- dell'azienda, non pulizie.
--
-- E' una funzione e non tre UPDATE sciolti perche' la chiama anche lo script 588,
-- dopo aver creato le anagrafiche mancanti. Una copia sola, quindi non possono
-- divergere.
CREATE OR REPLACE FUNCTION fn_silos_rimappa_movimenti()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE v_tot INTEGER := 0; v_n INTEGER;
BEGIN
    UPDATE mov_clienti_viaggi m SET cliente_id_fk = s.gemello_id
    FROM fn_silos_movimenti_fuori_azienda() s
    WHERE s.tabella = 'mov_clienti_viaggi.cliente_id_fk' AND s.rimediabile = 'RIMAPPABILE'
      AND m.data_viaggio_id_fk = s.partenza AND m.cliente_id_fk = s.cliente_id;
    GET DIAGNOSTICS v_n = ROW_COUNT; v_tot := v_tot + v_n;

    UPDATE mov_clienti_viaggi m SET cliente_pilota_id_fk = s.gemello_id
    FROM fn_silos_movimenti_fuori_azienda() s
    WHERE s.tabella = 'mov_clienti_viaggi.cliente_pilota_id_fk' AND s.rimediabile = 'RIMAPPABILE'
      AND m.data_viaggio_id_fk = s.partenza AND m.cliente_pilota_id_fk = s.cliente_id;
    GET DIAGNOSTICS v_n = ROW_COUNT; v_tot := v_tot + v_n;

    -- In una camera possono esserci PIU' occupanti fuori silo, e un UPDATE con FROM
    -- ne sistema uno solo per riga: i compagni di stanza resterebbero indietro.
    -- Si ripete finche' non cambia piu' niente.
    LOOP
        UPDATE mov_clienti_alloggi a SET
            cliente_id1_fk = CASE WHEN a.cliente_id1_fk = s.cliente_id THEN s.gemello_id ELSE a.cliente_id1_fk END,
            cliente_id2_fk = CASE WHEN a.cliente_id2_fk = s.cliente_id THEN s.gemello_id ELSE a.cliente_id2_fk END,
            cliente_id3_fk = CASE WHEN a.cliente_id3_fk = s.cliente_id THEN s.gemello_id ELSE a.cliente_id3_fk END,
            cliente_id4_fk = CASE WHEN a.cliente_id4_fk = s.cliente_id THEN s.gemello_id ELSE a.cliente_id4_fk END,
            cliente_id5_fk = CASE WHEN a.cliente_id5_fk = s.cliente_id THEN s.gemello_id ELSE a.cliente_id5_fk END,
            cliente_id6_fk = CASE WHEN a.cliente_id6_fk = s.cliente_id THEN s.gemello_id ELSE a.cliente_id6_fk END
        FROM fn_silos_movimenti_fuori_azienda() s
        WHERE s.tabella = 'mov_clienti_alloggi' AND s.rimediabile = 'RIMAPPABILE'
          AND a.data_viaggio_id_fk = s.partenza
          AND s.cliente_id IN (a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                               a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk);
        GET DIAGNOSTICS v_n = ROW_COUNT;
        EXIT WHEN v_n = 0;
        v_tot := v_tot + v_n;
    END LOOP;

    RETURN v_tot;
END;
$$;

COMMENT ON FUNCTION fn_silos_rimappa_movimenti() IS
'Fa puntare i movimenti al cliente dell''azienda del viaggio, dove il gemello esiste ed e''
uno solo. Lascia intatto cio'' che e'' GEMELLO_ASSENTE o GEMELLO_GIA_ISCRITTO.';

SELECT fn_silos_rimappa_movimenti() AS righe_rimappate;
