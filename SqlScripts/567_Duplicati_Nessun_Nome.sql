-- =============================================================================
-- 567 — Nessuna segnalazione nomina piu' nessuno
-- =============================================================================
--
-- Deciso il 2026-09-01, subito dopo il 566. Li' si era tolto il nome dalle due
-- segnalazioni che rivelavano un cliente altrui (stesso codice fiscale, stessa
-- email), lasciandolo dove il nome era gia' sullo schermo perche' l'aveva appena
-- digitato l'utente. La scelta ora e' piu' netta e piu' semplice da ricordare:
-- **non si fanno mai nomi**, in nessuna segnalazione.
--
-- Il messaggio dice cosa e' successo — esiste gia' una scheda con questi dati,
-- oppure con lo stesso cognome e nome — e tanto basta per fermarsi e cercare.
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
           'Esiste già un cliente con questi stessi dati anagrafici.'::TEXT,
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
           'Esiste già un cliente con lo stesso cognome e nome. Controlla che non sia la stessa persona.'::TEXT,
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
           'Esiste già un cliente con questi stessi dati anagrafici.'::TEXT,
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
           'Esiste già un cliente con lo stesso cognome e nome. Controlla che non sia la stessa persona.'::TEXT,
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
