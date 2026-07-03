-- Task 1.8 — web_traduzioni: traduzioni per-campo (polimorfica). IT = sorgente (non qui).
CREATE TABLE web_traduzioni (
    web_traduzioni_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entita             VARCHAR(40)  NOT NULL,   -- es. web_tour_contenuti, web_tour_itinerario, ...
    entita_id          BIGINT       NOT NULL,   -- id del record originale
    campo              VARCHAR(60)  NOT NULL,   -- es. descrizione_html
    lingua             CHAR(2)      NOT NULL,   -- CHECK sotto (IT esclusa: è la sorgente)
    testo              TEXT         NOT NULL,
    tradotto_auto      BOOLEAN      NOT NULL DEFAULT true,
    revisionato        BOOLEAN      NOT NULL DEFAULT false,
    obsoleto           BOOLEAN      NOT NULL DEFAULT false,  -- IT modificato dopo → da riaggiornare
    data_traduzione    TIMESTAMPTZ,
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT chk_web_traduzioni_lingua CHECK (lingua IN ('FR','EN','DE','ES')),
    CONSTRAINT uq_web_traduzioni UNIQUE (entita, entita_id, campo, lingua)
);
CREATE INDEX idx_web_traduzioni_azienda ON web_traduzioni (azienda_id);
CREATE TRIGGER trg_web_traduzioni_audit BEFORE INSERT OR UPDATE ON web_traduzioni
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_traduzioni ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_traduzioni
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
