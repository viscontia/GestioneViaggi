-- ============================================================================
-- 707 — Newsletter dal sito: iscrizione con doppio consenso e disiscrizione (Tappa 4D, Task 1; L7)
--
-- Decisioni di Adriano: 2026-10-19 (iscrizione dal sito con doppio consenso, utente sito_posta) e
-- 2026-10-28 (dentro anche la disiscrizione: oggi il link delle newsletter porta al vecchio sito e dà 404;
-- chi era soppresso e si riiscrive CONFERMANDO torna iscritto). Piano:
-- Sito Web SFT/Documenti/Analisi/2026-10-28-Tappa_4D_Piano_di_Lavoro.md
--
--   - web_newsletter_iscritti: stato 'in_attesa' (senza consenso: l'invio prende solo 'attivo' con consenso);
--     richiesta di conferma in corso: impronta del codice (il codice non sta in chiaro), scadenza 48 ore,
--     lingua della pagina, quando è stata usata. Via la regola anon_insert_iscrizione (451), inerte ma
--     contraria al doppio consenso;
--   - web_newsletter_richieste: ogni richiesta (visitatore = impronta, indirizzo, se è partita la mail), per i
--     limiti: 3 richieste all'ora per visitatore; per indirizzo una mail ogni 10 minuti e 3 al giorno. Si
--     ripulisce da sola dopo un giorno. RLS accese, chiusa a tutti;
--   - ana_aziende.segreto_disiscrizione: segreto casuale per azienda che firma il link di disiscrizione
--     (HMAC-SHA256 dell'indirizzo minuscolo, come NewsletterUnsubscribe del gestionale); separato da
--     token_iscrizione, che serve al link «Iscriviti» di Flask. Il sito non lo vede mai: la firma la
--     controlla il database;
--   - fn_web_newsletter_richiedi(azienda, email, lingua, impronta) → il codice da mettere nella mail, oppure
--     NULL (già iscritto, troppe richieste): il sito risponde uguale in ogni caso;
--   - fn_web_newsletter_conferma(azienda, codice) → 'confermato' | 'scaduto' | 'sconosciuto';
--   - fn_web_newsletter_disiscrivi(azienda, email, firma) → 'disiscritto' | 'firma': soppressione (ferma
--     qualunque fonte, anche un cliente con consenso) e iscritto disiscritto;
--   - le tre funzioni solo a sito_posta.
-- Rigiocabile. Test: Test_707_Web_Newsletter_Dal_Sito.sql
-- ============================================================================
BEGIN;

-- ---------------------------------------------------------------------------
-- Tabelle
-- ---------------------------------------------------------------------------
ALTER TABLE web_newsletter_iscritti DROP CONSTRAINT IF EXISTS chk_web_newsletter_iscritti_stato;
ALTER TABLE web_newsletter_iscritti ADD CONSTRAINT chk_web_newsletter_iscritti_stato
    CHECK (stato IN ('attivo', 'disiscritto', 'in_attesa'));
ALTER TABLE web_newsletter_iscritti
    ADD COLUMN IF NOT EXISTS conferma_impronta varchar(64),
    ADD COLUMN IF NOT EXISTS conferma_scadenza timestamptz,
    ADD COLUMN IF NOT EXISTS conferma_lingua   char(2),
    ADD COLUMN IF NOT EXISTS conferma_usata    timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS uq_web_newsletter_iscritti_conferma
    ON web_newsletter_iscritti (conferma_impronta) WHERE conferma_impronta IS NOT NULL;
DROP POLICY IF EXISTS anon_insert_iscrizione ON web_newsletter_iscritti;

CREATE TABLE IF NOT EXISTS web_newsletter_richieste (
    web_newsletter_richieste_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    azienda_id   integer     NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE CASCADE,
    impronta     varchar(64) NOT NULL,
    email        citext,
    mail_inviata boolean     NOT NULL,
    creata       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_web_newsletter_richieste_impronta ON web_newsletter_richieste (azienda_id, impronta, creata);
CREATE INDEX IF NOT EXISTS idx_web_newsletter_richieste_email ON web_newsletter_richieste (azienda_id, email, creata);
ALTER TABLE web_newsletter_richieste ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE web_newsletter_richieste FROM PUBLIC;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        EXECUTE 'REVOKE ALL ON TABLE web_newsletter_richieste FROM anon, authenticated';
    END IF;
END $$;

-- un valore diverso per ogni azienda, anche per quelle future (default volatile: calcolato riga per riga)
ALTER TABLE ana_aziende ADD COLUMN IF NOT EXISTS segreto_disiscrizione varchar(64) NOT NULL
    DEFAULT encode(extensions.gen_random_bytes(32), 'hex');

-- ---------------------------------------------------------------------------
-- La richiesta
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_web_newsletter_richiedi(p_azienda_id integer, p_email text, p_lingua varchar, p_impronta varchar)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_email  citext := lower(btrim(coalesce(p_email, '')));
    v_lingua char(2) := upper(btrim(coalesce(p_lingua, '')));
    v_codice text;
BEGIN
    IF length(v_email) > 254 OR v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
        RAISE EXCEPTION 'Email non valida.';
    END IF;
    IF v_lingua NOT IN ('IT', 'EN', 'DE', 'FR', 'ES') THEN
        RAISE EXCEPTION 'Lingua non valida: %.', p_lingua;
    END IF;
    IF nullif(btrim(coalesce(p_impronta, '')), '') IS NULL OR length(p_impronta) > 64 THEN
        RAISE EXCEPTION 'Impronta del visitatore mancante.';
    END IF;

    -- pulizia: richieste vecchie; iscrizioni mai confermate e scadute da più di un giorno (nessun consenso dato)
    DELETE FROM web_newsletter_richieste WHERE creata < now() - interval '1 day';
    DELETE FROM web_newsletter_iscritti
     WHERE stato = 'in_attesa' AND conferma_scadenza < now() - interval '1 day';

    -- 3 richieste all'ora per visitatore
    IF (SELECT count(*) FROM web_newsletter_richieste
         WHERE azienda_id = p_azienda_id AND impronta = p_impronta AND creata > now() - interval '1 hour') >= 3
    -- già iscritto e raggiunto dalla newsletter: niente mail (il visitatore vede la stessa risposta)
       OR EXISTS (SELECT 1 FROM web_newsletter_iscritti i
                   WHERE i.azienda_id = p_azienda_id AND i.email = v_email AND i.stato = 'attivo' AND i.consenso
                     AND NOT EXISTS (SELECT 1 FROM web_newsletter_soppressioni s
                                      WHERE s.azienda_id = p_azienda_id AND s.email = v_email))
    -- per indirizzo: una mail ogni 10 minuti, 3 al giorno (nessuno tempesta di mail una persona)
       OR (SELECT count(*) FROM web_newsletter_richieste
            WHERE azienda_id = p_azienda_id AND email = v_email AND mail_inviata AND creata > now() - interval '10 minutes') >= 1
       OR (SELECT count(*) FROM web_newsletter_richieste
            WHERE azienda_id = p_azienda_id AND email = v_email AND mail_inviata AND creata > now() - interval '1 day') >= 3
    THEN
        INSERT INTO web_newsletter_richieste (azienda_id, impronta, email, mail_inviata)
        VALUES (p_azienda_id, p_impronta, v_email, false);
        RETURN NULL;
    END IF;

    -- codice casuale (2 × 122 bit); nel database solo la sua impronta
    v_codice := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
    INSERT INTO web_newsletter_iscritti (email, lingua, consenso, stato, token_disiscrizione, azienda_id, created_by,
                                         conferma_impronta, conferma_scadenza, conferma_lingua, conferma_usata)
    VALUES (v_email, v_lingua, false, 'in_attesa', encode(gen_random_bytes(24), 'hex'), p_azienda_id, 'sito',
            encode(sha256(convert_to(v_codice, 'UTF8')), 'hex'), now() + interval '48 hours', v_lingua, NULL)
    ON CONFLICT (azienda_id, email) DO UPDATE
        -- chi c'era già (disiscritto, soppresso, in attesa) resta com'è finché non conferma
        SET conferma_impronta = EXCLUDED.conferma_impronta, conferma_scadenza = EXCLUDED.conferma_scadenza,
            conferma_lingua = EXCLUDED.conferma_lingua, conferma_usata = NULL;

    INSERT INTO web_newsletter_richieste (azienda_id, impronta, email, mail_inviata)
    VALUES (p_azienda_id, p_impronta, v_email, true);
    RETURN v_codice;
END;
$$;

-- ---------------------------------------------------------------------------
-- La conferma (dal bottone della pagina, mai al solo caricamento del link)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_web_newsletter_conferma(p_azienda_id integer, p_codice text)
RETURNS varchar
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    r record;
BEGIN
    IF p_codice IS NULL OR p_codice !~ '^[0-9a-f]{64}$' THEN
        RETURN 'sconosciuto';
    END IF;
    SELECT i.web_newsletter_iscritti_id, i.email, i.conferma_scadenza, i.conferma_usata, i.conferma_lingua
      INTO r
      FROM web_newsletter_iscritti i
     WHERE i.azienda_id = p_azienda_id AND i.conferma_impronta = encode(sha256(convert_to(p_codice, 'UTF8')), 'hex')
       FOR UPDATE;
    IF NOT FOUND THEN
        RETURN 'sconosciuto';
    END IF;
    IF r.conferma_usata IS NOT NULL THEN
        RETURN 'confermato';                    -- secondo clic: già fatto
    END IF;
    IF r.conferma_scadenza < now() THEN
        RETURN 'scaduto';
    END IF;

    -- consenso nuovo ed esplicito: anche una soppressione precedente si toglie (Adriano, 2026-10-28)
    UPDATE web_newsletter_iscritti
       SET stato = 'attivo', consenso = true, consenso_data = now(), consenso_fonte = 'sito, doppio consenso',
           lingua = coalesce(r.conferma_lingua, lingua), conferma_usata = now(), conferma_scadenza = NULL,
           updated_by = 'sito'
     WHERE web_newsletter_iscritti_id = r.web_newsletter_iscritti_id;
    DELETE FROM web_newsletter_soppressioni WHERE azienda_id = p_azienda_id AND email = r.email;
    RETURN 'confermato';
END;
$$;

-- ---------------------------------------------------------------------------
-- La disiscrizione (dal link di ogni newsletter, firmato dal gestionale)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_web_newsletter_disiscrivi(p_azienda_id integer, p_email text, p_firma text)
RETURNS varchar
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_email   citext := lower(btrim(coalesce(p_email, '')));
    v_segreto text;
BEGIN
    SELECT a.segreto_disiscrizione INTO v_segreto FROM ana_aziende a WHERE a.azienda_id = p_azienda_id;
    IF v_segreto IS NULL OR v_email = '' OR p_firma IS NULL
       OR lower(p_firma) <> encode(hmac(v_email::text, v_segreto, 'sha256'), 'hex') THEN
        RETURN 'firma';
    END IF;

    -- la soppressione è l'unico filtro che ferma qualunque fonte (anche un cliente con consenso)
    INSERT INTO web_newsletter_soppressioni (email, motivo, azienda_id, created_by)
    VALUES (v_email, 'disiscritto dal sito', p_azienda_id, 'sito')
    ON CONFLICT (azienda_id, email) DO NOTHING;
    UPDATE web_newsletter_iscritti
       SET stato = 'disiscritto', consenso = false, conferma_impronta = NULL, conferma_scadenza = NULL,
           conferma_usata = NULL, updated_by = 'sito'
     WHERE azienda_id = p_azienda_id AND email = v_email AND stato <> 'disiscritto';
    RETURN 'disiscritto';
END;
$$;

-- ---------------------------------------------------------------------------
-- Permessi: solo sito_posta (in PROD una funzione nuova nasce eseguibile da chiunque)
-- ---------------------------------------------------------------------------
DO $$
DECLARE f text;
BEGIN
    FOREACH f IN ARRAY ARRAY['fn_web_newsletter_richiedi(integer, text, varchar, varchar)',
                             'fn_web_newsletter_conferma(integer, text)',
                             'fn_web_newsletter_disiscrivi(integer, text, text)'] LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, authenticated', f);
        END IF;
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO sito_posta', f);
    END LOOP;
END $$;

COMMIT;
