-- =============================================================================
-- 541 — ana_clienti: gli invarianti scendono nel database
-- =============================================================================
-- Primo passo della centralizzazione decisa il 2026-08-19. Fino a oggi le regole
-- sui clienti vivevano tutte nel C#, dove il sito di iscrizione non arriva: il
-- database accettava quasi tutto, quindi dal sito poteva entrare un'anagrafica che
-- la form desktop avrebbe rifiutato.
--
-- Qui scendono solo le regole che sono INVARIANTI VERI: misurate sui dati reali di
-- PROD il 2026-08-20, nessuna riga le viola. Non c'e' bonifica da fare e non c'e'
-- niente da decidere — valgono per app e sito dal primo istante.
--
-- NON scende qui, e non e' una dimenticanza:
--   · "data di rilascio non nel futuro" — un CHECK deve essere IMMUTABLE, e
--     CURRENT_DATE non lo e'. PostgreSQL lo rifiuterebbe. Va nella funzione CRUD.
--   · "documento non scaduto" — stessa ragione tecnica, e anche concettuale: un
--     documento scade da solo col tempo, un vincolo renderebbe la scheda non
--     salvabile l'indomani. Resta un avviso (decisione del 2026-08-20).
--   · email obbligatoria — NON e' un invariante del cliente: dipende dal ruolo
--     nel viaggio (pilota si', accompagnatore no), che vive su mov_clienti_viaggi.
-- =============================================================================

BEGIN;

-- 1. Email: se c'e', deve essere un'email ---------------------------------------
ALTER TABLE ana_clienti DROP CONSTRAINT IF EXISTS ana_clienti_email_formato_check;
ALTER TABLE ana_clienti ADD CONSTRAINT ana_clienti_email_formato_check
    CHECK (cliente_email IS NULL OR btrim(cliente_email) = ''
           OR cliente_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$');

-- 2. e 3. Nome e cognome: due caratteri sono il minimo per essere un nome --------
ALTER TABLE ana_clienti DROP CONSTRAINT IF EXISTS ana_clienti_cognome_minimo_check;
ALTER TABLE ana_clienti ADD CONSTRAINT ana_clienti_cognome_minimo_check
    CHECK (length(btrim(cliente_cognome)) >= 2);

ALTER TABLE ana_clienti DROP CONSTRAINT IF EXISTS ana_clienti_nome_minimo_check;
ALTER TABLE ana_clienti ADD CONSTRAINT ana_clienti_nome_minimo_check
    CHECK (length(btrim(cliente_nome)) >= 2);

-- 4. Un documento non puo' essere stato rilasciato prima che la persona nascesse -
ALTER TABLE ana_clienti DROP CONSTRAINT IF EXISTS ana_clienti_rilascio_dopo_nascita_check;
ALTER TABLE ana_clienti ADD CONSTRAINT ana_clienti_rilascio_dopo_nascita_check
    CHECK (cliente_documento_rilasciato_data IS NULL
           OR cliente_data_nascita IS NULL
           OR cliente_documento_rilasciato_data > cliente_data_nascita);

-- 5. Ne' scadere prima di essere stato rilasciato --------------------------------
ALTER TABLE ana_clienti DROP CONSTRAINT IF EXISTS ana_clienti_scadenza_dopo_rilascio_check;
ALTER TABLE ana_clienti ADD CONSTRAINT ana_clienti_scadenza_dopo_rilascio_check
    CHECK (cliente_documento_rilasciato_scadenza IS NULL
           OR cliente_documento_rilasciato_data IS NULL
           OR cliente_documento_rilasciato_scadenza > cliente_documento_rilasciato_data);

-- 6. IBAN: lunghezza plausibile e due lettere di paese in testa ------------------
ALTER TABLE ana_clienti DROP CONSTRAINT IF EXISTS ana_clienti_iban_formato_check;
ALTER TABLE ana_clienti ADD CONSTRAINT ana_clienti_iban_formato_check
    CHECK (cliente_iban IS NULL OR btrim(cliente_iban) = ''
           OR (length(btrim(cliente_iban)) BETWEEN 15 AND 34
               AND btrim(cliente_iban) ~ '^[A-Za-z]{2}'));

COMMENT ON CONSTRAINT ana_clienti_email_formato_check ON ana_clienti IS
'Formato email. Non impone la presenza: l''obbligo dipende dal ruolo nel viaggio (pilota si'', accompagnatore no).';

COMMIT;
