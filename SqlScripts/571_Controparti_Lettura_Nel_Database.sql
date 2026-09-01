-- =============================================================================
-- 571 — La lettura delle controparti scende nel database, con la ricerca dentro
-- =============================================================================
--
-- Motivo immediato: l'inserimento dei fornitori puo' essere fatto da piu' persone
-- insieme, e la griglia filtrava la lista letta all'apertura della pagina — quello
-- che ha appena scritto un collega non c'era, e nessuna ricerca poteva trovarlo.
-- Stesso caso gia' chiuso per clienti (fn_search_clienti) e viaggi (script 570).
--
-- Motivo piu' serio, trovato scrivendo questo: ContropartiService.GetAllAsync
-- costruiva la query **in C#, concatenando stringhe**:
--
--     sql += $" AND c.azienda_fk = {currentAziendaId.Value}";
--
-- Due cose in una. La prima e' che il progetto e' DB-first e li' dentro non deve
-- esserci SQL. La seconda e' che il confine fra i silos delle aziende — la regola
-- che impedisce a un'azienda di vedere le controparti di un'altra — era scritto
-- con una concatenazione di stringa: sta reggendo perche' quel valore e' un
-- intero, ma e' il tipo di riga che nessuno vuole trovare in un audit.
--
-- Qui il filtro azienda diventa un parametro, come tutti gli altri.
-- =============================================================================

-- Il DROP rende lo script rigiocabile: CREATE OR REPLACE non puo' cambiare il tipo
-- restituito, e su un database che ha gia' visto una versione precedente fallirebbe
-- con "cannot change return type of existing function". Stessa famiglia di 544/547.
DROP FUNCTION IF EXISTS fn_ana_controparti_get_all(INTEGER, BOOLEAN, BOOLEAN, VARCHAR);

CREATE OR REPLACE FUNCTION fn_ana_controparti_get_all(
    p_azienda_fk      INTEGER DEFAULT NULL,
    p_solo_fornitori  BOOLEAN DEFAULT NULL,
    p_solo_clienti    BOOLEAN DEFAULT NULL,
    p_search_text     VARCHAR DEFAULT NULL
)
RETURNS TABLE(
    controparte_id INTEGER,
    azienda_fk INTEGER,
    ragione_sociale VARCHAR,
    nome_breve VARCHAR,
    is_fornitore BOOLEAN,
    is_cliente BOOLEAN,
    partita_iva VARCHAR,
    codice_fiscale VARCHAR,
    codice_destinatario_sdi VARCHAR,
    indirizzo VARCHAR,
    comune_fk INTEGER,
    telefono_prefisso VARCHAR,
    telefono_numero VARCHAR,
    email VARCHAR,
    pec VARCHAR,
    sito_web VARCHAR,
    tipo_fornitore_fk INTEGER,
    fornitore_estero BOOLEAN,
    attivo BOOLEAN,
    priorita SMALLINT,          -- smallint sulla tabella: dichiararla INTEGER fa fallire ogni chiamata
    note TEXT,
    created_at TIMESTAMPTZ,
    created_by VARCHAR,
    updated_at TIMESTAMPTZ,
    updated_by VARCHAR,
    tipo_fornitore_desc VARCHAR,
    comune_descrizione VARCHAR,
    provincia_sigla VARCHAR
)
LANGUAGE plpgsql
STABLE
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
        p.provincia_sigla
    FROM ana_controparti c
    LEFT JOIN ana_tipo_fornitore tf ON c.tipo_fornitore_fk = tf.tipo_fornitore_id
    LEFT JOIN ana_geo_comuni co     ON c.comune_fk = co.comune_id
    LEFT JOIN ana_geo_province p    ON co.comune_provincia_fk = p.provincia_id
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

COMMENT ON FUNCTION fn_ana_controparti_get_all(INTEGER, BOOLEAN, BOOLEAN, VARCHAR) IS
'Elenco controparti con le descrizioni collegate (tipo fornitore, comune, provincia) e la
ricerca dentro. Sostituisce la query che ContropartiService costruiva in C# concatenando
stringhe, filtro azienda compreso. Cercare qui e non a valle e'' cio'' che permette di
trovare un fornitore appena inserito da un altro utente.';
