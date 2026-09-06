-- =============================================================================
-- 603 — Le descrizioni dei generi e dei tipi di alloggio sono sempre maiuscole
-- =============================================================================
--
-- Segnalato in collaudo il 2026-09-06: nell'elenco dei generi le descrizioni si
-- leggono in minuscolo, ma aprendo la scheda sono maiuscole.
--
-- ⚠️ Non era un difetto di visualizzazione: erano **i dati** a essere in minuscolo.
-- Le tre righe iniziali le ha scritte lo script 599 come «Camera in struttura
-- ricettiva»; il maiuscolo lo faceva solo la scheda, con un `ToUpper` nel C# al
-- momento della digitazione. Chi non riapriva la riga non lo vedeva mai.
--
-- E' la solita forma: **una regola applicata in un punto solo del percorso**. La
-- scheda maiuscolizza, l'inserimento iniziale no, e il sito — che un domani
-- scrivera' sulle stesse tabelle — non saprebbe nemmeno che la regola esiste.
-- Scende quindi nella funzione, dove vale per chiunque scriva.
--
-- Il resto del progetto e' gia' cosi': `CAMERA MATRIMONIALE`, `SOLO CAMPI TENDATI`.
-- Erano le mie righe a essere fuori convenzione.
-- =============================================================================

-- 1. I dati esistenti
UPDATE ana_alloggio_generi
   SET genere_descrizione = upper(btrim(genere_descrizione))
 WHERE genere_descrizione <> upper(btrim(genere_descrizione));

UPDATE ana_tipo_alloggio
   SET tipo_alloggio_descrizione = upper(btrim(tipo_alloggio_descrizione))
 WHERE tipo_alloggio_descrizione <> upper(btrim(tipo_alloggio_descrizione));

-- 2. La regola, dove vale per tutti
CREATE OR REPLACE FUNCTION fn_ana_alloggio_generi_upsert(
    p_id INTEGER, p_codice VARCHAR, p_descrizione VARCHAR,
    p_ordine SMALLINT, p_attivo BOOLEAN
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE v_id INTEGER;
BEGIN
    IF btrim(COALESCE(p_codice,'')) = '' THEN
        RAISE EXCEPTION 'Il codice del genere è obbligatorio: è con quello che il programma lo riconosce.';
    END IF;

    -- ⚠️ Maiuscolo qui e non solo nella scheda: la stessa tabella la scrivera' il sito,
    -- e una convenzione applicata in un punto solo del percorso non e' una convenzione.
    IF COALESCE(p_id, 0) = 0 THEN
        INSERT INTO ana_alloggio_generi (genere_codice, genere_descrizione, genere_ordine, genere_attivo)
        VALUES (upper(btrim(p_codice)), upper(btrim(p_descrizione)),
                COALESCE(p_ordine, 99), COALESCE(p_attivo, TRUE))
        RETURNING genere_id INTO v_id;
    ELSE
        UPDATE ana_alloggio_generi
           SET genere_codice = upper(btrim(p_codice)),
               genere_descrizione = upper(btrim(p_descrizione)),
               genere_ordine = COALESCE(p_ordine, 99), genere_attivo = COALESCE(p_attivo, TRUE)
         WHERE genere_id = p_id
        RETURNING genere_id INTO v_id;
    END IF;
    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION fn_ana_tipo_alloggio_upsert(
    p_id INTEGER, p_descrizione VARCHAR, p_numero_occupanti INTEGER,
    p_supplemento VARCHAR, p_genere_fk INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE v_id INTEGER;
BEGIN
    IF COALESCE(p_genere_fk, 0) = 0 THEN
        RAISE EXCEPTION 'Il genere è obbligatorio: senza, non si può sapere su quali viaggi questa sistemazione è ammessa.';
    END IF;

    IF COALESCE(p_id, 0) = 0 THEN
        INSERT INTO ana_tipo_alloggio
            (tipo_alloggio_descrizione, tipo_alloggio_numero_occupanti, tipo_alloggio_supplemento, genere_fk)
        VALUES (upper(btrim(p_descrizione)), p_numero_occupanti, COALESCE(p_supplemento,'N'), p_genere_fk)
        RETURNING tipo_alloggio_id INTO v_id;
    ELSE
        UPDATE ana_tipo_alloggio
           SET tipo_alloggio_descrizione = upper(btrim(p_descrizione)),
               tipo_alloggio_numero_occupanti = p_numero_occupanti,
               tipo_alloggio_supplemento = COALESCE(p_supplemento,'N'),
               genere_fk = p_genere_fk
         WHERE tipo_alloggio_id = p_id
        RETURNING tipo_alloggio_id INTO v_id;
    END IF;
    RETURN v_id;
END;
$$;
