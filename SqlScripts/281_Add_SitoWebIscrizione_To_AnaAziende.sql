-- =============================================
-- Script: 281_Add_SitoWebIscrizione_To_AnaAziende.sql
-- Descrizione: Aggiunge il campo sito_web_iscrizione alla tabella ana_aziende
--              per memorizzare l'URL del programma di iscrizione clienti web
-- Data: 2026-03-17
-- =============================================

-- Aggiunge la colonna sito_web_iscrizione (nullable, VARCHAR 255)
ALTER TABLE ana_aziende
ADD COLUMN IF NOT EXISTS sito_web_iscrizione VARCHAR(255) DEFAULT NULL;

-- Commento sulla colonna
COMMENT ON COLUMN ana_aziende.sito_web_iscrizione IS 'URL del programma di iscrizione clienti dal web';
