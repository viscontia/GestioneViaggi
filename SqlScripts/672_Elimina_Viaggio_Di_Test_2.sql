-- ============================================================================
-- 672 — Via il «VIAGGIO DI TEST 2» (viaggio 903, partenza 1865 del 09/04/2026,
-- azienda 2), chiesto da Adriano il 2026-09-27: compariva nel promemoria
-- all'apertura (L2) come partenza passata non effettuata.
--
-- Collegati (verificato su tutte le chiavi esterne verso ana_viaggi e
-- ana_date_viaggi): 2 camere (mov_clienti_alloggi), 2 iscrizioni
-- (mov_clienti_viaggi). Niente scheda web, newsletter, pagamenti, contabilita'.
--
-- ⚠️ Le anagrafiche dei due iscritti RESTANO: si cancellano il viaggio e le
-- iscrizioni, non le persone.
--
-- Il viaggio e la data si tolgono con sp_ana_viaggi_delete, la stessa del
-- gestionale, che rifiuta se restano iscrizioni o camere: e' la prova che non
-- e' rimasto niente appeso. Rigiocabile (se il viaggio non c'e' non fa niente).
--
-- ✅ Applicato in locale e a PROD il 2026-09-27 (anagrafiche 3870 e 3944 intatte).
-- ============================================================================

BEGIN;

DO $$
DECLARE r record;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM ana_viaggi
                    WHERE viaggio_id = 903 AND azienda_id = 2
                      AND viaggio_descrizione_breve = 'VIAGGIO DI TEST 2') THEN
        RAISE NOTICE '672: viaggio 903 gia'' assente, niente da fare';
        RETURN;
    END IF;

    DELETE FROM mov_clienti_alloggi WHERE viaggio_id_fk = 903;
    DELETE FROM mov_clienti_viaggi  WHERE viaggio_id_fk = 903;

    SELECT * INTO r FROM sp_ana_viaggi_delete(903);
    IF NOT r.deleted THEN
        RAISE EXCEPTION '672: viaggio non cancellato: %', r.error_message;
    END IF;
    RAISE NOTICE '672: viaggio 903 cancellato';
END $$;

COMMIT;
