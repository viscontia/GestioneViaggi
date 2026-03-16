-- FUNZIONE: get_mezzi_count
-- DESCRIZIONE: Restituisce il numero totale di mezzi (veicoli) partecipanti per una specifica data viaggio.
--              Conta solo i partecipanti che hanno un mezzo assegnato (ana_mezzi_id_fk IS NOT NULL).
-- AUTORE: Antigravity
-- DATA: 2026-03-16
-- NOTA: Funzione richiesta da fn_get_viaggi_init_data per il caricamento dati dialog viaggi

CREATE OR REPLACE FUNCTION public.get_mezzi_count(p_data_viaggio_id integer)
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE
    v_count integer;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM mov_clienti_viaggi
    WHERE data_viaggio_id_fk = p_data_viaggio_id
      AND ana_mezzi_id_fk IS NOT NULL;

    RETURN v_count;
END;
$function$;
