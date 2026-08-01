-- Eliminazione di una scheda web: pulizia completa.
--
-- fn_web_tour_contenuti_delete faceva una sola DELETE su web_tour_contenuti e si affidava alle CASCADE.
-- Due problemi, entrambi verificati in locale prima di questo script:
--
-- 1) TRADUZIONI ORFANE. web_traduzioni è polimorfica (entita + entita_id) e NON ha vincoli verso le
--    entità tradotte: nessuna CASCADE la raggiunge. Eliminando una scheda clonata restavano 96 righe
--    che puntavano nel vuoto (40 contenuti + 24 giornate + 24 passaggi + 8 mappe), su 200 totali.
--    Sono righe innocue per i conteggi (nessuna join le trova più) ma è spazzatura che si accumula a
--    ogni eliminazione, e finora non si accumulava solo perché dall'interfaccia non si poteva eliminare.
--
-- 2) ORDINE DELLE CASCADE. web_tour_mappa punta a web_tour_contenuti con CASCADE ma a
--    web_tour_itinerario con RESTRICT. La DELETE funziona perché PostgreSQL elimina le mappe prima
--    delle giornate, ma è un ordine che dipende dai vincoli e non da noi. Qui le mappe vengono
--    eliminate esplicitamente per prime, così il risultato non dipende da quel dettaglio.
--
-- Nota: NON si ripuliscono le eventuali traduzioni orfane preesistenti. Sul DB locale non ce ne sono
-- (verificato: 0) e su PROD non possono essercene, perché fino a oggi non esisteva alcun percorso di
-- eliminazione. Una DELETE massiva "di bonifica" su PROD sarebbe un rischio senza contropartita.
--
-- I file su Supabase Storage NON vengono toccati: le immagini e le mappe possono essere condivise con
-- una scheda clonata (vedi 504), quindi cancellare i file qui romperebbe l'altra scheda.

CREATE OR REPLACE FUNCTION public.fn_web_tour_contenuti_delete(p_id bigint, p_azienda_id integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_n INTEGER;
BEGIN
    -- La scheda esiste ed è di questa azienda? Se no, si esce senza toccare nulla: le DELETE sulle
    -- figlie che seguono non sono scopate per azienda, quindi il controllo va fatto prima.
    IF NOT EXISTS (SELECT 1 FROM web_tour_contenuti
                    WHERE web_tour_contenuti_id = p_id AND azienda_id = p_azienda_id) THEN
        RETURN 0;
    END IF;

    -- 1) Traduzioni delle figlie e della scheda. Prima delle DELETE, finché gli id sono ancora leggibili.
    DELETE FROM web_traduzioni t
     WHERE t.entita = 'web_tour_itinerario_passaggi'
       AND t.entita_id IN (SELECT p.web_tour_itinerario_passaggi_id
                             FROM web_tour_itinerario_passaggi p
                             JOIN web_tour_itinerario i ON i.web_tour_itinerario_id = p.itinerario_id_fk
                            WHERE i.web_tour_contenuti_id_fk = p_id);

    DELETE FROM web_traduzioni t
     WHERE t.entita = 'web_tour_itinerario'
       AND t.entita_id IN (SELECT i.web_tour_itinerario_id FROM web_tour_itinerario i
                            WHERE i.web_tour_contenuti_id_fk = p_id);

    DELETE FROM web_traduzioni t
     WHERE t.entita = 'web_tour_mappa'
       AND t.entita_id IN (SELECT m.web_tour_mappa_id FROM web_tour_mappa m
                            WHERE m.web_tour_contenuti_id_fk = p_id);

    DELETE FROM web_traduzioni t
     WHERE t.entita = 'web_tour_contenuti' AND t.entita_id = p_id;

    -- 2) Mappe per prime: vedi nota (2) in testa.
    DELETE FROM web_tour_mappa WHERE web_tour_contenuti_id_fk = p_id;

    -- 3) La scheda. Giornate, passaggi e immagini seguono per CASCADE.
    DELETE FROM web_tour_contenuti
     WHERE web_tour_contenuti_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;

    RETURN v_n;
END $function$;

COMMENT ON FUNCTION public.fn_web_tour_contenuti_delete(bigint, integer) IS
'Elimina una scheda di contenuti web con giornate, passaggi, immagini, mappe e TUTTE le relative traduzioni (web_traduzioni è polimorfica e nessuna CASCADE la raggiunge). Scopata per azienda. I file su Storage non vengono toccati: possono essere condivisi con una scheda clonata.';
