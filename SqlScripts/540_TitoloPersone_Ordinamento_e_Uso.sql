-- =============================================================================
-- 540 — Titoli persone: ordine d'uso reale e conteggio d'impiego
-- =============================================================================
-- Due rilievi dal collaudo del 2026-08-19.
--
-- 1) L'ordine alfabetico metteva AVV. e AVV.SSA davanti a SIG. e SIG.RA, che sono
--    il 99,8% dei casi (741 clienti su 742). Chi compila l'anagrafica scorreva
--    ogni volta mezza tendina per trovare la voce ovvia. I due titoli generici
--    vanno in testa, maschile prima: in offroad partecipano piu' uomini.
--
-- 2) Il rifiuto di eliminare un titolo in uso viveva solo qui dentro, quindi
--    l'utente lo scopriva DOPO aver confermato l'eliminazione. La pagina ora
--    chiede prima quanti clienti lo portano: serve una funzione per farlo.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_ana_titolo_persone_list()
RETURNS SETOF ana_titolo_persone
LANGUAGE sql STABLE
AS $$
    SELECT *
    FROM ana_titolo_persone
    ORDER BY CASE UPPER(titolo_persone_descrizione)
                 WHEN 'SIG.'   THEN 1
                 WHEN 'SIG.RA' THEN 2
                 ELSE 3
             END,
             titolo_persone_descrizione;
$$;

COMMENT ON FUNCTION fn_ana_titolo_persone_list() IS
'Elenco dei titoli. SIG. e SIG.RA forzati in testa (in quest''ordine): sono la quasi totalita'' dei clienti, l''alfabetico li seppelliva. Il resto alfabetico.';

CREATE OR REPLACE FUNCTION fn_ana_titolo_persone_conta_clienti(p_cod INTEGER)
RETURNS INTEGER
LANGUAGE sql STABLE
AS $$
    SELECT COUNT(*)::INTEGER FROM ana_clienti WHERE cliente_titolo_fk = p_cod;
$$;

COMMENT ON FUNCTION fn_ana_titolo_persone_conta_clienti(INTEGER) IS
'Quanti clienti portano un titolo. Serve alla pagina per avvisare PRIMA di chiedere conferma dell''eliminazione: il rifiuto di fn_ana_titolo_persone_delete resta la guardia autoritativa.';

COMMIT;
