-- ============================================================================
-- 711 — Il dizionario degli errori per gli utenti finali (ToDo 5 del sito; decisione di Adriano del 2026-10-31)
--
-- «Ogni errore ha un codice e un testo corrispondente nelle 5 lingue. Questo ci aiuterà in tutti gli sviluppi
-- relativi a sw lato web che vanno in mano agli utenti finali.» Nel database («assolutamente A»): un posto solo per il
-- modulo di iscrizione, il sito pubblico e i programmi che verranno.
-- Disegno: GitHub/Iscrizione-Viaggi-Offroad PostgreSQL/docs/plans/2026-10-31-wizard-cinque-lingue-inventario.md
--
--   - web_errori: un codice per riga (ISCR_ modulo, SITO_ sito, COMUNE_ condivisi), i valori da riempire
--     («{posti}») e una nota interna su quando capita. Vale per il prodotto, non per un'azienda;
--   - web_errori_testi: il testo per lingua (IT, EN, DE, FR, ES). Una voce nuova entra con le 5 lingue nella
--     stessa modifica: il test lo controlla. Tono del sito: tu in it/en/es, Sie in de, vous in fr;
--   - fn_web_errori(lingua): il dizionario di una lingua, {codice: testo}, con l'italiano dove manca (pubblica);
--   - fn_errore_testo(codice, lingua, valori): il testo riempito (lingua → italiano → il codice stesso);
--   - fn_errore(codice, valori): per le funzioni SQL, al posto di RAISE EXCEPTION '<frase>'. Messaggio = testo
--     italiano (il gestionale lo mostra come oggi), HINT = 'errore:<codice>', DETAIL = i valori in JSON: i
--     programmi web riconoscono il codice e mostrano il testo nella lingua del cliente.
-- Rigiocabile (i testi di partenza si riscrivono). Test: Test_711_Web_Dizionario_Errori.sql
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS web_errori (
    codice     varchar(60)  PRIMARY KEY CHECK (codice ~ '^(ISCR|SITO|COMUNE)(_[A-Z0-9]+)+$'),
    area       varchar(10)  NOT NULL CHECK (area IN ('ISCR', 'SITO', 'COMUNE')),
    parametri  text[]       NOT NULL DEFAULT '{}',
    nota       text,
    updated_by varchar(100) NOT NULL DEFAULT current_user,
    updated    timestamptz  NOT NULL DEFAULT now(),
    CHECK (codice LIKE area || '\_%')
);

CREATE TABLE IF NOT EXISTS web_errori_testi (
    codice     varchar(60)  NOT NULL REFERENCES web_errori (codice) ON DELETE CASCADE ON UPDATE CASCADE,
    lingua     varchar(2)   NOT NULL CHECK (lingua IN ('IT', 'EN', 'DE', 'FR', 'ES')),
    testo      text         NOT NULL CHECK (btrim(testo) <> ''),
    updated_by varchar(100) NOT NULL DEFAULT current_user,
    updated    timestamptz  NOT NULL DEFAULT now(),
    PRIMARY KEY (codice, lingua)
);

DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['web_errori', 'web_errori_testi'] LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('REVOKE ALL ON TABLE %I FROM PUBLIC', t);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            EXECUTE format('REVOKE ALL ON TABLE %I FROM anon, authenticated', t);
        END IF;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- Le funzioni
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_web_errori(p_lingua varchar)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT coalesce(jsonb_object_agg(e.codice, coalesce(l.testo, i.testo, e.codice) ORDER BY e.codice), '{}'::jsonb)
      FROM web_errori e
      LEFT JOIN web_errori_testi l ON l.codice = e.codice AND l.lingua = upper(btrim(coalesce(p_lingua, '')))
      LEFT JOIN web_errori_testi i ON i.codice = e.codice AND i.lingua = 'IT';
$$;
COMMENT ON FUNCTION fn_web_errori(varchar) IS
    'Il dizionario degli errori per gli utenti finali in una lingua: {codice: testo}; l''italiano dove manca la lingua (script 711).';

CREATE OR REPLACE FUNCTION fn_errore_testo(p_codice varchar, p_lingua varchar, p_valori jsonb DEFAULT '{}')
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_testo text;
    v_k     text;
    v_v     text;
BEGIN
    SELECT coalesce(l.testo, i.testo) INTO v_testo
      FROM web_errori e
      LEFT JOIN web_errori_testi l ON l.codice = e.codice AND l.lingua = upper(btrim(coalesce(p_lingua, '')))
      LEFT JOIN web_errori_testi i ON i.codice = e.codice AND i.lingua = 'IT'
     WHERE e.codice = p_codice;
    IF v_testo IS NULL THEN
        RETURN p_codice;   -- codice sconosciuto: almeno si sa quale errore era
    END IF;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each_text(coalesce(p_valori, '{}'::jsonb)) LOOP
        v_testo := replace(v_testo, '{' || v_k || '}', coalesce(v_v, ''));
    END LOOP;
    RETURN v_testo;
END $$;

CREATE OR REPLACE FUNCTION fn_errore(p_codice varchar, p_valori jsonb DEFAULT '{}')
RETURNS void
LANGUAGE plpgsql STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
    RAISE EXCEPTION USING
        ERRCODE = 'P0001',
        MESSAGE = fn_errore_testo(p_codice, 'IT', p_valori),
        HINT    = 'errore:' || p_codice,
        DETAIL  = coalesce(p_valori, '{}'::jsonb)::text;
END $$;
COMMENT ON FUNCTION fn_errore(varchar, jsonb) IS
    'Solleva un errore del dizionario (script 711): messaggio in italiano, HINT errore:<codice>, DETAIL i valori in JSON.';

-- ---------------------------------------------------------------------------
-- I codici di partenza: gli errori comuni a ogni programma web (gli altri arrivano con i passi del lavoro)
-- ---------------------------------------------------------------------------
INSERT INTO web_errori (codice, area, parametri, nota) VALUES
    ('COMUNE_SERVIZIO_NON_DISPONIBILE', 'COMUNE', '{}', 'Il database o un servizio esterno non risponde. Serve anche a database fermo: i programmi ne tengono una copia.'),
    ('COMUNE_ERRORE_IMPREVISTO',        'COMUNE', '{}', 'Un errore senza codice più preciso: la riserva di ogni programma.'),
    ('COMUNE_DATI_MANCANTI',            'COMUNE', '{}', 'Mancano campi obbligatori nella richiesta.'),
    ('COMUNE_SESSIONE_SCADUTA',         'COMUNE', '{}', 'La sessione del visitatore non c''è più (scaduta o cookie cancellati).'),
    ('COMUNE_TROPPE_RICHIESTE',         'COMUNE', '{}', 'Limite di frequenza superato (codici, moduli).'),
    ('COMUNE_CAMPO_TROPPO_LUNGO',       'COMUNE', '{campo,massimo}', 'Un campo supera la lunghezza massima.')
ON CONFLICT (codice) DO UPDATE SET area = EXCLUDED.area, parametri = EXCLUDED.parametri, nota = EXCLUDED.nota,
                                   updated_by = current_user, updated = now();

INSERT INTO web_errori_testi (codice, lingua, testo) VALUES
    ('COMUNE_SERVIZIO_NON_DISPONIBILE', 'IT', 'Il servizio non è disponibile in questo momento. Riprova fra qualche minuto.'),
    ('COMUNE_SERVIZIO_NON_DISPONIBILE', 'EN', 'The service is not available right now. Please try again in a few minutes.'),
    ('COMUNE_SERVIZIO_NON_DISPONIBILE', 'DE', 'Der Dienst ist im Moment nicht verfügbar. Bitte versuchen Sie es in ein paar Minuten erneut.'),
    ('COMUNE_SERVIZIO_NON_DISPONIBILE', 'FR', 'Le service n''est pas disponible pour le moment. Veuillez réessayer dans quelques minutes.'),
    ('COMUNE_SERVIZIO_NON_DISPONIBILE', 'ES', 'El servicio no está disponible en este momento. Vuelve a intentarlo dentro de unos minutos.'),

    ('COMUNE_ERRORE_IMPREVISTO', 'IT', 'Si è verificato un errore imprevisto. Riprova; se il problema continua, scrivici.'),
    ('COMUNE_ERRORE_IMPREVISTO', 'EN', 'Something went wrong. Please try again; if the problem persists, write to us.'),
    ('COMUNE_ERRORE_IMPREVISTO', 'DE', 'Es ist ein unerwarteter Fehler aufgetreten. Bitte versuchen Sie es erneut; wenn das Problem weiterhin besteht, schreiben Sie uns.'),
    ('COMUNE_ERRORE_IMPREVISTO', 'FR', 'Une erreur inattendue s''est produite. Veuillez réessayer ; si le problème persiste, écrivez-nous.'),
    ('COMUNE_ERRORE_IMPREVISTO', 'ES', 'Se ha producido un error inesperado. Vuelve a intentarlo; si el problema continúa, escríbenos.'),

    ('COMUNE_DATI_MANCANTI', 'IT', 'Mancano alcuni dati obbligatori: controlla i campi evidenziati.'),
    ('COMUNE_DATI_MANCANTI', 'EN', 'Some required information is missing: please check the highlighted fields.'),
    ('COMUNE_DATI_MANCANTI', 'DE', 'Einige Pflichtangaben fehlen: Bitte prüfen Sie die markierten Felder.'),
    ('COMUNE_DATI_MANCANTI', 'FR', 'Certaines informations obligatoires manquent : veuillez vérifier les champs signalés.'),
    ('COMUNE_DATI_MANCANTI', 'ES', 'Faltan algunos datos obligatorios: revisa los campos marcados.'),

    ('COMUNE_SESSIONE_SCADUTA', 'IT', 'La sessione è scaduta: ricomincia dall''inizio, i dati già salvati non si perdono.'),
    ('COMUNE_SESSIONE_SCADUTA', 'EN', 'Your session has expired: please start again from the beginning; the information already saved is not lost.'),
    ('COMUNE_SESSIONE_SCADUTA', 'DE', 'Ihre Sitzung ist abgelaufen: Bitte beginnen Sie von vorn; bereits gespeicherte Angaben gehen nicht verloren.'),
    ('COMUNE_SESSIONE_SCADUTA', 'FR', 'Votre session a expiré : veuillez recommencer depuis le début ; les informations déjà enregistrées ne sont pas perdues.'),
    ('COMUNE_SESSIONE_SCADUTA', 'ES', 'La sesión ha caducado: vuelve a empezar desde el principio; los datos ya guardados no se pierden.'),

    ('COMUNE_TROPPE_RICHIESTE', 'IT', 'Troppi tentativi in poco tempo. Aspetta qualche minuto e riprova.'),
    ('COMUNE_TROPPE_RICHIESTE', 'EN', 'Too many attempts in a short time. Please wait a few minutes and try again.'),
    ('COMUNE_TROPPE_RICHIESTE', 'DE', 'Zu viele Versuche in kurzer Zeit. Bitte warten Sie ein paar Minuten und versuchen Sie es erneut.'),
    ('COMUNE_TROPPE_RICHIESTE', 'FR', 'Trop de tentatives en peu de temps. Veuillez patienter quelques minutes et réessayer.'),
    ('COMUNE_TROPPE_RICHIESTE', 'ES', 'Demasiados intentos en poco tiempo. Espera unos minutos y vuelve a intentarlo.'),

    ('COMUNE_CAMPO_TROPPO_LUNGO', 'IT', 'Il campo «{campo}» è troppo lungo: al massimo {massimo} caratteri.'),
    ('COMUNE_CAMPO_TROPPO_LUNGO', 'EN', 'The field “{campo}” is too long: {massimo} characters at most.'),
    ('COMUNE_CAMPO_TROPPO_LUNGO', 'DE', 'Das Feld „{campo}“ ist zu lang: höchstens {massimo} Zeichen.'),
    ('COMUNE_CAMPO_TROPPO_LUNGO', 'FR', 'Le champ « {campo} » est trop long : {massimo} caractères au maximum.'),
    ('COMUNE_CAMPO_TROPPO_LUNGO', 'ES', 'El campo «{campo}» es demasiado largo: como máximo {massimo} caracteres.')
ON CONFLICT (codice, lingua) DO UPDATE SET testo = EXCLUDED.testo, updated_by = current_user, updated = now();

-- ---------------------------------------------------------------------------
-- Permessi: il dizionario si legge in pubblico (è testo per i visitatori); il resto no.
-- In PROD una funzione nuova nasce eseguibile da chiunque: si toglie a tutti, poi si dà.
-- ---------------------------------------------------------------------------
DO $$
DECLARE f text;
BEGIN
    FOREACH f IN ARRAY ARRAY['fn_errore_testo(varchar, varchar, jsonb)', 'fn_errore(varchar, jsonb)'] LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, authenticated', f);
        END IF;
    END LOOP;
    EXECUTE 'REVOKE EXECUTE ON FUNCTION fn_web_errori(varchar) FROM PUBLIC';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION fn_web_errori(varchar) TO anon, authenticated';
    END IF;
END $$;

COMMIT;
