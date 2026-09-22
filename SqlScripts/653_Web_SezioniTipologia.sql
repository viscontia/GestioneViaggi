-- ============================================================================
-- Le sezioni del sito: quali mostrare adesso, e con che nome
--
-- COSA RISOLVE. Il sito ha una pagina per ogni genere di viaggio — «Viaggi in
-- 4x4», «Enduro», un domani «E-bike». Quelle pagine non sono scritte a mano nel
-- sito: **compaiono da sole** quando esiste almeno un tour pubblicato di quel
-- genere con una partenza da domani in avanti, e spariscono quando non ce n'è
-- piu' nessuno. Questa funzione e' cio' che il sito chiede per costruire il
-- menu e sapere quali pagine esistono oggi.
--
-- ⭐️ PERCHE' NON BASTAVA GUARDARE `ana_tipo_viaggi`. La mappatura verso la
-- sezione e' N:1 di proposito: «enduro bicilindrici» e «enduro monocilindrici»
-- sono due tipologie nel gestionale e **una sola sezione** sul sito. Il gergo
-- interno non e' il gergo del sito: per chi guarda, la differenza fra bi e
-- monocilindrico non dice niente, quella fra un enduro e un 4x4 si'.
--
-- ⚠️ POGGIA SU `fn_web_tour_pubblicati`, NON RICALCOLA NIENTE. E' la regola che
-- tiene insieme menu e catalogo: se la sezione compare, cliccandola si trovano
-- dei tour — sempre. Riscrivere qui il criterio «pubblicato e con partenza
-- futura» significherebbe che il giorno in cui quel criterio cambia, il menu
-- mostra sezioni che il catalogo non ha, o le nasconde pur avendo tour dentro.
--
-- ⛔️ UNA SEZIONE SENZA TOUR NON COMPARE AFFATTO, e non compare con conteggio
-- zero. Restituirla con zero vorrebbe dire scaricare sul sito la decisione di
-- nasconderla, e prima o poi qualcuno si dimentica di farlo.
--
-- ℹ️ LE SEZIONI SENZA FOTO non si filtrano qui, si presidiano a monte: un tour
-- senza immagine principale non dev'essere pubblicabile. Se il filtro stesse
-- qui, una scheda risulterebbe «pubblicata» nel gestionale e invisibile sul
-- sito, e chi l'ha scritta non capirebbe perche'.
--
-- ORDINE FISSO, dal campo `ordine` della tabella: ⛔️ non per numero di tour.
-- Un menu che si riordina da solo disorienta chi torna sul sito.
--
-- Riferimento: Sito Web SFT/Progettazione/2026-09-22-Disegno_Tappa1_Funzioni_Database.md
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_web_sezioni_tipologia(
    p_azienda_id INTEGER,
    p_lingua     CHAR(2) DEFAULT 'IT'
)
RETURNS TABLE(
    sezione_id       BIGINT,
    nome             VARCHAR,
    slug             VARCHAR,
    ordine           INTEGER,
    tour_disponibili INTEGER
)
LANGUAGE sql STABLE
AS $$
    SELECT d.web_tipi_viaggio_descrizioni_id,
           -- Il nome tradotto se c'e', altrimenti l'italiano.
           -- ⛔️ NESSUN filtro per azienda, ed e' voluto: web_tipi_viaggio_descrizioni
           -- e' una tabella GLOBALE (condivisa fra aziende) e l'unique di
           -- web_traduzioni e' (entita, entita_id, campo, lingua) SENZA azienda —
           -- la traduzione e' unica a prescindere da chi l'abbia prodotta
           -- (script 464). Filtrare per azienda farebbe sparire la traduzione
           -- quando a farla e' stata un'altra azienda: un difetto che si
           -- manifesta solo con la seconda azienda, cioe' quando nessuno lo cerca.
           COALESCE(t.testo, d.descrizione_web)::VARCHAR,
           d.slug,
           d.ordine,
           COUNT(*)::INTEGER
      FROM fn_web_tour_pubblicati(p_azienda_id, p_lingua) p
      JOIN web_tipi_viaggio_descrizioni d
        ON d.slug = p.descrizione_slug
      LEFT JOIN web_traduzioni t
        ON p_lingua <> 'IT'
       AND t.entita   = 'web_tipi_viaggio_descrizioni'
       AND t.entita_id = d.web_tipi_viaggio_descrizioni_id
       AND t.campo    = 'descrizione_web'
       AND t.lingua   = p_lingua
       AND NOT t.obsoleto
     -- Un tour senza sezione collegata non ha una pagina dove stare: resta nel
     -- catalogo generale ma non crea una voce di menu.
     WHERE p.descrizione_slug IS NOT NULL
     GROUP BY d.web_tipi_viaggio_descrizioni_id, t.testo, d.descrizione_web, d.slug, d.ordine
     ORDER BY d.ordine, 2;
$$;

COMMENT ON FUNCTION fn_web_sezioni_tipologia(INTEGER, CHAR) IS
    'Le sezioni da mostrare ADESSO nel menu del sito: quelle con almeno un tour pubblicato e con partenza da domani. Poggia su fn_web_tour_pubblicati per non avere due definizioni di «pubblicato». Nome tradotto senza filtro azienda, perche'' la tabella delle descrizioni e'' globale (script 653).';

-- ============================================================================
-- Il nome della sezione tradotto anche nella scheda tour
--
-- ⚠️ `fn_web_tour_pubblicati` restituiva `descrizione_web` **sempre in
-- italiano**: sulla scheda di un tour, un visitatore tedesco leggeva «Viaggi in
-- 4x4» accanto a tutto il resto tradotto. Ora segue la stessa regola del menu,
-- se no la stessa sezione si chiamerebbe in due modi diversi nelle due pagine.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_web_tour_pubblicati_nome_sezione(
    p_descrizione_id BIGINT,
    p_lingua         CHAR(2),
    p_fallback       VARCHAR
)
RETURNS VARCHAR
LANGUAGE sql STABLE
AS $$
    SELECT COALESCE(
        (SELECT t.testo FROM web_traduzioni t
          WHERE p_lingua <> 'IT'
            AND t.entita = 'web_tipi_viaggio_descrizioni'
            AND t.entita_id = p_descrizione_id
            AND t.campo = 'descrizione_web'
            AND t.lingua = p_lingua
            AND NOT t.obsoleto
          LIMIT 1),
        p_fallback)::VARCHAR;
$$;

COMMENT ON FUNCTION fn_web_tour_pubblicati_nome_sezione(BIGINT, CHAR, VARCHAR) IS
    'Nome della sezione nella lingua richiesta, con ripiego sull''italiano. Senza filtro azienda: la tabella delle descrizioni e'' globale (script 653).';

-- ============================================================================
-- ⛔️ Il difetto latente: il gestionale non vede le traduzioni delle altre aziende
--
-- `fn_web_traduzioni_list_by_entita` filtra `azienda_id = p_azienda_id`. Sui
-- contenuti di un tour va bene — sono di quell'azienda. Su un'entita' GLOBALE
-- come le descrizioni web no, ed ecco cosa succederebbe con due aziende:
--
--   1. l'azienda 6 traduce «FUORISTRADA» -> riga con azienda_id = 6;
--   2. SFT apre lo stesso dialogo e **non vede niente**: il filtro la nasconde;
--   3. SFT traduce -> la upsert va in conflitto sull'unique (entita, entita_id,
--      campo, lingua), che NON contiene l'azienda, e **sovrascrive** quella riga.
--
-- Le due aziende si sovrascrivono a vicenda senza vedersi. ⚠️ E ogni traduzione
-- rifatta e' una **chiamata a Claude pagata**, per riscrivere un testo che c'era
-- gia'.
--
-- Qui la variante che non filtra, sul modello di
-- `fn_web_traduzioni_marca_obsolete_global` (script 464).
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_web_traduzioni_list_by_entita_global(
    p_entita    VARCHAR,
    p_entita_id BIGINT
)
RETURNS SETOF web_traduzioni
LANGUAGE sql STABLE
AS $$
    SELECT * FROM web_traduzioni
     WHERE entita = p_entita AND entita_id = p_entita_id
     ORDER BY campo, lingua;
$$;

COMMENT ON FUNCTION fn_web_traduzioni_list_by_entita_global(VARCHAR, BIGINT) IS
    'Traduzioni di un''entita'' GLOBALE (web_tipi_viaggio_descrizioni), senza filtro azienda: l''unique di web_traduzioni non contiene l''azienda, quindi la traduzione e'' unica a prescindere da chi l''abbia prodotta. Filtrare qui farebbe ritradurre - a pagamento - un testo gia'' esistente (script 653).';

COMMIT;

-- ============================================================================
-- Verifica. ⚠️ Oggi risponde ZERO righe, ed e' corretto: in produzione
-- web_tipi_viaggio_descrizioni e' vuota e nessuna scheda e' pubblicata. La
-- funzione si accende quando Antonio fa il lavoro di redazione.
--
--   SELECT * FROM fn_web_sezioni_tipologia(2);
--   SELECT * FROM fn_web_sezioni_tipologia(2, 'EN');
-- ============================================================================
