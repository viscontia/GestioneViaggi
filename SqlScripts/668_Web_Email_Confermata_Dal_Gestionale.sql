-- ============================================================================
-- 668 — Il gestionale conferma un'email agganciata dal sito (L12)
--
-- Dallo script 662, su una scheda la cui email e' stata agganciata dal sito il
-- codice usa e getta non parte (fn_web_otp_genera → EMAIL_NON_VERIFICATA): quella
-- casella l'ha scritta chi compilava il modulo, e nessuno ha verificato che sia
-- della persona. Finche' l'email non cambia, il cliente non puo' modificare i suoi
-- dati dal sito. Se Antonio verifica che l'email e' giusta (una telefonata, la
-- conosce), deve poterlo dire: queste due funzioni sono il bottone della scheda
-- cliente.
--
--   fn_web_email_da_confermare(cliente, azienda) → boolean
--     true se l'email ATTUALE della scheda e' quella agganciata dal sito (la
--     stessa condizione di fn_web_otp_genera: se il gestionale ha gia' cambiato
--     l'email, non c'e' niente da confermare).
--   fn_web_email_conferma(cliente, azienda) → boolean
--     toglie la riga di web_email_agganciate: da qui il codice puo' partire.
--     true se c'era qualcosa da confermare.
--
-- Solo per il gestionale (postgres, proprietario): nessun GRANT, nascono chiuse
-- (script 659). search_path fissato (script 655).
--
-- ✅ Applicato in locale e a PROD il 2026-09-26 (test OK). Lo usa il gestionale dalla 2.3.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_web_email_da_confermare(p_cliente_id integer, p_azienda_id integer)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path = public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1
          FROM web_email_agganciate a
          JOIN ana_clienti c ON c.cliente_id = a.cliente_id
         WHERE a.cliente_id = p_cliente_id
           AND c.azienda_fk = p_azienda_id
           AND lower(btrim(a.email)) = lower(btrim(coalesce(c.cliente_email, ''))));
$$;

CREATE OR REPLACE FUNCTION fn_web_email_conferma(p_cliente_id integer, p_azienda_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path = public, pg_temp
AS $$
DECLARE v_righe integer;
BEGIN
    DELETE FROM web_email_agganciate a
     USING ana_clienti c
     WHERE a.cliente_id = p_cliente_id
       AND c.cliente_id = a.cliente_id
       AND c.azienda_fk = p_azienda_id;
    GET DIAGNOSTICS v_righe = ROW_COUNT;
    RETURN v_righe > 0;
END;
$$;

COMMENT ON FUNCTION fn_web_email_da_confermare(integer, integer) IS
    'L12 (668): true se l''email attuale della scheda e'' stata agganciata dal sito e nessuno l''ha confermata.';
COMMENT ON FUNCTION fn_web_email_conferma(integer, integer) IS
    'L12 (668): il gestionale conferma l''email agganciata dal sito; da qui il codice usa e getta puo'' partire.';

COMMIT;
