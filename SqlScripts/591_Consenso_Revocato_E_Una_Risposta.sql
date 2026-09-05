-- =============================================================================
-- 591 — Chi ha revocato il consenso ha risposto: non gli si richiede
-- =============================================================================
--
-- Trovato il 2026-09-05 preparando il test G6, che il piano stesso segnalava come
-- «il caso insidioso». Lo era davvero.
--
-- `fn_consenso_da_chiedere` chiedeva a chi ha `consenso_marketing = FALSE` e la
-- colonna `consenso_marketing_chiesto_data` vuota. Chi ha **concesso e poi
-- revocato** sta esattamente in quello stato: il consenso e' tornato falso, e la
-- data della domanda non c'e' perche' quella colonna e' nata dopo (script 581) e
-- nessuno l'ha riempita a ritroso.
--
-- ⚠️ Risultato: al primo che si reiscriveva, il popup sarebbe ricomparso — proprio
-- a chi si era preso la briga di disdire. E' il contrario della regola decisa:
-- «a chi ha rifiutato non lo richiediamo piu', essere insistenti non paga mai».
--
-- La revoca **e' una risposta**. Anzi, e' la piu' esplicita di tutte: quella
-- persona la newsletter la conosceva, e ha deciso di non volerla piu'.
-- `consenso_marketing_data` valorizzato con consenso falso significa proprio
-- questo — un consenso c'e' stato, e non c'e' piu'.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_consenso_da_chiedere(
    p_cliente_id INTEGER,
    p_azienda_id INTEGER
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM ana_clienti c
        WHERE c.cliente_id = p_cliente_id
          AND c.azienda_fk = p_azienda_id
          -- Deve avere un recapito: chiedere il consenso a chi non ha un indirizzo
          -- e' raccogliere un permesso che non si potra' usare.
          AND nullif(btrim(c.cliente_email), '') IS NOT NULL
          -- Non ha mai risposto, in nessuno dei tre modi in cui una risposta si vede:
          AND c.consenso_marketing_chiesto_data IS NULL   -- gliel'abbiamo chiesto
          AND COALESCE(c.consenso_marketing, FALSE) = FALSE -- ha detto sì e vale ancora
          AND c.consenso_marketing_data IS NULL           -- ha detto sì e poi ha revocato
    );
$$;

COMMENT ON FUNCTION fn_consenso_da_chiedere(INTEGER, INTEGER) IS
'Se a questo cliente DI QUESTA AZIENDA va chiesto il consenso alla newsletter: solo a chi
non ha MAI risposto e ha un indirizzo. Una risposta si riconosce da tre segni — la domanda
gia'' posta, il consenso in corso, oppure un consenso concesso e poi revocato. ⚠️ La revoca
e'' la risposta piu'' esplicita di tutte: richiedere il consenso a chi ha disdetto e''
esattamente l''insistenza che la regola vuole evitare.';
