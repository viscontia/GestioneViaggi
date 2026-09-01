-- =============================================================================
-- 566 — Il duplicato si segnala senza dire di chi e'
-- =============================================================================
--
-- Deciso il 2026-09-01. Chi digita un codice fiscale o un'email si vedeva
-- rispondere con il **nome e cognome** dell'altro cliente che li possiede: un
-- dato che non aveva digitato lui e che non gli serve per correggere il proprio
-- inserimento. Bastava provare codici a caso per farsi dire chi c'e' in
-- anagrafica.
--
-- Restano con il nome le due segnalazioni in cui il nome e' **quello appena
-- digitato dall'utente** — stessi dati anagrafici, e omonimo — perche' li' non
-- si rivela niente che non fosse gia' sullo schermo, e toglierlo renderebbe il
-- messaggio incomprensibile.
--
-- Al posto del nome, il codice fiscale dice **come trovarla**, quella scheda:
-- cercandola per codice fiscale. Chi ne ha diritto la raggiunge lo stesso.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_ana_clienti_verifica_duplicato(p_azienda_id integer, p_cognome character varying, p_nome character varying, p_data_nascita date DEFAULT NULL::date, p_comune_nascita_id integer DEFAULT NULL::integer, p_cf character varying DEFAULT NULL::character varying, p_escludi_cliente_id integer DEFAULT NULL::integer)
 RETURNS TABLE(gravita character varying, esito character varying, messaggio text, cliente_id integer)
 LANGUAGE sql
 STABLE
AS $function$
    SELECT r.gravita, r.esito, r.messaggio, r.cliente_id FROM (
    WITH candidati AS (
        SELECT c.cliente_id, c.cliente_cognome, c.cliente_nome, c.cliente_data_nascita,
               c.cliente_comune_nascita_fk, upper(btrim(c.cliente_codicefiscale)) AS cf
        FROM ana_clienti c
        WHERE c.azienda_fk = p_azienda_id
          AND (p_escludi_cliente_id IS NULL OR c.cliente_id <> p_escludi_cliente_id)
    )
    -- 1. Stesso codice fiscale: e' la stessa persona, senza discussione.
    SELECT 'ERRORE'::VARCHAR, 'STESSO_CF'::VARCHAR,
           'Questo codice fiscale è già registrato su un altro cliente. Cercalo in anagrafica per codice fiscale.'::TEXT,
           k.cliente_id
    FROM candidati k
    WHERE btrim(COALESCE(p_cf,'')) <> ''
      AND k.cf = upper(btrim(p_cf))

    UNION ALL
    -- 2. Stessa anagrafica completa. L'omonimia esiste, ma non alla stessa data
    --    E nello stesso comune di nascita.
    SELECT 'ERRORE'::VARCHAR, 'STESSA_ANAGRAFICA'::VARCHAR,
           format('Esiste già un cliente con gli stessi dati anagrafici: %s %s, nato il %s.',
                  k.cliente_cognome, k.cliente_nome, to_char(k.cliente_data_nascita, 'DD/MM/YYYY'))::TEXT,
           k.cliente_id
    FROM candidati k
    WHERE p_data_nascita IS NOT NULL
      AND p_comune_nascita_id IS NOT NULL
      AND k.cliente_data_nascita = p_data_nascita
      AND k.cliente_comune_nascita_fk = p_comune_nascita_id
      AND upper(btrim(k.cliente_cognome)) = upper(btrim(p_cognome))
      AND upper(btrim(k.cliente_nome))    = upper(btrim(p_nome))
      -- se il codice fiscale li ha gia' dichiarati la stessa persona, non si ripete
      AND (btrim(COALESCE(p_cf,'')) = '' OR k.cf IS DISTINCT FROM upper(btrim(p_cf)))

    UNION ALL
    -- 3. Solo cognome e nome: gli omonimi esistono davvero, quindi si avvisa.
    SELECT 'AVVISO'::VARCHAR, 'OMONIMO'::VARCHAR,
           format('Esiste già un cliente che si chiama %s %s%s. Controlla che non sia la stessa persona.',
                  k.cliente_cognome, k.cliente_nome,
                  CASE WHEN k.cliente_data_nascita IS NOT NULL
                       THEN ', nato il ' || to_char(k.cliente_data_nascita, 'DD/MM/YYYY') ELSE '' END)::TEXT,
           k.cliente_id
    FROM candidati k
    WHERE upper(btrim(k.cliente_cognome)) = upper(btrim(p_cognome))
      AND upper(btrim(k.cliente_nome))    = upper(btrim(p_nome))
      -- non si ripete cio' che i due livelli sopra hanno gia' detto
      AND (btrim(COALESCE(p_cf,'')) = '' OR k.cf IS DISTINCT FROM upper(btrim(p_cf)))
      AND NOT (p_data_nascita IS NOT NULL AND p_comune_nascita_id IS NOT NULL
               AND k.cliente_data_nascita = p_data_nascita
               AND k.cliente_comune_nascita_fk = p_comune_nascita_id)

    ) AS r(gravita, esito, messaggio, cliente_id)
    -- Il piu' grave per primo: chi chiama legge la prima riga. In ordine
    -- alfabetico AVVISO verrebbe prima di ERRORE, cioe' l'opposto di cio' che serve.
    ORDER BY CASE WHEN r.gravita = 'ERRORE' THEN 1 ELSE 2 END, r.cliente_id;
$function$;

CREATE OR REPLACE FUNCTION public.fn_ana_clienti_verifica_duplicato(p_azienda_id integer, p_cognome character varying, p_nome character varying, p_data_nascita date DEFAULT NULL::date, p_comune_nascita_id integer DEFAULT NULL::integer, p_cf character varying DEFAULT NULL::character varying, p_escludi_cliente_id integer DEFAULT NULL::integer, p_email character varying DEFAULT NULL::character varying)
 RETURNS TABLE(gravita character varying, esito character varying, messaggio text, cliente_id integer)
 LANGUAGE sql
 STABLE
AS $function$
    SELECT r.gravita, r.esito, r.messaggio, r.cliente_id FROM (
    WITH candidati AS (
        SELECT c.cliente_id, c.cliente_cognome, c.cliente_nome, c.cliente_data_nascita,
               c.cliente_comune_nascita_fk, upper(btrim(c.cliente_codicefiscale)) AS cf,
               lower(btrim(c.cliente_email)) AS email
        FROM ana_clienti c
        WHERE c.azienda_fk = p_azienda_id
          AND (p_escludi_cliente_id IS NULL OR c.cliente_id <> p_escludi_cliente_id)
    )
    SELECT 'ERRORE'::VARCHAR, 'STESSO_CF'::VARCHAR,
           'Questo codice fiscale è già registrato su un altro cliente. Cercalo in anagrafica per codice fiscale.'::TEXT, k.cliente_id
    FROM candidati k
    WHERE btrim(COALESCE(p_cf,'')) <> '' AND k.cf = upper(btrim(p_cf))

    UNION ALL
    SELECT 'ERRORE'::VARCHAR, 'STESSA_ANAGRAFICA'::VARCHAR,
           format('Esiste già un cliente con gli stessi dati anagrafici: %s %s, nato il %s.',
                  k.cliente_cognome, k.cliente_nome, to_char(k.cliente_data_nascita, 'DD/MM/YYYY'))::TEXT,
           k.cliente_id
    FROM candidati k
    WHERE p_data_nascita IS NOT NULL AND p_comune_nascita_id IS NOT NULL
      AND k.cliente_data_nascita = p_data_nascita
      AND k.cliente_comune_nascita_fk = p_comune_nascita_id
      AND upper(btrim(k.cliente_cognome)) = upper(btrim(p_cognome))
      AND upper(btrim(k.cliente_nome))    = upper(btrim(p_nome))
      AND (btrim(COALESCE(p_cf,'')) = '' OR k.cf IS DISTINCT FROM upper(btrim(p_cf)))

    UNION ALL
    SELECT 'AVVISO'::VARCHAR, 'OMONIMO'::VARCHAR,
           format('Esiste già un cliente che si chiama %s %s%s. Controlla che non sia la stessa persona.',
                  k.cliente_cognome, k.cliente_nome,
                  CASE WHEN k.cliente_data_nascita IS NOT NULL
                       THEN ', nato il ' || to_char(k.cliente_data_nascita, 'DD/MM/YYYY') ELSE '' END)::TEXT,
           k.cliente_id
    FROM candidati k
    WHERE upper(btrim(k.cliente_cognome)) = upper(btrim(p_cognome))
      AND upper(btrim(k.cliente_nome))    = upper(btrim(p_nome))
      AND (btrim(COALESCE(p_cf,'')) = '' OR k.cf IS DISTINCT FROM upper(btrim(p_cf)))
      AND NOT (p_data_nascita IS NOT NULL AND p_comune_nascita_id IS NOT NULL
               AND k.cliente_data_nascita = p_data_nascita
               AND k.cliente_comune_nascita_fk = p_comune_nascita_id)

    UNION ALL
    -- 4. Stessa email. AVVISO e non vincolo: condividere la casella e' prassi
    --    legittima — marito e moglie, o chi non lascia il proprio indirizzo e usa
    --    quello del compagno di viaggio. Serve a intercettare la scheda duplicata
    --    per errore, non a vietare la coppia.
    SELECT 'AVVISO'::VARCHAR, 'STESSA_EMAIL'::VARCHAR,
           'Questo indirizzo email è già usato da un altro cliente. Verifica che non sia la stessa persona.'::TEXT, k.cliente_id
    FROM candidati k
    WHERE btrim(COALESCE(p_email,'')) <> ''
      AND k.email = lower(btrim(p_email))
      AND (btrim(COALESCE(p_cf,'')) = '' OR k.cf IS DISTINCT FROM upper(btrim(p_cf)))
    ) AS r(gravita, esito, messaggio, cliente_id)
    ORDER BY CASE WHEN r.gravita = 'ERRORE' THEN 1 ELSE 2 END, r.cliente_id;
$function$;
