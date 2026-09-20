-- ============================================================================
-- Modalità di pagamento: dove si vede e dove arriva
--
-- Il 645 ha creato la tabella e le colonne, il 646 le funzioni e i dati. Qui si
-- collegano alle due letture che servono davvero:
--
--   1. `fn_ana_controparti_get_all` — la scheda e l'elenco delle controparti
--      devono poter mostrare e salvare la modalità abituale;
--   2. `fn_get_transazione_init_data` — la scheda dei movimenti riceve l'elenco
--      delle modalità attive e, su ogni controparte, quale sia la sua: così la
--      proposta compare **appena si sceglie l'interlocutore**, senza un'altra
--      andata e ritorno al database.
--
-- ⚠️ DROP + CREATE sulle due funzioni delle controparti: cambia il tipo del
-- risultato (due colonne in più) e CREATE OR REPLACE non può farlo.
-- ℹ️ `fn_ana_controparti_get_by_id` va ricreata anche se il suo corpo non cambia:
-- restituisce `SELECT *` dell'altra, quindi il suo tipo cambia con quello.
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS fn_ana_controparti_get_by_id(integer);
DROP FUNCTION IF EXISTS fn_ana_controparti_get_all(integer, boolean, boolean, character varying);

CREATE OR REPLACE FUNCTION fn_ana_controparti_get_all(
    p_azienda_fk     INTEGER DEFAULT NULL,
    p_solo_fornitori BOOLEAN DEFAULT NULL,
    p_solo_clienti   BOOLEAN DEFAULT NULL,
    p_search_text    VARCHAR DEFAULT NULL
)
RETURNS TABLE(
    controparte_id INTEGER, azienda_fk INTEGER, ragione_sociale VARCHAR, nome_breve VARCHAR,
    is_fornitore BOOLEAN, is_cliente BOOLEAN, partita_iva VARCHAR, codice_fiscale VARCHAR,
    codice_destinatario_sdi VARCHAR, indirizzo VARCHAR, comune_fk INTEGER,
    telefono_prefisso VARCHAR, telefono_numero VARCHAR, email VARCHAR, pec VARCHAR, sito_web VARCHAR,
    tipo_fornitore_fk INTEGER, fornitore_estero BOOLEAN, attivo BOOLEAN, priorita SMALLINT, note TEXT,
    created_at TIMESTAMPTZ, created_by VARCHAR, updated_at TIMESTAMPTZ, updated_by VARCHAR,
    tipo_fornitore_desc VARCHAR, comune_descrizione VARCHAR, provincia_sigla VARCHAR,
    modalita_pagamento_fk INTEGER, modalita_pagamento_codice VARCHAR
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.controparte_id, c.azienda_fk, c.ragione_sociale, c.nome_breve,
        c.is_fornitore, c.is_cliente, c.partita_iva, c.codice_fiscale,
        c.codice_destinatario_sdi, c.indirizzo, c.comune_fk,
        c.telefono_prefisso, c.telefono_numero, c.email, c.pec, c.sito_web,
        c.tipo_fornitore_fk, c.fornitore_estero, c.attivo, c.priorita, c.note,
        c.created_at, c.created_by, c.updated_at, c.updated_by,
        tf.descrizione   AS tipo_fornitore_desc,
        co.comune_descrizione,
        p.provincia_sigla,
        -- La modalità abituale, con il suo codice gia' pronto da mostrare:
        -- l'elenco delle controparti non deve andarselo a cercare da solo.
        c.modalita_pagamento_fk,
        mp.modpag_codice AS modalita_pagamento_codice
    FROM ana_controparti c
    LEFT JOIN ana_tipo_fornitore tf ON c.tipo_fornitore_fk = tf.tipo_fornitore_id
    LEFT JOIN ana_geo_comuni co     ON c.comune_fk = co.comune_id
    LEFT JOIN ana_geo_province p    ON co.comune_provincia_fk = p.provincia_id
    LEFT JOIN ana_modalita_pagamento mp ON c.modalita_pagamento_fk = mp.modpag_id
    -- NULL e 0 valgono "tutte le aziende", ed e' il caso del SuperAdmin. Per chiunque
    -- altro il chiamante passa la propria, e il confine fra i silos vale qui.
    WHERE (p_azienda_fk IS NULL OR p_azienda_fk = 0 OR c.azienda_fk = p_azienda_fk)
      AND (p_solo_fornitori IS NOT TRUE OR c.is_fornitore = TRUE)
      AND (p_solo_clienti   IS NOT TRUE OR c.is_cliente  = TRUE)
      -- Gli stessi campi su cui filtrava la griglia in memoria: ragione sociale,
      -- nome breve, email, partita IVA, tipo di fornitore.
      AND (NULLIF(btrim(COALESCE(p_search_text, '')), '') IS NULL
           OR UPPER(c.ragione_sociale)          LIKE '%' || UPPER(btrim(p_search_text)) || '%'
           OR UPPER(COALESCE(c.nome_breve, ''))  LIKE '%' || UPPER(btrim(p_search_text)) || '%'
           OR UPPER(COALESCE(c.email, ''))       LIKE '%' || UPPER(btrim(p_search_text)) || '%'
           OR UPPER(COALESCE(c.partita_iva, '')) LIKE '%' || UPPER(btrim(p_search_text)) || '%'
           OR UPPER(COALESCE(tf.descrizione, '')) LIKE '%' || UPPER(btrim(p_search_text)) || '%')
    ORDER BY c.priorita ASC, c.ragione_sociale ASC;
END;
$$;

CREATE OR REPLACE FUNCTION fn_ana_controparti_get_by_id(p_controparte_id INTEGER)
RETURNS TABLE(
    controparte_id INTEGER, azienda_fk INTEGER, ragione_sociale VARCHAR, nome_breve VARCHAR,
    is_fornitore BOOLEAN, is_cliente BOOLEAN, partita_iva VARCHAR, codice_fiscale VARCHAR,
    codice_destinatario_sdi VARCHAR, indirizzo VARCHAR, comune_fk INTEGER,
    telefono_prefisso VARCHAR, telefono_numero VARCHAR, email VARCHAR, pec VARCHAR, sito_web VARCHAR,
    tipo_fornitore_fk INTEGER, fornitore_estero BOOLEAN, attivo BOOLEAN, priorita SMALLINT, note TEXT,
    created_at TIMESTAMPTZ, created_by VARCHAR, updated_at TIMESTAMPTZ, updated_by VARCHAR,
    tipo_fornitore_desc VARCHAR, comune_descrizione VARCHAR, provincia_sigla VARCHAR,
    modalita_pagamento_fk INTEGER, modalita_pagamento_codice VARCHAR
)
LANGUAGE sql STABLE
AS $$
    -- Si filtra il risultato di fn_ana_controparti_get_all invece di riscriverne la
    -- query: la forma della riga — con le descrizioni dei join che il gestionale si
    -- aspetta — resta definita in un posto solo. Duplicarla qui vorrebbe dire due
    -- SELECT da tenere allineate, ed e' esattamente il modo in cui divergono.
    SELECT * FROM fn_ana_controparti_get_all(NULL, NULL, NULL, NULL) g
    WHERE g.controparte_id = p_controparte_id;
$$;

COMMIT;
