-- Copia Causali Contabili da Azienda 6 (Offroad Adventures) a Azienda 2 (Sardegna Fuori Traccia)
INSERT INTO ana_tipi_causali (
    azienda_fk, 
    causale_codice, 
    causale_descrizione, 
    causale_segno, 
    causale_is_documento, 
    is_active, 
    created_by
)
SELECT 
    2, -- Nuova azienda
    causale_codice, 
    causale_descrizione, 
    causale_segno, 
    causale_is_documento, 
    is_active, 
    'segreteria@sardegnafuoritraccia.it' -- Utente azienda 2
FROM ana_tipi_causali
WHERE azienda_fk = 6
ON CONFLICT (azienda_fk, causale_codice) DO NOTHING;
