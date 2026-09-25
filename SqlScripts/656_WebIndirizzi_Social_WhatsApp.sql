-- ============================================================================
-- WhatsApp diventa un social riconosciuto
--
-- SFT usa WhatsApp come canale di contatto, ma il vincolo accettava solo
-- facebook, instagram, tiktok e youtube: il numero poteva stare in rubrica solo
-- come collegamento normale, e il sito e la newsletter non avrebbero saputo che
-- era WhatsApp — niente colore del marchio, niente icona.
--
-- Il catalogo C# (`SocialCatalogo`, Models/Web/NewsletterDefinizioni.cs) è
-- l'unica definizione dei social lato applicazione; questi due vincoli sono il
-- solo punto che il database non può leggere da lì, e vanno tenuti allineati a
-- mano (vedi script 519).
--
-- L'URL di un contatto WhatsApp è https://wa.me/<prefisso><numero>, senza «+»
-- né spazi: così il vincolo sull'URL (http/https) resta valido.
--
-- ✅ Applicato a PROD il 2026-09-25, insieme alla riga WHATSAPP di azienda 2
--    (https://wa.me/393457081307) inserita con fn_web_indirizzi_insert.
-- ============================================================================

BEGIN;

ALTER TABLE web_indirizzi DROP CONSTRAINT IF EXISTS chk_web_indirizzi_social;
ALTER TABLE web_indirizzi
    ADD CONSTRAINT chk_web_indirizzi_social
    CHECK (social IS NULL OR social IN ('facebook','instagram','tiktok','youtube','whatsapp'));

ALTER TABLE web_newsletter_blocchi DROP CONSTRAINT IF EXISTS chk_web_newsletter_blocchi_social;
ALTER TABLE web_newsletter_blocchi
    ADD CONSTRAINT chk_web_newsletter_blocchi_social
    CHECK (social IS NULL OR social IN ('facebook','instagram','tiktok','youtube','whatsapp'));

COMMIT;
