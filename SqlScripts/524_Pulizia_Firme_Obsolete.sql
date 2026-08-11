-- Rimozione delle firme obsolete lasciate dai CREATE OR REPLACE con parametri aggiunti.
--
-- IL PROBLEMA. CREATE OR REPLACE FUNCTION sostituisce una function solo a PARITA' di firma: se
-- si aggiunge un parametro, PostgreSQL crea una NUOVA function e la vecchia resta. Gli script
-- 512 -> 518 -> 520 (blocchi) e 517 -> 519 (indirizzi) hanno aggiunto parametri, quindi hanno
-- lasciato dietro di se' sette versioni superate.
--
-- Perche' non e' innocuo: una chiamata che non elenca tutti i parametri diventa AMBIGUA e
-- PostgreSQL la rifiuta con "function is not unique". Il C# oggi passa sempre l'elenco completo
-- con i cast espliciti e quindi funziona, ma qualunque chiamata manuale o futura piu' breve
-- fallirebbe - ed e' successo davvero, in un test di questa stessa sessione.
--
-- ⚠️ In PROD accadra' lo stesso applicando gli script in ordine: questo script va eseguito DOPO
-- di essi, ed e' il motivo per cui esiste.
--
-- Le firme rimosse sono elencate per esteso, non individuate da un ciclo: cancellare function
-- per pattern e' esattamente il modo di perdere quella giusta.

-- Blocchi newsletter: restano le firme a 18 (insert) e 16 (update) parametri.
DROP FUNCTION IF EXISTS fn_web_newsletter_blocchi_insert(
    integer, bigint, character varying, integer, character varying, smallint,
    character varying, character varying, text, character varying, character varying,
    character varying, character varying, character varying, integer);

DROP FUNCTION IF EXISTS fn_web_newsletter_blocchi_insert(
    integer, bigint, character varying, integer, character varying, smallint,
    character varying, character varying, text, character varying, character varying,
    character varying, character varying, character varying, integer, bigint);

DROP FUNCTION IF EXISTS fn_web_newsletter_blocchi_update(
    bigint, integer, character varying, smallint, character varying, character varying,
    text, character varying, character varying, character varying, character varying,
    character varying, integer);

DROP FUNCTION IF EXISTS fn_web_newsletter_blocchi_update(
    bigint, integer, character varying, smallint, character varying, character varying,
    text, character varying, character varying, character varying, character varying,
    character varying, integer, bigint);

-- Indirizzi web: restano le firme a 9 (insert) e 10 (update) parametri.
DROP FUNCTION IF EXISTS fn_web_indirizzi_insert(
    integer, character varying, character varying, text, integer, boolean);

DROP FUNCTION IF EXISTS fn_web_indirizzi_update(
    bigint, integer, character varying, character varying, text, integer, boolean);

-- Verifica: ognuna di queste deve restare in UNA sola versione.
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN
        SELECT proname, count(*) AS versioni
          FROM pg_proc
         WHERE proname IN ('fn_web_newsletter_blocchi_insert','fn_web_newsletter_blocchi_update',
                           'fn_web_indirizzi_insert','fn_web_indirizzi_update')
         GROUP BY proname
    LOOP
        IF r.versioni > 1 THEN
            RAISE WARNING 'ATTENZIONE: % ha ancora % versioni: le chiamate parziali resteranno ambigue.',
                          r.proname, r.versioni;
        ELSE
            RAISE NOTICE '% : una sola versione, corretto.', r.proname;
        END IF;
    END LOOP;
END $$;
