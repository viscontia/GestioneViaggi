-- ============================================================================
-- 706 — Se nel testo italiano cambia solo la formattazione, le traduzioni non si rifanno (L29)
--
-- Richiesta di Adriano del 2026-10-27: ha cambiato un titoletto da Heading3 a Heading2 e il
-- gestionale ha reso «da rifare» tutte le traduzioni, cioè una nuova traduzione pagata per
-- le stesse parole. Il confronto era sull'HTML esatto: bastava un tag.
--
-- La regola, decisa il 2026-10-27 e il 2026-10-28:
--   - parole cambiate (fn_solo_testo diverso, anche solo in un blocco) → tutto da rifare,
--     come prima;
--   - solo formattazione → ogni traduzione riceve la formattazione nuova BLOCCO PER BLOCCO
--     (paragrafi, titoletti, voci d'elenco, citazioni): il tipo e gli attributi del blocco e
--     gli elenchi vengono dall'italiano nuovo, le parole tradotte restano. Righe vuote
--     aggiunte o tolte passano anche alle traduzioni;
--   - dentro un blocco: un grassetto/corsivo/link su TUTTO il blocco passa alla traduzione;
--     su alcune parole no (non si sa quali parole tradotte siano), ma la traduzione resta
--     valida (decisione A di Adriano, 2026-10-28);
--   - una traduzione con un numero di blocchi diverso dall'italiano → da rifare solo lei;
--   - le traduzioni riviste a mano restano riviste.
-- Quill 1.3.6 scrive blocchi piatti (mai un blocco dentro un altro; gli elenchi sono
-- <ul>/<ol> con dentro <li>): per questo «blocco per blocco» si può fare con certezza.
--
--   - fn_html_blocchi, fn_html_involucro, fn_html_riporta_formattazione: la regola sul solo
--     testo, senza tabelle;
--   - fn_web_traduzioni_dopo_modifica(azienda, entità, id, campo, vecchio, nuovo) e
--     fn_web_traduzioni_dopo_modifica_global (entità comuni a tutte le aziende): prendono il
--     posto di fn_web_traduzioni_marca_obsolete quando l'italiano cambia; restituiscono
--     quante traduzioni sono diventate da rifare;
--   - fn_web_sito_faq_save: come la 704, con la regola nuova per gruppo, domanda e risposta.
-- Il gestionale (C#) chiama fn_web_traduzioni_dopo_modifica in tutti i punti dove prima
-- marcava da rifare. Rigiocabile. Test: Test_706_Traduzioni_Solo_Formattazione.sql
-- ============================================================================
BEGIN;

-- I blocchi di un frammento HTML di Quill: apertura, contenuto e chiusura di ciascuno, e ciò che
-- sta fra un blocco e l'altro (gli elenchi; 'fra' ha un elemento in più dei blocchi). Un testo
-- senza blocchi è un blocco solo, senza tag.
CREATE OR REPLACE FUNCTION fn_html_blocchi(p_html text,
    OUT aperture text[], OUT interni text[], OUT chiusure text[], OUT fra text[])
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    -- il contenuto di un blocco non può contenere la chiusura di un blocco (Quill non li annida)
    re constant text := '(<(?:p|h[1-6]|li|blockquote|pre)(?:\s[^>]*)?>)'
                     || '((?:[^<]|<(?!/(?:p|h[1-6]|li|blockquote|pre)>))*)'
                     || '(</(?:p|h[1-6]|li|blockquote|pre)>)';
    m text[];
BEGIN
    aperture := '{}'; interni := '{}'; chiusure := '{}';
    FOR m IN SELECT regexp_matches(coalesce(p_html, ''), re, 'g') LOOP
        aperture := aperture || m[1];
        interni  := interni  || m[2];
        chiusure := chiusure || m[3];
    END LOOP;
    IF cardinality(interni) = 0 THEN
        aperture := ARRAY['']; interni := ARRAY[coalesce(p_html, '')]; chiusure := ARRAY['']; fra := ARRAY['', ''];
    ELSE
        fra := regexp_split_to_array(coalesce(p_html, ''), re);
    END IF;
END $$;

-- La formattazione che avvolge TUTTO il contenuto di un blocco (<strong>…</strong>, anche più
-- d'una: <strong><em>…</em></strong>): 'prima' e 'dopo' sono i tag, 'nucleo' ciò che avvolgono.
CREATE OR REPLACE FUNCTION fn_html_involucro(p_interno text, OUT prima text, OUT nucleo text, OUT dopo text)
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE m text[];
BEGIN
    prima := ''; dopo := ''; nucleo := coalesce(p_interno, '');
    LOOP
        m := regexp_match(nucleo, '^(<(strong|em|u|s|a|span|code|sub|sup)(?:\s[^>]*)?>)(.*)(</\2>)$');
        -- <strong>A</strong> e <strong>B</strong> comincia e finisce col grassetto, ma non è tutto in grassetto
        EXIT WHEN m IS NULL OR position('</' || m[2] || '>' IN m[3]) > 0;
        prima := prima || m[1]; dopo := m[4] || dopo; nucleo := m[3];
    END LOOP;
END $$;

-- La traduzione con la formattazione dell'italiano nuovo, oppure NULL se va rifatta.
CREATE OR REPLACE FUNCTION fn_html_riporta_formattazione(p_vecchio text, p_nuovo text, p_traduzione text)
RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    v record; n record; t record;
    pv int[]; pn int[]; pt int[];      -- i blocchi con parole (le righe vuote no)
    iv record; inn record; it record;
    k int := 0;
    r text;
    c text;
BEGIN
    IF p_vecchio IS NOT DISTINCT FROM p_nuovo THEN
        RETURN p_traduzione;
    END IF;
    IF fn_solo_testo(p_vecchio) IS DISTINCT FROM fn_solo_testo(p_nuovo) THEN
        RETURN NULL;                                        -- parole cambiate
    END IF;

    v := fn_html_blocchi(p_vecchio); n := fn_html_blocchi(p_nuovo); t := fn_html_blocchi(p_traduzione);
    -- parole fuori dai blocchi (Quill non ne scrive): non si saprebbe dove metterle
    IF fn_solo_testo(array_to_string(v.fra, '')) IS NOT NULL OR fn_solo_testo(array_to_string(n.fra, '')) IS NOT NULL
       OR fn_solo_testo(array_to_string(t.fra, '')) IS NOT NULL THEN
        RETURN NULL;
    END IF;

    SELECT coalesce(array_agg(i ORDER BY i), '{}') INTO pv FROM generate_subscripts(v.interni, 1) i WHERE fn_solo_testo(v.interni[i]) IS NOT NULL;
    SELECT coalesce(array_agg(i ORDER BY i), '{}') INTO pn FROM generate_subscripts(n.interni, 1) i WHERE fn_solo_testo(n.interni[i]) IS NOT NULL;
    SELECT coalesce(array_agg(i ORDER BY i), '{}') INTO pt FROM generate_subscripts(t.interni, 1) i WHERE fn_solo_testo(t.interni[i]) IS NOT NULL;
    IF cardinality(pv) <> cardinality(pn) OR cardinality(pt) <> cardinality(pn) THEN
        RETURN NULL;                                        -- blocchi spezzati o uniti, o traduzione diversa
    END IF;
    FOR k IN 1 .. cardinality(pn) LOOP
        IF fn_solo_testo(v.interni[pv[k]]) IS DISTINCT FROM fn_solo_testo(n.interni[pn[k]]) THEN
            RETURN NULL;                                    -- parole spostate da un blocco all'altro
        END IF;
    END LOOP;

    -- si ricompone l'italiano nuovo con dentro le parole tradotte
    r := n.fra[1]; k := 0;
    FOR i IN 1 .. cardinality(n.interni) LOOP
        IF fn_solo_testo(n.interni[i]) IS NULL THEN
            c := n.interni[i];                              -- riga vuota: com'è in italiano
        ELSE
            k := k + 1;
            c := t.interni[pt[k]];
            iv := fn_html_involucro(v.interni[pv[k]]);
            inn := fn_html_involucro(n.interni[i]);
            IF iv.prima <> inn.prima OR iv.dopo <> inn.dopo THEN
                it := fn_html_involucro(c);
                c := inn.prima || it.nucleo || inn.dopo;    -- formattazione di tutto il blocco
            END IF;
        END IF;
        r := r || n.aperture[i] || c || n.chiusure[i] || n.fra[i + 1];
    END LOOP;
    RETURN r;
END $$;

-- L'italiano di un campo è cambiato: ogni traduzione valida riceve la formattazione nuova o
-- diventa da rifare. p_azienda_id NULL = entità comune a tutte le aziende (solo da _global).
CREATE OR REPLACE FUNCTION fn_web_traduzioni_dopo_modifica_tutte(
    p_azienda_id integer, p_entita varchar, p_entita_id bigint, p_campo varchar, p_vecchio text, p_nuovo text)
RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
    t   record;
    r   text;
    v_n integer := 0;
BEGIN
    IF p_vecchio IS NOT DISTINCT FROM p_nuovo THEN
        RETURN 0;
    END IF;
    FOR t IN SELECT x.web_traduzioni_id, x.testo FROM web_traduzioni x
              WHERE x.entita = p_entita AND x.entita_id = p_entita_id AND x.campo = p_campo AND NOT x.obsoleto
                AND (p_azienda_id IS NULL OR x.azienda_id = p_azienda_id)
              FOR UPDATE LOOP
        r := fn_html_riporta_formattazione(p_vecchio, p_nuovo, t.testo);
        IF r IS NULL THEN
            UPDATE web_traduzioni SET obsoleto = TRUE WHERE web_traduzioni_id = t.web_traduzioni_id;
            v_n := v_n + 1;
        ELSIF r IS DISTINCT FROM t.testo THEN
            UPDATE web_traduzioni SET testo = r WHERE web_traduzioni_id = t.web_traduzioni_id;
        END IF;
    END LOOP;
    RETURN v_n;
END $$;

CREATE OR REPLACE FUNCTION fn_web_traduzioni_dopo_modifica(
    p_azienda_id integer, p_entita varchar, p_entita_id bigint, p_campo varchar, p_vecchio text, p_nuovo text)
RETURNS integer
LANGUAGE plpgsql AS $$
BEGIN
    IF p_azienda_id IS NULL THEN
        RAISE EXCEPTION 'Azienda mancante (per le entità comuni: fn_web_traduzioni_dopo_modifica_global).';
    END IF;
    RETURN fn_web_traduzioni_dopo_modifica_tutte(p_azienda_id, p_entita, p_entita_id, p_campo, p_vecchio, p_nuovo);
END $$;

-- Entità comuni (web_tipi_viaggio_descrizioni): la traduzione è una sola, chiunque l'abbia fatta.
CREATE OR REPLACE FUNCTION fn_web_traduzioni_dopo_modifica_global(
    p_entita varchar, p_entita_id bigint, p_campo varchar, p_vecchio text, p_nuovo text)
RETURNS integer
LANGUAGE sql AS $$
    SELECT fn_web_traduzioni_dopo_modifica_tutte(NULL, p_entita, p_entita_id, p_campo, p_vecchio, p_nuovo);
$$;

-- Le FAQ: la 704 con la regola nuova al posto di fn_web_traduzioni_marca_obsolete.
CREATE OR REPLACE FUNCTION fn_web_sito_faq_save(p_azienda_id integer, p_gruppi jsonb, p_utente varchar)
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    g        jsonb;
    q        jsonb;
    gi       bigint;
    qi       bigint;
    v_gid    bigint;
    v_qid    bigint;
    v_nome   text;
    v_dom    text;
    v_risp   text;
    v_att    boolean;
    v_vecchio_nome text;
    v_vecchia_dom  text;
    v_vecchia_risp text;
    v_tenuti_g bigint[] := '{}';
    v_tenuti_q bigint[] := '{}';
BEGIN
    IF jsonb_typeof(coalesce(p_gruppi, '[]'::jsonb)) <> 'array' THEN
        RAISE EXCEPTION 'Elenco dei gruppi non valido.';
    END IF;

    FOR g, gi IN SELECT e.value, e.ordinality FROM jsonb_array_elements(coalesce(p_gruppi, '[]'::jsonb)) WITH ORDINALITY e LOOP
        v_nome := nullif(btrim(g->>'nome'), '');
        IF v_nome IS NULL THEN
            RAISE EXCEPTION 'Il gruppo n. % non ha un nome.', gi;
        END IF;
        IF g->>'id' IS NOT NULL THEN
            v_gid := (g->>'id')::bigint;
            SELECT x.nome INTO v_vecchio_nome FROM web_sito_faq_gruppi x
             WHERE x.web_sito_faq_gruppi_id = v_gid AND x.azienda_id = p_azienda_id;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Il gruppo % non è dell''azienda %.', v_gid, p_azienda_id;
            END IF;
            PERFORM fn_web_traduzioni_dopo_modifica(p_azienda_id, 'web_sito_faq_gruppi', v_gid, 'nome', v_vecchio_nome, v_nome);
            UPDATE web_sito_faq_gruppi
               SET nome = v_nome, ordine = gi, updated_by = p_utente, updated = now()
             WHERE web_sito_faq_gruppi_id = v_gid AND (nome IS DISTINCT FROM v_nome OR ordine IS DISTINCT FROM gi);
        ELSE
            INSERT INTO web_sito_faq_gruppi (azienda_id, ordine, nome, updated_by)
            VALUES (p_azienda_id, gi, v_nome, p_utente)
            RETURNING web_sito_faq_gruppi_id INTO v_gid;
        END IF;
        v_tenuti_g := v_tenuti_g || v_gid;

        FOR q, qi IN SELECT e.value, e.ordinality FROM jsonb_array_elements(coalesce(g->'domande', '[]'::jsonb)) WITH ORDINALITY e LOOP
            v_dom  := nullif(btrim(q->>'domanda'), '');
            v_risp := fn_web_sito_html_pieno(q->>'risposta');
            v_att  := coalesce((q->>'attiva')::boolean, true);
            IF v_dom IS NULL THEN
                RAISE EXCEPTION 'La domanda n. % del gruppo «%» è vuota.', qi, v_nome;
            END IF;
            IF q->>'id' IS NOT NULL THEN
                v_qid := (q->>'id')::bigint;
                SELECT x.domanda, x.risposta INTO v_vecchia_dom, v_vecchia_risp FROM web_sito_faq x
                 WHERE x.web_sito_faq_id = v_qid AND x.azienda_id = p_azienda_id;
                IF NOT FOUND THEN
                    RAISE EXCEPTION 'La domanda % non è dell''azienda %.', v_qid, p_azienda_id;
                END IF;
                PERFORM fn_web_traduzioni_dopo_modifica(p_azienda_id, 'web_sito_faq', v_qid, 'domanda', v_vecchia_dom, v_dom);
                PERFORM fn_web_traduzioni_dopo_modifica(p_azienda_id, 'web_sito_faq', v_qid, 'risposta', v_vecchia_risp, v_risp);
                UPDATE web_sito_faq
                   SET gruppo_fk = v_gid, ordine = qi, domanda = v_dom, risposta = v_risp, attiva = v_att,
                       updated_by = p_utente, updated = now()
                 WHERE web_sito_faq_id = v_qid
                   AND (gruppo_fk, ordine, domanda, risposta, attiva) IS DISTINCT FROM (v_gid, qi, v_dom, v_risp, v_att);
            ELSE
                INSERT INTO web_sito_faq (gruppo_fk, azienda_id, ordine, domanda, risposta, attiva, updated_by)
                VALUES (v_gid, p_azienda_id, qi, v_dom, v_risp, v_att, p_utente)
                RETURNING web_sito_faq_id INTO v_qid;
            END IF;
            v_tenuti_q := v_tenuti_q || v_qid;
        END LOOP;
    END LOOP;

    -- ciò che non è più nell'elenco si cancella, con le sue traduzioni (nessuna traduzione orfana)
    DELETE FROM web_traduzioni t
     WHERE t.azienda_id = p_azienda_id AND t.entita = 'web_sito_faq'
       AND t.entita_id IN (SELECT x.web_sito_faq_id FROM web_sito_faq x
                            WHERE x.azienda_id = p_azienda_id AND NOT x.web_sito_faq_id = ANY (v_tenuti_q));
    DELETE FROM web_sito_faq x WHERE x.azienda_id = p_azienda_id AND NOT x.web_sito_faq_id = ANY (v_tenuti_q);
    DELETE FROM web_traduzioni t
     WHERE t.azienda_id = p_azienda_id AND t.entita = 'web_sito_faq_gruppi'
       AND t.entita_id IN (SELECT x.web_sito_faq_gruppi_id FROM web_sito_faq_gruppi x
                            WHERE x.azienda_id = p_azienda_id AND NOT x.web_sito_faq_gruppi_id = ANY (v_tenuti_g));
    DELETE FROM web_sito_faq_gruppi x WHERE x.azienda_id = p_azienda_id AND NOT x.web_sito_faq_gruppi_id = ANY (v_tenuti_g);
END;
$$;

-- Permessi: solo il gestionale (in PROD una funzione nuova nasce eseguibile da chiunque;
-- CREATE OR REPLACE di fn_web_sito_faq_save conserva quelli della 704).
DO $$
DECLARE f text;
BEGIN
    FOREACH f IN ARRAY ARRAY['fn_html_blocchi(text)', 'fn_html_involucro(text)',
                             'fn_html_riporta_formattazione(text, text, text)',
                             'fn_web_traduzioni_dopo_modifica_tutte(integer, varchar, bigint, varchar, text, text)',
                             'fn_web_traduzioni_dopo_modifica(integer, varchar, bigint, varchar, text, text)',
                             'fn_web_traduzioni_dopo_modifica_global(varchar, bigint, varchar, text, text)'] LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, authenticated', f);
        END IF;
    END LOOP;
END $$;

COMMIT;
