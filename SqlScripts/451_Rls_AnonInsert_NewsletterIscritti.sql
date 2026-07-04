-- Blocco 3 (Task 3.4) - Iscrizione newsletter dal sito pubblico (unico caso di scrittura anon).
-- Il trigger trg_web_audit() popola created_by='anon' (nessun my.app_user dal sito):
-- in DB si distinguono a colpo d'occhio gli iscritti arrivati dal form pubblico.
--
-- GRANT INSERT a livello di colonna: il sito NON puo' impostare stato (default 'attivo'),
-- cliente_fk (arricchimento solo lato gestionale) ne' le colonne di audit.
-- PK GENERATED ALWAYS AS IDENTITY: sequenza gestita internamente, nessun GRANT sequence.
--
-- NB (da valutare in Fase 3, anti-spam): alternativa piu' blindata = funzione SECURITY DEFINER
-- fn_web_newsletter_signup(...) con validazione/rate-limit e revoca dell'INSERT diretto.

GRANT INSERT (email, nome, cognome, lingua, consenso, consenso_data, consenso_fonte,
              token_disiscrizione, azienda_id)
    ON web_newsletter_iscritti TO anon;

CREATE POLICY anon_insert_iscrizione ON web_newsletter_iscritti
    FOR INSERT TO anon
    WITH CHECK (stato = 'attivo' AND consenso = true);
