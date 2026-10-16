-- ============================================================================
-- 688 — Le richieste del PDF della scheda tour, contate (Tappa 3 del sito)
--
-- Adriano vuole il numero dei PDF scaricati nelle statistiche della mail
-- settimanale. Il PDF lo consegna il sito Next, che è l'unico a saperlo: è
-- l'UNICA eccezione alla regola «il sito non scrive» (decisa da Adriano il
-- 2026-10-16, scritta in overview.md e CLAUDE.md del sito):
--   - scrive il SERVER del sito, mai il browser;
--   - con un utente dedicato, sito_statistiche, che può fare SOLO questo:
--     chiamare fn_web_pdf_richiesta. Nessuna tabella, nessun'altra funzione;
--   - l'IP non si salva: impronta di 64 caratteri esadecimali (come il 687);
--   - una volta per visitatore, edizione e lingua in un'ora.
--
-- ⛔️ sito_statistiche nasce NOLOGIN e senza password: il login si dà a mano (solo
-- l'impronta SCRAM, come 679/681) e la password vive solo nel .env del server.
-- Rigiocabile.
-- ============================================================================
BEGIN;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sito_statistiche') THEN
        CREATE ROLE sito_statistiche NOLOGIN;
    END IF;
END $$;
GRANT USAGE ON SCHEMA public TO sito_statistiche;

CREATE TABLE IF NOT EXISTS web_pdf_richieste (
    richiesta_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    azienda_id       integer     NOT NULL REFERENCES ana_aziende(azienda_id),
    data_viaggio_id  integer     NOT NULL REFERENCES ana_date_viaggi(data_viaggio_id),
    lingua           char(2)     NOT NULL CHECK (lingua IN ('IT', 'EN', 'DE', 'FR', 'ES')),
    impronta         char(64)    NOT NULL CHECK (impronta ~ '^[0-9a-f]{64}$'),
    richiesta_il     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_web_pdf_richieste_visitatore
    ON web_pdf_richieste (data_viaggio_id, lingua, impronta, richiesta_il DESC);
CREATE INDEX IF NOT EXISTS idx_web_pdf_richieste_azienda_data
    ON web_pdf_richieste (azienda_id, richiesta_il);

ALTER TABLE web_pdf_richieste ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE web_pdf_richieste FROM PUBLIC;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon')          THEN REVOKE ALL ON TABLE web_pdf_richieste FROM anon; END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN REVOKE ALL ON TABLE web_pdf_richieste FROM authenticated; END IF;
END $$;

-- true se la richiesta è stata contata, false se lo stesso visitatore aveva già chiesto
-- lo stesso PDF (edizione e lingua) nell'ultima ora.
CREATE OR REPLACE FUNCTION fn_web_pdf_richiesta(p_azienda_id integer, p_data_viaggio_id integer,
                                                p_lingua varchar, p_impronta varchar)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
BEGIN
    -- I formati si controllano sempre, prima di tutto (lezione del 687).
    IF p_impronta IS NULL OR p_impronta !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION 'Impronta del visitatore non valida (attesi 64 caratteri esadecimali)';
    END IF;
    IF p_lingua IS NULL OR p_lingua NOT IN ('IT', 'EN', 'DE', 'FR', 'ES') THEN
        RAISE EXCEPTION 'Lingua non valida: %', left(coalesce(p_lingua, '(nulla)'), 10);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM ana_date_viaggi WHERE data_viaggio_id = p_data_viaggio_id AND azienda_id = p_azienda_id) THEN
        RAISE EXCEPTION 'L''edizione % non appartiene all''azienda %', p_data_viaggio_id, p_azienda_id;
    END IF;

    IF EXISTS (SELECT 1 FROM web_pdf_richieste r
                WHERE r.data_viaggio_id = p_data_viaggio_id AND r.azienda_id = p_azienda_id
                  AND r.lingua = p_lingua AND r.impronta = p_impronta
                  AND r.richiesta_il > now() - interval '1 hour') THEN
        RETURN false;
    END IF;

    INSERT INTO web_pdf_richieste (azienda_id, data_viaggio_id, lingua, impronta)
    VALUES (p_azienda_id, p_data_viaggio_id, p_lingua, p_impronta);
    RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_web_pdf_richiesta(integer, integer, varchar, varchar) FROM PUBLIC;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        REVOKE EXECUTE ON FUNCTION fn_web_pdf_richiesta(integer, integer, varchar, varchar) FROM anon, authenticated;
    END IF;
END $$;
GRANT EXECUTE ON FUNCTION fn_web_pdf_richiesta(integer, integer, varchar, varchar) TO sito_statistiche;

COMMIT;

-- ============================================================================
-- Verifica: Test_688_Web_Pdf_Richieste.sql
-- ============================================================================
