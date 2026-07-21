-- Preferenze utente generiche (key-value), "nascoste": nessuna UI CRUD, solo function DB.
-- Usata per la prima volta da: slider "dimensione miniature" condiviso tra WebTourGalleriaTab e WebTourPassoEditDialog
-- (chiave applicativa: galleria.thumb_size).
--
-- Nota: la tabella utenti reale è app_users, PK user_id UUID (non INTEGER) -> utente_id qui è UUID.
CREATE TABLE IF NOT EXISTS sys_utente_preferenze (
    utente_id  UUID NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    chiave     VARCHAR(100) NOT NULL,
    valore     TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (utente_id, chiave)
);

CREATE OR REPLACE FUNCTION fn_sys_utente_pref_get(
    p_utente_id UUID,
    p_chiave    VARCHAR
)
RETURNS TEXT
LANGUAGE sql
AS $$
    SELECT valore
    FROM sys_utente_preferenze
    WHERE utente_id = p_utente_id
      AND chiave = p_chiave;
$$;

CREATE OR REPLACE FUNCTION fn_sys_utente_pref_set(
    p_utente_id UUID,
    p_chiave    VARCHAR,
    p_valore    TEXT
)
RETURNS void
LANGUAGE sql
AS $$
    INSERT INTO sys_utente_preferenze (utente_id, chiave, valore)
    VALUES (p_utente_id, p_chiave, p_valore)
    ON CONFLICT (utente_id, chiave)
    DO UPDATE SET valore = EXCLUDED.valore, updated_at = now();
$$;
