-- =============================================================================
-- 549 — Fase 2: il controllo anti-omonimia che non si autodisattiva
-- =============================================================================
-- Il controllo che c'era prima (ClienteService, ~riga 476) era racchiuso in:
--     if (DataNascita.HasValue && !string.IsNullOrWhiteSpace(CodiceFiscale))
-- e la query che eseguiva pretendeva per giunta l'UGUAGLIANZA del codice fiscale
-- fra i criteri di ricerca. Girava quindi solo sulle schede complete, ed era
-- cieco esattamente su quelle che hanno piu' probabilita' di essere duplicate:
-- su PROD 327 clienti su 778 non avevano il codice fiscale. Risultato, cinque
-- gruppi di omonimi, fra cui le due schede di ANTONIO TOLU fuse a mano il 19/08.
--
-- ⚠️ LA REGOLA DA NON RIPETERE: nessuno dei tre livelli qui sotto pretende il
--    codice fiscale per funzionare. Il codice fiscale, quando c'e', RAFFORZA il
--    controllo; quando manca, non lo spegne.
--
-- Tre livelli (decisione del committente, 2026-08-20):
--   · stesso codice fiscale                          -> ERRORE, e' la stessa persona
--   · stessi cognome, nome, data E comune di nascita -> ERRORE
--   · stessi cognome e nome soltanto                 -> AVVISO, l'omonimia esiste
--
-- Restituisce una riga per ogni riscontro, dalla piu' grave: chi chiama prende la
-- prima, o le mostra tutte.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_ana_clienti_verifica_duplicato(
    p_azienda_id          INTEGER,
    p_cognome             VARCHAR,
    p_nome                VARCHAR,
    p_data_nascita        DATE    DEFAULT NULL,
    p_comune_nascita_id   INTEGER DEFAULT NULL,
    p_cf                  VARCHAR DEFAULT NULL,
    p_escludi_cliente_id  INTEGER DEFAULT NULL
) RETURNS TABLE (gravita VARCHAR, esito VARCHAR, messaggio TEXT, cliente_id INTEGER)
LANGUAGE sql STABLE AS $$
    SELECT r.gravita, r.esito, r.messaggio, r.cliente_id FROM (
    WITH candidati AS (
        SELECT c.cliente_id, c.cliente_cognome, c.cliente_nome, c.cliente_data_nascita,
               c.cliente_comune_nascita_fk, upper(btrim(c.cliente_codicefiscale)) AS cf
        FROM ana_clienti c
        WHERE c.azienda_fk = p_azienda_id
          AND (p_escludi_cliente_id IS NULL OR c.cliente_id <> p_escludi_cliente_id)
    )
    -- 1. Stesso codice fiscale: e' la stessa persona, senza discussione.
    SELECT 'ERRORE'::VARCHAR, 'STESSO_CF'::VARCHAR,
           format('Il codice fiscale è già registrato su un altro cliente: %s %s.',
                  k.cliente_cognome, k.cliente_nome)::TEXT,
           k.cliente_id
    FROM candidati k
    WHERE btrim(COALESCE(p_cf,'')) <> ''
      AND k.cf = upper(btrim(p_cf))

    UNION ALL
    -- 2. Stessa anagrafica completa. L'omonimia esiste, ma non alla stessa data
    --    E nello stesso comune di nascita.
    SELECT 'ERRORE'::VARCHAR, 'STESSA_ANAGRAFICA'::VARCHAR,
           format('Esiste già un cliente con gli stessi dati anagrafici: %s %s, nato il %s.',
                  k.cliente_cognome, k.cliente_nome, to_char(k.cliente_data_nascita, 'DD/MM/YYYY'))::TEXT,
           k.cliente_id
    FROM candidati k
    WHERE p_data_nascita IS NOT NULL
      AND p_comune_nascita_id IS NOT NULL
      AND k.cliente_data_nascita = p_data_nascita
      AND k.cliente_comune_nascita_fk = p_comune_nascita_id
      AND upper(btrim(k.cliente_cognome)) = upper(btrim(p_cognome))
      AND upper(btrim(k.cliente_nome))    = upper(btrim(p_nome))
      -- se il codice fiscale li ha gia' dichiarati la stessa persona, non si ripete
      AND (btrim(COALESCE(p_cf,'')) = '' OR k.cf IS DISTINCT FROM upper(btrim(p_cf)))

    UNION ALL
    -- 3. Solo cognome e nome: gli omonimi esistono davvero, quindi si avvisa.
    SELECT 'AVVISO'::VARCHAR, 'OMONIMO'::VARCHAR,
           format('Esiste già un cliente che si chiama %s %s%s. Controlla che non sia la stessa persona.',
                  k.cliente_cognome, k.cliente_nome,
                  CASE WHEN k.cliente_data_nascita IS NOT NULL
                       THEN ', nato il ' || to_char(k.cliente_data_nascita, 'DD/MM/YYYY') ELSE '' END)::TEXT,
           k.cliente_id
    FROM candidati k
    WHERE upper(btrim(k.cliente_cognome)) = upper(btrim(p_cognome))
      AND upper(btrim(k.cliente_nome))    = upper(btrim(p_nome))
      -- non si ripete cio' che i due livelli sopra hanno gia' detto
      AND (btrim(COALESCE(p_cf,'')) = '' OR k.cf IS DISTINCT FROM upper(btrim(p_cf)))
      AND NOT (p_data_nascita IS NOT NULL AND p_comune_nascita_id IS NOT NULL
               AND k.cliente_data_nascita = p_data_nascita
               AND k.cliente_comune_nascita_fk = p_comune_nascita_id)

    ) AS r(gravita, esito, messaggio, cliente_id)
    -- Il piu' grave per primo: chi chiama legge la prima riga. In ordine
    -- alfabetico AVVISO verrebbe prima di ERRORE, cioe' l'opposto di cio' che serve.
    ORDER BY CASE WHEN r.gravita = 'ERRORE' THEN 1 ELSE 2 END, r.cliente_id;
$$;

COMMENT ON FUNCTION fn_ana_clienti_verifica_duplicato(INTEGER,VARCHAR,VARCHAR,DATE,INTEGER,VARCHAR,INTEGER) IS
'Anti-duplicato anagrafico a tre livelli (SqlScripts/549). NESSUN livello richiede il codice fiscale per funzionare: era l''errore del controllo precedente, cieco sul 42% dei clienti. Unico punto di verita'' per gestionale e sito.';

COMMIT;
