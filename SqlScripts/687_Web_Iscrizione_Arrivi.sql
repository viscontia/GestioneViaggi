-- ============================================================================
-- 687 — Gli arrivi al wizard d'iscrizione dal sito, contati nel database (L20)
--
-- Il bottone «Iscriviti» della scheda tour porta al wizard con l'edizione e la
-- provenienza (?data=…&da=sito). Il sito Flask registra l'ARRIVO (non il clic:
-- il sito pubblico non scrive, regola 3) e, a iscrizione completata, lo segna
-- «concluso». La mail settimanale potrà dire, per tour: arrivi dal sito →
-- iscrizioni. Decisione di Adriano del 2026-10-16 (Tappa 3, disegno §4).
--
-- Privacy: l'IP non si salva. Il Flask manda un'IMPRONTA (64 caratteri
-- esadecimali, SHA-256 di IP + browser + un segreto): serve solo a contare lo
-- stesso visitatore una volta per edizione in un'ora. Il vincolo della tabella
-- rifiuta qualunque altro formato.
--
-- Chi chiama: il sito Flask, che si collega come postgres (proprietario).
-- Nessun permesso al pubblico: funzioni e tabella negate ad anon/authenticated,
-- RLS attiva (su Supabase una tabella nuova di public è esposta alle API).
-- Rigiocabile.
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS web_iscrizione_arrivi (
    arrivo_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    azienda_id       integer     NOT NULL REFERENCES ana_aziende(azienda_id),
    data_viaggio_id  integer     NOT NULL REFERENCES ana_date_viaggi(data_viaggio_id),
    provenienza      varchar(20) NOT NULL CHECK (provenienza ~ '^[a-z0-9_-]{1,20}$'),
    impronta         char(64)    NOT NULL CHECK (impronta ~ '^[0-9a-f]{64}$'),
    arrivato_il      timestamptz NOT NULL DEFAULT now(),
    concluso_il      timestamptz
);
CREATE INDEX IF NOT EXISTS idx_web_iscrizione_arrivi_visitatore
    ON web_iscrizione_arrivi (data_viaggio_id, impronta, arrivato_il DESC);
CREATE INDEX IF NOT EXISTS idx_web_iscrizione_arrivi_azienda_data
    ON web_iscrizione_arrivi (azienda_id, arrivato_il);

ALTER TABLE web_iscrizione_arrivi ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE web_iscrizione_arrivi FROM PUBLIC;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon')          THEN REVOKE ALL ON TABLE web_iscrizione_arrivi FROM anon; END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN REVOKE ALL ON TABLE web_iscrizione_arrivi FROM authenticated; END IF;
END $$;

-- L'arrivo: lo stesso visitatore sulla stessa edizione nell'ultima ora è lo stesso arrivo.
CREATE OR REPLACE FUNCTION fn_web_iscrizione_arrivo(p_azienda_id integer, p_data_viaggio_id integer,
                                                    p_provenienza varchar, p_impronta varchar)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE v_id bigint;
BEGIN
    -- I formati si controllano SEMPRE, prima di tutto: anche quando l'arrivo esiste già
    -- (altrimenti un dato sbagliato passerebbe in silenzio). Gli stessi vincoli della tabella.
    IF p_impronta IS NULL OR p_impronta !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION 'Impronta del visitatore non valida (attesi 64 caratteri esadecimali)';
    END IF;
    IF p_provenienza IS NULL OR p_provenienza !~ '^[a-z0-9_-]{1,20}$' THEN
        RAISE EXCEPTION 'Provenienza non valida: %', left(coalesce(p_provenienza, '(nulla)'), 40);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM ana_date_viaggi WHERE data_viaggio_id = p_data_viaggio_id AND azienda_id = p_azienda_id) THEN
        RAISE EXCEPTION 'L''edizione % non appartiene all''azienda %', p_data_viaggio_id, p_azienda_id;
    END IF;

    SELECT a.arrivo_id INTO v_id
      FROM web_iscrizione_arrivi a
     WHERE a.data_viaggio_id = p_data_viaggio_id AND a.azienda_id = p_azienda_id
       AND a.impronta = p_impronta AND a.arrivato_il > now() - interval '1 hour'
     ORDER BY a.arrivato_il DESC
     LIMIT 1;
    IF v_id IS NOT NULL THEN RETURN v_id; END IF;

    INSERT INTO web_iscrizione_arrivi (azienda_id, data_viaggio_id, provenienza, impronta)
    VALUES (p_azienda_id, p_data_viaggio_id, p_provenienza, p_impronta)
    RETURNING arrivo_id INTO v_id;
    RETURN v_id;
END;
$$;

-- A iscrizione completata: l'arrivo è «concluso» (una volta sola: la data non si sposta).
CREATE OR REPLACE FUNCTION fn_web_iscrizione_arrivo_concluso(p_azienda_id integer, p_arrivo_id bigint)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
    WITH aggiornato AS (
        UPDATE web_iscrizione_arrivi SET concluso_il = coalesce(concluso_il, now())
         WHERE arrivo_id = p_arrivo_id AND azienda_id = p_azienda_id
        RETURNING 1
    )
    SELECT EXISTS (SELECT 1 FROM aggiornato);
$$;

REVOKE EXECUTE ON FUNCTION fn_web_iscrizione_arrivo(integer, integer, varchar, varchar) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_web_iscrizione_arrivo_concluso(integer, bigint)          FROM PUBLIC;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        REVOKE EXECUTE ON FUNCTION fn_web_iscrizione_arrivo(integer, integer, varchar, varchar) FROM anon, authenticated;
        REVOKE EXECUTE ON FUNCTION fn_web_iscrizione_arrivo_concluso(integer, bigint)          FROM anon, authenticated;
    END IF;
END $$;

COMMIT;

-- ============================================================================
-- Verifica: Test_687_Web_Iscrizione_Arrivi.sql
-- ============================================================================
