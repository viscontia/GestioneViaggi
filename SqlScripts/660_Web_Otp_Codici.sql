-- ============================================================================
-- Il codice usa e getta per vedere e modificare la propria scheda dal sito
--
-- Disegno: Iscrizione-Viaggi-Offroad PostgreSQL/docs/plans/2026-09-25-cliente-
-- riconosciuto-otp-design.md (approvato il 2026-09-25). Voce L4 delle due liste.
--
-- Il sito riconosce un cliente dall'email, ma l'email non identifica nessuno:
-- chiunque puo' digitarla. Per VEDERE o MODIFICARE la scheda serve dimostrare di
-- leggere la casella IN ARCHIVIO. Le regole — 8 cifre, 5 minuti, uso singolo,
-- 3 tentativi, 3 richieste ogni 15 minuti e 10 ogni 24 ore — stanno qui e non
-- nel Python.
--
-- ⚠️ PERCHE' 8 CIFRE E NON 6 (deciso dopo la revisione della parte Flask). Chi
-- conosce molte email puo' chiedere codici per tutte e provare a indovinarli:
-- 10 codici al giorno x 3 tentativi = 30 tentativi al giorno per scheda. Con
-- 1000 email sono 30.000 tentativi al giorno: su un milione di codici possibili
-- (6 cifre) apre qualche scheda con probabilita' ~3% al giorno; su cento
-- milioni (8 cifre) ~0,03%. Due cifre in piu' da digitare costano poco.
--
-- ⚠️ Il codice NON si tiene in chiaro: si conserva l'impronta sha256 di sale+codice.
-- sha256 e gen_random_uuid sono nativi (PG 13+): nessuna estensione, quindi lo
-- stesso script gira in locale e su Supabase, dove pgcrypto sta in un altro schema.
--
-- ⚠️ «L'ultimo codice» e' quello con l'id piu' alto, non quello con il `created`
-- piu' recente: dentro una transazione now() e' costante e due righe possono
-- avere lo stesso `created`. L'id no.
--
-- Permessi: nessun GRANT. Nascono chiuse ad anon (script 659); le chiama solo
-- Flask, che si connette come postgres, proprietario. La tabella si chiude
-- esplicitamente ad anon/authenticated: oggi non hanno permessi, ma un GRANT
-- dato per sbaglio domani non deve bastare a leggere le impronte.
-- search_path fissato su entrambe le funzioni, come da script 655.
--
-- Test: Test_660_Web_Otp.sql (gira in una transazione annullata).
--
-- ✅ Applicato in locale e a PROD il 2026-09-26 (rilascio L4/L13, sito Flask v5.0.0); test OK.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS web_otp_codici (
    web_otp_codici_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    azienda_id        INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    cliente_id        INTEGER      NOT NULL REFERENCES ana_clienti(cliente_id) ON DELETE CASCADE,
    -- La casella a cui e' partito il codice: quella in archivio in quel momento.
    email             VARCHAR(254) NOT NULL,
    codice_sale       TEXT         NOT NULL,
    codice_hash       TEXT         NOT NULL,
    scadenza          TIMESTAMPTZ  NOT NULL,
    tentativi         INTEGER      NOT NULL DEFAULT 0,
    usato_il          TIMESTAMPTZ,
    created           TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_web_otp_cliente ON web_otp_codici (cliente_id, created DESC);

ALTER TABLE web_otp_codici ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS superadmin_bypass_all ON web_otp_codici;
CREATE POLICY superadmin_bypass_all ON web_otp_codici TO app_superadmin USING (true) WITH CHECK (true);

-- ⚠️ `authenticated` esiste su Supabase ma non in locale: si revoca solo ai
-- ruoli che ci sono, cosi' lo stesso script gira in tutti e due i posti.
DO $$
DECLARE v_ruolo TEXT;
BEGIN
    FOR v_ruolo IN
        SELECT r FROM unnest(ARRAY['anon','authenticated']) r
         WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r)
    LOOP
        EXECUTE format('REVOKE ALL ON web_otp_codici FROM %I', v_ruolo);
    END LOOP;
END $$;

COMMENT ON TABLE web_otp_codici IS
    'Codici usa e getta del sito di iscrizione: servono a vedere e modificare la propria scheda. Solo l''impronta sha256, mai il codice (script 660).';

CREATE OR REPLACE FUNCTION fn_web_otp_genera(p_azienda_id INTEGER, p_cliente_id INTEGER)
RETURNS TABLE(esito TEXT, codice TEXT, email VARCHAR)
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
    v_email  VARCHAR;
    v_codice TEXT;
    v_sale   TEXT;
BEGIN
    SELECT btrim(c.cliente_email) INTO v_email
      FROM ana_clienti c
     WHERE c.cliente_id = p_cliente_id AND c.azienda_fk = p_azienda_id;
    IF NOT FOUND THEN
        RETURN QUERY SELECT 'CLIENTE_ASSENTE'::TEXT, NULL::TEXT, NULL::VARCHAR; RETURN;
    END IF;
    -- Senza email in archivio il codice andrebbe dove dice chi chiede: non prova nulla.
    IF COALESCE(v_email, '') = '' THEN
        RETURN QUERY SELECT 'SENZA_EMAIL'::TEXT, NULL::TEXT, NULL::VARCHAR; RETURN;
    END IF;

    -- Una richiesta alla volta per cliente, fino alla fine della transazione.
    -- ⚠️ Senza, due richieste parallele passerebbero entrambe il conteggio del
    -- tetto, e ognuna annullerebbe solo i codici che vede: resterebbero due
    -- codici aperti. Il lucchetto e' consultivo e non tocca ana_clienti: un
    -- FOR UPDATE sulla scheda bloccherebbe invece le modifiche dal gestionale.
    PERFORM pg_advisory_xact_lock(660, p_cliente_id);

    -- Una riga per richiesta, e dopo un giorno non serve a nessuno.
    DELETE FROM web_otp_codici o WHERE o.created < now() - interval '1 day';

    -- Il tetto conta le richieste, non i codici validi: anche quelli gia' usati
    -- o annullati. E' il freno contro chi riempie di codici la casella altrui.
    -- Due soglie: 3 ogni 15 minuti e 10 ogni 24 ore. ⚠️ La sola prima darebbe 9
    -- tentativi ogni 15 minuti per cliente, che su molti clienti diventano un
    -- budget di tentativi non trascurabile; con la seconda il massimo e' 30
    -- tentativi al giorno per cliente.
    IF (SELECT count(*) FILTER (WHERE o.created > now() - interval '15 minutes') >= 3
            OR count(*) >= 10
          FROM web_otp_codici o
         WHERE o.cliente_id = p_cliente_id AND o.created > now() - interval '1 day') THEN
        RETURN QUERY SELECT 'TROPPE_RICHIESTE'::TEXT, NULL::TEXT, NULL::VARCHAR; RETURN;
    END IF;

    -- Un codice nuovo annulla quelli ancora aperti: vale solo l'ultimo arrivato.
    -- ⚠️ Serve davvero: quando l'ultimo e' stato usato, la verifica ripiega sul
    -- penultimo ancora aperto, che senza questo tornerebbe buono.
    UPDATE web_otp_codici o SET scadenza = now()
     WHERE o.cliente_id = p_cliente_id AND o.usato_il IS NULL AND o.scadenza > now();

    -- gen_random_uuid usa il generatore sicuro del sistema; random() no.
    -- ⚠️ 48 bit (12 cifre esadecimali), non 32: 2^32 fa ~4,29 miliardi, e il
    -- modulo 100.000.000 renderebbe i codici sotto ~95 milioni piu' probabili
    -- del 2,4%. Con 2^48 lo scarto scende sotto una parte su un milione.
    v_codice := lpad(((('x' || substr(md5(gen_random_uuid()::text), 1, 12))::bit(48)::bigint) % 100000000)::text, 8, '0');
    v_sale   := gen_random_uuid()::text;

    INSERT INTO web_otp_codici (azienda_id, cliente_id, email, codice_sale, codice_hash, scadenza)
    VALUES (p_azienda_id, p_cliente_id, v_email, v_sale,
            encode(sha256(convert_to(v_sale || v_codice, 'UTF8')), 'hex'),
            now() + interval '5 minutes');

    RETURN QUERY SELECT 'OK'::TEXT, v_codice, v_email;
END;
$$;

COMMENT ON FUNCTION fn_web_otp_genera(INTEGER, INTEGER) IS
    'Genera un codice a 8 cifre per il cliente e lo restituisce UNA volta, per spedirlo alla casella in archivio. Tetto: 3 richieste in 15 minuti, 10 in 24 ore. Esiti: OK, CLIENTE_ASSENTE, SENZA_EMAIL, TROPPE_RICHIESTE (script 660).';

CREATE OR REPLACE FUNCTION fn_web_otp_verifica(p_azienda_id INTEGER, p_cliente_id INTEGER, p_codice TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
    r web_otp_codici%ROWTYPE;
BEGIN
    -- FOR UPDATE: due verifiche in parallelo non devono contare un tentativo solo.
    SELECT * INTO r FROM web_otp_codici
     WHERE azienda_id = p_azienda_id AND cliente_id = p_cliente_id AND usato_il IS NULL
     ORDER BY web_otp_codici_id DESC LIMIT 1
     FOR UPDATE;
    IF NOT FOUND THEN RETURN 'NESSUN_CODICE'; END IF;
    -- Prima i tentativi, poi la scadenza: un codice bruciato resta bruciato.
    IF r.tentativi >= 3 THEN RETURN 'TENTATIVI_ESAURITI'; END IF;
    IF r.scadenza <= now() THEN RETURN 'SCADUTO'; END IF;

    UPDATE web_otp_codici SET tentativi = tentativi + 1 WHERE web_otp_codici_id = r.web_otp_codici_id;

    IF encode(sha256(convert_to(r.codice_sale || btrim(COALESCE(p_codice, '')), 'UTF8')), 'hex') <> r.codice_hash THEN
        RETURN CASE WHEN r.tentativi + 1 >= 3 THEN 'TENTATIVI_ESAURITI' ELSE 'ERRATO' END;
    END IF;

    UPDATE web_otp_codici SET usato_il = now() WHERE web_otp_codici_id = r.web_otp_codici_id;
    RETURN 'OK';
END;
$$;

COMMENT ON FUNCTION fn_web_otp_verifica(INTEGER, INTEGER, TEXT) IS
    'Verifica il codice del cliente. Esiti: OK (e il codice non vale piu''), ERRATO, SCADUTO, TENTATIVI_ESAURITI, NESSUN_CODICE (script 660).';

COMMIT;
