-- ============================================================================
-- Le email agganciate dal sito non aprono la scheda
--
-- Disegno: Iscrizione-Viaggi-Offroad PostgreSQL/docs/plans/2026-09-25-cliente-
-- riconosciuto-otp-design.md (approvato il 2026-09-25). Voce L4 delle due liste.
-- Il disegno lo diceva gia': su una scheda senza email il codice usa e getta
-- non prova nulla, e sblocca solo il COMPLETARE.
--
-- ⛔️ IL PERCORSO CHE LO SCAVALCAVA (revisione del salvataggio Flask, 2026-09-25).
-- Chi conosce cognome, nome, data e comune di nascita di una persona SENZA email
-- in archivio salva sul sito; il controllo duplicati la ritrova e Flask chiama
-- fn_ana_clienti_aggancia_email (script 593), che scrive l'email solo se il campo
-- e' vuoto: l'email di CHI STA SCRIVENDO. Da li' l'email e' «in archivio»,
-- fn_web_otp_genera le manda il codice, e l'estraneo apre e modifica la scheda.
--
-- LA CURA: il sito aggancia attraverso fn_web_cliente_aggancia_email, che fa
-- lo stesso aggancio del 593 e in piu' ne tiene traccia in web_email_agganciate.
-- fn_web_otp_genera rifiuta il codice ('EMAIL_NON_VERIFICATA') finche' l'email
-- in scheda e' quella agganciata dal sito. Quando il gestionale la corregge, la
-- riga non corrisponde piu' e il codice torna possibile: la riga non si cancella,
-- perche' non serve.
--
-- ⚠️ Il 593 non si tocca: resta com'e', e il sito smette di chiamarlo direttamente.
-- Il gestionale non lo usa (nessuna chiamata nel codice C#).
--
-- ⚠️ PERCHE' fn_web_otp_genera SI RIDEFINISCE QUI E NON NEL 660: la regola nasce
-- dalla tabella di questo script, che al 660 non esiste. Il corpo e' quello del
-- 660 copiato dal database, con un solo controllo in piu'. ⛔️ Chi riapplica il
-- 660 deve riapplicare anche il 662, altrimenti il controllo sparisce.
--
-- Permessi: nessun GRANT. Nascono chiuse ad anon (script 659); le chiama solo
-- Flask, che si connette come postgres, proprietario. search_path fissato, come
-- da script 655.
--
-- Test: Test_662_Web_Email_Agganciate_Dal_Sito.sql (transazione annullata).
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS web_email_agganciate (
    -- Una riga per cliente: conta solo l'ultimo aggancio fatto dal sito.
    cliente_id    INTEGER      PRIMARY KEY REFERENCES ana_clienti(cliente_id) ON DELETE CASCADE,
    azienda_id    INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    email         VARCHAR(254) NOT NULL,
    agganciata_il TIMESTAMPTZ  NOT NULL DEFAULT now()
);

ALTER TABLE web_email_agganciate ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS superadmin_bypass_all ON web_email_agganciate;
CREATE POLICY superadmin_bypass_all ON web_email_agganciate TO app_superadmin USING (true) WITH CHECK (true);

-- ⚠️ `authenticated` esiste su Supabase ma non in locale: si revoca solo ai
-- ruoli che ci sono, cosi' lo stesso script gira in tutti e due i posti.
DO $$
DECLARE v_ruolo TEXT;
BEGIN
    FOR v_ruolo IN
        SELECT r FROM unnest(ARRAY['anon','authenticated']) r
         WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r)
    LOOP
        EXECUTE format('REVOKE ALL ON web_email_agganciate FROM %I', v_ruolo);
    END LOOP;
END $$;

COMMENT ON TABLE web_email_agganciate IS
    'Email agganciate dal sito a schede che ne erano prive: non verificate da nessuno, quindi non ricevono codici usa e getta finche'' restano quelle in scheda (script 662).';

CREATE OR REPLACE FUNCTION fn_web_cliente_aggancia_email(p_cliente_id INTEGER, p_azienda_id INTEGER, p_email VARCHAR)
RETURNS BOOLEAN
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    -- La regola dell'aggancio resta una sola, quella del 593: qui si aggiunge
    -- solo la traccia, e solo se l'aggancio c'e' stato davvero.
    IF NOT fn_ana_clienti_aggancia_email(p_cliente_id, p_azienda_id, p_email) THEN
        RETURN FALSE;
    END IF;

    INSERT INTO web_email_agganciate (cliente_id, azienda_id, email)
    VALUES (p_cliente_id, p_azienda_id, btrim(p_email))
    ON CONFLICT (cliente_id) DO UPDATE
       SET azienda_id = EXCLUDED.azienda_id, email = EXCLUDED.email, agganciata_il = now();
    RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION fn_web_cliente_aggancia_email(INTEGER, INTEGER, VARCHAR) IS
    'L''aggancio dell''email fatto dal sito: come fn_ana_clienti_aggancia_email (solo su schede senza email), e in piu'' lo registra, perche'' quell''email non riceva codici usa e getta. Il sito chiama questa, non la 593 (script 662).';

-- Il corpo del 660, copiato dal database, con il controllo del 662.
CREATE OR REPLACE FUNCTION fn_web_otp_genera(p_azienda_id integer, p_cliente_id integer)
 RETURNS TABLE(esito text, codice text, email character varying)
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

    -- ⚠️ Script 662: un'email agganciata dal sito non l'ha verificata nessuno. E'
    -- la casella di chi ha scritto nel modulo, che puo' essere chiunque conosca
    -- cognome, nome e nascita della persona: mandarle il codice gli aprirebbe la
    -- scheda. Se il gestionale poi corregge l'email, la riga non corrisponde piu'
    -- e il codice torna possibile.
    IF EXISTS (SELECT 1 FROM web_email_agganciate a
                WHERE a.cliente_id = p_cliente_id
                  AND lower(btrim(a.email)) = lower(v_email)) THEN
        RETURN QUERY SELECT 'EMAIL_NON_VERIFICATA'::TEXT, NULL::TEXT, NULL::VARCHAR; RETURN;
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
    'Genera un codice a 8 cifre per il cliente e lo restituisce UNA volta, per spedirlo alla casella in archivio. Tetto: 3 richieste in 15 minuti, 10 in 24 ore. Esiti: OK, CLIENTE_ASSENTE, SENZA_EMAIL, EMAIL_NON_VERIFICATA (email agganciata dal sito, script 662), TROPPE_RICHIESTE (script 660, 662).';

COMMIT;
