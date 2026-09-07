-- ============================================================================
-- 630 — «questa persona si può iscrivere?», che non è «questa scheda è valida»
--
-- Adriano, 2026-09-07: «un cliente esistente che si iscrive da Flask e che è
-- residente in IT e che non ha il CF deve essere invitato a integrare la sua
-- anagrafica pena non continua l'iscrizione».
--
-- ⚠️ PERCHE' UNA FUNZIONE NUOVA E NON UNA RIGA IN fn_ana_clienti_valida.
-- Sono due domande diverse, fatte in due momenti diversi:
--   • fn_ana_clienti_valida risponde a «questa SCHEDA si può salvare?» — e li' il
--     codice fiscale è obbligatorio solo per le schede NUOVE (script 629), perché
--     i 44 clienti che ci sono già senza devono restare modificabili;
--   • questa risponde a «questa PERSONA si può portare in viaggio?» — e li' il
--     codice fiscale serve a chiunque risieda in Italia, vecchio o nuovo, perché
--     è a lui che si emetterà la fattura.
-- Metterle insieme avrebbe reso non salvabili le 44 schede: il difetto di §2.9.
--
-- Non impone nulla da sola: è una LETTURA che elenca cosa manca. A fermare
-- l'iscrizione sono i chiamanti — oggi il sito, e il gestionale se si deciderà
-- che vale anche li' (⚠️ da decidere: la segreteria può rincorrere il cliente,
-- chi si iscrive di notte dal sito no).
--
-- Rigiocabile.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_cliente_iscrivibile(
    p_cliente_id INTEGER,
    p_azienda_id INTEGER
)
RETURNS TABLE (gravita VARCHAR, esito VARCHAR, messaggio TEXT)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_cf       VARCHAR;
    v_com_res  INTEGER;
    v_estero   BOOLEAN;
BEGIN
    SELECT c.cliente_codicefiscale, c.cliente_comune_residenza_fk
      INTO v_cf, v_com_res
      FROM ana_clienti c
     WHERE c.cliente_id = p_cliente_id AND c.azienda_fk = p_azienda_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'CLIENTE_INESISTENTE'::VARCHAR,
               'Questa scheda cliente non esiste.'::TEXT;
        RETURN;
    END IF;

    -- Il codice fiscale: serve a chi risiede in Italia, perché senza non si emette
    -- fattura. Qui vale anche per chi è già in anagrafica: non gli si chiede di
    -- correggere la scheda, gli si chiede di completarla prima di partire.
    IF btrim(COALESCE(v_cf, '')) = '' AND v_com_res IS NOT NULL THEN
        SELECT (g.comune_estero = 'Y') INTO v_estero
          FROM ana_geo_comuni g WHERE g.comune_id = v_com_res;

        IF COALESCE(v_estero, FALSE) = FALSE THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'MANCA_CF_PER_ISCRIZIONE'::VARCHAR,
                   ('Per completare l''iscrizione manca il codice fiscale, che è '
                    || 'obbligatorio per chi risiede in Italia: serve per emettere la '
                    || 'fattura. Integra la tua anagrafica per proseguire.')::TEXT;
        END IF;
    END IF;
END;
$$;

COMMENT ON FUNCTION fn_cliente_iscrivibile(INTEGER, INTEGER) IS
    'Cosa manca a un cliente per potersi iscrivere a un viaggio. Diverso da fn_ana_clienti_valida, che giudica la scheda. Script 630.';

DO $verifica$
DECLARE
    v_senza_cf INTEGER;
    v_con_cf   INTEGER;
    v_esiti    INTEGER;
BEGIN
    -- Un cliente residente in Italia SENZA codice fiscale: deve essere fermato.
    SELECT c.cliente_id INTO v_senza_cf
      FROM ana_clienti c JOIN ana_geo_comuni g ON g.comune_id = c.cliente_comune_residenza_fk
     WHERE c.azienda_fk = 2 AND g.comune_estero = 'N'
       AND btrim(COALESCE(c.cliente_codicefiscale,'')) = '' LIMIT 1;

    -- ...e uno CON codice fiscale: deve passare.
    SELECT c.cliente_id INTO v_con_cf
      FROM ana_clienti c JOIN ana_geo_comuni g ON g.comune_id = c.cliente_comune_residenza_fk
     WHERE c.azienda_fk = 2 AND g.comune_estero = 'N'
       AND btrim(COALESCE(c.cliente_codicefiscale,'')) <> '' LIMIT 1;

    IF v_senza_cf IS NOT NULL THEN
        SELECT count(*) INTO v_esiti FROM fn_cliente_iscrivibile(v_senza_cf, 2)
         WHERE esito = 'MANCA_CF_PER_ISCRIZIONE';
        IF v_esiti <> 1 THEN
            RAISE EXCEPTION '630: il cliente % (residente IT, senza CF) doveva essere fermato.', v_senza_cf;
        END IF;
        RAISE NOTICE '630: cliente % senza CF -> fermato, come deve.', v_senza_cf;
    END IF;

    IF v_con_cf IS NOT NULL THEN
        SELECT count(*) INTO v_esiti FROM fn_cliente_iscrivibile(v_con_cf, 2);
        IF v_esiti <> 0 THEN
            RAISE EXCEPTION '630: il cliente % (con CF) NON doveva avere rilievi.', v_con_cf;
        END IF;
        RAISE NOTICE '630: cliente % con CF -> passa, come deve.', v_con_cf;
    END IF;
END
$verifica$;

COMMIT;
