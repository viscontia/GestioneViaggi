-- ============================================================================
-- 710 — Forma degli slug controllata dal database (L21, deciso da Adriano il 2026-10-14)
--
-- Lo slug è il pezzo dell'indirizzo web di una sezione (web_tipi_viaggio_descrizioni), di un tour
-- (web_tour_contenuti) o di un articolo (web_blog_articoli). Il gestionale lo genera già giusto (minuscole, cifre,
-- trattini singoli), ma il campo si può scrivere a mano e finora il database non ne controllava la forma. Il proxy
-- del sito tratta uno slug fuori forma come sconosciuto: nel caso peggiore un tour tolto risponderebbe 404 invece
-- di 410, e Google lo terrebbe in elenco più a lungo.
--
-- Forma ammessa: ^[a-z0-9]+(-[a-z0-9]+)*$ (la stessa del proxy del sito). In PROD tutti gli slug la rispettano
-- (verificato il 2026-10-14 e il 2026-10-30: 5 sezioni, 11 tour, nessun articolo).
-- Il gestionale mostra un messaggio chiaro per i tre vincoli (DatabaseExceptionHelper, dalla 2.5); prima, un
-- messaggio generico. La scheda del tour normalizza già lo slug al salvataggio.
-- Rigiocabile. Test: Test_710_Web_Slug_Forma.sql
-- ============================================================================
BEGIN;

ALTER TABLE web_tipi_viaggio_descrizioni DROP CONSTRAINT IF EXISTS ck_web_tipi_viaggio_descrizioni_slug_forma;
ALTER TABLE web_tipi_viaggio_descrizioni ADD CONSTRAINT ck_web_tipi_viaggio_descrizioni_slug_forma
    CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$');

ALTER TABLE web_tour_contenuti DROP CONSTRAINT IF EXISTS ck_web_tour_contenuti_slug_forma;
ALTER TABLE web_tour_contenuti ADD CONSTRAINT ck_web_tour_contenuti_slug_forma
    CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$');

ALTER TABLE web_blog_articoli DROP CONSTRAINT IF EXISTS ck_web_blog_articoli_slug_forma;
ALTER TABLE web_blog_articoli ADD CONSTRAINT ck_web_blog_articoli_slug_forma
    CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$');

COMMIT;
