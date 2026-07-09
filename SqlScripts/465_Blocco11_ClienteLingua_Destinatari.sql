-- Blocco 11: lingua per-cliente (multilingua newsletter).

-- 1) Nuovo campo editabile: lingua preferita del cliente (default scritto da noi con regole geo).
ALTER TABLE ana_clienti ADD COLUMN IF NOT EXISTS cliente_lingua CHAR(2);

-- 2) Deriva la lingua dalla nazione di residenza (comune → provincia → regione → country → iso).
--    Comuni italiani → 'IT'; esteri → mappa iso→lingua; CH→DE; non coperti → 'EN' (internazionale).
CREATE OR REPLACE FUNCTION fn_lingua_da_comune(p_comune_id INTEGER)
RETURNS CHAR(2) LANGUAGE sql STABLE AS $$
    SELECT (CASE
        WHEN co.iso_alpha2 IS NULL THEN 'IT'
        WHEN upper(co.iso_alpha2) = 'IT' THEN 'IT'
        WHEN upper(co.iso_alpha2) IN ('DE','AT','CH') THEN 'DE'
        WHEN upper(co.iso_alpha2) IN ('FR','BE','LU','MC') THEN 'FR'
        WHEN upper(co.iso_alpha2) IN ('ES','AR','MX','CL','CO','PE','VE','UY') THEN 'ES'
        WHEN upper(co.iso_alpha2) IN ('GB','IE','US','AU','NZ','CA','ZA') THEN 'EN'
        ELSE 'EN'
    END)::CHAR(2)
    FROM ana_geo_comuni c
    LEFT JOIN ana_geo_province p    ON p.provincia_id = c.comune_provincia_fk
    LEFT JOIN ana_geo_regioni_ita r ON r.regione_id  = p.regione_id_fk
    LEFT JOIN eba_countries co      ON co.country_id = r.country_id_fk
    WHERE c.comune_id = p_comune_id;
$$;

-- 3) Backfill dei clienti esistenti (chi non ha già una lingua impostata).
UPDATE ana_clienti
   SET cliente_lingua = COALESCE(fn_lingua_da_comune(cliente_comune_residenza_fk), 'IT')
 WHERE cliente_lingua IS NULL;

-- 4) fn_web_destinatari_newsletter: lingua effettiva = iscritto.lingua ?? cliente_lingua ?? derivata ?? IT.
CREATE OR REPLACE FUNCTION fn_web_destinatari_newsletter(p_azienda_id integer)
 RETURNS TABLE(email citext, nome character varying, cognome character varying, lingua character, fonte character varying, cliente_id integer, iscritto_id bigint, token_disiscrizione character varying)
 LANGUAGE sql STABLE
AS $function$
    WITH clienti AS (
        SELECT DISTINCT ON (TRIM(cl.cliente_email)::CITEXT)
               TRIM(cl.cliente_email)::CITEXT AS email,
               cl.cliente_nome, cl.cliente_cognome, cl.cliente_id,
               cl.cliente_lingua, cl.cliente_comune_residenza_fk
          FROM ana_clienti cl
         WHERE cl.azienda_fk = p_azienda_id
           AND cl.consenso_marketing = true
           AND NULLIF(TRIM(cl.cliente_email), '') IS NOT NULL
         ORDER BY TRIM(cl.cliente_email)::CITEXT, cl.cliente_id
    ),
    iscritti AS (
        SELECT i.email, i.nome, i.cognome, i.lingua,
               i.web_newsletter_iscritti_id, i.token_disiscrizione
          FROM web_newsletter_iscritti i
         WHERE i.azienda_id = p_azienda_id
           AND i.stato = 'attivo'
           AND i.consenso = true
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
           i.token_disiscrizione
      FROM clienti c
      FULL JOIN iscritti i ON i.email = c.email
     WHERE NOT EXISTS (
           SELECT 1 FROM web_newsletter_soppressioni s
            WHERE s.azienda_id = p_azienda_id
              AND s.email = COALESCE(i.email, c.email))
     ORDER BY 1;
$function$;
