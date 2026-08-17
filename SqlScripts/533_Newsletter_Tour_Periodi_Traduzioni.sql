-- Fase 4.3 — il riquadro tour nelle altre lingue.
--
-- Due problemi distinti, che sembravano uno solo.
--
-- 1) IL PERIODO. "Dal 2 al 7 maggio 2026" non e' testo scritto da qualcuno: lo compone
--    fn_web_newsletter_dati_tour dalle date della partenza, e viene salvato sul blocco. Tradurlo
--    fotograferebbe un valore che cambia — spostata la partenza, l'italiano si aggiorna e il
--    tedesco resta indietro in silenzio. Va RIGENERATO nella lingua, e per farlo al momento della
--    composizione servono le date, che sul blocco non ci sono: c'e' solo l'aggancio alla partenza.
--
-- 2) IL TESTO. Il corpo di un riquadro tour e' una copia di web_tour_contenuti.sottotitolo, che
--    E' GIA' TRADOTTO per il sito. Ritradurlo significherebbe pagarlo due volte e ritrovarsi due
--    testi diversi per lo stesso tour, uno sul sito e uno nella mail. Si eredita.
--
--    Ereditare al momento della SCELTA e non al rendering non e' un dettaglio: se il riquadro
--    leggesse la traduzione del tour ogni volta, modificando la scheda dopo aver composto la
--    newsletter si otterrebbe l'italiano vecchio (che e' la copia sul blocco) e il tedesco nuovo
--    (preso dal tour). Due testi che non dicono la stessa cosa, nella stessa mail.

-- =====================================================================
-- 1) Le date delle partenze agganciate ai blocchi
-- =====================================================================
-- Una lettura sola per newsletter: il periodo si ricompone in memoria, per ogni lingua servita.
CREATE OR REPLACE FUNCTION fn_web_newsletter_periodi(p_invio_id BIGINT, p_azienda_id INTEGER)
RETURNS TABLE(blocco_id BIGINT, data_inizio DATE, data_fine DATE)
LANGUAGE sql STABLE AS $$
    SELECT b.web_newsletter_blocchi_id, d.data_viaggio_data_inizio, d.data_viaggio_data_fine
      FROM web_newsletter_blocchi b
      JOIN ana_date_viaggi d ON d.data_viaggio_id = b.data_viaggio_id_fk
     WHERE b.invio_id_fk = p_invio_id
       AND b.azienda_id = p_azienda_id
       AND b.tipo = 'tour'
       AND b.data_viaggio_id_fk IS NOT NULL;
$$;

COMMENT ON FUNCTION fn_web_newsletter_periodi(BIGINT, INTEGER) IS
'Date delle partenze agganciate ai riquadri tour: servono a rigenerare il periodo nella lingua del destinatario.';

-- =====================================================================
-- 2) Il riquadro eredita la traduzione del tour
-- =====================================================================
-- Copia le traduzioni di web_tour_contenuti.sottotitolo nel campo corpo_html del blocco.
--
-- La copia avviene SOLO se il testo italiano del blocco e' ancora quello del tour: e' la verifica
-- che distingue «l'utente ha accettato il testo del tour» da «l'utente l'ha riscritto». Senza,
-- si assegnerebbero a un testo riscritto a mano le traduzioni di un testo diverso — l'errore
-- peggiore possibile, perche' in italiano si legge giusto.
--
-- Il corpo del blocco e' il sottotitolo del tour avvolto in <p>…</p> (lo fa NewsletterTourApplicatore):
-- il confronto e la copia rispettano la stessa forma.
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

    -- Nessuna scheda, nessun sottotitolo, o testo riscritto dall'utente: non si eredita nulla.
    IF v_contenuto_id IS NULL OR v_sottotitolo IS NULL THEN
        RETURN 0;
    END IF;

    IF btrim(COALESCE(v_corpo, '')) IS DISTINCT FROM '<p>' || v_sottotitolo || '</p>' THEN
        RETURN 0;
    END IF;

    -- Si scrive con INSERT diretto e non con fn_web_traduzioni_upsert: quella azzera
    -- "revisionato", e una traduzione del tour gia' riletta e approvata resta valida qui, perche'
    -- il testo e' lo stesso. Le obsolete restano fuori: sono gia' disallineate dall'italiano.
    INSERT INTO web_traduzioni(entita, entita_id, campo, lingua, testo,
                               tradotto_auto, revisionato, obsoleto, data_traduzione, azienda_id, created_by)
    SELECT 'web_newsletter_blocchi', p_blocco_id, 'corpo_html', t.lingua,
           '<p>' || t.testo || '</p>',
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

COMMENT ON FUNCTION fn_web_newsletter_blocco_eredita_traduzioni(BIGINT, INTEGER) IS
'Il riquadro tour eredita le traduzioni del tour, ma solo se il suo testo italiano è ancora quello del tour.';

-- =====================================================================
-- 3) L'ereditarietà scatta da sola
-- =====================================================================
-- Con un trigger e non con una chiamata dal programma: i riquadri tour si creano e si modificano
-- da due percorsi diversi (la form dei blocchi e il riaggancio della partenza), e la clonazione
-- ne aggiunge un terzo. Una chiamata da ricordare in tre punti e' una chiamata che prima o poi
-- manca in uno.
--
-- Nessuna ricorsione: la function scrive su web_traduzioni, non su web_newsletter_blocchi.
CREATE OR REPLACE FUNCTION trg_web_newsletter_blocco_eredita() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.tipo = 'tour' AND NEW.data_viaggio_id_fk IS NOT NULL THEN
        PERFORM fn_web_newsletter_blocco_eredita_traduzioni(NEW.web_newsletter_blocchi_id, NEW.azienda_id);
    END IF;
    RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_web_newsletter_blocchi_eredita ON web_newsletter_blocchi;
CREATE TRIGGER trg_web_newsletter_blocchi_eredita
    AFTER INSERT OR UPDATE OF corpo_html, data_viaggio_id_fk ON web_newsletter_blocchi
    FOR EACH ROW EXECUTE FUNCTION trg_web_newsletter_blocco_eredita();

DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT proname, count(*) AS v FROM pg_proc
              WHERE proname IN ('fn_web_newsletter_periodi','fn_web_newsletter_blocco_eredita_traduzioni')
              GROUP BY proname
    LOOP
        RAISE NOTICE '% -> % versione/i', r.proname, r.v;
        IF r.v > 1 THEN RAISE EXCEPTION 'La function % ha % firme sovrapposte.', r.proname, r.v; END IF;
    END LOOP;
END $$;
