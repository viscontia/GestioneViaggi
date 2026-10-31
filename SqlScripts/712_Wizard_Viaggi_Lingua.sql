-- ============================================================================
-- 712 — Il passo 1 del modulo di iscrizione nella lingua del cliente (ToDo 5 del sito, passo 1)
--
-- fn_wizard_get_viaggi_disponibili(azienda, lingua): gli stessi viaggi della funzione di prima, con
--   - il titolo tradotto se c'è una traduzione non obsoleta, altrimenti il titolo italiano leggibile: la stessa regola
--     del sito pubblico (script 684), quindi il cliente ritrova nel modulo il titolo che ha letto sulla scheda;
--   - il codice ISO della nazione: il nome lo scrive il browser nella lingua del cliente (Intl.DisplayNames).
-- La funzione di prima (un solo argomento) resta finché il modulo nuovo non è su tutti i server: poi si toglie.
-- Disegno: GitHub/Iscrizione-Viaggi-Offroad PostgreSQL/docs/plans/2026-10-31-wizard-cinque-lingue-inventario.md
-- Rigiocabile. Test: Test_712_Wizard_Viaggi_Lingua.sql
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION fn_wizard_get_viaggi_disponibili(p_azienda_id integer, p_lingua varchar)
RETURNS TABLE(viaggio_id integer, titolo varchar, viaggio_numero_giorni integer, nazione_iso2 varchar, nome_nazione_it varchar)
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
    WITH l AS (SELECT upper(btrim(coalesce(p_lingua, ''))) AS lingua)
    SELECT DISTINCT
           v.viaggio_id,
           coalesce(nullif(btrim(t.testo), ''), fn_web_titolo_leggibile(v.viaggio_descrizione_breve))::varchar,
           v.viaggio_numero_giorni,
           n.iso_alpha2::varchar,
           coalesce(n.name_it, n.name)::varchar
      FROM ana_viaggi v
      JOIN ana_date_viaggi dv ON dv.viaggio_id_fk = v.viaggio_id
      LEFT JOIN eba_countries n ON n.country_id = v.viaggio_nazione_fk
      CROSS JOIN l
      LEFT JOIN web_traduzioni t ON l.lingua <> 'IT'
           AND t.entita = 'ana_viaggi' AND t.entita_id = v.viaggio_id
           AND t.campo = 'viaggio_descrizione_breve' AND t.lingua = l.lingua AND NOT t.obsoleto
     WHERE v.azienda_id = p_azienda_id
       AND fn_partenza_iscrivibile(dv.data_viaggio_id)
     ORDER BY 2;
$$;
COMMENT ON FUNCTION fn_wizard_get_viaggi_disponibili(integer, varchar) IS
    'Viaggi iscrivibili per il modulo di iscrizione, con il titolo nella lingua del cliente e il codice ISO della nazione (script 712).';

-- In PROD una funzione nuova nasce eseguibile da chiunque: la usa solo il modulo, che si collega come proprietario.
DO $$
BEGIN
    EXECUTE 'REVOKE EXECUTE ON FUNCTION fn_wizard_get_viaggi_disponibili(integer, varchar) FROM PUBLIC';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        EXECUTE 'REVOKE EXECUTE ON FUNCTION fn_wizard_get_viaggi_disponibili(integer, varchar) FROM anon, authenticated';
    END IF;
END $$;

COMMIT;
