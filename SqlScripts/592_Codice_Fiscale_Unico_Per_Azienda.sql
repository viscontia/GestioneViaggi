-- =============================================================================
-- 592 — Un codice fiscale, una persona (dentro la stessa azienda)
-- =============================================================================
--
-- Verificato il 2026-09-05 su richiesta dell'utente, preparando il test F3.
--
-- I due software rifiutano entrambi un codice fiscale gia' registrato: lo fa
-- `fn_ana_clienti_verifica_duplicato`, che risponde ERRORE/STESSO_CF, ed e' la
-- stessa funzione per il gestionale e per il sito. Da li' non si passa.
--
-- ⚠️ Il database pero' lo permetteva. L'unico indice unico e'
-- `ana_clienti_idx06_scoped` su (azienda, cognome, nome, data di nascita, CF):
-- basta cambiare il nome perche' lo stesso codice fiscale entri una seconda
-- volta. Provato: due schede con CF `PPPPPP80C15F979Q` e nomi diversi sono state
-- accettate senza un lamento.
--
-- Finche' si passa dalle due applicazioni non succede. Ma una regola che vale
-- ovunque deve stare nel database — e' il principio del progetto — perche' li'
-- vale anche per l'importazione, per una correzione fatta a mano e per il
-- prossimo software che si collegherà.
--
-- ⚠️ L'unicita' e' PER AZIENDA, non globale: le aziende sono silos, e la stessa
-- persona esiste legittimamente in due anagrafiche diverse — lo script 588 ne ha
-- appena create 25 cosi'. Un indice globale le rifiuterebbe tutte.
--
-- Dati esistenti: nessuna violazione. Locale 0, PROD 0 su tutte le aziende.
-- =============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS ana_clienti_cf_unico_per_azienda
    ON ana_clienti (azienda_fk, upper(btrim(cliente_codicefiscale)))
    -- Chi non ha il codice fiscale non e' un duplicato di nessuno: gli stranieri
    -- spesso non ce l'hanno, e la colonna resta vuota per molti clienti storici.
    WHERE nullif(btrim(cliente_codicefiscale), '') IS NOT NULL;

COMMENT ON INDEX ana_clienti_cf_unico_per_azienda IS
'Un codice fiscale identifica una persona sola dentro la stessa azienda. Le applicazioni
lo controllavano gia'' (fn_ana_clienti_verifica_duplicato), il database no: bastava
cambiare il nome per infilare lo stesso codice due volte. ⚠️ Per azienda e non globale —
le aziende sono silos e la stessa persona vive legittimamente in due anagrafiche.';
