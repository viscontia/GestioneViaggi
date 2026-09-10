-- =============================================================================
-- 637 — Import di una lista newsletter esterna
--
-- Nasce per portare dentro i 2.523 indirizzi raccolti dal vecchio sito Drupal
-- (Simplenews) di Sardegna Fuori Traccia, ma non e' legata a quel caso: prende
-- due elenchi di indirizzi e li sistema al posto giusto.
--
-- ⛔️ GLI INDIRIZZI NON STANNO QUI. Sono dati personali di migliaia di persone e
--    non entrano nel repository: lo script porta la logica, i dati arrivano come
--    parametro da un file tenuto fuori (vedi Backup_GoLive/newsletter_drupal/).
--
-- Rigiocabile: si puo' lanciare due volte di fila senza raddoppiare nulla.
-- =============================================================================

BEGIN;

-- --- Prima: due colonne troppo strette per dire la verita' -------------------
-- ⛔️ `consenso_fonte` e `motivo` erano VARCHAR(20). Venti caratteri non bastano
--    a scrivere da dove viene davvero un consenso — «newsletter sito Drupal,
--    esportata il 2026-09-10» ne occupa 46 — e quella frase e' esattamente cio'
--    che un domani permette di dimostrarlo. Comprimerla in una sigla la renderebbe
--    illeggibile fra due anni, cioe' inutile proprio quando servirebbe.
-- ℹ️ Nessun CHECK vincola i valori e nessun codice dipende dalla lunghezza:
--    l'allargamento non tocca nulla di quel che c'e' gia'.
ALTER TABLE web_newsletter_iscritti     ALTER COLUMN consenso_fonte TYPE VARCHAR(120);
ALTER TABLE web_newsletter_soppressioni ALTER COLUMN motivo         TYPE VARCHAR(120);

DROP FUNCTION IF EXISTS fn_web_newsletter_import(INTEGER, TEXT[], TEXT[], VARCHAR, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fn_web_newsletter_import(
    p_azienda_id  INTEGER,
    p_iscritti    TEXT[],      -- chi ha un consenso attivo
    p_soppressi   TEXT[],      -- chi si e' disiscritto: NON verra' mai contattato
    p_fonte       VARCHAR,     -- da dove viene il consenso, in chiaro
    p_motivo      VARCHAR,     -- perche' i soppressi sono soppressi
    p_utente      VARCHAR DEFAULT 'import'
)
RETURNS TABLE (
    soppressi_nuovi      INTEGER,
    soppressi_gia_noti   INTEGER,
    iscritti_nuovi       INTEGER,
    iscritti_gia_noti    INTEGER,
    iscritti_collegati   INTEGER,
    scartati_perche_soppressi INTEGER,
    scartati_malformati  INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sopp_nuovi   INTEGER := 0;
    v_sopp_noti    INTEGER := 0;
    v_isc_nuovi    INTEGER := 0;
    v_isc_noti     INTEGER := 0;
    v_collegati    INTEGER := 0;
    v_scartati_s   INTEGER := 0;
    v_malformati   INTEGER := 0;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM ana_aziende WHERE azienda_id = p_azienda_id) THEN
        RAISE EXCEPTION 'Azienda % inesistente: non si importa una lista in un''azienda che non c''e''.', p_azienda_id;
    END IF;

    -- Normalizzazione unica per entrambi gli elenchi: minuscolo, senza spazi,
    -- e scarto di cio' che non e' un indirizzo. Meglio contarli che lasciarli
    -- passare e trovarsi righe che non si possono contattare.
    -- ⚠️ ON COMMIT DROP non basta: le temporanee restano fino al COMMIT, quindi
    -- una seconda chiamata NELLA STESSA transazione (due aziende di fila) le
    -- troverebbe gia' li' e fallirebbe. Si buttano esplicitamente.
    DROP TABLE IF EXISTS _in_sopp;
    DROP TABLE IF EXISTS _in_isc;

    CREATE TEMP TABLE _in_sopp ON COMMIT DROP AS
        SELECT DISTINCT lower(btrim(e)) AS email
        FROM unnest(coalesce(p_soppressi, ARRAY[]::TEXT[])) AS e
        WHERE lower(btrim(e)) ~ '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,}$';

    CREATE TEMP TABLE _in_isc ON COMMIT DROP AS
        SELECT DISTINCT lower(btrim(e)) AS email
        FROM unnest(coalesce(p_iscritti, ARRAY[]::TEXT[])) AS e
        WHERE lower(btrim(e)) ~ '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,}$';

    v_malformati :=
        (SELECT count(DISTINCT lower(btrim(e))) FROM unnest(coalesce(p_iscritti, ARRAY[]::TEXT[])
             || coalesce(p_soppressi, ARRAY[]::TEXT[])) AS e
         WHERE lower(btrim(e)) !~ '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,}$');

    -- 1) I SOPPRESSI PER PRIMI, sempre.
    -- ⛔️ L'ordine non e' un dettaglio: se si inserissero prima gli iscritti,
    --    per un attimo qualcuno che si era disiscritto risulterebbe contattabile.
    WITH ins AS (
        INSERT INTO web_newsletter_soppressioni (email, motivo, azienda_id, created_by)
        SELECT s.email, p_motivo, p_azienda_id, p_utente
        FROM _in_sopp s
        ON CONFLICT (azienda_id, email) DO NOTHING
        RETURNING 1
    ) SELECT count(*) INTO v_sopp_nuovi FROM ins;
    v_sopp_noti := (SELECT count(*) FROM _in_sopp) - v_sopp_nuovi;

    -- 1-bis) Chi era gia' in lista e ora risulta soppresso va marcato ANCHE fra
    -- gli iscritti. ℹ️ Il motore di invio controlla gia' le soppressioni, quindi
    -- nessuno verrebbe contattato comunque; ma una riga che dice «attivo» mentre
    -- la persona e' soppressa e' una seconda verita', e chi apre l'elenco dal
    -- gestionale la leggerebbe come contattabile. Due verita' divergono sempre.
    UPDATE web_newsletter_iscritti i
       SET stato = 'disiscritto', consenso = FALSE, updated = now(), updated_by = p_utente
     WHERE i.azienda_id = p_azienda_id
       AND i.stato <> 'disiscritto'
       AND EXISTS (SELECT 1 FROM _in_sopp s WHERE s.email = i.email);

    -- 2) Chi compare in entrambi gli elenchi resta fuori dagli iscritti.
    -- Rete di sicurezza: il chiamante dovrebbe averli gia' separati, ma se
    -- sbaglia il danno sarebbe scrivere a chi ha detto di no.
    v_scartati_s := (SELECT count(*) FROM _in_isc i WHERE EXISTS (
        SELECT 1 FROM web_newsletter_soppressioni x
        WHERE x.azienda_id = p_azienda_id AND x.email = i.email));

    DELETE FROM _in_isc i WHERE EXISTS (
        SELECT 1 FROM web_newsletter_soppressioni x
        WHERE x.azienda_id = p_azienda_id AND x.email = i.email);

    -- 3) Gli iscritti, collegati alla scheda cliente quando il legame e' certo.
    -- ⚠️ Si collega SOLO se in quell'azienda esiste UN cliente con quell'indirizzo.
    --    Due coniugi che condividono la casella sono un caso reale e legittimo:
    --    attribuire l'iscrizione a uno dei due sarebbe una scelta arbitraria, e
    --    un legame sbagliato e' peggio di un legame assente.
    WITH candidati AS (
        SELECT i.email,
               -- max() + HAVING count(*)=1: se in quell'azienda l'indirizzo
               -- appartiene a due clienti, la riga sparisce e il legame resta NULL.
               (SELECT max(c.cliente_id) FROM ana_clienti c
                 WHERE c.azienda_fk = p_azienda_id
                   AND lower(btrim(c.cliente_email)) = i.email
                HAVING count(*) = 1) AS cliente_fk
        FROM _in_isc i
    ), ins AS (
        INSERT INTO web_newsletter_iscritti (
            email, lingua, data_iscrizione, consenso, consenso_data, consenso_fonte,
            stato, token_disiscrizione, cliente_fk, azienda_id, created_by)
        SELECT c.email, 'IT', now(), TRUE, now(), p_fonte,
               'attivo',
               replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
               c.cliente_fk, p_azienda_id, p_utente
        FROM candidati c
        ON CONFLICT (azienda_id, email) DO NOTHING
        RETURNING cliente_fk
    )
    SELECT count(*), count(cliente_fk) INTO v_isc_nuovi, v_collegati FROM ins;
    v_isc_noti := (SELECT count(*) FROM _in_isc) - v_isc_nuovi;

    RETURN QUERY SELECT v_sopp_nuovi, v_sopp_noti, v_isc_nuovi, v_isc_noti,
                        v_collegati, v_scartati_s, v_malformati;
END;
$$;

COMMENT ON FUNCTION fn_web_newsletter_import IS
'Importa una lista newsletter esterna. Inserisce PRIMA i soppressi, poi gli iscritti, escludendo chi risulta soppresso. Collega cliente_fk solo quando in quella azienda esiste un unico cliente con quell''indirizzo. Rigiocabile.';

-- --- Verifica: la funzione esiste ed e' invocabile -------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_web_newsletter_import') THEN
        RAISE EXCEPTION 'fn_web_newsletter_import non e'' stata creata';
    END IF;
    IF (SELECT character_maximum_length FROM information_schema.columns
         WHERE table_name='web_newsletter_iscritti' AND column_name='consenso_fonte') < 120 THEN
        RAISE EXCEPTION 'consenso_fonte non e'' stata allargata';
    END IF;
    RAISE NOTICE 'OK — fn_web_newsletter_import creata, colonne allargate a 120';
END $$;

COMMIT;
