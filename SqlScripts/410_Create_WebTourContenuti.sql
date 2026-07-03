-- Task 1.3 — web_tour_contenuti: contenuti editoriali del tour (1:1 con ana_viaggi)
CREATE TABLE web_tour_contenuti (
    web_tour_contenuti_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    viaggio_id_fk            INTEGER      NOT NULL UNIQUE REFERENCES ana_viaggi(viaggio_id),
    sottotitolo              VARCHAR(255),                   -- es. "Selvaggia Sardegna"
    descrizione_html         TEXT,                           -- RichText (riassunto 2-3 righe)
    difficolta               VARCHAR(20),                    -- CHECK sotto
    durata_testo             VARCHAR(100),                   -- es. "5gg/4nn in campeggio"
    luoghi_visitati          TEXT,                           -- lista separata da virgola
    info_pernottamento_html  TEXT,                           -- RichText
    info_pasti_html          TEXT,                           -- RichText
    info_equipaggiamento_html TEXT,                          -- RichText
    altre_info_html          TEXT,                           -- RichText
    slug                     VARCHAR(160) NOT NULL,          -- per URL pagina tour
    meta_title               VARCHAR(255),                   -- SEO
    meta_description         VARCHAR(320),                   -- SEO
    stato_pubblicazione      VARCHAR(12)  NOT NULL DEFAULT 'bozza',
    ordine                   INTEGER      NOT NULL DEFAULT 0,
    data_pubblicazione       TIMESTAMPTZ,
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT chk_web_tour_contenuti_difficolta
        CHECK (difficolta IN ('turistica','media','medio_alta','alta')),
    CONSTRAINT chk_web_tour_contenuti_stato
        CHECK (stato_pubblicazione IN ('bozza','pubblicato','archiviato')),
    CONSTRAINT uq_web_tour_contenuti_slug UNIQUE (azienda_id, slug)
);
CREATE INDEX idx_web_tour_contenuti_stato
    ON web_tour_contenuti (azienda_id, stato_pubblicazione);
CREATE TRIGGER trg_web_tour_contenuti_audit BEFORE INSERT OR UPDATE ON web_tour_contenuti
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_tour_contenuti ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_tour_contenuti
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
