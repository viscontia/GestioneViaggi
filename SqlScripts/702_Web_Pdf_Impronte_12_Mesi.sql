-- ============================================================================
-- 702 — L'impronta del conteggio dei PDF dura 12 mesi (Tappa 4B, Task 2)
--
-- Scritta la privacy del sito (2026-10-23), è emerso che le impronte dei visitatori
-- (web_pdf_richieste, script 688) non si cancellavano mai: è un dato personale, anche se
-- cifrato. Decisione di Adriano: 12 mesi. fn_web_pdf_richiesta, a ogni conteggio, cancella
-- quelle più vecchie, di tutte le aziende. Il resto invariato (SECURITY DEFINER: niente
-- permessi in più a sito_statistiche).
-- Corpo preso dal locale (identico a PROD, md5 9218f465...). Rigiocabile.
-- Test: Test_702_Web_Pdf_Impronte_12_Mesi.sql
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_web_pdf_richiesta(p_azienda_id integer, p_data_viaggio_id integer, p_lingua character varying, p_impronta character varying)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    -- I formati si controllano sempre, prima di tutto (lezione del 687).
    IF p_impronta IS NULL OR p_impronta !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION 'Impronta del visitatore non valida (attesi 64 caratteri esadecimali)';
    END IF;
    IF p_lingua IS NULL OR p_lingua NOT IN ('IT', 'EN', 'DE', 'FR', 'ES') THEN
        RAISE EXCEPTION 'Lingua non valida: %', left(coalesce(p_lingua, '(nulla)'), 10);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM ana_date_viaggi WHERE data_viaggio_id = p_data_viaggio_id AND azienda_id = p_azienda_id) THEN
        RAISE EXCEPTION 'L''edizione % non appartiene all''azienda %', p_data_viaggio_id, p_azienda_id;
    END IF;

    -- 702: le impronte si tengono 12 mesi (privacy del sito, 2026-10-23), per TUTTE le aziende: la pulizia la fa
    -- ogni conteggio, così non serve un compito a orario (e un'azienda senza richieste non le tiene per sempre).
    DELETE FROM web_pdf_richieste WHERE richiesta_il < now() - interval '12 months';

    IF EXISTS (SELECT 1 FROM web_pdf_richieste r
                WHERE r.data_viaggio_id = p_data_viaggio_id AND r.azienda_id = p_azienda_id
                  AND r.lingua = p_lingua AND r.impronta = p_impronta
                  AND r.richiesta_il > now() - interval '1 hour') THEN
        RETURN false;
    END IF;

    INSERT INTO web_pdf_richieste (azienda_id, data_viaggio_id, lingua, impronta)
    VALUES (p_azienda_id, p_data_viaggio_id, p_lingua, p_impronta);
    RETURN true;
END;
$function$;

COMMIT;
