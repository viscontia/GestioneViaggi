-- =============================================================================
-- 595 — Rileggere UNA controparte, per aprirla in modifica com'è adesso
-- =============================================================================
--
-- Osservazione dell'utente, 2026-09-05: «pensa a un ufficio dove lavorano più
-- persone sulla stessa azienda e sullo stesso gestionale!»
--
-- Le pagine aprivano la modifica sulla riga presa dall'elenco, cioè su una
-- fotografia del momento in cui l'elenco era stato caricato. Con più persone che
-- lavorano insieme quella fotografia invecchia in fretta, e il rischio non è
-- vedere dati vecchi: è **salvarli sopra a quelli nuovi** di un collega.
--
-- Per rileggere una controparte c'era solo `fn_ana_controparti_get_all`, che
-- restituisce l'elenco intero. Leggere tutto per prenderne una è lo spreco che si
-- ripete a ogni apertura di scheda.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_ana_controparti_get_by_id(p_controparte_id INTEGER)
RETURNS TABLE(
    controparte_id integer,
    azienda_fk integer,
    ragione_sociale character varying,
    nome_breve character varying,
    is_fornitore boolean,
    is_cliente boolean,
    partita_iva character varying,
    codice_fiscale character varying,
    codice_destinatario_sdi character varying,
    indirizzo character varying,
    comune_fk integer,
    telefono_prefisso character varying,
    telefono_numero character varying,
    email character varying,
    pec character varying,
    sito_web character varying,
    tipo_fornitore_fk integer,
    fornitore_estero boolean,
    attivo boolean,
    priorita smallint,
    note text,
    created_at timestamp with time zone,
    created_by character varying,
    updated_at timestamp with time zone,
    updated_by character varying,
    tipo_fornitore_desc character varying,
    comune_descrizione character varying,
    provincia_sigla character varying
)
LANGUAGE sql
STABLE
AS $$
    -- Si filtra il risultato di fn_ana_controparti_get_all invece di riscriverne la
    -- query: la forma della riga — con le descrizioni dei join che il gestionale si
    -- aspetta — resta definita in un posto solo. Duplicarla qui vorrebbe dire due
    -- SELECT da tenere allineate, ed e' esattamente il modo in cui divergono.
    SELECT * FROM fn_ana_controparti_get_all(NULL, NULL, NULL, NULL) g
    WHERE g.controparte_id = p_controparte_id;
$$;
