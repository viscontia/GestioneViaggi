-- ============================================================================
-- Pagamenti online: spenti finché la funzione non esiste
--
-- Il 2026-09-24 Antonio ha acceso l'interruttore «pagamenti online» nella
-- linguetta Funzioni Web di SFT. Ma il pagamento online sul sito non c'è
-- ancora: un interruttore acceso che non fa niente è una bugia che il database
-- racconta al sito — il giorno in cui il sito lo leggerà, mostrerebbe una
-- possibilità che non esiste.
--
-- Si spegne, non si cancella: la riga resta, e quando la funzione sarà pronta
-- la si riaccende dalla stessa schermata.
--
-- ✅ Applicato in locale e a PROD il 2026-09-25 (decisione di Adriano).
-- ============================================================================

BEGIN;

UPDATE web_aziende_funzioni SET attiva = false
 WHERE azienda_id = 2 AND funzione = 'pagamenti_online' AND attiva;

COMMIT;

-- Verifica
SELECT azienda_id, funzione, attiva FROM web_aziende_funzioni ORDER BY azienda_id, funzione;
