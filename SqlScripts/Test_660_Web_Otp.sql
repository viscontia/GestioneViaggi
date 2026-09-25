-- ============================================================================
-- Test dello script 660: i codici usa e getta del sito di iscrizione
--
-- Gira tutto dentro una transazione che si annulla: non lascia righe.
-- Usa il cliente 3870 (azienda 2, scheda completa con email); l'azienda 6
-- esiste e il 3870 non ci sta.
--
-- ⚠️ TUTTO IL TEST E' UNA TRANSAZIONE SOLA, quindi now() e' costante: tutte le
-- righe hanno lo stesso `created`, e «annullare» un codice (scadenza = now())
-- lo rende scaduto subito, perche' la verifica usa `scadenza <= now()`.
--
-- ⚠️ IL TETTO DI 3 RICHIESTE OGNI 15 MINUTI conta ogni chiamata a
-- fn_web_otp_genera andata a buon fine. Per non farlo scattare per caso, il
-- test svuota le righe del 3870 dove gli serve un budget pulito (inizio, caso 6,
-- caso 8): cosi' ogni caso prova quello che dice, e il caso 8 e' l'unico che il
-- tetto lo supera apposta.
-- ============================================================================

BEGIN;
DO $$
DECLARE r RECORD; v_codice TEXT;
BEGIN
    -- Budget pulito: in locale potrebbero esserci righe vere di prove al sito.
    DELETE FROM web_otp_codici WHERE cliente_id = 3870;

    -- 1. genera: restituisce un codice a 6 cifre e l'email in archivio
    SELECT * INTO r FROM fn_web_otp_genera(2, 3870);                     -- richiesta 1
    ASSERT r.esito = 'OK', 'genera: atteso OK, ottenuto ' || r.esito;
    ASSERT r.codice ~ '^[0-9]{6}$', 'genera: codice non di 6 cifre';
    ASSERT r.email = (SELECT btrim(cliente_email) FROM ana_clienti WHERE cliente_id = 3870),
           'genera: non e'' l''email in archivio';
    v_codice := r.codice;

    -- 2. il codice non e' in chiaro in tabella: c'e' la sua impronta sha256
    ASSERT NOT EXISTS (SELECT 1 FROM web_otp_codici WHERE codice_hash = v_codice),
           'il codice e'' salvato in chiaro';
    ASSERT (SELECT codice_hash = encode(sha256(convert_to(codice_sale || v_codice, 'UTF8')), 'hex')
                   AND length(codice_hash) = 64
              FROM web_otp_codici WHERE cliente_id = 3870
             ORDER BY web_otp_codici_id DESC LIMIT 1),
           'l''impronta non e'' sha256 di sale+codice';

    -- 3. sbagliato, poi giusto, poi riusato
    -- 'sbagliato' non e' di 6 cifre: non puo' coincidere per caso col codice vero.
    ASSERT fn_web_otp_verifica(2, 3870, 'sbagliato') = 'ERRATO', 'verifica sbagliata';
    ASSERT fn_web_otp_verifica(2, 3870, v_codice) = 'OK', 'verifica giusta';
    ASSERT fn_web_otp_verifica(2, 3870, v_codice) = 'NESSUN_CODICE', 'riuso ammesso';

    -- 4. tre errori esauriscono il codice, e dopo nemmeno quello giusto passa
    SELECT * INTO r FROM fn_web_otp_genera(2, 3870);                     -- richiesta 2
    ASSERT r.esito = 'OK', 'caso 4: genera ha risposto ' || r.esito;
    ASSERT fn_web_otp_verifica(2, 3870, 'sbagliato') = 'ERRATO', 'primo errore';
    ASSERT fn_web_otp_verifica(2, 3870, 'sbagliato') = 'ERRATO', 'secondo errore';
    ASSERT fn_web_otp_verifica(2, 3870, 'sbagliato') = 'TENTATIVI_ESAURITI', 'terzo errore';
    ASSERT fn_web_otp_verifica(2, 3870, r.codice) = 'TENTATIVI_ESAURITI', 'giusto dopo tre errori';

    -- 5. scaduto
    SELECT * INTO r FROM fn_web_otp_genera(2, 3870);                     -- richiesta 3
    ASSERT r.esito = 'OK', 'caso 5: genera ha risposto ' || r.esito;
    UPDATE web_otp_codici SET scadenza = now() - interval '1 second'
     WHERE cliente_id = 3870 AND usato_il IS NULL;
    ASSERT fn_web_otp_verifica(2, 3870, r.codice) = 'SCADUTO', 'scaduto accettato';

    -- 6. un codice nuovo annulla il precedente.
    -- Budget pulito, altrimenti qui scatterebbe il tetto e il caso proverebbe altro.
    DELETE FROM web_otp_codici WHERE cliente_id = 3870;
    SELECT * INTO r FROM fn_web_otp_genera(2, 3870);
    ASSERT r.esito = 'OK', 'caso 6: primo genera ha risposto ' || r.esito;
    v_codice := r.codice;
    SELECT * INTO r FROM fn_web_otp_genera(2, 3870);
    ASSERT r.esito = 'OK', 'caso 6: secondo genera ha risposto ' || r.esito;
    -- Il vecchio non vale mentre c'e' il nuovo (la verifica guarda l'ultimo)...
    ASSERT fn_web_otp_verifica(2, 3870, v_codice) = 'ERRATO',
           'vecchio codice accettato al posto del nuovo';
    ASSERT fn_web_otp_verifica(2, 3870, r.codice) = 'OK', 'il nuovo codice non passa';
    -- ...e nemmeno DOPO che il nuovo e' stato usato: qui l'ultimo aperto torna a
    -- essere il vecchio, e lo ferma solo l'annullamento fatto da genera.
    ASSERT fn_web_otp_verifica(2, 3870, v_codice) = 'SCADUTO',
           'il vecchio codice e'' tornato valido dopo l''uso del nuovo';

    -- 7. azienda sbagliata: nessun codice, e nessuna riga scritta
    SELECT * INTO r FROM fn_web_otp_genera(6, 3870);
    ASSERT r.esito = 'CLIENTE_ASSENTE', 'cliente di un''altra azienda';
    ASSERT r.codice IS NULL AND r.email IS NULL, 'CLIENTE_ASSENTE con codice o email';
    ASSERT NOT EXISTS (SELECT 1 FROM web_otp_codici WHERE azienda_id = 6), 'riga scritta per l''azienda sbagliata';

    -- 8. troppe richieste: tre passano, la quarta nei 15 minuti no
    DELETE FROM web_otp_codici WHERE cliente_id = 3870;
    ASSERT (SELECT esito FROM fn_web_otp_genera(2, 3870)) = 'OK', 'tetto: richiesta 1';
    ASSERT (SELECT esito FROM fn_web_otp_genera(2, 3870)) = 'OK', 'tetto: richiesta 2';
    ASSERT (SELECT esito FROM fn_web_otp_genera(2, 3870)) = 'OK', 'tetto: richiesta 3';
    SELECT * INTO r FROM fn_web_otp_genera(2, 3870);
    ASSERT r.esito = 'TROPPE_RICHIESTE', 'tetto richieste non applicato: ' || r.esito;
    ASSERT r.codice IS NULL, 'TROPPE_RICHIESTE con un codice';
    ASSERT (SELECT count(*) FROM web_otp_codici WHERE cliente_id = 3870) = 3,
           'la richiesta rifiutata ha scritto una riga';

    -- 8b. tetto giornaliero: 10 richieste nelle 24 ore, tutte fuori dai 15 minuti
    DELETE FROM web_otp_codici WHERE cliente_id = 3870;
    INSERT INTO web_otp_codici (azienda_id, cliente_id, email, codice_sale, codice_hash, scadenza, created)
    SELECT 2, 3870, 'prova@example.invalid', 's', 'h',
           now() - interval '1 hour' * g, now() - interval '1 hour' * g
      FROM generate_series(1, 10) g;          -- da 1 a 10 ore fa
    SELECT * INTO r FROM fn_web_otp_genera(2, 3870);
    ASSERT r.esito = 'TROPPE_RICHIESTE', 'tetto giornaliero non applicato: ' || r.esito;
    -- e con 9 si passa: il tetto e' 10, non meno
    DELETE FROM web_otp_codici WHERE cliente_id = 3870 AND created < now() - interval '9 hours 30 minutes';
    SELECT * INTO r FROM fn_web_otp_genera(2, 3870);
    ASSERT r.esito = 'OK', 'con 9 richieste nelle 24 ore: atteso OK, ottenuto ' || r.esito;

    -- 9. senza email in archivio nessun codice: andrebbe dove dice chi chiede
    DELETE FROM web_otp_codici WHERE cliente_id = 3870;
    UPDATE ana_clienti SET cliente_email = '  ' WHERE cliente_id = 3870;
    SELECT * INTO r FROM fn_web_otp_genera(2, 3870);
    ASSERT r.esito = 'SENZA_EMAIL', 'email vuota: atteso SENZA_EMAIL, ottenuto ' || r.esito;

    -- 10. anon non le puo' chiamare (script 659)
    ASSERT NOT has_function_privilege('anon', 'fn_web_otp_genera(integer,integer)', 'EXECUTE'),
           'anon puo'' generare codici';
    ASSERT NOT has_function_privilege('anon', 'fn_web_otp_verifica(integer,integer,text)', 'EXECUTE'),
           'anon puo'' verificare codici';
    ASSERT NOT has_table_privilege('anon', 'web_otp_codici', 'SELECT'),
           'anon puo'' leggere la tabella dei codici';

    RAISE NOTICE 'Test 660: tutto OK';
END $$;
ROLLBACK;
