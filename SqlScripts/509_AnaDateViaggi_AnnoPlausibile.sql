-- Plausibilità dell'anno sulle date di partenza.
--
-- Il caso: una partenza salvata con anno 262 invece di 2026. Indagine fatta riproducendo la maschera
-- dei campi data fuori dall'applicazione:
--   * DateMask("dd/MM/yyyy") accetta un anno che comincia per zero: "0262" è un anno di 4 cifre
--     formalmente valido, e il converter di MudBlazor lo interpreta senza obiezioni come 0262-12-01.
--   * Basta UN tasto fuori posto per produrlo: digitando 0-1-1-2-0-2-2-6 (una sola inversione rispetto
--     a 0-1-1-2-2-0-2-6) esce "01/12/0226". Nessun avviso, in nessun punto.
--   * Nessuno dei controlli esistenti se ne accorge, perché sono tutti RELATIVI: fine >= inizio
--     (chk_data_viaggio_date_order) e durata = viaggio_numero_giorni (trg_validate_date_viaggio_duration).
--     Un refuso sull'anno sposta entrambe le date insieme, quindi ordine e durata restano corretti.
--
-- Questo vincolo è il controllo ASSOLUTO che mancava. Non è una regola commerciale: è un pavimento di
-- plausibilità. La stessa soglia è in Validation/Semantic/DateValidator.cs (AnnoMinimo/AnnoMassimo):
-- se un giorno cambia, vanno cambiate entrambe.
--
-- Intervallo FISSO e non relativo a CURRENT_DATE: PostgreSQL accetterebbe anche un CHECK che usa
-- CURRENT_DATE (verificato), ma un vincolo che si muove nel tempo rende invalidi domani record validi
-- oggi e fa fallire un pg_dump/restore. Le date "insolite ma legittime" (anno passato, oltre 5 anni)
-- si gestiscono con una conferma nell'interfaccia, non con un vincolo.
--
-- Dati esistenti: 146 righe, dal 09/02/2019 al 01/12/2026, tutte già dentro l'intervallo. Nessuna
-- riparazione necessaria. Su PROD verificare comunque prima di applicare (query in coda).

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint
                WHERE conname = 'chk_data_viaggio_anno_plausibile'
                  AND conrelid = 'ana_date_viaggi'::regclass) THEN
        RAISE NOTICE 'chk_data_viaggio_anno_plausibile già presente: nulla da fare.';
    ELSE
        ALTER TABLE ana_date_viaggi
          ADD CONSTRAINT chk_data_viaggio_anno_plausibile
          CHECK (data_viaggio_data_inizio BETWEEN DATE '2000-01-01' AND DATE '2100-12-31'
             AND data_viaggio_data_fine   BETWEEN DATE '2000-01-01' AND DATE '2100-12-31');
        RAISE NOTICE 'chk_data_viaggio_anno_plausibile creato.';
    END IF;
END $$;

COMMENT ON CONSTRAINT chk_data_viaggio_anno_plausibile ON ana_date_viaggi IS
'Pavimento di plausibilità sull''anno (2000-2100). Intercetta i refusi di digitazione che tutti gli altri controlli lasciano passare, perché sono relativi fra le due date. Stessa soglia in DateValidator.AnnoMinimo/AnnoMassimo.';

-- Verifica prima di applicare su PROD (deve restituire zero righe):
--   SELECT data_viaggio_id, data_viaggio_data_inizio, data_viaggio_data_fine
--     FROM ana_date_viaggi
--    WHERE data_viaggio_data_inizio NOT BETWEEN DATE '2000-01-01' AND DATE '2100-12-31'
--       OR data_viaggio_data_fine   NOT BETWEEN DATE '2000-01-01' AND DATE '2100-12-31';
