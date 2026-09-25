-- ============================================================================
-- Test dello script 663: le letture del wizard restano dentro la propria azienda
--
-- Gira tutto dentro una transazione che si annulla. Per confrontare con «prima»
-- ricrea in pg_temp le tre funzioni com'erano (corpo copiato dal database prima
-- del 663): la versione nuova, sui clienti della propria azienda, deve dare
-- esattamente le stesse righe; su quelli di un'altra, nessuna.
-- Clienti: 3870 e 3664 sono dell'azienda 2, 1163 e 1129 dell'azienda 6.
-- ============================================================================

BEGIN;

CREATE FUNCTION pg_temp.vecchia_client_data(p_cliente_id integer)
 RETURNS TABLE(cliente_cognome character varying, cliente_nome character varying, cliente_data_nascita date, cliente_sesso character, comune_codfisc character varying, cliente_intolleranza text)
 LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT c.cliente_cognome, c.cliente_nome, c.cliente_data_nascita, c.cliente_sesso,
           g.comune_codfisc, c.cliente_intolleranza
    FROM ana_clienti c
    LEFT JOIN ana_geo_comuni g ON c.cliente_comune_nascita_fk = g.comune_id
    WHERE c.cliente_id = p_cliente_id;
END;
$$;

CREATE FUNCTION pg_temp.vecchia_partecipanti_details(p_ids integer[])
 RETURNS TABLE(cliente_id integer, cliente_cognome character varying, cliente_nome character varying, cliente_email character varying, cliente_data_nascita date, cliente_intolleranza text)
 LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT c.cliente_id, c.cliente_cognome, c.cliente_nome, c.cliente_email,
           c.cliente_data_nascita, c.cliente_intolleranza
    FROM ana_clienti c
    WHERE c.cliente_id = ANY(p_ids);
END;
$$;

CREATE FUNCTION pg_temp.vecchia_partecipanti(p_ids integer[])
 RETURNS TABLE(cliente_id integer, cliente_cognome character varying, cliente_nome character varying)
 LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT c.cliente_id, c.cliente_cognome, c.cliente_nome
    FROM ana_clienti c
    WHERE c.cliente_id = ANY(p_ids)
    ORDER BY c.cliente_cognome, c.cliente_nome;
END;
$$;

DO $$
DECLARE
    v_nostri  INTEGER[] := ARRAY[3870, 3664];
    v_altri   INTEGER[] := ARRAY[1163, 1129];
    v_misti   INTEGER[] := ARRAY[3870, 1163, 3664, 1129];
    v_n       INTEGER;
    v_ruolo   TEXT;
BEGIN
    -- 0. i dati di prova sono quelli che il test crede
    ASSERT (SELECT count(*) FROM ana_clienti WHERE cliente_id = ANY(v_nostri) AND azienda_fk = 2) = 2,
           'dati di prova: 3870 e 3664 non sono entrambi dell''azienda 2';
    ASSERT (SELECT count(*) FROM ana_clienti WHERE cliente_id = ANY(v_altri) AND azienda_fk = 6) = 2,
           'dati di prova: 1163 e 1129 non sono entrambi dell''azienda 6';

    -- 1. fn_wizard_get_client_data
    ASSERT NOT EXISTS (SELECT * FROM fn_wizard_get_client_data(1163, 2)),
           'client_data: restituito un cliente dell''azienda 6 al sito dell''azienda 2';
    ASSERT (SELECT count(*) FROM fn_wizard_get_client_data(3870, 2)) = 1,
           'client_data: il cliente della propria azienda non c''e''';
    ASSERT NOT EXISTS (
        (SELECT * FROM fn_wizard_get_client_data(3870, 2)
         EXCEPT ALL SELECT * FROM pg_temp.vecchia_client_data(3870))
        UNION ALL
        (SELECT * FROM pg_temp.vecchia_client_data(3870)
         EXCEPT ALL SELECT * FROM fn_wizard_get_client_data(3870, 2))),
           'client_data: righe diverse da prima';

    -- 2. fn_wizard_get_partecipanti_details
    ASSERT NOT EXISTS (SELECT * FROM fn_wizard_get_partecipanti_details(v_altri, 2)),
           'details: restituiti clienti dell''azienda 6 al sito dell''azienda 2';
    SELECT count(*) INTO v_n FROM fn_wizard_get_partecipanti_details(v_misti, 2);
    ASSERT v_n = 2, 'details: attesi 2 clienti della propria azienda, ottenuti ' || v_n;
    ASSERT NOT EXISTS (
        (SELECT * FROM fn_wizard_get_partecipanti_details(v_misti, 2)
         EXCEPT ALL SELECT * FROM pg_temp.vecchia_partecipanti_details(v_nostri))
        UNION ALL
        (SELECT * FROM pg_temp.vecchia_partecipanti_details(v_nostri)
         EXCEPT ALL SELECT * FROM fn_wizard_get_partecipanti_details(v_misti, 2))),
           'details: righe diverse da prima';

    -- 3. fn_wizard_get_partecipanti (qui conta anche l'ordine)
    ASSERT NOT EXISTS (SELECT * FROM fn_wizard_get_partecipanti(v_altri, 2)),
           'partecipanti: restituiti clienti dell''azienda 6 al sito dell''azienda 2';
    ASSERT (SELECT array_agg(p ORDER BY n) FROM (
                SELECT row(t.*)::text p, row_number() OVER () n FROM fn_wizard_get_partecipanti(v_misti, 2) t) x)
         = (SELECT array_agg(p ORDER BY n) FROM (
                SELECT row(t.*)::text p, row_number() OVER () n FROM pg_temp.vecchia_partecipanti(v_nostri) t) x),
           'partecipanti: righe o ordine diversi da prima';

    -- 4. dall'altra parte vale lo stesso: l'azienda 6 vede i suoi e non quelli della 2
    ASSERT (SELECT array_agg(cliente_id ORDER BY cliente_id) FROM fn_wizard_get_partecipanti_details(v_misti, 6))
         = ARRAY[1129, 1163], 'details: l''azienda 6 non vede esattamente i suoi';

    -- 5. la vecchia firma non c'e' piu': nessun chiamante puo' restare senza filtro
    ASSERT to_regprocedure('fn_wizard_get_client_data(integer)') IS NULL,
           'esiste ancora fn_wizard_get_client_data senza azienda';
    ASSERT to_regprocedure('fn_wizard_get_partecipanti_details(integer[])') IS NULL,
           'esiste ancora fn_wizard_get_partecipanti_details senza azienda';
    ASSERT to_regprocedure('fn_wizard_get_partecipanti(integer[])') IS NULL,
           'esiste ancora fn_wizard_get_partecipanti senza azienda';

    -- 6. chiuse ad anon e authenticated (dove esiste): script 659
    FOR v_ruolo IN SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated') LOOP
        ASSERT NOT has_function_privilege(v_ruolo, 'fn_wizard_get_client_data(integer,integer)', 'EXECUTE'),
               v_ruolo || ' puo'' eseguire fn_wizard_get_client_data';
        ASSERT NOT has_function_privilege(v_ruolo, 'fn_wizard_get_partecipanti_details(integer[],integer)', 'EXECUTE'),
               v_ruolo || ' puo'' eseguire fn_wizard_get_partecipanti_details';
        ASSERT NOT has_function_privilege(v_ruolo, 'fn_wizard_get_partecipanti(integer[],integer)', 'EXECUTE'),
               v_ruolo || ' puo'' eseguire fn_wizard_get_partecipanti';
    END LOOP;

    RAISE NOTICE 'Test 663: tutto OK';
END $$;
ROLLBACK;
