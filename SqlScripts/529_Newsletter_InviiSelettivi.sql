-- Invii selettivi: a chi spedire la newsletter.
--
-- Fino a oggi si spediva "a tutti quelli che ne hanno diritto". Serve poter restringere: chi e'
-- entrato in anagrafica da una certa data, chi ha partecipato a una certa partenza, chi risiede
-- in una certa nazione, chi nell'anno X non ha viaggiato.
--
-- TRE REGOLE, che valgono per tutto quello che c'e' qui sotto.
--
-- 1) I filtri RESTRINGONO, non sostituiscono. Consenso, disiscrizioni e soppressioni restano
--    invalicabili: nessun filtro puo' far arrivare una mail a chi si e' cancellato. Per questo i
--    filtri si applicano DENTRO la CTE dei clienti e non a valle del risultato.
--
-- 2) I criteri sono ANAGRAFICI, quindi riguardano solo i clienti. Gli iscritti dal sito
--    (web_newsletter_iscritti) hanno solo email, nome e lingua: non hanno una data di ingresso in
--    anagrafica, ne' una residenza, ne' dei viaggi. Attivando un filtro restano automaticamente
--    fuori — non e' un difetto, e' conseguenza del non avere quei dati. Chi vuole includerli
--    comunque lo dichiara con web_newsletter_invii.includi_iscritti_web.
--
-- 3) Il filtro usato resta ATTACCATO alla newsletter. Una newsletter spedita e' la prova di cosa
--    e' stato mandato e a chi: finche' si spediva "a tutti" il "a chi" era ricostruibile, con i
--    filtri non lo e' piu'. Per questo ogni criterio porta con se' una descrizione in chiaro,
--    congelata al momento in cui viene aggiunto: fra un anno la partenza citata potrebbe non
--    esistere piu', ma la frase resta leggibile.

-- =====================================================================
-- 1) I criteri
-- =====================================================================
CREATE TABLE IF NOT EXISTS web_newsletter_filtri (
    web_newsletter_filtri_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invio_id_fk              BIGINT      NOT NULL REFERENCES web_newsletter_invii(web_newsletter_invii_id) ON DELETE CASCADE,
    criterio                 VARCHAR(30) NOT NULL,
    param_data               DATE,
    param_int                INTEGER,
    -- Descrizione in chiaro, congelata: e' quella che si legge nell'archivio di cio' che e' stato
    -- spedito, e non deve dipendere da dati che nel frattempo possono sparire.
    descrizione              VARCHAR(200) NOT NULL,
    azienda_id               INTEGER     NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by               VARCHAR(50) NOT NULL DEFAULT current_user,
    created                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE web_newsletter_filtri DROP CONSTRAINT IF EXISTS chk_web_newsletter_filtri_criterio;
ALTER TABLE web_newsletter_filtri
    ADD CONSTRAINT chk_web_newsletter_filtri_criterio CHECK (criterio IN (
        'cliente_dal',           -- param_data: in anagrafica da quella data compresa
        'iscritti_da_partenza',  -- param_int: data_viaggio_id, partenza compresa
        'iscritti_a_partenza',   -- param_int: data_viaggio_id
        'residenza_estero',      -- nessun parametro
        'residenza_nazione',     -- param_int: eba_countries.country_id
        'mai_viaggiato_anno'     -- param_int: anno
    ));

CREATE INDEX IF NOT EXISTS idx_web_newsletter_filtri_invio ON web_newsletter_filtri(invio_id_fk);

ALTER TABLE web_newsletter_invii
    ADD COLUMN IF NOT EXISTS includi_iscritti_web BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN web_newsletter_invii.includi_iscritti_web IS
'Con un filtro attivo, includere comunque gli iscritti dal sito (che non hanno anagrafica e nessun filtro puo'' valutare). Senza filtri non ha effetto: gli iscritti ci sono sempre.';

-- =====================================================================
-- 2) Nazioni disponibili per il filtro
-- =====================================================================
-- Solo quelle in cui risiede almeno un cliente dell'azienda: proporne 249 vuote sarebbe rumore.
-- L'Italia esce per prima perche' e' il caso normale, le altre in ordine alfabetico italiano.
CREATE OR REPLACE FUNCTION fn_web_nazioni_clienti(p_azienda_id INTEGER)
RETURNS TABLE(country_id INTEGER, nome VARCHAR, estero BOOLEAN, clienti BIGINT)
LANGUAGE sql STABLE AS $$
    SELECT n.country_id,
           COALESCE(n.name_it, n.name)::VARCHAR AS nome,
           (co.comune_estero = 'Y')             AS estero,
           count(*)                             AS clienti
      FROM ana_clienti cl
      JOIN ana_geo_comuni      co ON co.comune_id   = cl.cliente_comune_residenza_fk
      JOIN ana_geo_province    p  ON p.provincia_id = co.comune_provincia_fk
      JOIN ana_geo_regioni_ita r  ON r.regione_id   = p.regione_id_fk
      JOIN eba_countries       n  ON n.country_id   = r.country_id_fk
     WHERE cl.azienda_fk = p_azienda_id
     GROUP BY n.country_id, COALESCE(n.name_it, n.name), (co.comune_estero = 'Y')
     ORDER BY (co.comune_estero = 'Y'), COALESCE(n.name_it, n.name);
$$;

-- =====================================================================
-- 3) CRUD dei criteri
-- =====================================================================
-- La descrizione la compone la function e non il programma: e' il testo che finisce
-- nell'archivio di cio' che e' stato spedito, e deve essere lo stesso da qualunque punto si
-- aggiunga un criterio.
CREATE OR REPLACE FUNCTION fn_web_newsletter_filtri_insert(
    p_azienda_id INTEGER, p_invio_id BIGINT, p_criterio VARCHAR,
    p_param_data DATE DEFAULT NULL, p_param_int INTEGER DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT; v_descr VARCHAR(200); v_tmp TEXT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM web_newsletter_invii
                    WHERE web_newsletter_invii_id = p_invio_id AND azienda_id = p_azienda_id) THEN
        RAISE EXCEPTION 'Newsletter non trovata per questa azienda.';
    END IF;

    IF EXISTS (SELECT 1 FROM web_newsletter_invii
                WHERE web_newsletter_invii_id = p_invio_id AND stato <> 'bozza') THEN
        RAISE EXCEPTION 'I destinatari di una newsletter già spedita non si cambiano.';
    END IF;

    CASE p_criterio
        WHEN 'cliente_dal' THEN
            IF p_param_data IS NULL THEN RAISE EXCEPTION 'Serve una data.'; END IF;
            v_descr := 'Clienti in anagrafica dal ' || to_char(p_param_data, 'DD/MM/YYYY');

        WHEN 'iscritti_da_partenza' THEN
            SELECT v.viaggio_descrizione_breve || ' del ' || to_char(d.data_viaggio_data_inizio, 'DD/MM/YYYY')
              INTO v_tmp
              FROM ana_date_viaggi d JOIN ana_viaggi v ON v.viaggio_id = d.viaggio_id_fk
             WHERE d.data_viaggio_id = p_param_int AND d.azienda_id = p_azienda_id;
            IF v_tmp IS NULL THEN RAISE EXCEPTION 'Partenza non trovata per questa azienda.'; END IF;
            v_descr := 'Clienti iscritti a partenze dal ' || v_tmp || ' in poi (compresa)';

        WHEN 'iscritti_a_partenza' THEN
            SELECT v.viaggio_descrizione_breve || ' del ' || to_char(d.data_viaggio_data_inizio, 'DD/MM/YYYY')
              INTO v_tmp
              FROM ana_date_viaggi d JOIN ana_viaggi v ON v.viaggio_id = d.viaggio_id_fk
             WHERE d.data_viaggio_id = p_param_int AND d.azienda_id = p_azienda_id;
            IF v_tmp IS NULL THEN RAISE EXCEPTION 'Partenza non trovata per questa azienda.'; END IF;
            v_descr := 'Clienti iscritti a ' || v_tmp;

        WHEN 'residenza_estero' THEN
            v_descr := 'Clienti residenti all''estero';

        WHEN 'residenza_nazione' THEN
            SELECT COALESCE(n.name_it, n.name) INTO v_tmp
              FROM eba_countries n WHERE n.country_id = p_param_int;
            IF v_tmp IS NULL THEN RAISE EXCEPTION 'Nazione non trovata.'; END IF;
            v_descr := 'Clienti residenti in ' || v_tmp;

        WHEN 'mai_viaggiato_anno' THEN
            IF p_param_int IS NULL THEN RAISE EXCEPTION 'Serve un anno.'; END IF;
            v_descr := 'Clienti che nel ' || p_param_int || ' non hanno viaggiato';

        ELSE
            RAISE EXCEPTION 'Criterio "%" non riconosciuto.', p_criterio;
    END CASE;

    INSERT INTO web_newsletter_filtri(invio_id_fk, criterio, param_data, param_int, descrizione, azienda_id)
    VALUES (p_invio_id, p_criterio, p_param_data, p_param_int, v_descr, p_azienda_id)
    RETURNING web_newsletter_filtri_id INTO v_id;

    RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION fn_web_newsletter_filtri_delete(p_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    IF EXISTS (SELECT 1 FROM web_newsletter_filtri f
                 JOIN web_newsletter_invii i ON i.web_newsletter_invii_id = f.invio_id_fk
                WHERE f.web_newsletter_filtri_id = p_id AND i.stato <> 'bozza') THEN
        RAISE EXCEPTION 'I destinatari di una newsletter già spedita non si cambiano.';
    END IF;

    DELETE FROM web_newsletter_filtri
     WHERE web_newsletter_filtri_id = p_id AND azienda_id = p_azienda_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

CREATE OR REPLACE FUNCTION fn_web_newsletter_filtri_list(p_invio_id BIGINT, p_azienda_id INTEGER)
RETURNS TABLE(id BIGINT, criterio VARCHAR, descrizione VARCHAR, param_data DATE, param_int INTEGER)
LANGUAGE sql STABLE AS $$
    SELECT web_newsletter_filtri_id, criterio, descrizione, param_data, param_int
      FROM web_newsletter_filtri
     WHERE invio_id_fk = p_invio_id AND azienda_id = p_azienda_id
     ORDER BY web_newsletter_filtri_id;
$$;

-- =====================================================================
-- 4) I destinatari, con i filtri
-- =====================================================================
-- La firma a un solo parametro va rimossa ESPLICITAMENTE: CREATE OR REPLACE non sostituisce una
-- function quando cambia il numero di parametri, e le chiamate a un argomento diventerebbero
-- ambigue fra le due versioni (vedi script 524).
DROP FUNCTION IF EXISTS fn_web_destinatari_newsletter(integer);

CREATE OR REPLACE FUNCTION fn_web_destinatari_newsletter(
    p_azienda_id INTEGER, p_invio_id BIGINT DEFAULT NULL)
RETURNS TABLE(
    email CITEXT, nome VARCHAR, cognome VARCHAR, lingua CHAR(2), fonte VARCHAR,
    cliente_id INTEGER, iscritto_id BIGINT, token_disiscrizione VARCHAR, telefono VARCHAR)
LANGUAGE sql STABLE AS $$
    WITH filtri AS (
        SELECT f.criterio, f.param_data, f.param_int
          FROM web_newsletter_filtri f
         WHERE p_invio_id IS NOT NULL
           AND f.invio_id_fk = p_invio_id
           AND f.azienda_id  = p_azienda_id
    ),
    -- Gli iscritti dal sito non hanno anagrafica: nessun criterio puo' valutarli. Con un filtro
    -- attivo restano fuori, a meno che l'utente non li richieda esplicitamente.
    ammetti_iscritti AS (
        SELECT NOT EXISTS (SELECT 1 FROM filtri)
               OR COALESCE((SELECT i.includi_iscritti_web FROM web_newsletter_invii i
                             WHERE i.web_newsletter_invii_id = p_invio_id), false) AS si
    ),
    clienti AS (
        SELECT DISTINCT ON (TRIM(cl.cliente_email)::CITEXT)
               TRIM(cl.cliente_email)::CITEXT AS email,
               cl.cliente_nome, cl.cliente_cognome, cl.cliente_id,
               cl.cliente_lingua, cl.cliente_comune_residenza_fk,
               NULLIF(BTRIM(CONCAT_WS(' ',
                   NULLIF(BTRIM(cl.cliente_preftelint), ''),
                   NULLIF(BTRIM(cl.cliente_telefono), ''))), '') AS telefono
          FROM ana_clienti cl
         WHERE cl.azienda_fk = p_azienda_id
           AND cl.consenso_marketing = true
           AND NULLIF(TRIM(cl.cliente_email), '') IS NOT NULL
           -- Un cliente passa se non c'e' NESSUN criterio che non soddisfa. Scritto cosi' i
           -- criteri si sommano in AND senza costruire SQL dinamico.
           AND NOT EXISTS (
               SELECT 1 FROM filtri f
                WHERE NOT CASE f.criterio

                    WHEN 'cliente_dal' THEN
                        cl.created >= f.param_data

                    WHEN 'iscritti_a_partenza' THEN
                        EXISTS (SELECT 1 FROM mov_clienti_viaggi m
                                 WHERE m.cliente_id_fk = cl.cliente_id
                                   AND m.data_viaggio_id_fk = f.param_int)

                    WHEN 'iscritti_da_partenza' THEN
                        EXISTS (SELECT 1
                                  FROM mov_clienti_viaggi m
                                  JOIN ana_date_viaggi d ON d.data_viaggio_id = m.data_viaggio_id_fk
                                 WHERE m.cliente_id_fk = cl.cliente_id
                                   AND d.data_viaggio_data_inizio >=
                                       (SELECT dv.data_viaggio_data_inizio FROM ana_date_viaggi dv
                                         WHERE dv.data_viaggio_id = f.param_int))

                    WHEN 'residenza_estero' THEN
                        EXISTS (SELECT 1 FROM ana_geo_comuni co
                                 WHERE co.comune_id = cl.cliente_comune_residenza_fk
                                   AND co.comune_estero = 'Y')

                    WHEN 'residenza_nazione' THEN
                        EXISTS (SELECT 1
                                  FROM ana_geo_comuni      co
                                  JOIN ana_geo_province    p ON p.provincia_id = co.comune_provincia_fk
                                  JOIN ana_geo_regioni_ita r ON r.regione_id   = p.regione_id_fk
                                 WHERE co.comune_id = cl.cliente_comune_residenza_fk
                                   AND r.country_id_fk = f.param_int)

                    WHEN 'mai_viaggiato_anno' THEN
                        NOT EXISTS (SELECT 1
                                      FROM mov_clienti_viaggi m
                                      JOIN ana_date_viaggi d ON d.data_viaggio_id = m.data_viaggio_id_fk
                                     WHERE m.cliente_id_fk = cl.cliente_id
                                       AND EXTRACT(YEAR FROM d.data_viaggio_data_inizio) = f.param_int)

                    ELSE true
                END)
         ORDER BY TRIM(cl.cliente_email)::CITEXT, cl.cliente_id
    ),
    iscritti AS (
        SELECT i.email, i.nome, i.cognome, i.lingua,
               i.web_newsletter_iscritti_id, i.token_disiscrizione
          FROM web_newsletter_iscritti i
         WHERE i.azienda_id = p_azienda_id
           AND i.stato = 'attivo'
           AND i.consenso = true
           AND (SELECT si FROM ammetti_iscritti)
    )
    SELECT COALESCE(i.email, c.email)                       AS email,
           COALESCE(i.nome, c.cliente_nome)::VARCHAR        AS nome,
           COALESCE(i.cognome, c.cliente_cognome)::VARCHAR  AS cognome,
           COALESCE(i.lingua, c.cliente_lingua, fn_lingua_da_comune(c.cliente_comune_residenza_fk), 'IT')::CHAR(2) AS lingua,
           CASE WHEN i.email IS NOT NULL AND c.email IS NOT NULL THEN 'entrambi'
                WHEN i.email IS NOT NULL THEN 'iscritto'
                ELSE 'cliente' END::VARCHAR                 AS fonte,
           c.cliente_id,
           i.web_newsletter_iscritti_id                     AS iscritto_id,
           i.token_disiscrizione,
           c.telefono::VARCHAR
      FROM clienti c
      FULL JOIN iscritti i ON i.email = c.email
     WHERE NOT EXISTS (
           SELECT 1 FROM web_newsletter_soppressioni s
            WHERE s.azienda_id = p_azienda_id
              AND s.email = COALESCE(i.email, c.email))
     ORDER BY 1;
$$;

-- =====================================================================
-- 5) Conteggio spaccato, per la scelta a video
-- =====================================================================
-- Un totale secco non basta: con un filtro attivo l'utente deve vedere quanti iscritti dal sito
-- sta lasciando fuori, altrimenti l'esclusione avviene in silenzio.
CREATE OR REPLACE FUNCTION fn_web_newsletter_conteggio(p_azienda_id INTEGER, p_invio_id BIGINT DEFAULT NULL)
RETURNS TABLE(destinatari BIGINT, clienti BIGINT, iscritti BIGINT, iscritti_esclusi BIGINT)
LANGUAGE sql STABLE AS $$
    SELECT count(*)                                                   AS destinatari,
           count(*) FILTER (WHERE d.fonte IN ('cliente', 'entrambi')) AS clienti,
           count(*) FILTER (WHERE d.fonte = 'iscritto')               AS iscritti,
           (SELECT count(*) FROM fn_web_destinatari_newsletter(p_azienda_id) t
             WHERE t.fonte = 'iscritto')
             - count(*) FILTER (WHERE d.fonte = 'iscritto')           AS iscritti_esclusi
      FROM fn_web_destinatari_newsletter(p_azienda_id, p_invio_id) d;
$$;

DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT proname, count(*) AS v FROM pg_proc
              WHERE proname IN ('fn_web_destinatari_newsletter','fn_web_newsletter_conteggio')
              GROUP BY proname
    LOOP
        RAISE NOTICE '% -> % versione/i', r.proname, r.v;
        IF r.v > 1 THEN
            RAISE EXCEPTION 'La function % ha % firme sovrapposte.', r.proname, r.v;
        END IF;
    END LOOP;
END $$;
