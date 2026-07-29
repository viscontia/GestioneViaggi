-- Promemoria di verifica del listino Anthropic.
-- Segue lo script 500.
--
-- Anthropic NON espone i prezzi via API (verificato: /v1/models restituisce id, capacità e
-- dimensione del contesto, nessun costo). L'unica fonte è la pagina di documentazione, quindi
-- leggerla da programma significherebbe interpretare HTML: si romperebbe in silenzio a ogni
-- cambio di impaginazione, e il modo peggiore in cui può rompersi è mostrare al cliente prezzi
-- sbagliati con la stessa sicurezza di prima.
--
-- Invece di indovinare i prezzi, si ricorda QUANDO sono stati confermati l'ultima volta: passata
-- la scadenza il gestionale lo segnala e l'utente ricontrolla il listino. I listini cambiano
-- qualche volta l'anno, quindi il promemoria basta e non aggiunge dipendenze di rete.

ALTER TABLE web_ai_config
    ADD COLUMN IF NOT EXISTS prezzi_verificati_il DATE;

COMMENT ON COLUMN web_ai_config.prezzi_verificati_il IS
    'Data in cui l''operatore ha confermato i prezzi configurati contro il listino Anthropic. NULL = mai confermati.';

-- Backfill: i prezzi in codice sono stati verificati sul listino ufficiale il 2026-07-28
-- (Haiku 4.5 = $1/MTok input, $5/MTok output). Le configurazioni già esistenti partono da lì,
-- così il promemoria non scatta subito su un dato che è appena stato controllato.
UPDATE web_ai_config
   SET prezzi_verificati_il = DATE '2026-07-28'
 WHERE prezzi_verificati_il IS NULL;

CREATE OR REPLACE FUNCTION fn_web_ai_prezzi_verificati(p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO web_ai_config(azienda_id, prezzi_verificati_il, created_by)
    VALUES (p_azienda_id, CURRENT_DATE, COALESCE(current_setting('my.app_user', true), 'system'))
    ON CONFLICT (azienda_id) DO UPDATE
       SET prezzi_verificati_il = CURRENT_DATE,
           updated_by = COALESCE(current_setting('my.app_user', true), 'system'),
           updated = now();
    RETURN 1;
END $$;

COMMENT ON FUNCTION fn_web_ai_prezzi_verificati(INTEGER) IS
'Registra che oggi l''operatore ha confermato i prezzi contro il listino Anthropic (azzera il promemoria).';

-- Il getter deve esporre anche la data di verifica: il RETURNS TABLE cambia, quindi drop esplicito.
DROP FUNCTION IF EXISTS fn_web_ai_config_get(INTEGER);

CREATE OR REPLACE FUNCTION fn_web_ai_config_get(p_azienda_id INTEGER)
RETURNS TABLE (soglia_spesa NUMERIC, conteggio_da TIMESTAMPTZ, avvisato_il TIMESTAMPTZ, prezzi_verificati_il DATE)
LANGUAGE sql STABLE AS $$
    SELECT c.soglia_spesa, c.conteggio_da, c.avvisato_il, c.prezzi_verificati_il
      FROM web_ai_config c WHERE c.azienda_id = p_azienda_id;
$$;
