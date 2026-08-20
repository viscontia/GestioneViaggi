-- =============================================================================
-- 559 — Le ultime quattro letture inline di ClienteRepository scendono nel DB
-- =============================================================================
-- Dopo la 558 restavano nel repository quattro SELECT scritte a mano. Sono le
-- ultime: con queste, ana_clienti non ha piu' SQL inline in MAUI.
--
-- Due scelte che vale la pena motivare:
--
-- 1) Le letture per email e per codice fiscale NON riscrivono la SELECT: risolvono
--    l'id e delegano a fn_get_cliente_by_id. Cosi' la forma del JSON esiste in un
--    posto solo, e aggiungere domani una colonna al dettaglio la fa comparire da
--    sola anche qui. Duplicare la SELECT significherebbe ricreare esattamente il
--    problema che stiamo chiudendo.
--
-- 2) Entrambe aggiungono ORDER BY cliente_id. Le versioni C# prendevano la prima
--    riga senza ordinare: l'email non e' univoca (le coppie condividono la casella,
--    tre casi accertati in PROD), quindi quale scheda tornasse era arbitrario e
--    poteva cambiare fra due esecuzioni identiche. Ora torna la piu' vecchia,
--    sempre.
--
-- Le due verifiche "ha iscrizioni / ha alloggi" filtrano per azienda passando da
-- ana_clienti. Il C# il parametro azienda lo riceveva e non lo usava mai: la
-- guardia sulla cancellazione guardava tutte le aziende insieme. Con un cliente
-- coerente il risultato non cambia; se un giorno non lo fosse, adesso il silos
-- regge.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_get_cliente_by_email(p_email VARCHAR, p_azienda_fk INTEGER)
RETURNS JSON AS $$
    SELECT fn_get_cliente_by_id(c.cliente_id, p_azienda_fk)
    FROM ana_clienti c
    WHERE LOWER(c.cliente_email) = LOWER(p_email)
      AND c.azienda_fk = p_azienda_fk
    ORDER BY c.cliente_id
    LIMIT 1;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION fn_get_cliente_by_codice_fiscale(p_codice_fiscale VARCHAR, p_azienda_fk INTEGER)
RETURNS JSON AS $$
    SELECT fn_get_cliente_by_id(c.cliente_id, p_azienda_fk)
    FROM ana_clienti c
    WHERE UPPER(c.cliente_codicefiscale) = UPPER(p_codice_fiscale)
      AND c.azienda_fk = p_azienda_fk
    ORDER BY c.cliente_id
    LIMIT 1;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION fn_cliente_ha_iscrizioni(p_cliente_id INTEGER, p_azienda_fk INTEGER)
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT 1 FROM mov_clienti_viaggi m
        JOIN ana_clienti c ON c.cliente_id = m.cliente_id_fk
        WHERE m.cliente_id_fk = p_cliente_id
          AND c.azienda_fk = p_azienda_fk);
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION fn_cliente_ha_alloggi(p_cliente_id INTEGER, p_azienda_fk INTEGER)
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT 1 FROM mov_clienti_alloggi a
        JOIN ana_clienti c ON c.cliente_id = p_cliente_id
        WHERE p_cliente_id IN (a.cliente_id1_fk, a.cliente_id2_fk, a.cliente_id3_fk,
                               a.cliente_id4_fk, a.cliente_id5_fk, a.cliente_id6_fk)
          AND c.azienda_fk = p_azienda_fk);
$$ LANGUAGE sql STABLE;

COMMIT;
