-- Il congelamento all'invio riguarda anche social e icona (segue 518, 519, 520).
--
-- Senza, un pulsante che prende social e icona dalla rubrica li perderebbe al momento dell'invio:
-- il rendering li risolve dalla rubrica solo finche' la newsletter e' bozza, e il congelamento
-- serve proprio a fissare nel blocco cio' che e' stato spedito.

CREATE OR REPLACE FUNCTION fn_web_newsletter_congela_indirizzi(p_invio_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE web_newsletter_blocchi b
       SET link_url  = i.url,
           social    = i.social,
           icona_url = i.icona_url
      FROM web_indirizzi i
     WHERE b.indirizzo_id_fk = i.web_indirizzi_id
       AND b.invio_id_fk = p_invio_id
       AND b.azienda_id  = p_azienda_id
       AND (b.link_url  IS DISTINCT FROM i.url
         OR b.social    IS DISTINCT FROM i.social
         OR b.icona_url IS DISTINCT FROM i.icona_url);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;
