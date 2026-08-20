-- =============================================================================
-- 544 — Il motore del codice fiscale, nel database
-- =============================================================================
-- Fase 1 del piano "ana_clienti: un controllo, un posto solo"
-- (docs/plans/2026-08-20-ana-clienti-un-controllo-un-posto-solo.md).
--
-- Perche' qui: l'algoritmo esisteva DUE volte, in due linguaggi —
--   · Validation/Fiscal/CodiceFiscaleValidator.cs (MAUI): completo, con omocodia,
--     ma con i tre metodi principali ORFANI, mai chiamati da nessuno;
--   · codice_fiscale_utils.py (sito Flask): in uso, esposto da /api/validate_cf.
-- Stesso algoritmo, destini opposti. E i codici catastali su cui entrambi si
-- appoggiano stanno gia' qui, in ana_geo_comuni.comune_codfisc.
--
-- ⚠️ Le due implementazioni esistenti NON concordano sugli accenti:
--    · Python scarta le lettere accentate (lista bianca BCDFGHJKLMNPQRSTVWXYZ);
--    · C# le conta come consonanti (e' una lettera e non e' AEIOU).
--    Su "NICOLO'" con accento la prima da' NCL, la seconda NCLO-accentata.
--    Nessuna delle due segue la regola ufficiale, che vuole l'accento ripiegato
--    sulla vocale base. Qui si fa la cosa giusta: A-grave -> A, e' una vocale.
--    Su PROD i cognomi accentati sono 2 (PEYRE', SARA'), ma quelli con spazi o
--    apostrofi sono 84 — e per quelli tutte e tre le versioni concordano.
-- =============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- Normalizzazione: maiuscolo, accenti ripiegati, via tutto cio' che non e' lettera
-- (spazi e apostrofi si ignorano: DE LUCA -> DELUCA, D'ANGELO -> DANGELO).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_cf_normalizza(p_testo TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT regexp_replace(
             translate(upper(COALESCE(p_testo,'')),
                       'ÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝÇÑ',
                       'AAAAAAEEEEIIIIOOOOOUUUUYCN'),
             '[^A-Z]', '', 'g');
$$;

CREATE OR REPLACE FUNCTION fn_cf_consonanti(p_testo TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT regexp_replace(fn_cf_normalizza(p_testo), '[AEIOU]', '', 'g');
$$;

CREATE OR REPLACE FUNCTION fn_cf_vocali(p_testo TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT regexp_replace(fn_cf_normalizza(p_testo), '[^AEIOU]', '', 'g');
$$;

-- Cognome: consonanti, poi vocali, poi X di riempimento. Sempre 3 caratteri.
CREATE OR REPLACE FUNCTION fn_cf_codice_cognome(p_cognome TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT left(rpad(fn_cf_consonanti(p_cognome) || fn_cf_vocali(p_cognome), 3, 'X'), 3);
$$;

-- Nome: se le consonanti sono 4 o piu', si prendono la 1a, la 3a e la 4a.
-- Altrimenti vale la regola del cognome.
CREATE OR REPLACE FUNCTION fn_cf_codice_nome(p_nome TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN length(fn_cf_consonanti(p_nome)) >= 4
                THEN substr(fn_cf_consonanti(p_nome), 1, 1)
                  || substr(fn_cf_consonanti(p_nome), 3, 1)
                  || substr(fn_cf_consonanti(p_nome), 4, 1)
                ELSE fn_cf_codice_cognome(p_nome)
           END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Carattere di controllo. Le posizioni dispari (1a, 3a, 5a...) e quelle pari
-- pesano in modo diverso: sono le due tabelle ufficiali.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_cf_carattere_controllo(p_primi15 TEXT)
RETURNS CHAR LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    c_alfabeto CONSTANT TEXT := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    c_dispari  CONSTANT INTEGER[] := ARRAY[
        1,0,5,7,9,13,15,17,19,21,
        1,0,5,7,9,13,15,17,19,21,2,4,18,20,11,3,6,8,12,14,16,10,22,25,24,23];
    c_pari     CONSTANT INTEGER[] := ARRAY[
        0,1,2,3,4,5,6,7,8,9,
        0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25];
    v_somma INTEGER := 0;
    v_pos   INTEGER;
    i       INTEGER;
BEGIN
    IF p_primi15 IS NULL OR length(p_primi15) <> 15 THEN
        RETURN NULL;
    END IF;

    FOR i IN 1..15 LOOP
        v_pos := strpos(c_alfabeto, substr(p_primi15, i, 1));
        IF v_pos = 0 THEN
            RETURN NULL;   -- carattere non ammesso
        END IF;
        -- i dispari (1,3,5...) usano la tabella "dispari"
        v_somma := v_somma + CASE WHEN i % 2 = 1 THEN c_dispari[v_pos] ELSE c_pari[v_pos] END;
    END LOOP;

    RETURN chr(ascii('A') + (v_somma % 26));
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Il codice atteso, dall'anagrafica. Il comune arriva per ID: il codice
-- catastale lo sa il database, ed e' il motivo per cui questa funzione sta qui.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_cf_calcola(
    p_cognome       VARCHAR,
    p_nome          VARCHAR,
    p_data_nascita  DATE,
    p_sesso         CHAR,
    p_comune_id     INTEGER
) RETURNS VARCHAR LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_codfisc  VARCHAR;
    v_giorno   INTEGER;
    v_primi15  TEXT;
    c_mesi CONSTANT TEXT := 'ABCDEHLMPRST';   -- gennaio..dicembre
BEGIN
    IF btrim(COALESCE(p_cognome,'')) = '' OR btrim(COALESCE(p_nome,'')) = ''
       OR p_data_nascita IS NULL OR p_sesso NOT IN ('M','F') OR p_comune_id IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT btrim(upper(comune_codfisc)) INTO v_codfisc
    FROM ana_geo_comuni WHERE comune_id = p_comune_id;

    IF v_codfisc IS NULL OR length(v_codfisc) <> 4 THEN
        RETURN NULL;   -- comune sconosciuto o senza codice catastale
    END IF;

    -- Le donne hanno il giorno di nascita aumentato di 40: e' cosi' che il
    -- codice porta con se' anche il sesso.
    v_giorno := EXTRACT(DAY FROM p_data_nascita)::INTEGER + CASE WHEN p_sesso = 'F' THEN 40 ELSE 0 END;

    v_primi15 := fn_cf_codice_cognome(p_cognome)
              || fn_cf_codice_nome(p_nome)
              || to_char(p_data_nascita, 'YY')
              || substr(c_mesi, EXTRACT(MONTH FROM p_data_nascita)::INTEGER, 1)
              || lpad(v_giorno::TEXT, 2, '0')
              || v_codfisc;

    RETURN v_primi15 || fn_cf_carattere_controllo(v_primi15);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Omocodia: quando due persone otterrebbero lo stesso codice, l'Agenzia
-- sostituisce una o piu' cifre con lettere. Per confrontare due codici bisogna
-- prima riportarli alla forma con le cifre.
-- Posizioni sostituibili (1-indexed): 7, 8, 10, 11, 13, 14, 15.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_cf_omocodia_a_base(p_cf TEXT)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    v_cf TEXT := upper(btrim(COALESCE(p_cf,'')));
    v_posizioni CONSTANT INTEGER[] := ARRAY[7,8,10,11,13,14,15];
    p INTEGER;
BEGIN
    IF length(v_cf) <> 16 THEN RETURN NULL; END IF;

    FOREACH p IN ARRAY v_posizioni LOOP
        v_cf := overlay(v_cf PLACING
                    translate(substr(v_cf, p, 1), 'LMNPQRSTUV', '0123456789')
                    FROM p FOR 1);
    END LOOP;

    RETURN v_cf;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- La verifica completa: forma, carattere di controllo, corrispondenza con
-- l'anagrafica, omocodia. Un solo esito, leggibile da chiunque chiami.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_cf_verifica(
    p_cf            VARCHAR,
    p_cognome       VARCHAR DEFAULT NULL,
    p_nome          VARCHAR DEFAULT NULL,
    p_data_nascita  DATE    DEFAULT NULL,
    p_sesso         CHAR    DEFAULT NULL,
    p_comune_id     INTEGER DEFAULT NULL
) RETURNS TABLE (valido BOOLEAN, esito VARCHAR, messaggio TEXT, cf_atteso VARCHAR)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_cf      TEXT := upper(btrim(COALESCE(p_cf,'')));
    v_atteso  VARCHAR;
BEGIN
    IF v_cf = '' THEN
        RETURN QUERY SELECT FALSE, 'MANCANTE'::VARCHAR, 'Il codice fiscale non è stato inserito.'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    IF v_cf !~ '^[A-Z]{6}[0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{3}[A-Z]$' THEN
        RETURN QUERY SELECT FALSE, 'FORMA'::VARCHAR,
               'Il codice fiscale non ha una forma valida: servono 16 caratteri nel formato previsto.'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    IF substr(v_cf, 16, 1) <> fn_cf_carattere_controllo(substr(v_cf, 1, 15)) THEN
        RETURN QUERY SELECT FALSE, 'CARATTERE_CONTROLLO'::VARCHAR,
               'Il codice fiscale non supera il controllo dell''ultimo carattere: c''è un errore di digitazione.'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    -- Senza anagrafica ci si ferma alla forma: e' gia' molto piu' di prima.
    IF p_cognome IS NULL OR p_nome IS NULL OR p_data_nascita IS NULL
       OR p_sesso IS NULL OR p_comune_id IS NULL THEN
        RETURN QUERY SELECT TRUE, 'FORMA_OK'::VARCHAR,
               'Codice fiscale formalmente valido (non confrontato con l''anagrafica).'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    v_atteso := fn_cf_calcola(p_cognome, p_nome, p_data_nascita, p_sesso, p_comune_id);

    IF v_atteso IS NULL THEN
        RETURN QUERY SELECT TRUE, 'FORMA_OK'::VARCHAR,
               'Codice fiscale formalmente valido: l''anagrafica non basta per il confronto.'::TEXT, NULL::VARCHAR;
        RETURN;
    END IF;

    IF v_cf = v_atteso THEN
        RETURN QUERY SELECT TRUE, 'CORRISPONDE'::VARCHAR,
               'Codice fiscale corrispondente ai dati anagrafici.'::TEXT, v_atteso;
    ELSIF fn_cf_omocodia_a_base(v_cf) = fn_cf_omocodia_a_base(v_atteso) THEN
        RETURN QUERY SELECT TRUE, 'OMOCODIA'::VARCHAR,
               'Codice fiscale corrispondente, con sostituzioni per omocodia.'::TEXT, v_atteso;
    ELSE
        RETURN QUERY SELECT FALSE, 'NON_CORRISPONDE'::VARCHAR,
               format('Il codice fiscale non corrisponde ai dati anagrafici: da cognome, nome, data di nascita, sesso e comune risulterebbe %s.', v_atteso)::TEXT,
               v_atteso;
    END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- La lettura inversa: dal codice all'anagrafica. E' cio' che ha permesso di
-- verificare la data di nascita di un cliente con due schede (2026-08-20).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_cf_decodifica(p_cf VARCHAR)
RETURNS TABLE (data_nascita DATE, sesso CHAR, comune_id INTEGER, comune_descrizione VARCHAR, comune_codfisc VARCHAR)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_base    TEXT := fn_cf_omocodia_a_base(p_cf);
    v_anno    INTEGER;
    v_mese    INTEGER;
    v_giorno  INTEGER;
    v_sesso   CHAR;
    v_codfisc TEXT;
    c_mesi CONSTANT TEXT := 'ABCDEHLMPRST';
BEGIN
    IF v_base IS NULL THEN RETURN; END IF;

    v_mese := strpos(c_mesi, substr(v_base, 9, 1));
    IF v_mese = 0 THEN RETURN; END IF;

    v_giorno := substr(v_base, 10, 2)::INTEGER;
    v_sesso  := CASE WHEN v_giorno > 40 THEN 'F' ELSE 'M' END;
    IF v_giorno > 40 THEN v_giorno := v_giorno - 40; END IF;

    -- Il codice porta due sole cifre d'anno: si sceglie il secolo che non cade
    -- nel futuro. Una persona nata nel 1930 e una nel 2030 sono indistinguibili,
    -- ma la seconda non e' ancora nata.
    v_anno := substr(v_base, 7, 2)::INTEGER;
    v_anno := CASE WHEN v_anno > EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER % 100
                   THEN 1900 + v_anno ELSE 2000 + v_anno END;

    v_codfisc := substr(v_base, 12, 4);

    RETURN QUERY
    SELECT make_date(v_anno, v_mese, v_giorno), v_sesso, g.comune_id,
           g.comune_descrizione, g.comune_codfisc
    FROM ana_geo_comuni g WHERE btrim(upper(g.comune_codfisc)) = v_codfisc
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION fn_cf_calcola(VARCHAR,VARCHAR,DATE,CHAR,INTEGER) IS
'Codice fiscale atteso dall''anagrafica. Sta nel DB perche'' i codici catastali stanno in ana_geo_comuni: e'' l''unico posto che li conosce. Sostituisce le implementazioni duplicate in C# e Python.';
COMMENT ON FUNCTION fn_cf_verifica(VARCHAR,VARCHAR,VARCHAR,DATE,CHAR,INTEGER) IS
'Verifica completa: forma, carattere di controllo, corrispondenza con l''anagrafica, omocodia. Unico punto di verita'' per gestionale e sito.';

COMMIT;
