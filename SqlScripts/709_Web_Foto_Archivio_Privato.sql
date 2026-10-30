-- ============================================================================
-- 709 — Protezione delle foto (L27, Task 1): chi può leggere gli originali, e l'archivio delle newsletter
--
-- Disegno: Sito Web SFT/Documenti/Analisi/2026-10-29-L27_Protezione_Foto_Disegno_e_Piano.md (§2.1, §2.3).
--   - Regola sull'archivio: gli originali delle foto (tour-media; tour-media-dev per le prove del gestionale) li
--     legge l'utente di Supabase che ha «sito_foto» in app_metadata (il server del sito). app_metadata la scrive
--     solo la chiave di servizio: chi si registra da sé non può darsela. Sola lettura: niente scrittura né
--     cancellazione, che restano al gestionale.
--   - Archivio newsletter-media, pubblico: solo le immagini preparate per le newsletter, che un programma di posta
--     deve poter aprire senza permessi. Solo immagini, al massimo 5 MB.
--
-- Non cambia nulla per chi guarda oggi: tour-media resta pubblico. Diventa privato con uno script a parte, dopo
-- la consegna del gestionale 2.4 (piano, Task 7).
-- Solo su Supabase (schema storage): sul database locale non c'è e lo script non fa nulla.
-- Rigiocabile. Test: Test_709_Web_Foto_Archivio_Privato.sql
-- ============================================================================
BEGIN;

DO $$
BEGIN
    IF to_regclass('storage.objects') IS NULL THEN
        RAISE NOTICE '709: niente schema storage (database locale), nulla da fare.';
        RETURN;
    END IF;

    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES ('newsletter-media', 'newsletter-media', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
    ON CONFLICT (id) DO UPDATE SET public = true, file_size_limit = EXCLUDED.file_size_limit,
                                   allowed_mime_types = EXCLUDED.allowed_mime_types;

    DROP POLICY IF EXISTS sito_foto_legge_originali ON storage.objects;
    CREATE POLICY sito_foto_legge_originali ON storage.objects
        FOR SELECT TO authenticated
        USING (bucket_id IN ('tour-media', 'tour-media-dev')
               AND coalesce(auth.jwt() -> 'app_metadata' ->> 'sito_foto', '') = 'true');
END $$;

COMMIT;
