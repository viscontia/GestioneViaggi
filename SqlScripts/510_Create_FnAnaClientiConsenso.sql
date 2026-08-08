-- Blocco 11-B: get/set del consenso marketing del cliente (ana_clienti.consenso_marketing
-- + _data + _fonte, creati dallo script 428), gestito come side-field nella scheda cliente
-- allo stesso modo della lingua (466) — evita di toccare la grande ClienteRepository.
--
-- Le colonne esistevano dal 428 ma nessuno le scriveva: il consenso poteva arrivare solo dal
-- sito pubblico (Fase 3) o via SQL a mano.
--
-- Semantica delle tre colonne:
--   consenso_marketing        stato attuale (è questo che filtra fn_web_destinatari_newsletter)
--   consenso_marketing_data   data dell'ULTIMO cambio di stato (concessione o revoca)
--   consenso_marketing_fonte  cosa/chi ha causato l'ultimo cambio ('gestionale', 'iscrizione',
--                             'import', 'revoca_gestionale')
-- Serve a poter dimostrare quando il consenso è stato dato e quando è stato ritirato.

CREATE OR REPLACE FUNCTION fn_ana_clienti_get_consenso(p_cliente_id INTEGER)
RETURNS TABLE(consenso BOOLEAN, data TIMESTAMPTZ, fonte VARCHAR)
LANGUAGE sql STABLE AS $$
    SELECT consenso_marketing, consenso_marketing_data, consenso_marketing_fonte
      FROM ana_clienti
     WHERE cliente_id = p_cliente_id;
$$;

CREATE OR REPLACE FUNCTION fn_ana_clienti_set_consenso(
    p_cliente_id INTEGER,
    p_consenso   BOOLEAN,
    p_fonte      VARCHAR DEFAULT 'gestionale')
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
    v_n       INTEGER;
    v_attuale BOOLEAN;
BEGIN
    SELECT consenso_marketing INTO v_attuale
      FROM ana_clienti WHERE cliente_id = p_cliente_id;

    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    -- Nessun cambio di stato: non tocco data/fonte, altrimenti ogni salvataggio della scheda
    -- cliente riscriverebbe la data del consenso e la tracciabilità andrebbe persa.
    IF v_attuale IS NOT DISTINCT FROM p_consenso THEN
        RETURN 0;
    END IF;

    UPDATE ana_clienti
       SET consenso_marketing       = p_consenso,
           consenso_marketing_data  = NOW(),
           consenso_marketing_fonte = CASE WHEN p_consenso
                                           THEN COALESCE(NULLIF(btrim(p_fonte), ''), 'gestionale')
                                           ELSE 'revoca_gestionale'
                                      END
     WHERE cliente_id = p_cliente_id;

    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
