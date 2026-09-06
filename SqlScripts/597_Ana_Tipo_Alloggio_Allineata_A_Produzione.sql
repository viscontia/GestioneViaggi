-- =============================================================================
-- 597 — `ana_tipo_alloggio` allineata a produzione
-- =============================================================================
--
-- Trovato il 2026-09-06 verificando su PROD, e non in locale, la questione della
-- composizione delle tende: i due cataloghi non coincidevano. PROD ha **15** tipi,
-- il database di sviluppo ne aveva **13** — mancavano `TENDA 2 POSTI DI PROPRIETA'`
-- e `TENDA 4 POSTI DI PROPRIETA'`, che su PROD esistono già e senza supplemento.
--
-- ⚠️ Il punto non è la riga mancante: una **tabella di riferimento divergente fa
-- mentire le prove**. Si sarebbe collaudata la composizione delle tende su un
-- database che le tende di proprietà non le ha, concludendo che funziona.
--
-- -----------------------------------------------------------------------------
-- ⚠️ IL TRIGGER CHE RENDE INUTILE OGNI `ON CONFLICT`
-- -----------------------------------------------------------------------------
-- Il primo tentativo di questo script ha creato **17 righe doppie** invece di
-- allinearne 15, e il motivo merita di restare scritto:
--
--     CREATE TRIGGER ana_tipo_alloggio_trg1 BEFORE INSERT ... EXECUTE
--         new.tipo_alloggio_id := nextval('ana_tipo_alloggio_seq');
--
-- Il trigger **sovrascrive l'identificativo a ogni inserimento**, qualunque valore
-- gli si passi. Quindi un `INSERT ... VALUES (34, ...)` non entra con la chiave 34:
-- entra con la prima libera. E `ON CONFLICT (tipo_alloggio_id)` non scatta **mai**,
-- perché la chiave e' sempre nuova: al posto di un aggiornamento si ottiene un
-- duplicato, in silenzio.
--
-- Per portare le chiavi di PROD bisogna quindi **spegnere il trigger** per la durata
-- dell'inserimento. Non e' un aggiramento sospetto: e' l'unico modo di dire «questa
-- riga ha questo numero», che e' esattamente cio' che serve quando si allineano due
-- cataloghi. Un tipo di alloggio si riconosce per numero, e due ambienti che
-- numerano diversamente la stessa cosa sono peggio di uno incompleto.
-- =============================================================================

BEGIN;

-- 1. Via i duplicati creati dal tentativo precedente. Il vincolo e' che non siano
--    usati da nessuna assegnazione: se lo fossero, il trigger di cancellazione
--    (trg2) fermerebbe tutto — ed e' giusto cosi'.
DELETE FROM ana_tipo_alloggio
WHERE tipo_alloggio_id > 32
  AND NOT EXISTS (SELECT 1 FROM mov_clienti_alloggi a
                  WHERE a.tipo_alloggio_id_fk = ana_tipo_alloggio.tipo_alloggio_id);

-- 2. Le chiavi devono essere quelle di produzione: il trigger si spegne, si scrive,
--    si riaccende. Il BEGIN/COMMIT tiene tutto insieme.
ALTER TABLE ana_tipo_alloggio DISABLE TRIGGER ana_tipo_alloggio_trg1;

INSERT INTO ana_tipo_alloggio
    (tipo_alloggio_id, tipo_alloggio_descrizione, tipo_alloggio_numero_occupanti,
     tipo_alloggio_supplemento, tipo_alloggio_fk)
VALUES
    (1, 'CAMERA MATRIMONIALE', 2, 'N', NULL),
    (2, 'CAMERA SINGOLA', 1, 'Y', NULL),
    (3, 'CAMERA DOPPIA LETTI SINGOLI', 2, 'N', NULL),
    (21, 'CAMERA DOPPIA USO SINGOLA', 1, 'Y', NULL),
    (22, 'CAMERA MATRIMONIALE DISABILI', 2, 'N', NULL),
    (23, 'CAMERA SINGOLA DISABILI', 1, 'Y', NULL),
    (24, 'CAMERA QUADRUPLA (MATRIMONIALE E DUE LETTI SINGOLI 5P)', 5, 'N', NULL),
    (25, 'CAMERA QUADRUPLA (MATRIMONIALE E DUE LETTI SINGOLI 4P)', 4, 'N', NULL),
    (26, 'CAMERA TRIPLA (TRE LETTI SINGOLI)', 3, 'N', NULL),
    (27, 'CAMERA TRIPLA (MATRIMONIALE E LETTO SINGOLO)', 3, 'N', NULL),
    (28, 'NESSUNA CAMERA', 0, 'N', NULL),
    (30, 'TENDA 2 POSTI NOLEGGIATA', 2, 'Y', NULL),
    (32, 'TENDA 4 POSTI NOLEGGIATA', 4, 'Y', NULL),
    (34, 'TENDA 2 POSTI DI PROPRIETA''', 2, 'N', NULL),
    (36, 'TENDA 4 POSTI DI PROPRIETA''', 4, 'N', NULL)
ON CONFLICT (tipo_alloggio_id) DO UPDATE
    SET tipo_alloggio_descrizione      = EXCLUDED.tipo_alloggio_descrizione,
        tipo_alloggio_numero_occupanti = EXCLUDED.tipo_alloggio_numero_occupanti,
        tipo_alloggio_supplemento      = EXCLUDED.tipo_alloggio_supplemento,
        tipo_alloggio_fk               = EXCLUDED.tipo_alloggio_fk;

ALTER TABLE ana_tipo_alloggio ENABLE TRIGGER ana_tipo_alloggio_trg1;

-- 3. La sequenza deve ripartire DOPO l'ultima chiave, altrimenti il prossimo
--    inserimento fatto dal gestionale collide con una riga esistente.
SELECT setval('ana_tipo_alloggio_seq', (SELECT max(tipo_alloggio_id) FROM ana_tipo_alloggio));

COMMIT;

-- Verifica: devono essere 15, e le quattro tende devono esserci tutte.
DO $$
DECLARE v_quanti INTEGER; v_tende INTEGER;
BEGIN
    SELECT count(*), count(*) FILTER (WHERE tipo_alloggio_descrizione ILIKE '%TENDA%')
      INTO v_quanti, v_tende FROM ana_tipo_alloggio;
    RAISE NOTICE 'tipi di alloggio: % (attesi 15), di cui tende: % (attese 4)', v_quanti, v_tende;
    IF v_quanti <> 15 THEN
        RAISE EXCEPTION 'allineamento non riuscito: % righe invece di 15', v_quanti;
    END IF;
END;
$$;
