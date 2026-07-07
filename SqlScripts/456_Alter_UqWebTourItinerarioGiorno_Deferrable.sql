-- Blocco 6: il riordino delle giornate (fn_web_tour_itinerario_reorder) riscrive
-- giorno_numero per piu' righe in un SINGOLO UPDATE. Con l'unique NON deferrable la
-- verifica avviene riga-per-riga -> uno swap (es. 1<->3) produce una violazione
-- TRANSITORIA a meta' statement ("duplicate key ... uq_web_tour_itinerario_giorno").
-- Soluzione standard per colonne di posizione riordinabili: DEFERRABLE INITIALLY DEFERRED
-- -> il vincolo e' verificato a fine transazione, quando i valori sono di nuovo tutti
-- distinti. Nessun impatto sugli insert normali (giorno_numero sempre progressivo).
ALTER TABLE web_tour_itinerario DROP CONSTRAINT uq_web_tour_itinerario_giorno;
ALTER TABLE web_tour_itinerario ADD CONSTRAINT uq_web_tour_itinerario_giorno
    UNIQUE (viaggio_id_fk, giorno_numero) DEFERRABLE INITIALLY DEFERRED;
