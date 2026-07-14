-- ============================================================================
-- DB-first: converto la CRUD inline di TipoViaggioService in funzioni DB
-- (richiesta Adriano). Restano allineate al comportamento pre-esistente:
--   * create: imposta tipo/descrizione/breve (descrizione_web_fk resta NULL,
--     come faceva l'INSERT inline; il mapping web si fa in update — Blocco 8).
--   * update: aggiorna tipo/descrizione/descrizione_web_fk/breve.
-- Entrambe ritornano la riga completa (SETOF) così il C# la mappa con MapFromReader.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_ana_tipo_viaggi_create(
    p_tipo character varying,
    p_descrizione character varying,
    p_breve boolean DEFAULT false
) RETURNS SETOF ana_tipo_viaggi
LANGUAGE sql AS $$
    INSERT INTO ana_tipo_viaggi (tipo_viaggi_tipo, tipo_viaggi_descrizione, tipo_viaggio_breve)
    VALUES (p_tipo, p_descrizione, COALESCE(p_breve, false))
    RETURNING *;
$$;

CREATE OR REPLACE FUNCTION fn_ana_tipo_viaggi_update(
    p_id integer,
    p_tipo character varying,
    p_descrizione character varying,
    p_descrizione_web_fk bigint,
    p_breve boolean
) RETURNS SETOF ana_tipo_viaggi
LANGUAGE sql AS $$
    UPDATE ana_tipo_viaggi
       SET tipo_viaggi_tipo = p_tipo,
           tipo_viaggi_descrizione = p_descrizione,
           descrizione_web_fk = p_descrizione_web_fk,
           tipo_viaggio_breve = COALESCE(p_breve, false)
     WHERE tipo_viaggi_id = p_id
    RETURNING *;
$$;

COMMIT;
