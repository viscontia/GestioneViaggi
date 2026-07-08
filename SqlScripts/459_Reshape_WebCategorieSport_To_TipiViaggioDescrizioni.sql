-- Blocco 8: consolidamento della "categoria sport" in un'unica tabella GLOBALE di
-- descrizioni web dei tipi di viaggio. La tabella web_categorie_sport è VUOTA →
-- reshape IN-PLACE (rename/drop): trigger audit, policy RLS, GRANT anon e la FK da
-- ana_tipo_viaggi seguono automaticamente i rename, quindi niente drop&recreate.
-- Decisioni (2026-07-07): GLOBALE (drop azienda_id), tenere slug/ordine, rinominare
-- per chiarezza E/R. Motivazione: evitare descrizione web come testo libero ripetuto
-- su più tipi (rompe 3NF / falsi raggruppamenti) → lookup + FK, condivisa da N tipi.

-- 1) rimuovo i vincoli legati ad azienda_id (unique compositi + FK azienda)
ALTER TABLE web_categorie_sport DROP CONSTRAINT web_categorie_sport_azienda_id_fkey;
ALTER TABLE web_categorie_sport DROP CONSTRAINT uq_web_categorie_sport_codice;
ALTER TABLE web_categorie_sport DROP CONSTRAINT uq_web_categorie_sport_slug;

-- 2) tabella globale e snella: via azienda_id (globale) e codice (slug è l'identificatore web)
ALTER TABLE web_categorie_sport DROP COLUMN azienda_id;
ALTER TABLE web_categorie_sport DROP COLUMN codice;

-- 3) rinomino per chiarezza E/R
ALTER TABLE web_categorie_sport RENAME COLUMN etichetta TO descrizione_web;
ALTER TABLE web_categorie_sport RENAME COLUMN web_categorie_sport_id TO web_tipi_viaggio_descrizioni_id;
ALTER TABLE web_categorie_sport RENAME TO web_tipi_viaggio_descrizioni;
ALTER TABLE web_tipi_viaggio_descrizioni RENAME CONSTRAINT web_categorie_sport_pkey TO web_tipi_viaggio_descrizioni_pkey;
ALTER TRIGGER trg_web_categorie_sport_audit ON web_tipi_viaggio_descrizioni RENAME TO trg_web_tipi_viaggio_descrizioni_audit;

-- 4) unique GLOBALE sullo slug (prima era per-azienda)
ALTER TABLE web_tipi_viaggio_descrizioni ADD CONSTRAINT uq_web_tipi_viaggio_descrizioni_slug UNIQUE (slug);

-- 5) rinomino la FK sul tipo viaggio (il vincolo segue il rename di tabella/colonna)
ALTER TABLE ana_tipo_viaggi RENAME COLUMN web_categoria_fk TO descrizione_web_fk;
ALTER TABLE ana_tipo_viaggi RENAME CONSTRAINT ana_tipo_viaggi_web_categoria_fk_fkey TO ana_tipo_viaggi_descrizione_web_fk_fkey;
