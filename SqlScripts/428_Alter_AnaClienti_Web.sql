-- Task 1.20 — ana_clienti: consenso marketing (§1.1) + collegamento contabilità (§1.4, predisposizione Fase 4)
-- Nota: la Spec §1.4 cita "ana_fornitori" come target di controparte_fk, ma quella tabella NON esiste;
-- la controparte fiscale reale è ana_controparti(controparte_id) INTEGER. La FK è DIFFERITA a Fase 4
-- (la controparte si crea/abbina al primo incasso): qui si aggiunge solo la colonna di predisposizione.
ALTER TABLE ana_clienti
    ADD COLUMN consenso_marketing        BOOLEAN     NOT NULL DEFAULT false,
    ADD COLUMN consenso_marketing_data   TIMESTAMPTZ NULL,
    ADD COLUMN consenso_marketing_fonte  VARCHAR(30) NULL,   -- iscrizione/gestionale/import
    ADD COLUMN controparte_fk            INTEGER     NULL;   -- predisposizione; target previsto ana_controparti(controparte_id); FK in Fase 4
