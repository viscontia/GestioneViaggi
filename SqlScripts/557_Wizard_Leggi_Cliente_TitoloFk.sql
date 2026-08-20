-- =============================================================================
-- 557 — La rilettura del cliente restituisce anche la chiave del titolo
-- =============================================================================
-- Il sito ora sceglie il titolo dalla lookup (ana_titolo_persone) e manda la
-- CHIAVE. Ma quando ricarica un cliente esistente riceveva solo il testo, e con
-- quello non ritrovava la voce nella tendina: il titolo sarebbe rimasto vuoto.
-- E' lo stesso difetto che il gestionale aveva prima del 538, per la stessa
-- ragione — un valore testuale usato come se fosse una chiave.
--
-- Si aggiunge cliente_titolo_fk IN CODA: il sito legge per nome di colonna
-- (cursor.description), quindi un campo in piu' non disturba chi c'e' gia'.
-- =============================================================================

BEGIN;

DROP FUNCTION IF EXISTS fn_wizard_leggi_dati_cliente(VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION fn_wizard_leggi_dati_cliente(
    p_email VARCHAR, p_azienda_id INTEGER
) RETURNS TABLE(
    cliente_id INTEGER, cliente_titolo VARCHAR, cliente_cognome VARCHAR, cliente_nome VARCHAR,
    cliente_sesso CHARACTER, cliente_comune_residenza_fk INTEGER,
    descrizione_comune_residenza VARCHAR, cliente_indirizzo_residenza VARCHAR,
    cliente_comune_nascita_fk INTEGER, descrizione_comune_nascita VARCHAR,
    cliente_data_nascita DATE, cliente_preftelint VARCHAR, cliente_telefono VARCHAR,
    cliente_email VARCHAR, cliente_codicefiscale VARCHAR, cliente_intolleranza TEXT,
    cliente_tipodoc_identita VARCHAR, cliente_documento_numero VARCHAR,
    cliente_documento_rilasciato_da VARCHAR, cliente_documento_rilasciato_data DATE,
    cliente_documento_rilasciato_scadenza DATE,
    cliente_titolo_fk INTEGER,
    consenso_marketing BOOLEAN
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.cliente_id, c.cliente_titolo, c.cliente_cognome, c.cliente_nome, c.cliente_sesso,
        c.cliente_comune_residenza_fk, gr.comune_descrizione, c.cliente_indirizzo_residenza,
        c.cliente_comune_nascita_fk, gn.comune_descrizione, c.cliente_data_nascita,
        c.cliente_preftelint, c.cliente_telefono, c.cliente_email, c.cliente_codicefiscale,
        c.cliente_intolleranza, c.cliente_tipodoc_identita, c.cliente_documento_numero,
        c.cliente_documento_rilasciato_da, c.cliente_documento_rilasciato_data,
        c.cliente_documento_rilasciato_scadenza,
        -- I due campi nuovi, in coda.
        c.cliente_titolo_fk,
        -- Il consenso serve a ripresentare la spunta com'e': ricaricando un cliente
        -- che l'aveva dato, la casella deve risultare gia' segnata — altrimenti al
        -- primo salvataggio successivo verrebbe spento senza che nessuno l'abbia revocato.
        c.consenso_marketing
    FROM ana_clienti c
    LEFT JOIN ana_geo_comuni gr ON c.cliente_comune_residenza_fk = gr.comune_id
    LEFT JOIN ana_geo_comuni gn ON c.cliente_comune_nascita_fk = gn.comune_id
    WHERE LOWER(c.cliente_email) = LOWER(p_email)
      AND c.azienda_fk = p_azienda_id;
END;
$$;

COMMIT;
