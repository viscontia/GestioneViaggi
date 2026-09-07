-- ============================================================================
-- 632 — «chi ha scritto questa riga» tornava sempre «postgres»
--
-- TROVATO collaudando il sito il 2026-09-07: completata un'iscrizione dal sito,
-- la CAMERA risultava creata da giordano.fiorendi@gmail.com ma l'ISCRIZIONE da
-- «postgres». Due scritture della stessa operazione, due autori diversi.
--
-- ⚠️ NON era un difetto del sito. Riprodotto in isolamento:
--     SELECT set_config('my.app_user', 'prova@esempio.it', true);
--     -> my.app_user vale: [prova@esempio.it]
--     -> created_by scritto: [postgres]
--
-- LA CAUSA. Su queste due tabelle ci sono DUE trigger BEFORE INSERT che scrivono
-- lo stesso campo, e vince quello sbagliato perche' viene prima in ordine
-- alfabetico:
--
--   mov_clienti_viaggi_trg1      -> legge 'jwt.claims.app_user'  ⛔️ nome VECCHIO
--   trg_mov_clienti_viaggi_audit -> legge 'my.app_user'          ✅ nome giusto
--
-- Il primo cerca una variabile che nessuno imposta piu', ripiega su current_user
-- (= l'utente di connessione, «postgres») e riempie il campo. Il secondo trova
-- created_by gia' valorizzato e per costruzione non lo tocca.
--
-- Per questo la camera «funzionava»: fn_alloggi_salva_camera riceve p_created_by
-- esplicito (script 619) e lo scrive lei, cosi' entrambi i trigger trovano il
-- campo pieno. Non era il trigger a funzionare: era il parametro a coprirlo.
--
-- Riguarda SOLO queste due tabelle: sulle altre — ana_clienti compresa — il
-- trigger vecchio non c'e', e infatti li' gli autori sono corretti.
--
-- COSA NON SI PERDE: il trigger di audit fa tutto quello che faceva il vecchio
-- (created_by, created) e in piu' gestisce l'UPDATE come si deve.
--
-- IN PIU': i due audit vengono irrobustiti con NULLIF. current_setting(...,true)
-- restituisce la stringa VUOTA quando la variabile e' impostata a '', e COALESCE
-- la considera un valore buono: si sarebbe scritto un autore vuoto invece di
-- ripiegare su current_user.
--
-- ⚠️ Non tocca le righe gia' scritte: i «postgres» storici restano.
-- Rigiocabile.
-- ============================================================================

BEGIN;

DROP TRIGGER IF EXISTS mov_clienti_viaggi_trg1  ON mov_clienti_viaggi;
DROP TRIGGER IF EXISTS mov_clienti_alloggi_trg1 ON mov_clienti_alloggi;
DROP FUNCTION IF EXISTS public.mov_clienti_viaggi_trg1_func();
DROP FUNCTION IF EXISTS public.mov_clienti_alloggi_trg1_func();

-- Gli audit, con il ripiego che funziona anche a variabile vuota.
CREATE OR REPLACE FUNCTION public.trg_mov_clienti_viaggi_audit()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.created_by IS NULL THEN
            NEW.created_by := COALESCE(NULLIF(current_setting('my.app_user', true), ''),
                                       current_user, 'system');
        END IF;
        IF NEW.created IS NULL THEN
            NEW.created := CURRENT_TIMESTAMP;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        NEW.updated := CURRENT_TIMESTAMP;
        NEW.updated_by := COALESCE(NULLIF(current_setting('my.app_user', true), ''),
                                   current_user, 'system');
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_mov_clienti_alloggi_audit()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.created_by IS NULL THEN
            NEW.created_by := COALESCE(NULLIF(current_setting('my.app_user', true), ''),
                                       current_user, 'system');
        END IF;
        IF NEW.created IS NULL THEN
            NEW.created := CURRENT_TIMESTAMP;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        NEW.updated := CURRENT_TIMESTAMP;
        NEW.updated_by := COALESCE(NULLIF(current_setting('my.app_user', true), ''),
                                   current_user, 'system');
    END IF;
    RETURN NEW;
END;
$$;

DO $verifica$
DECLARE v_vecchi INTEGER;
BEGIN
    SELECT count(*) INTO v_vecchi
    FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid
    WHERE NOT t.tgisinternal AND p.prosrc LIKE '%jwt.claims.app_user%';
    IF v_vecchi > 0 THEN
        RAISE EXCEPTION '632: restano % trigger che leggono la variabile vecchia.', v_vecchi;
    END IF;
    RAISE NOTICE '632: nessun trigger legge piu jwt.claims.app_user.';
END
$verifica$;

COMMIT;
