-- ============================================================================
-- Test dello script 666: in camera solo chi e' iscritto alla partenza
--
-- Gira tutto dentro una transazione che si annulla. Prende una camera vera
-- (la prima con un solo occupante) e prova:
--   1. a risalvarla com'e'                         → riesce (nessuna regressione);
--   2. a metterci chi non e' iscritto a quella partenza → errore, nulla cambia;
--   3. a metterci un cliente di un'altra azienda   → errore.
-- Ogni caso stampa OK o solleva un errore che ferma lo script.
-- ============================================================================

BEGIN;

DO $$
DECLARE
    a        RECORD;
    v_estr   INTEGER;
    v_altra  INTEGER;
    v_prima  TEXT;
BEGIN
    SELECT x.mov_clienti_alloggio_pk AS pk, x.viaggio_id_fk AS viaggio,
           x.data_viaggio_id_fk AS partenza, x.tipo_alloggio_id_fk AS tipo,
           x.cliente_id1_fk AS cliente, v.azienda_id AS azienda
      INTO a
      FROM mov_clienti_alloggi x
      JOIN ana_tipo_alloggio t ON t.tipo_alloggio_id = x.tipo_alloggio_id_fk
      JOIN ana_viaggi v        ON v.viaggio_id = x.viaggio_id_fk
     WHERE t.tipo_alloggio_numero_occupanti = 1 AND x.cliente_id1_fk IS NOT NULL
     ORDER BY x.mov_clienti_alloggio_pk LIMIT 1;
    IF a.pk IS NULL THEN RAISE EXCEPTION 'Nessuna camera singola su cui provare'; END IF;

    -- 1. Risalvarla com'e'
    PERFORM fn_alloggi_salva_camera(a.pk, a.viaggio, a.partenza, a.tipo, ARRAY[a.cliente]);
    RAISE NOTICE 'OK 1: la camera esistente si risalva';

    -- 2. Un cliente della stessa azienda NON iscritto a quella partenza
    SELECT k.cliente_id INTO v_estr FROM ana_clienti k
     WHERE k.azienda_fk = a.azienda
       AND NOT EXISTS (SELECT 1 FROM mov_clienti_viaggi m
                        WHERE m.data_viaggio_id_fk = a.partenza AND m.cliente_id_fk = k.cliente_id)
     LIMIT 1;
    SELECT md5(string_agg(x::text, ',' ORDER BY x.mov_clienti_alloggio_pk)) INTO v_prima
      FROM mov_clienti_alloggi x WHERE x.data_viaggio_id_fk = a.partenza;
    BEGIN
        PERFORM fn_alloggi_salva_camera(a.pk, a.viaggio, a.partenza, a.tipo, ARRAY[v_estr]);
        RAISE EXCEPTION 'KO 2: accettato un cliente non iscritto (%)', v_estr;
    EXCEPTION WHEN check_violation THEN
        IF SQLERRM NOT LIKE 'In una sistemazione possono stare solo persone iscritte%' THEN
            RAISE EXCEPTION 'KO 2: errore inatteso: %', SQLERRM;
        END IF;
    END;
    IF v_prima IS DISTINCT FROM (SELECT md5(string_agg(x::text, ',' ORDER BY x.mov_clienti_alloggio_pk))
                                   FROM mov_clienti_alloggi x WHERE x.data_viaggio_id_fk = a.partenza) THEN
        RAISE EXCEPTION 'KO 2: le camere della partenza sono cambiate';
    END IF;
    RAISE NOTICE 'OK 2: chi non e'' iscritto non entra, e nulla cambia';

    -- 3. Un cliente di un'altra azienda
    SELECT k.cliente_id INTO v_altra FROM ana_clienti k WHERE k.azienda_fk <> a.azienda LIMIT 1;
    BEGIN
        PERFORM fn_alloggi_salva_camera(0, a.viaggio, a.partenza, a.tipo, ARRAY[v_altra]);
        RAISE EXCEPTION 'KO 3: accettato un cliente di un''altra azienda (%)', v_altra;
    EXCEPTION WHEN check_violation THEN
        IF SQLERRM NOT LIKE 'In una sistemazione possono stare solo persone iscritte%' THEN
            RAISE EXCEPTION 'KO 3: errore inatteso: %', SQLERRM;
        END IF;
    END;
    RAISE NOTICE 'OK 3: un cliente di un''altra azienda non entra';
END $$;

ROLLBACK;
