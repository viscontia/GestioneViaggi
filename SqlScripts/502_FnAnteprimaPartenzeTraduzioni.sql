-- Supporto all'anteprima: prossime partenze e traduzioni del contenuto.
--
-- 1) Nell'anteprima non compaiono le date: si sta lavorando sul contenuto del viaggio, non sul
--    calendario. Utile però ricordare all'operatore quali partenze sono effettivamente in
--    programma, per accorgersi se sta curando la scheda di un viaggio senza date future.
-- 2) L'anteprima è in italiano. Avendo le traduzioni, si vuole poter vedere lo stesso contenuto in
--    un'altra lingua per una verifica d'insieme.

-- ---------------------------------------------------------------------------
-- Prossime partenze del viaggio a cui appartiene il contenuto
-- ---------------------------------------------------------------------------
-- Solo date di inizio da OGGI in avanti: le partenze passate non sono un promemoria utile.
-- Il confronto è su data_viaggio_data_inizio: una partenza già cominciata non è più "prossima".
CREATE OR REPLACE FUNCTION fn_web_tour_prossime_partenze(
    p_contenuto_id BIGINT,
    p_azienda_id   INTEGER)
RETURNS TABLE (data_viaggio_id INTEGER, data_inizio DATE, data_fine DATE, e_questa_edizione BOOLEAN)
LANGUAGE sql STABLE AS $$
    SELECT d.data_viaggio_id,
           d.data_viaggio_data_inizio,
           d.data_viaggio_data_fine,
           d.data_viaggio_id = c.data_viaggio_id_fk       -- per evidenziare l'edizione in lavorazione
      FROM web_tour_contenuti c
      JOIN ana_date_viaggi d ON d.viaggio_id_fk = c.viaggio_id_fk
                            AND d.azienda_id = c.azienda_id
     WHERE c.web_tour_contenuti_id = p_contenuto_id
       AND c.azienda_id = p_azienda_id
       AND d.data_viaggio_data_inizio >= CURRENT_DATE
     ORDER BY d.data_viaggio_data_inizio;
$$;

COMMENT ON FUNCTION fn_web_tour_prossime_partenze(BIGINT, INTEGER) IS
'Partenze future (data_inizio >= oggi) del viaggio a cui appartiene il contenuto, con il flag dell''edizione in lavorazione. Usata dal promemoria in testa all''anteprima.';

-- ---------------------------------------------------------------------------
-- Traduzioni del contenuto, tutte le lingue
-- ---------------------------------------------------------------------------
-- Ristretta ai campi effettivamente traducibili (fn_web_tour_campi_traducibili): così l'anteprima
-- non pesca traduzioni rimaste in tabella per campi ormai svuotati, e il conteggio per lingua
-- combacia con quello del semaforo.
CREATE OR REPLACE FUNCTION fn_web_traduzioni_per_contenuto(
    p_contenuto_id BIGINT,
    p_azienda_id   INTEGER)
RETURNS TABLE (entita VARCHAR, entita_id BIGINT, campo VARCHAR, lingua CHAR(2),
               testo TEXT, revisionato BOOLEAN, obsoleto BOOLEAN)
LANGUAGE sql STABLE AS $$
    SELECT w.entita, w.entita_id, w.campo, w.lingua, w.testo, w.revisionato, w.obsoleto
      FROM fn_web_tour_campi_traducibili(p_contenuto_id, p_azienda_id) t
      JOIN web_traduzioni w ON w.entita = t.entita
                           AND w.entita_id = t.entita_id
                           AND w.campo = t.campo
                           AND w.azienda_id = p_azienda_id;
$$;

COMMENT ON FUNCTION fn_web_traduzioni_per_contenuto(BIGINT, INTEGER) IS
'Traduzioni (tutte le lingue) dei campi traducibili di una edizione. L''anteprima le usa per mostrare il contenuto in lingua e per capire quali lingue sono complete.';
