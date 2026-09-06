-- =============================================================================
-- 611 — La tenda da uno, e le sistemazioni che non si propongono da sole
-- =============================================================================
--
-- Due richieste di Adriano il 2026-09-06, provando il suggerimento del tipo.
--
-- 1. ⚠️ **«La camera disabili non va mai proposta per prima, anche se in elenco ci
--    deve essere.»** Fra i tipi da 1 posto ce ne sono tre — CAMERA SINGOLA, CAMERA
--    DOPPIA USO SINGOLA e CAMERA SINGOLA DISABILI — tutti con supplemento. Il
--    suggerimento ne sceglieva uno per anzianita', e usciva quella giusta solo
--    perche' era la piu' vecchia: per fortuna, non per regola. Serve un dato.
--
-- 2. **«Chi viaggia da solo in un viaggio SOLO TENDA verra' con una tenda singola.»**
--    In tabella non c'era: le tende erano solo da 2 e da 4 posti, quindi a chi
--    partiva da solo il programma non proponeva niente e non aveva niente da
--    scegliere. Non e' un caso limite — e' il motociclista che viaggia da solo.
--    ⚠️ Adriano le ha inserite lui su PROD, in entrambe le versioni (noleggiata e di
--    proprieta'): qui si ricopiano con le SUE chiavi, 38 e 40.
--
-- ⚠️ La chiave della riga nuova e' ESPLICITA (37, libera in entrambi gli ambienti).
-- Locale e PROD hanno lo stesso max_id 36 ma sequenze diverse (37 e 36): lasciando
-- assegnare la chiave al database, la stessa tenda avrebbe due id diversi nei due
-- ambienti — ed e' il tipo di divergenza che rende i test bugiardi (vedi 597).
-- Dopo l'inserimento la sequenza si riallinea in tutti e due.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Il segno «esiste, ma non si propone da sola»
-- ---------------------------------------------------------------------------
ALTER TABLE ana_tipo_alloggio
    ADD COLUMN IF NOT EXISTS tipo_alloggio_mai_proposta BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN ana_tipo_alloggio.tipo_alloggio_mai_proposta IS
'La sistemazione resta scegliibile, ma il programma non la propone mai d''ufficio.
Nasce per le camere attrezzate per disabili: devono comparire in elenco — si mostrano
sempre, anche per rispetto verso la categoria — ma assegnarle a chi non le ha chieste
sarebbe sbagliato. Vale per qualunque sistemazione che si dia su richiesta.';

-- Si riconoscono UNA volta, qui, dai dati di oggi: da domani sono un dato.
-- ⛔️ Il suggerimento NON deve mai guardare la descrizione: e' il difetto tolto dai
-- generi, dove bastava rinominare una riga per spegnere una regola in silenzio.
UPDATE ana_tipo_alloggio
   SET tipo_alloggio_mai_proposta = TRUE
 WHERE tipo_alloggio_descrizione ILIKE '%DISABIL%';


-- ---------------------------------------------------------------------------
-- 2. La tenda da una persona
-- ---------------------------------------------------------------------------
-- ⚠️ Le ha inserite Adriano SU PROD mentre scrivevo questo script, entrambe le
-- versioni. Le chiavi le detta PROD: 38 e 40 (il trigger vecchio salta di due, come
-- per le tende da 2 e 4 — 30, 32, 34, 36). Qui si ricopiano identiche, descrizione e
-- supplemento compresi, perche' un catalogo di riferimento diverso fra i due ambienti
-- e' cio' che rende i test bugiardi: e' successo il 5 settembre con questa stessa
-- tabella (vedi 597).
--
-- ⚠️ Su PROD questo INSERT non fa nulla — le righe ci sono gia'. Serve al locale, e
-- serve a chiunque ricostruisca un ambiente da zero.
INSERT INTO ana_tipo_alloggio (
    tipo_alloggio_id, tipo_alloggio_descrizione, tipo_alloggio_numero_occupanti,
    tipo_alloggio_supplemento, genere_fk)
SELECT v.id, v.descrizione, 1, v.suppl, g.genere_id
FROM (VALUES (38, 'TENDA 1 POSTO NOLEGGIATA',     'Y'),
             (40, 'TENDA 1 POSTO DI PROPRIETA''', 'N')) AS v(id, descrizione, suppl)
CROSS JOIN ana_alloggio_generi g
WHERE g.genere_codice = 'TENDA'
ON CONFLICT (tipo_alloggio_id) DO NOTHING;

-- La riga 37 e' un mio errore: l'avevo inserita prima di sapere che le chiavi vere
-- erano 38 e 40. Se c'e' e non e' mai stata usata, se ne va.
DELETE FROM ana_tipo_alloggio t
 WHERE t.tipo_alloggio_id = 37
   AND t.tipo_alloggio_descrizione = 'TENDA 1 POSTO DI PROPRIETA'''
   AND NOT EXISTS (SELECT 1 FROM mov_clienti_alloggi a WHERE a.tipo_alloggio_id_fk = 37);

SELECT setval('ana_tipo_alloggio_seq', (SELECT max(tipo_alloggio_id) FROM ana_tipo_alloggio));


-- ---------------------------------------------------------------------------
-- 3. La lettura dice anche questo
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_alloggi_tipi_ammessi(INTEGER);

CREATE OR REPLACE FUNCTION fn_alloggi_tipi_ammessi(p_data_viaggio_id INTEGER)
RETURNS TABLE(tipo_id INTEGER, descrizione VARCHAR, posti INTEGER,
              supplemento BOOLEAN, genere VARCHAR, mai_proposta BOOLEAN)
LANGUAGE sql STABLE AS $$
    SELECT t.tipo_alloggio_id, t.tipo_alloggio_descrizione, t.tipo_alloggio_numero_occupanti,
           (t.tipo_alloggio_supplemento = 'Y'), g.genere_codice, t.tipo_alloggio_mai_proposta
    FROM ana_date_viaggi dv
    JOIN ana_viaggi v            ON v.viaggio_id = dv.viaggio_id_fk
    JOIN ana_tipo_alloggio t     ON TRUE
    JOIN ana_alloggio_generi g   ON g.genere_id = t.genere_fk
    WHERE dv.data_viaggio_id = p_data_viaggio_id
      AND (
            -- «Nessuna sistemazione» vale sempre: chi dorme nel proprio mezzo puo'
            -- indicarlo su qualunque viaggio.
            g.genere_codice = 'NESSUNA'
            OR EXISTS (SELECT 1 FROM ana_tipo_pernottamento_generi pg
                       WHERE pg.pernottamento_fk = v.viaggio_tipo_pernottamento_fk
                         AND pg.genere_fk = t.genere_fk)
          )
    ORDER BY t.tipo_alloggio_numero_occupanti, t.tipo_alloggio_descrizione;
$$;

COMMENT ON FUNCTION fn_alloggi_tipi_ammessi(INTEGER) IS
'Le sistemazioni che questa partenza ammette, secondo il pernottamento del viaggio.
Unica fonte per gestionale e sito: ⚠️ `mai_proposta` dice quali non vanno suggerite
d''ufficio — restano scegliibili, non si propongono.';


-- ---------------------------------------------------------------------------
-- 4. Il flag si legge e si scrive dalla scheda: e' una scelta dell'operatore
-- ---------------------------------------------------------------------------
-- ⚠️ Senza questo, «mai proposta» resterebbe una cosa che solo io posso cambiare
-- con una UPDATE a mano. Domani nascono i bungalow attrezzati, e chi lavora deve
-- poterlo dire da solo.
DROP FUNCTION IF EXISTS fn_ana_tipo_alloggio_get_all();

CREATE OR REPLACE FUNCTION fn_ana_tipo_alloggio_get_all()
RETURNS TABLE(tipo_alloggio_id integer, tipo_alloggio_descrizione character varying,
              tipo_alloggio_numero_occupanti integer, tipo_alloggio_supplemento character varying,
              genere_fk integer, genere_descrizione character varying, genere_codice character varying,
              tipo_alloggio_mai_proposta boolean)
LANGUAGE sql STABLE AS $$
    SELECT t.tipo_alloggio_id, t.tipo_alloggio_descrizione, t.tipo_alloggio_numero_occupanti,
           t.tipo_alloggio_supplemento, t.genere_fk, g.genere_descrizione, g.genere_codice,
           t.tipo_alloggio_mai_proposta
    FROM ana_tipo_alloggio t
    JOIN ana_alloggio_generi g ON g.genere_id = t.genere_fk
    ORDER BY g.genere_ordine, t.tipo_alloggio_numero_occupanti, t.tipo_alloggio_descrizione;
$$;

DROP FUNCTION IF EXISTS fn_ana_tipo_alloggio_upsert(INTEGER, VARCHAR, INTEGER, VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION fn_ana_tipo_alloggio_upsert(
    p_id               INTEGER,
    p_descrizione      VARCHAR,
    p_numero_occupanti INTEGER,
    p_supplemento      VARCHAR,
    p_genere_fk        INTEGER,
    p_mai_proposta     BOOLEAN DEFAULT FALSE
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_id           INTEGER;
    v_genere_prima INTEGER;
    v_quante       INTEGER;
    v_viaggi       TEXT;
BEGIN
    IF COALESCE(p_genere_fk, 0) = 0 THEN
        RAISE EXCEPTION 'Il genere è obbligatorio: senza, non si può sapere su quali viaggi questa sistemazione è ammessa.';
    END IF;

    IF COALESCE(p_id, 0) = 0 THEN
        INSERT INTO ana_tipo_alloggio
            (tipo_alloggio_descrizione, tipo_alloggio_numero_occupanti, tipo_alloggio_supplemento,
             genere_fk, tipo_alloggio_mai_proposta)
        VALUES (upper(btrim(p_descrizione)), p_numero_occupanti, COALESCE(p_supplemento,'N'),
                p_genere_fk, COALESCE(p_mai_proposta, FALSE))
        RETURNING tipo_alloggio_id INTO v_id;
        RETURN v_id;
    END IF;

    SELECT genere_fk INTO v_genere_prima FROM ana_tipo_alloggio WHERE tipo_alloggio_id = p_id;

    IF v_genere_prima IS DISTINCT FROM p_genere_fk THEN
        SELECT count(*),
               string_agg(DISTINCT v.viaggio_descrizione_breve, ', ' ORDER BY v.viaggio_descrizione_breve)
          INTO v_quante, v_viaggi
        FROM mov_clienti_alloggi a
        JOIN ana_viaggi v ON v.viaggio_id = a.viaggio_id_fk
        WHERE a.tipo_alloggio_id_fk = p_id
          -- Oggi valida…
          AND EXISTS (SELECT 1 FROM ana_tipo_pernottamento_generi pg
                      WHERE pg.pernottamento_fk = v.viaggio_tipo_pernottamento_fk
                        AND pg.genere_fk = v_genere_prima)
          -- …e col genere nuovo non piu'.
          AND NOT EXISTS (SELECT 1 FROM ana_tipo_pernottamento_generi pg
                          WHERE pg.pernottamento_fk = v.viaggio_tipo_pernottamento_fk
                            AND pg.genere_fk = p_genere_fk);

        IF COALESCE(v_quante, 0) > 0 THEN
            RAISE EXCEPTION
                'Con questo genere % assegnazioni oggi valide non lo sarebbero più, su: %. Cambia prima le sistemazioni previste da quei viaggi, oppure lascia il genere com''è.',
                v_quante, left(v_viaggi, 200)
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    UPDATE ana_tipo_alloggio
       SET tipo_alloggio_descrizione = upper(btrim(p_descrizione)),
           tipo_alloggio_numero_occupanti = p_numero_occupanti,
           tipo_alloggio_supplemento = COALESCE(p_supplemento,'N'),
           genere_fk = p_genere_fk,
           tipo_alloggio_mai_proposta = COALESCE(p_mai_proposta, FALSE)
     WHERE tipo_alloggio_id = p_id
    RETURNING tipo_alloggio_id INTO v_id;
    RETURN v_id;
END;
$$;
