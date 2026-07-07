-- Imposta l'immagine "principale" (copertina) di un viaggio (Blocco 7 estensione web).
-- CHECK DB: tipo IN ('principale','galleria'); indice unique PARZIALE
-- uq_web_tour_immagini_principale UNIQUE(viaggio_id_fk) WHERE tipo='principale'
-- (una sola copertina per viaggio). Gli indici parziali NON sono deferrable, quindi un
-- singolo UPDATE con CASE viola il vincolo in modo transitorio nello swap (due 'principale'
-- a meta' statement). Soluzione: DUE pass nella stessa transazione (atomica):
--   1) retrocedi l'eventuale principale a 'galleria';  2) promuovi la target.
-- Ritorna 1 se la target e' stata promossa (esiste per quel viaggio/azienda), altrimenti 0.
CREATE OR REPLACE FUNCTION fn_web_tour_immagini_set_principale(
    p_id BIGINT,
    p_azienda_id INTEGER,
    p_viaggio_id_fk INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_tour_immagini
       SET tipo = 'galleria'
     WHERE viaggio_id_fk = p_viaggio_id_fk AND azienda_id = p_azienda_id AND tipo = 'principale';

    UPDATE web_tour_immagini
       SET tipo = 'principale'
     WHERE web_tour_immagini_id = p_id AND viaggio_id_fk = p_viaggio_id_fk AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
