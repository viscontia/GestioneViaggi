-- ============================================================================
-- 695 — Home: titolo e sottotitolo al posto della «frase d'apertura» (Tappa 4A)
--
-- Decisione di Adriano e Antonio del 2026-10-20: l'apertura della home ha tre testi,
-- tutti tradotti: il MOTTO (grande, in cima), il TITOLO (medio) e il SOTTOTITOLO
-- (facoltativo). Il disegno: Sito Web SFT/Documenti/Analisi/2026-10-19-Tappa_4_Contorno_Disegno.md.
--   - web_sito_contenuti.frase_home → titolo_home; nuova sottotitolo_home;
--     le traduzioni seguono il nuovo nome (campo 'frase_home' → 'titolo_home').
--   - fn_web_sito_contenuti_save: un parametro in più. La vecchia firma si toglie:
--     la usava solo il codice della 2.4, non ancora rilasciato.
--   - fn_web_sito_home: chiavi 'titolo' e 'sottotitolo' (non più 'frase').
-- Rigiocabile.
-- ============================================================================
BEGIN;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_name = 'web_sito_contenuti' AND column_name = 'frase_home') THEN
        ALTER TABLE web_sito_contenuti RENAME COLUMN frase_home TO titolo_home;
    END IF;
END $$;
ALTER TABLE web_sito_contenuti ADD COLUMN IF NOT EXISTS sottotitolo_home varchar(300);

UPDATE web_traduzioni SET campo = 'titolo_home'
 WHERE entita = 'web_sito_contenuti' AND campo = 'frase_home';

DROP FUNCTION IF EXISTS fn_web_sito_contenuti_save(integer, bigint, varchar, varchar, integer, varchar, varchar);

-- Salva la sotto-scheda Home (crea la riga se manca). Testi vuoti → NULL.
CREATE OR REPLACE FUNCTION fn_web_sito_contenuti_save(
    p_azienda_id integer, p_foto_home_fk bigint, p_motto varchar, p_titolo_home varchar,
    p_sottotitolo_home varchar, p_email_messaggi_fk integer, p_evidenza_titolo varchar, p_utente varchar)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO web_sito_contenuti AS c
           (azienda_id, foto_home_fk, motto, titolo_home, sottotitolo_home, email_messaggi_fk,
            evidenza_titolo, updated_by, updated)
    VALUES (p_azienda_id, p_foto_home_fk, nullif(btrim(p_motto), ''), nullif(btrim(p_titolo_home), ''),
            nullif(btrim(p_sottotitolo_home), ''), p_email_messaggi_fk, nullif(btrim(p_evidenza_titolo), ''),
            p_utente, now())
    ON CONFLICT (azienda_id) DO UPDATE
       SET foto_home_fk      = EXCLUDED.foto_home_fk,
           motto             = EXCLUDED.motto,
           titolo_home       = EXCLUDED.titolo_home,
           sottotitolo_home  = EXCLUDED.sottotitolo_home,
           email_messaggi_fk = EXCLUDED.email_messaggi_fk,
           evidenza_titolo   = EXCLUDED.evidenza_titolo,
           updated_by        = EXCLUDED.updated_by,
           updated           = now();
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_web_sito_contenuti_save(integer, bigint, varchar, varchar, varchar, integer, varchar, varchar) FROM PUBLIC;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        REVOKE EXECUTE ON FUNCTION fn_web_sito_contenuti_save(integer, bigint, varchar, varchar, varchar, integer, varchar, varchar)
            FROM anon, authenticated;
    END IF;
END $$;

-- La home per il sito: foto, motto, titolo, sottotitolo (tradotti, ripiego sull'italiano).
CREATE OR REPLACE FUNCTION fn_web_sito_home(p_azienda_id integer, p_lingua varchar)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v jsonb;
BEGIN
    PERFORM fn_web_sito_lingua_valida(p_lingua);
    SELECT jsonb_build_object(
               'foto', (SELECT jsonb_build_object('url', i.url, 'larghezza', i.larghezza,
                                                  'altezza', i.altezza, 'descrizione', i.descrizione)
                          FROM web_immagini_libreria i WHERE i.web_immagini_libreria_id = c.foto_home_fk),
               'motto', fn_web_sito_testo('web_sito_contenuti', c.azienda_id, 'motto', p_lingua, c.motto),
               'titolo', fn_web_sito_testo('web_sito_contenuti', c.azienda_id, 'titolo_home', p_lingua, c.titolo_home),
               'sottotitolo', fn_web_sito_testo('web_sito_contenuti', c.azienda_id, 'sottotitolo_home', p_lingua, c.sottotitolo_home))
      INTO v
      FROM web_sito_contenuti c
     WHERE c.azienda_id = p_azienda_id;
    RETURN v;
END;
$$;

COMMIT;

-- ============================================================================
-- Verifica: Test_695_Web_Sito_Titolo_Sottotitolo.sql
-- ============================================================================
