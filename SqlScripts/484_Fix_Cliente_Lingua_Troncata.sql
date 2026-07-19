-- Ripara ana_clienti.cliente_lingua troncata a 1 carattere dal vecchio bug del cast ::char
-- in ClienteLinguaService.SetAsync ('IT'::char -> 'I', ecc.). Rimappa il singolo carattere legacy
-- al codice ISO a 2 lettere usato dal select in ClienteDialog.
-- Idempotente: agisce solo sui valori di lunghezza 1 (dopo btrim). 'E' -> 'EN' (default; ES raro/ambiguo).
UPDATE ana_clienti
SET cliente_lingua = CASE upper(btrim(cliente_lingua))
        WHEN 'I' THEN 'IT'
        WHEN 'E' THEN 'EN'
        WHEN 'D' THEN 'DE'
        WHEN 'F' THEN 'FR'
        WHEN 'S' THEN 'ES'
        ELSE cliente_lingua
    END
WHERE length(btrim(cliente_lingua)) = 1;
