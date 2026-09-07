-- =============================================================================
-- 622 — Via l'ESP: il piano è stato abbandonato, e va tolto anche il ponteggio
-- =============================================================================
--
-- ESP sta per *Email Service Provider*: l'idea di mandare le mail — newsletter
-- comprese — attraverso un servizio esterno (Brevo, Mailchimp, SES), con la chiave
-- API cifrata per azienda.
--
-- ⚠️ Il piano è stato **abbandonato il 2026-07-12**: il canale email è lo SMTP del
-- cliente (`ana_aziende_smtp`), instradato da `EmailSenderFactory`. La decisione di
-- allora diceva di lasciare la tabella «predisposta ma inutilizzata, pronta per un
-- eventuale uso futuro».
--
-- Adriano, 2026-09-07: «sì, confermo piano abbandonato, puoi eliminare».
--
-- Perché toglierla e non lasciarla dov'è:
--   • le sue tre funzioni di scrittura risultavano fra le **50 senza chiamanti**, e
--     una funzione che nessuno chiama è la prossima strada che qualcuno prende;
--   • ⛔️ tiene una colonna per una **chiave API cifrata**: un posto dove mettere un
--     segreto, in un sistema che quel segreto non lo usa. Un contenitore di segreti
--     dimenticato è peggio di nessun contenitore;
--   • «pronta per un uso futuro» non è mai vero: il giorno che servisse davvero, il
--     provider e il modello sarebbero altri, e questa andrebbe rifatta comunque.
--
-- ⚠️ **Su PROD non esiste**: né tabella né funzioni (verificato in sola lettura il
-- 2026-09-07). È nata solo negli ambienti dove sono stati applicati gli script 421 e
-- 443. Lì questo script la toglie; su PROD non troverà niente e non farà nulla.
--
-- ⚠️ Gli script **421** e **443** restano nella sequenza — non si riscrive la storia —
-- ma sono superati da questo. Lo script **475** invece **serve ancora**: cifra anche i
-- segreti SMTP, che sono vivi.
-- =============================================================================

-- In locale la tabella è vuota (verificato: 0 righe). Se in un ambiente qualcuno ci
-- avesse messo dentro qualcosa, questo lo direbbe invece di cancellarlo in silenzio.
DO $$
DECLARE v_righe INTEGER;
BEGIN
    IF to_regclass('ana_aziende_esp') IS NULL THEN
        RAISE NOTICE 'ana_aziende_esp non esiste in questo ambiente: niente da fare.';
        RETURN;
    END IF;

    EXECUTE 'SELECT count(*) FROM ana_aziende_esp' INTO v_righe;
    IF v_righe > 0 THEN
        RAISE EXCEPTION
            'ana_aziende_esp contiene % righe: qualcuno l''ha usata davvero. Guardarle prima di eliminarla.',
            v_righe;
    END IF;
END $$;

-- ⚠️ Firme lette dal database, non scritte a memoria: una firma sbagliata lascia la
-- funzione dov'era e il DROP non protesta.
DROP FUNCTION IF EXISTS fn_ana_aziende_esp_delete(bigint,integer);
DROP FUNCTION IF EXISTS fn_ana_aziende_esp_get(bigint,integer);
DROP FUNCTION IF EXISTS fn_ana_aziende_esp_get_by_azienda(integer);
DROP FUNCTION IF EXISTS fn_ana_aziende_esp_get_key(integer,text);
DROP FUNCTION IF EXISTS fn_ana_aziende_esp_insert(integer,character varying,text,text,character varying,character varying,character varying,boolean);
DROP FUNCTION IF EXISTS fn_ana_aziende_esp_update(bigint,integer,character varying,text,text,character varying,character varying,character varying,boolean);

DROP TABLE IF EXISTS ana_aziende_esp;
