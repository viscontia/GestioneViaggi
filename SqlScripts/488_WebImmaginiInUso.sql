-- 488_WebImmaginiInUso.sql
-- Blocco 7 (Galleria) — impedisce l'eliminazione di una foto usata come immagine di un passaggio
-- dell'itinerario. Nessuna FK diretta: il legame è debole, per storage_path
-- (web_tour_immagini.storage_path == web_tour_itinerario_passaggi.immagine_storage_path).
-- web_tour_itinerario_passaggi.itinerario_id_fk -> web_tour_itinerario.web_tour_itinerario_id;
-- web_tour_itinerario.web_tour_contenuti_id_fk -> il contenuto/edizione.

BEGIN;

-- Set (distinct) degli storage_path in uso in un passaggio, per contenuto+azienda.
-- Usata lato UI per pre-disabilitare il pulsante "Elimina" sulle foto in uso.
CREATE OR REPLACE FUNCTION fn_web_immagini_in_uso(p_contenuto_id BIGINT, p_azienda_id INTEGER)
RETURNS TABLE(storage_path VARCHAR) LANGUAGE sql STABLE AS $$
    SELECT DISTINCT p.immagine_storage_path
      FROM web_tour_itinerario_passaggi p
      JOIN web_tour_itinerario i ON p.itinerario_id_fk = i.web_tour_itinerario_id
     WHERE i.web_tour_contenuti_id_fk = p_contenuto_id
       AND p.azienda_id = p_azienda_id
       AND p.immagine_storage_path IS NOT NULL;
$$;

-- Difesa a livello DB (anche se la UI non pre-controlla): blocca la DELETE se lo storage_path
-- dell'immagine risulta referenziato da un passaggio dell'itinerario (di qualunque contenuto
-- della stessa azienda: lo storage_path è univoco per immagine caricata).
CREATE OR REPLACE FUNCTION fn_web_tour_immagini_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
    v_n INTEGER;
    v_storage_path VARCHAR;
    v_in_uso BOOLEAN;
BEGIN
    SELECT storage_path INTO v_storage_path
      FROM web_tour_immagini
     WHERE web_tour_immagini_id = p_id AND azienda_id = p_azienda_id;

    IF v_storage_path IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1
              FROM web_tour_itinerario_passaggi p
              JOIN web_tour_itinerario i ON p.itinerario_id_fk = i.web_tour_itinerario_id
             WHERE p.immagine_storage_path = v_storage_path
               AND p.azienda_id = p_azienda_id
        ) INTO v_in_uso;

        IF v_in_uso THEN
            RAISE EXCEPTION 'Immagine in uso in un passaggio dell''itinerario: non eliminabile.'
                USING ERRCODE = 'P0001';
        END IF;
    END IF;

    DELETE FROM web_tour_immagini WHERE web_tour_immagini_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

COMMIT;
