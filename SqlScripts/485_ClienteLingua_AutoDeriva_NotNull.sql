-- cliente_lingua: mai NULL.
-- 1) fn_ana_clienti_set_lingua deriva dalla nazione di residenza quando p_lingua è vuoto/NULL
--    (fn_lingua_da_comune), fallback 'IT'. La newsletter legge cliente_lingua senza ragionare.
-- 2) backfill dei NULL residui. 3) DEFAULT 'IT' + NOT NULL a livello colonna.
-- Idempotente (CREATE OR REPLACE; backfill su IS NULL; ALTER ripetibili).

-- 1) Set con auto-derivazione (stessa firma: REPLACE in place)
CREATE OR REPLACE FUNCTION public.fn_ana_clienti_set_lingua(p_cliente_id integer, p_lingua character)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE v_n INTEGER;
BEGIN
    UPDATE ana_clienti
       SET cliente_lingua = COALESCE(
               NULLIF(upper(btrim(p_lingua)), ''),
               fn_lingua_da_comune(cliente_comune_residenza_fk),
               'IT'
           )::CHAR(2)
     WHERE cliente_id = p_cliente_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $function$;

-- 2) Backfill NULL residui (deriva da nazione, fallback IT)
UPDATE ana_clienti
   SET cliente_lingua = COALESCE(fn_lingua_da_comune(cliente_comune_residenza_fk), 'IT')::CHAR(2)
 WHERE cliente_lingua IS NULL;

-- 3) Default + NOT NULL (INSERT non passa la colonna -> usa il DEFAULT)
ALTER TABLE ana_clienti ALTER COLUMN cliente_lingua SET DEFAULT 'IT';
ALTER TABLE ana_clienti ALTER COLUMN cliente_lingua SET NOT NULL;
