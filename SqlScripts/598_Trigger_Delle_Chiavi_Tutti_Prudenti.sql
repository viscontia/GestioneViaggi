-- =============================================================================
-- 598 — I trigger che assegnano la chiave diventano tutti prudenti
-- =============================================================================
--
-- Nasce dal difetto 97 (2026-09-06): allineando `ana_tipo_alloggio` fra sviluppo e
-- produzione, uno script con `ON CONFLICT` ha creato 17 righe doppie invece di
-- allinearne 15. Il colpevole era un trigger `BEFORE INSERT`:
--
--     new.tipo_alloggio_id := nextval('ana_tipo_alloggio_seq');
--
-- Sovrascrive la chiave a **ogni** inserimento, qualunque valore le si passi.
-- Quindi `ON CONFLICT (chiave)` non scatta mai — la chiave e' sempre nuova — e al
-- posto dell'aggiornamento arriva un duplicato. ⚠️ **In silenzio**: lo script
-- stampa `INSERT 0 15` e sembra che abbia funzionato.
--
-- Censite tutte le tabelle il 2026-09-06, in locale e su PROD (identiche):
--
--     ⚠️ 4  trigger che SOVRASCRIVONO sempre   ← queste quattro
--        9  trigger prudenti (`if new.id is null`)
--       23  nessun trigger, DEFAULT nextval    → gia' sicure: un DEFAULT si applica
--                                                solo se un valore non viene dato
--       37  colonne IDENTITY                   → gia' sicure per costruzione
--
-- **Non si aggiungono trigger dove non ci sono**: sarebbe lavoro inutile e una
-- copia in piu' da mantenere. DEFAULT e IDENTITY fanno gia' esattamente cio' che
-- fa il trigger prudente.
--
-- ⚠️ La guardia controlla NULL **e zero**. Il gestionale inserisce senza nominare
-- la chiave (verificato: `INSERT INTO ana_geo_capoluogo (capoluogo_descrizione)`),
-- quindi arriva NULL — ma i modelli C# hanno `int Id` non annullabile, e un domani
-- una scrittura fatta con lo zero al posto del niente si infilerebbe come chiave 0.
-- Trattare lo zero come «assegnamela tu» costa una condizione e toglie il caso.
-- =============================================================================

CREATE OR REPLACE FUNCTION ana_tipo_alloggio_trg1_func()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF new.tipo_alloggio_id IS NULL OR new.tipo_alloggio_id = 0 THEN
        new.tipo_alloggio_id := nextval('ana_tipo_alloggio_seq');
    END IF;
    RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION ana_geo_capoluogo_trg1_func()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF new.capoluogo_id IS NULL OR new.capoluogo_id = 0 THEN
        new.capoluogo_id := nextval('ana_geo_capoluogo_seq');
    END IF;
    RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION ana_geo_ita_ripgeo_trg1_func()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF new.ripgeo_id IS NULL OR new.ripgeo_id = 0 THEN
        new.ripgeo_id := nextval('ana_geo_ripgeo_seq');
    END IF;
    RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION ana_geo_regioni_ita_trg1_func()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF new.regione_id IS NULL OR new.regione_id = 0 THEN
        new.regione_id := nextval('ana_geo_regioni_ita_seq');
    END IF;
    RETURN new;
END;
$$;

COMMENT ON FUNCTION ana_tipo_alloggio_trg1_func() IS
'Assegna la chiave solo se chi scrive non l''ha data. Prima la sovrascriveva sempre, e
questo rendeva inutile ogni ON CONFLICT: al posto di un aggiornamento arrivava un
duplicato, senza che nessuno protestasse (difetto 97).';
