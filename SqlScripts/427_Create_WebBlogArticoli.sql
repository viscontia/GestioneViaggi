-- Task 1.19 — web_blog_articoli: blog/diario (PREDISPOSIZIONE, non nel 1° rilascio)
CREATE TABLE web_blog_articoli (
    web_blog_articoli_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    titolo                  VARCHAR(255) NOT NULL,
    slug                    VARCHAR(160) NOT NULL,
    sottotitolo             VARCHAR(255),
    contenuto_html          TEXT,                        -- RichText
    immagine_url            TEXT,                        -- Supabase Storage
    stato_pubblicazione     VARCHAR(12)  NOT NULL DEFAULT 'bozza',
    data_pubblicazione      TIMESTAMPTZ,
    meta_title              VARCHAR(255),
    meta_description        VARCHAR(320),
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT chk_web_blog_articoli_stato CHECK (stato_pubblicazione IN ('bozza','pubblicato','archiviato')),
    CONSTRAINT uq_web_blog_articoli_slug UNIQUE (azienda_id, slug)
);
CREATE INDEX idx_web_blog_articoli_stato ON web_blog_articoli (azienda_id, stato_pubblicazione);
CREATE TRIGGER trg_web_blog_articoli_audit BEFORE INSERT OR UPDATE ON web_blog_articoli
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_blog_articoli ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_blog_articoli
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
