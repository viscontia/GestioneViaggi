-- =============================================================================
-- 556 — Il CRUD accetta anche il titolo come testo
-- =============================================================================
-- Il sito di iscrizione manda il titolo come STRINGA ("SIG.", "SIG.RA") e il sesso
-- come campo a parte: non conosce ana_titolo_persone, che e' nata dopo. Senza un
-- ponte, il passaggio del sito al CRUD unico farebbe fallire ogni iscrizione,
-- perche' cliente_titolo_fk e' NOT NULL.
--
-- Il ponte esiste gia' dal 539 — fn_ana_titolo_persone_da_testo — ed e' lo stesso
-- che regge le nove function che scrivono ancora la colonna testuale. Qui lo si
-- riusa: se manca la chiave, la si ricava dal testo e dal sesso.
--
-- ⚠️ E' compatibilita', non la meta. Quando il sito passera' alla lookup (§2.8.3
--    della Checklist Go-Live) questo pezzo si toglie insieme al resto del ponte.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_ana_clienti_titolo_fk(p_dati JSONB)
RETURNS INTEGER LANGUAGE sql STABLE AS $$
    SELECT COALESCE(
        (p_dati->>'cliente_titolo_fk')::INTEGER,
        fn_ana_titolo_persone_da_testo(
            p_dati->>'cliente_titolo',
            COALESCE(upper(left(btrim(p_dati->>'cliente_sesso'),1)), 'M')::CHAR)
    );
$$;

COMMENT ON FUNCTION fn_ana_clienti_titolo_fk(JSONB) IS
'Chiave del titolo: quella esplicita se c''e'', altrimenti ricavata dal testo e dal sesso (ponte per il sito di iscrizione, SqlScripts/556). Si elimina quando il sito passa alla lookup.';

COMMIT;

-- L'inserimento usa il ponte. (Il 550 e' gia' applicato su PROD: si sostituisce
-- la funzione, non si riscrive quello script.)
BEGIN;

CREATE OR REPLACE FUNCTION fn_ana_clienti_insert(
    p_dati JSONB, p_conferme_accettate BOOLEAN DEFAULT FALSE
) RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_id INTEGER; v_completo JSONB;
BEGIN
    -- Si normalizza la chiave del titolo PRIMA di validare: la validazione legge
    -- il sesso dal titolo, e senza chiave non lo troverebbe.
    v_completo := p_dati || jsonb_build_object('cliente_titolo_fk', fn_ana_clienti_titolo_fk(p_dati));

    PERFORM fn_ana_clienti_guardia(v_completo, NULL, p_conferme_accettate);

    INSERT INTO ana_clienti (
        azienda_fk, cliente_titolo_fk, cliente_cognome, cliente_nome, cliente_sesso,
        cliente_comune_residenza_fk, cliente_indirizzo_residenza,
        cliente_comune_nascita_fk, cliente_data_nascita,
        cliente_preftelint, cliente_telefono, cliente_email, cliente_codicefiscale,
        cliente_iban, cliente_foto, cliente_carta_identita,
        cliente_tipodoc_identita, cliente_documento_numero, cliente_documento_rilasciato_da,
        cliente_documento_rilasciato_data, cliente_documento_rilasciato_scadenza,
        cliente_note, cliente_intolleranza,
        cliente_foto_mimetype, cliente_foto_filename, cliente_foto_charset, cliente_foto_upd_date,
        cliente_documento_mimetype, cliente_documento_filename, cliente_documento_chartset,
        cliente_documento_upd_date, controparte_fk,
        cliente_lingua, consenso_marketing, consenso_marketing_data, consenso_marketing_fonte
    ) VALUES (
        (v_completo->>'azienda_fk')::INTEGER, (v_completo->>'cliente_titolo_fk')::INTEGER,
        upper(btrim(v_completo->>'cliente_cognome')), upper(btrim(v_completo->>'cliente_nome')),
        'M',   -- segnaposto: lo riscrive il trigger dal titolo (SqlScripts/538)
        (v_completo->>'cliente_comune_residenza_fk')::INTEGER, v_completo->>'cliente_indirizzo_residenza',
        (v_completo->>'cliente_comune_nascita_fk')::INTEGER, (v_completo->>'cliente_data_nascita')::DATE,
        v_completo->>'cliente_preftelint', v_completo->>'cliente_telefono',
        lower(btrim(v_completo->>'cliente_email')), upper(btrim(v_completo->>'cliente_codicefiscale')),
        upper(btrim(v_completo->>'cliente_iban')),
        decode(COALESCE(v_completo->>'cliente_foto',''), 'base64'),
        decode(COALESCE(v_completo->>'cliente_carta_identita',''), 'base64'),
        v_completo->>'cliente_tipodoc_identita', v_completo->>'cliente_documento_numero',
        v_completo->>'cliente_documento_rilasciato_da',
        (v_completo->>'cliente_documento_rilasciato_data')::DATE,
        (v_completo->>'cliente_documento_rilasciato_scadenza')::DATE,
        v_completo->>'cliente_note', v_completo->>'cliente_intolleranza',
        v_completo->>'cliente_foto_mimetype', v_completo->>'cliente_foto_filename',
        v_completo->>'cliente_foto_charset', (v_completo->>'cliente_foto_upd_date')::DATE,
        v_completo->>'cliente_documento_mimetype', v_completo->>'cliente_documento_filename',
        v_completo->>'cliente_documento_chartset', (v_completo->>'cliente_documento_upd_date')::DATE,
        (v_completo->>'controparte_fk')::INTEGER,
        COALESCE(upper(btrim(v_completo->>'cliente_lingua')), 'IT'),
        COALESCE((v_completo->>'consenso_marketing')::BOOLEAN, FALSE),
        CASE WHEN COALESCE((v_completo->>'consenso_marketing')::BOOLEAN, FALSE)
             THEN COALESCE((v_completo->>'consenso_marketing_data')::TIMESTAMPTZ, now()) END,
        CASE WHEN COALESCE((v_completo->>'consenso_marketing')::BOOLEAN, FALSE)
             THEN COALESCE(v_completo->>'consenso_marketing_fonte', 'NON_DICHIARATA') END
    ) RETURNING cliente_id INTO v_id;

    RETURN v_id;
END;
$$;

COMMIT;
