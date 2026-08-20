-- =============================================================================
-- 560 — Anche il dettaglio passa dalla funzione canonica
-- =============================================================================
-- get_cliente_detail restituiva una TABLE con 41 colonne, mappata a mano da
-- MapFromReader. Era rimasta indietro: non conosce cliente_titolo_fk, la lingua
-- ne' il consenso, e restituisce ancora cliente_titolo, il testo deprecato.
-- Il risultato e' che TravelStatsDialog, l'unico che la usa, andava in eccezione
-- appena il mapper ha iniziato a leggere le colonne nuove.
--
-- Invece di rincorrere l'elenco delle colonne per la seconda volta, il dettaglio
-- delega a fn_get_cliente_by_id: stessa forma JSON di tutte le altre letture,
-- foto compresa. L'azienda si prende dal cliente stesso — la ricerca e' per
-- chiave primaria, quindi il silos e' rispettato per costruzione, ed e'
-- esattamente cio' che get_cliente_detail faceva (non filtrava per azienda).
--
-- get_cliente_detail resta in piedi ma senza chiamanti: va nell'elenco delle
-- funzioni da ritirare al go-live, non prima, perche' va verificato che nessun
-- altro software la usi.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_get_cliente_detail(p_cliente_id INTEGER)
RETURNS JSON AS $$
    SELECT fn_get_cliente_by_id(c.cliente_id, c.azienda_fk)
    FROM ana_clienti c
    WHERE c.cliente_id = p_cliente_id;
$$ LANGUAGE sql STABLE;

COMMIT;
