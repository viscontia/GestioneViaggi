-- ============================================================================
-- Test dello script 709. Solo su Supabase (schema storage). Transazione annullata: nessun dato resta.
-- Prima dello script deve FALLIRE (manca la regola, l'utente del sito non legge nulla).
-- ============================================================================
BEGIN;

DO $$
BEGIN
    ASSERT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'newsletter-media' AND public
                     AND file_size_limit = 5242880 AND 'image/jpeg' = ANY (allowed_mime_types)
                     AND NOT 'video/mp4' = ANY (allowed_mime_types)),
           'newsletter-media: pubblico, 5 MB, solo immagini';
    ASSERT (SELECT count(*) FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'
              AND policyname = 'sito_foto_legge_originali' AND cmd = 'SELECT' AND roles = '{authenticated}') = 1,
           'una sola regola, di lettura, per authenticated';
    -- un file di prova in ognuno degli archivi che contano (il conteggio non dipende da cosa c'è oggi)
    INSERT INTO storage.objects (bucket_id, name) VALUES
        ('tour-media', 'prova709/a.jpg'), ('tour-media-dev', 'prova709/b.jpg'), ('newsletter-media', 'prova709/c.jpg');
END $$;

CREATE TEMP TABLE esito709 (caso text, visti int) ON COMMIT DROP;
GRANT ALL ON esito709 TO authenticated, anon;

-- 1. L'utente del sito (app_metadata.sito_foto = true): legge tour-media e tour-media-dev, non newsletter-media
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"role":"authenticated","app_metadata":{"sito_foto":true}}', true);
INSERT INTO esito709 SELECT 'sito ' || bucket_id, count(*) FROM storage.objects WHERE name LIKE 'prova709/%' GROUP BY bucket_id;
-- …e non scrive, non cambia, non cancella
DO $$
BEGIN
    BEGIN
        INSERT INTO storage.objects (bucket_id, name) VALUES ('tour-media', 'prova709/scritta.jpg');
        RAISE EXCEPTION 'l''utente del sito ha scritto';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    -- (o manca il permesso, o la regola non gli mostra la riga: in tutti e due i casi non tocca nulla)
    BEGIN
        UPDATE storage.objects SET name = 'prova709/cambiata.jpg' WHERE name = 'prova709/a.jpg';
        ASSERT NOT FOUND, 'l''utente del sito ha cambiato un file';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        DELETE FROM storage.objects WHERE name = 'prova709/a.jpg';
        ASSERT NOT FOUND, 'l''utente del sito ha cancellato un file';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END $$;

-- 2. Un utente qualunque, registrato da sé (nessun app_metadata, o sito_foto messo nei dati che può scrivere)
SELECT set_config('request.jwt.claims', '{"role":"authenticated","user_metadata":{"sito_foto":true}}', true);
INSERT INTO esito709 SELECT 'qualunque', count(*) FROM storage.objects WHERE name LIKE 'prova709/%';
SELECT set_config('request.jwt.claims', '{"role":"authenticated","app_metadata":{"sito_foto":false}}', true);
INSERT INTO esito709 SELECT 'falso', count(*) FROM storage.objects WHERE name LIKE 'prova709/%';

-- 3. Anonimo, anche con il segno nei dati
RESET ROLE;
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon","app_metadata":{"sito_foto":true}}', true);
INSERT INTO esito709 SELECT 'anonimo', count(*) FROM storage.objects WHERE name LIKE 'prova709/%';
RESET ROLE;

DO $$
DECLARE
    r text := (SELECT string_agg(caso || '=' || visti, ' ' ORDER BY caso) FROM esito709);
BEGIN
    ASSERT (SELECT visti FROM esito709 WHERE caso = 'sito tour-media') = 1, 'il sito legge tour-media: ' || coalesce(r, '-');
    ASSERT (SELECT visti FROM esito709 WHERE caso = 'sito tour-media-dev') = 1, 'il sito legge tour-media-dev: ' || coalesce(r, '-');
    ASSERT NOT EXISTS (SELECT 1 FROM esito709 WHERE caso = 'sito newsletter-media'), 'il sito non legge altri archivi: ' || r;
    ASSERT coalesce((SELECT visti FROM esito709 WHERE caso = 'qualunque'), 0) = 0, 'un utente qualunque non legge: ' || r;
    ASSERT coalesce((SELECT visti FROM esito709 WHERE caso = 'falso'), 0) = 0, 'sito_foto=false non legge: ' || r;
    ASSERT coalesce((SELECT visti FROM esito709 WHERE caso = 'anonimo'), 0) = 0, 'l''anonimo non legge: ' || r;
    RAISE NOTICE 'Test 709 superato (%)', r;
END $$;

ROLLBACK;
