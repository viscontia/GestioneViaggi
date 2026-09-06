-- =============================================================================
-- 600 — Cosa si può assegnare, e in che forme: le regole delle sistemazioni
-- =============================================================================
--
-- Le tre funzioni che il sito e il gestionale chiamano ENTRAMBI. ⚠️ E' il punto
-- dell'intero lavoro: le due interfacce possono essere diverse — il sito guida chi
-- si iscrive, il gestionale serve chi lavora e deve poter correggere — ma non
-- possono avere idee diverse su cosa sia valido.
--
-- Prima di questo, l'elenco dei tipi arrivava intero e il filtro lo faceva il
-- JavaScript del sito («capienza <= persone da assegnare»): un criterio che con
-- `NESSUNA CAMERA` a capienza 0 e' sempre vero, e che il gestionale non applicava
-- affatto. Da li' le 17 assegnazioni incoerenti trovate su PROD.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Cosa si può assegnare su questa partenza
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_alloggi_tipi_ammessi(p_data_viaggio_id INTEGER)
RETURNS TABLE(
    tipo_id      INTEGER,
    descrizione  VARCHAR,
    posti        INTEGER,
    supplemento  BOOLEAN,
    genere       VARCHAR
)
LANGUAGE sql
STABLE
AS $$
    SELECT t.tipo_alloggio_id, t.tipo_alloggio_descrizione,
           t.tipo_alloggio_numero_occupanti, t.tipo_alloggio_supplemento = 'Y',
           g.genere_codice
    FROM ana_date_viaggi d
    JOIN ana_viaggi v            ON v.viaggio_id = d.viaggio_id_fk
    JOIN ana_tipo_alloggio t     ON TRUE
    JOIN ana_alloggio_generi g   ON g.genere_id = t.genere_fk AND g.genere_attivo
    WHERE d.data_viaggio_id = p_data_viaggio_id
      AND (
        -- I generi che questo viaggio prevede…
        EXISTS (SELECT 1 FROM ana_tipo_pernottamento_generi pg
                WHERE pg.pernottamento_fk = v.viaggio_tipo_pernottamento_fk
                  AND pg.genere_fk = t.genere_fk)
        -- …piu' NESSUNA, che vale sempre e non si configura: chi dorme nel proprio
        -- mezzo o si ferma da parenti esiste su qualunque viaggio.
        OR g.genere_codice = 'NESSUNA'
      )
    ORDER BY g.genere_ordine, t.tipo_alloggio_numero_occupanti DESC, t.tipo_alloggio_descrizione;
$$;

COMMENT ON FUNCTION fn_alloggi_tipi_ammessi(INTEGER) IS
'I tipi di sistemazione assegnabili su questa partenza: quelli del genere che il viaggio
prevede, piu'' NESSUNA che vale sempre. Sostituisce l''elenco intero filtrato a mano dal
JavaScript — filtro che il gestionale non applicava affatto.';


-- ---------------------------------------------------------------------------
-- 2. In che forme si possono dividere N persone
-- ---------------------------------------------------------------------------
-- ⚠️ p_persone sono le persone che una sistemazione la vogliono: chi sceglie
-- «nessuna» esce dal conto prima, perche' non occupa un posto in nessun gruppo.
CREATE OR REPLACE FUNCTION fn_alloggi_combinazioni(
    p_data_viaggio_id INTEGER,
    p_persone         INTEGER
)
RETURNS TABLE(
    forma        INTEGER,     -- numero progressivo della combinazione
    gruppi       INTEGER[],   -- dimensione di ciascun gruppo, dal piu' grande
    camere       INTEGER,     -- quante sistemazioni servono
    chiedere_chi BOOLEAN      -- se serve sapere chi sta con chi
)
LANGUAGE sql
STABLE
AS $$
    -- Le forme sono le partizioni di N in parti non crescenti: {4}, {3,1}, {2,2},
    -- {2,1,1}, {1,1,1,1}. Si generano qui e non nel programma perche' devono venire
    -- uguali al sito e al gestionale.
    WITH RECURSIVE
    capienze AS (
        -- Solo le capienze davvero disponibili su questa partenza: una forma che
        -- chiede un gruppo da 4 non esiste se il viaggio non offre nulla da 4 posti.
        SELECT DISTINCT posti FROM fn_alloggi_tipi_ammessi(p_data_viaggio_id) WHERE posti > 0
    ),
    partizioni(resto, massimo, gruppi) AS (
        SELECT p_persone, p_persone, ARRAY[]::INTEGER[]
        UNION ALL
        SELECT pz.resto - c.posti, c.posti, pz.gruppi || c.posti
        FROM partizioni pz
        JOIN capienze c ON c.posti <= LEAST(pz.resto, pz.massimo)
        WHERE pz.resto > 0
    ),
    complete AS (
        SELECT gruppi FROM partizioni WHERE resto = 0 AND array_length(gruppi, 1) > 0
    )
    SELECT (row_number() OVER (ORDER BY array_length(c.gruppi,1), c.gruppi))::INTEGER,
           c.gruppi,
           array_length(c.gruppi, 1),
           -- ⚠️ Si chiede «chi con chi» solo se i gruppi sono piu' d''uno E almeno uno
           -- ha due o piu' persone. Due gruppi da una persona sono indistinguibili:
           -- chiedere chi va dove sarebbe un passaggio a vuoto. E' il motivo per cui
           -- la coppia — il caso piu' frequente — non vede mai quella domanda.
           array_length(c.gruppi, 1) > 1 AND (SELECT max(x) FROM unnest(c.gruppi) x) >= 2
    FROM complete c
    ORDER BY 1;
$$;

COMMENT ON FUNCTION fn_alloggi_combinazioni(INTEGER, INTEGER) IS
'Le forme in cui N persone possono dividersi fra le sistemazioni disponibili su questa
partenza, con l''indicazione se serve chiedere chi sta con chi. ⚠️ N sono le persone che una
sistemazione la vogliono: chi sceglie «nessuna» esce dal conto prima.';


-- ---------------------------------------------------------------------------
-- 3. Un'assegnazione completa e' valida?
-- ---------------------------------------------------------------------------
-- ⚠️ Esiste anche se l''interfaccia impedisce gia'' di sbagliare: l''interfaccia e'' il
-- modo comodo di rispettare la regola, non la regola.
CREATE OR REPLACE FUNCTION fn_alloggi_assegnazione_valida(
    p_data_viaggio_id INTEGER,
    p_assegnazioni    JSONB   -- [{"tipo_id": 1, "clienti": [12, 34]}, ...]
)
RETURNS TABLE(gravita VARCHAR, esito VARCHAR, messaggio TEXT)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    r          JSONB;
    v_tipo     INTEGER;
    v_clienti  INTEGER[];
    v_posti    INTEGER;
    v_desc     VARCHAR;
    v_tutti    INTEGER[] := ARRAY[]::INTEGER[];
BEGIN
    FOR r IN SELECT * FROM jsonb_array_elements(COALESCE(p_assegnazioni, '[]'::jsonb))
    LOOP
        v_tipo := (r->>'tipo_id')::INTEGER;
        SELECT array_agg(x::INTEGER) INTO v_clienti
        FROM jsonb_array_elements_text(COALESCE(r->'clienti', '[]'::jsonb)) x;
        v_clienti := COALESCE(v_clienti, ARRAY[]::INTEGER[]);

        SELECT a.posti, a.descrizione INTO v_posti, v_desc
        FROM fn_alloggi_tipi_ammessi(p_data_viaggio_id) a WHERE a.tipo_id = v_tipo;

        -- Il tipo non e' ammesso su questa partenza: e' il controllo che mancava, e
        -- che ha lasciato passare 17 camere d''albergo su viaggi senza albergo.
        IF v_posti IS NULL THEN
            SELECT t.tipo_alloggio_descrizione INTO v_desc
            FROM ana_tipo_alloggio t WHERE t.tipo_alloggio_id = v_tipo;
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'TIPO_NON_AMMESSO'::VARCHAR,
                   format('«%s» non e'' una sistemazione prevista da questo viaggio.',
                          COALESCE(v_desc, 'Tipo ' || v_tipo))::TEXT;
            CONTINUE;
        END IF;

        -- La capienza deve corrispondere: una doppia con una persona sola si chiama
        -- «doppia uso singola» ed e'' un tipo suo, con il suo supplemento.
        IF v_posti > 0 AND array_length(v_clienti, 1) IS DISTINCT FROM v_posti THEN
            RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'CAPIENZA_NON_RISPETTATA'::VARCHAR,
                   format('«%s» ospita %s persone, ne sono state indicate %s.',
                          v_desc, v_posti, COALESCE(array_length(v_clienti,1), 0))::TEXT;
        END IF;

        v_tutti := v_tutti || v_clienti;
    END LOOP;

    -- Nessuno due volte.
    IF (SELECT count(*) FROM unnest(v_tutti)) <> (SELECT count(DISTINCT x) FROM unnest(v_tutti) x) THEN
        RETURN QUERY SELECT 'ERRORE'::VARCHAR, 'PERSONA_RIPETUTA'::VARCHAR,
               'Una stessa persona risulta assegnata a piu'' di una sistemazione.'::TEXT;
    END IF;

    -- Nessuno dimenticato: chi e'' iscritto o ha una sistemazione, o ha scelto di non
    -- averne. Restare senza per distrazione e'' il modo in cui, sui PIRENEI, undici
    -- persone su dodici non hanno nulla di registrato.
    RETURN QUERY
    SELECT 'AVVISO'::VARCHAR, 'PARTECIPANTE_SENZA_SISTEMAZIONE'::VARCHAR,
           format('%s non ha una sistemazione indicata.',
                  c.cliente_cognome || ' ' || c.cliente_nome)::TEXT
    FROM mov_clienti_viaggi m
    JOIN ana_clienti c ON c.cliente_id = m.cliente_id_fk
    WHERE m.data_viaggio_id_fk = p_data_viaggio_id
      AND NOT (m.cliente_id_fk = ANY (v_tutti));
END;
$$;

COMMENT ON FUNCTION fn_alloggi_assegnazione_valida(INTEGER, JSONB) IS
'Verifica un''assegnazione completa: tipi ammessi dal viaggio, capienza rispettata, nessuno
ripetuto, nessuno dimenticato. La chiamano il sito e il gestionale — una regola sola, due
interfacce.';
