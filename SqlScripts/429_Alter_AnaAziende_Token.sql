-- Task 1.21 — ana_aziende: token per il link "Iscriviti" dell'app iscrizioni (§1.2)
-- Da allineare al valore usato dall'app Flask su Hetzner (.env: AZIENDA_ID/FLASK_SECRET_KEY; app.py ~riga 353).
ALTER TABLE ana_aziende
    ADD COLUMN token_iscrizione VARCHAR(64) NULL;
