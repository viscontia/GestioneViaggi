-- L'ereditarieta' delle traduzioni non deve rompersi per un grassetto.
--
-- Il confronto era sul testo ESATTO: il corpo del blocco doveva essere identico a
-- '<p>' || sottotitolo del tour || '</p>'. Bastava che l'utente mettesse in grassetto la frase —
-- <p><strong>Dalla Gallura all'Ogliastra</strong></p> — perche' il confronto fallisse e il
-- riquadro restasse senza traduzioni, pur avendo esattamente le parole del tour.
--
-- La domanda giusta non e' "il markup e' identico?" ma "le PAROLE sono ancora quelle del tour?".
-- Se lo sono, la traduzione della scheda vale, e va applicata dentro la formattazione che
-- l'utente ha scelto: si sostituisce il testo lasciando i tag al loro posto, cosi' il grassetto
-- resta grassetto anche in tedesco.
--
-- Restano fuori i casi in cui l'utente ha scritto ALTRO: se il testo spogliato dei tag non
-- coincide — una frase aggiunta, una parola cambiata — non si eredita niente, perche' non
-- sapremmo tradurre la parte nuova e una traduzione a meta' e' peggio di nessuna.

-- Testo puro di un frammento HTML: serve a confrontare due contenuti guardando cio' che si legge
-- e non come e' scritto.
CREATE OR REPLACE FUNCTION fn_solo_testo(p_html TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT NULLIF(btrim(regexp_replace(
             regexp_replace(COALESCE(p_html, ''), '<[^>]*>', '', 'g'),  -- via i tag
             '(&nbsp;|\s)+', ' ', 'g')), '');                          -- spazi normalizzati
$$;

COMMENT ON FUNCTION fn_solo_testo(TEXT) IS
'Testo leggibile di un frammento HTML: tag rimossi, spazi normalizzati. Per confronti di contenuto.';

CREATE OR REPLACE FUNCTION fn_web_newsletter_blocco_eredita_traduzioni(
    p_blocco_id BIGINT, p_azienda_id INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
    v_contenuto_id BIGINT;
    v_sottotitolo  TEXT;
    v_corpo        TEXT;
    v_n            INTEGER := 0;
BEGIN
    SELECT c.web_tour_contenuti_id, NULLIF(btrim(c.sottotitolo), ''), b.corpo_html
      INTO v_contenuto_id, v_sottotitolo, v_corpo
      FROM web_newsletter_blocchi b
      JOIN web_tour_contenuti c ON c.data_viaggio_id_fk = b.data_viaggio_id_fk
                               AND c.azienda_id = b.azienda_id
     WHERE b.web_newsletter_blocchi_id = p_blocco_id
       AND b.azienda_id = p_azienda_id
       AND b.tipo = 'tour';

    IF v_contenuto_id IS NULL OR v_sottotitolo IS NULL OR v_corpo IS NULL THEN
        RETURN 0;
    END IF;

    -- Confronto sul testo, non sul markup: si spogliano entrambi dei tag e si normalizzano gli
    -- spazi. &nbsp; diventa spazio perche' gli editor di testo ricco lo inseriscono da soli.
    IF fn_solo_testo(v_corpo) IS DISTINCT FROM fn_solo_testo(v_sottotitolo) THEN
        RETURN 0;
    END IF;

    -- La traduzione entra DENTRO la formattazione del blocco: si sostituisce la frase italiana
    -- lasciando i tag dove sono. Se la sostituzione non trova nulla (l'utente ha spezzato la
    -- frase con dei tag in mezzo) si ripiega sul paragrafo semplice: meglio tradotto e senza
    -- grassetto che non tradotto.
    INSERT INTO web_traduzioni(entita, entita_id, campo, lingua, testo,
                               tradotto_auto, revisionato, obsoleto, data_traduzione, azienda_id, created_by)
    SELECT 'web_newsletter_blocchi', p_blocco_id, 'corpo_html', t.lingua,
           COALESCE(NULLIF(replace(v_corpo, v_sottotitolo, t.testo), v_corpo),
                    '<p>' || t.testo || '</p>'),
           t.tradotto_auto, t.revisionato, FALSE, t.data_traduzione, t.azienda_id, current_user
      FROM web_traduzioni t
     WHERE t.entita = 'web_tour_contenuti'
       AND t.entita_id = v_contenuto_id
       AND t.campo = 'sottotitolo'
       AND t.azienda_id = p_azienda_id
       AND NOT t.obsoleto
       AND NULLIF(btrim(t.testo), '') IS NOT NULL
    ON CONFLICT (entita, entita_id, campo, lingua) DO UPDATE
        SET testo = EXCLUDED.testo,
            obsoleto = FALSE,
            revisionato = EXCLUDED.revisionato,
            tradotto_auto = EXCLUDED.tradotto_auto;

    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

DO $$
BEGIN
    IF fn_solo_testo('<p><strong>Dalla Gallura all''Ogliastra</strong></p>')
       IS DISTINCT FROM fn_solo_testo('Dalla Gallura all''Ogliastra') THEN
        RAISE EXCEPTION 'fn_solo_testo non normalizza come atteso';
    END IF;
    RAISE NOTICE 'fn_solo_testo: grassetto e paragrafo danno lo stesso testo.';
END $$;
