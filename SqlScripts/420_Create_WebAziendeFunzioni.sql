-- Task 1.13 — web_aziende_funzioni: toggle funzioni per-azienda (recensioni/pagamenti_online/blog/newsletter_esp/…)
CREATE TABLE web_aziende_funzioni (
    web_aziende_funzioni_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    funzione             VARCHAR(40)  NOT NULL,        -- recensioni/pagamenti_online/blog/newsletter_esp/…
    attiva               BOOLEAN      NOT NULL DEFAULT false,
    parametri            JSONB,                        -- es. {"fonte":"google"} per recensioni
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT uq_web_aziende_funzioni UNIQUE (azienda_id, funzione)
);
CREATE TRIGGER trg_web_aziende_funzioni_audit BEFORE INSERT OR UPDATE ON web_aziende_funzioni
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_aziende_funzioni ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_aziende_funzioni
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
