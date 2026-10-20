-- ============================================================================
-- 694 — L'utente sito_posta: la posta del sito pubblico (Tappa 4A, modulo Contatti)
--
-- Disegno: Sito Web SFT/Documenti/Analisi/2026-10-19-Tappa_4_Contorno_Disegno.md §3, §5
-- Il modulo Contatti del sito manda una mail dal SERVER del sito e NON scrive nel
-- database (decisione di Adriano del 2026-10-19). Per mandarla gli servono la
-- configurazione di posta dell'azienda (cifrata: la decifra il database con la
-- chiave dei segreti, come per il guardiano, script 681) e l'indirizzo che riceve i
-- messaggi del sito (scheda «Sito web», script 692; vuoto = l'email principale).
--
--   - ruolo sito_posta: può SOLO chiamare fn_web_sito_posta. Nessuna tabella.
--     Il pezzo 4D (newsletter) gli aggiungerà le sue due funzioni, con uno script suo.
--   - ⛔️ nasce NOLOGIN e senza password: il login si dà a mano (solo l'impronta
--     SCRAM, come 679/681/688) e la password vive solo nel .env del server.
-- Rigiocabile.
-- ============================================================================
BEGIN;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sito_posta') THEN
        CREATE ROLE sito_posta NOLOGIN;
    END IF;
END $$;
GRANT USAGE ON SCHEMA public TO sito_posta;

-- { smtp: configurazione decifrata (o null se l'azienda non ne ha una attiva),
--   destinatario: l'email dei messaggi del sito, altrimenti la principale,
--   mittente_nome: la ragione sociale }
-- Chiave sbagliata → errore (pgp_sym_decrypt), mai una password.
CREATE OR REPLACE FUNCTION fn_web_sito_posta(p_azienda_id integer, p_master text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path = public, extensions, pg_temp
AS $$
    SELECT jsonb_build_object(
        'smtp', fn_get_smtp_config_for_email(p_azienda_id, p_master),
        'destinatario', coalesce(
            (SELECT e.email FROM web_sito_contenuti c
               JOIN ana_aziende_email e ON e.email_id = c.email_messaggi_fk
              WHERE c.azienda_id = p_azienda_id),
            fn_ana_aziende_email_principale(p_azienda_id)),
        'mittente_nome', (SELECT a.ragione_sociale FROM ana_aziende a WHERE a.azienda_id = p_azienda_id));
$$;

REVOKE EXECUTE ON FUNCTION fn_web_sito_posta(integer, text) FROM PUBLIC;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        REVOKE EXECUTE ON FUNCTION fn_web_sito_posta(integer, text) FROM anon, authenticated;
    END IF;
END $$;
GRANT EXECUTE ON FUNCTION fn_web_sito_posta(integer, text) TO sito_posta;

COMMIT;

-- ============================================================================
-- Verifica: Test_694_Web_Utente_Sito_Posta.sql
-- ============================================================================
