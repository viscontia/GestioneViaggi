-- fn_web_destinatari_newsletter espone anche il telefono del destinatario.
--
-- Serve all'anteprima dell'elenco destinatari (chip "Destinatari: N" cliccabile nella pagina
-- Newsletter): prima di spedire, l'operatore vuole vedere CHI riceve, e il telefono e' il dato
-- che gli permette di riconoscere una persona quando nome e cognome non bastano.
--
-- Il telefono esiste solo per i CLIENTI (ana_clienti.cliente_preftelint + cliente_telefono):
-- gli iscritti dal sito lasciano solo l'email, quindi per fonte='iscritto' resta NULL.
-- Concatenazione prefisso+numero fatta qui perche' e' presentazione dello stesso dato.
--
-- Colonna aggiunta IN CODA al RETURNS TABLE: i consumer esistenti che selezionano per nome
-- (NewsletterSenderService legge email/nome/cognome/lingua) non si accorgono del cambio.

DROP FUNCTION IF EXISTS fn_web_destinatari_newsletter(INTEGER);

CREATE OR REPLACE FUNCTION fn_web_destinatari_newsletter(p_azienda_id INTEGER)
RETURNS TABLE(
    email               CITEXT,
    nome                VARCHAR,
    cognome             VARCHAR,
    lingua              CHAR(2),
    fonte               VARCHAR,
    cliente_id          INTEGER,
    iscritto_id         BIGINT,
    token_disiscrizione VARCHAR,
    telefono            VARCHAR
)
LANGUAGE sql STABLE AS $$
    WITH clienti AS (
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
