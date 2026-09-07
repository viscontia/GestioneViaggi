-- =============================================================================
-- 618 — Il tipo lo sceglie il database, e la capienza non può superare sei
-- =============================================================================
--
-- Due cose che servono a rifare il passo 5 del sito.
--
-- 1. **Il sito non fa scegliere il tipo di sistemazione.** Deciso nell'analisi del
--    2026-09-05: chi si iscrive non puo' sapere se quell'albergo ha le camere
--    singole, quindi il sito raccoglie l'INTENZIONE — «dormiamo insieme o
--    separati?» — e il tipo lo mette il sistema.
--    ⚠️ La regola per sceglierlo esiste gia', ma vive in C#
--    (`TipoAlloggioService.Suggerisci`). Usandola anche da Flask diventerebbero due
--    copie, ed e' esattamente cio' che questo progetto sta togliendo da giorni.
--    Scende qui, e il gestionale chiamera' questa.
--
-- 2. **Il tetto di sei posti diventa un vincolo, non una coincidenza.**
--    `mov_clienti_alloggi` ha SEI colonne cliente. Un tipo da 7 posti si potrebbe
--    inserire a catalogo, le combinazioni lo userebbero, e la scrittura fallirebbe
--    con un errore incomprensibile — o peggio, silenziosamente, perdendo la settima
--    persona. ⚠️ Adriano, 2026-09-07: «questo 6 e' un difetto di analisi molto
--    vecchio, di circa 5 anni fa, ancora su Oracle. Avrei dovuto immaginare un
--    testa-righe. Ma fino ad oggi ha tenuto e casi oltre 6 non si sono mai
--    verificati». Finche' il modello e' questo, il limite va detto dove si sbaglia:
--    nel momento in cui qualcuno prova a superarlo.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Il tetto: sei posti, quante sono le colonne
-- ---------------------------------------------------------------------------
ALTER TABLE ana_tipo_alloggio
    DROP CONSTRAINT IF EXISTS chk_tipo_alloggio_capienza_max;

ALTER TABLE ana_tipo_alloggio
    ADD CONSTRAINT chk_tipo_alloggio_capienza_max
    CHECK (tipo_alloggio_numero_occupanti BETWEEN 0 AND 6);

COMMENT ON CONSTRAINT chk_tipo_alloggio_capienza_max ON ana_tipo_alloggio IS
'Sei e'' il numero di colonne cliente in mov_clienti_alloggi, non una scelta di prodotto.
⚠️ Un tipo con capienza maggiore verrebbe offerto dalle combinazioni e poi non ci starebbe
dentro nessuno. Se un domani servisse di piu'' — una tenda comune, un dormitorio — la strada
non e'' alzare questo numero ma passare a una tabella di righe occupante, come sarebbe stato
giusto fare gia'' su Oracle. Zero e'' ammesso: e'' «nessuna sistemazione».';


-- ---------------------------------------------------------------------------
-- 2. Il tipo predefinito per un gruppo di N persone
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_alloggi_tipo_predefinito(
    p_data_viaggio_id INTEGER,
    p_persone         INTEGER
)
RETURNS INTEGER
LANGUAGE sql STABLE AS $$
    SELECT a.tipo_id
    FROM fn_alloggi_tipi_ammessi(p_data_viaggio_id) a
    WHERE p_persone > 0
      AND a.posti = p_persone
      -- ⚠️ Fuori chi non si propone d'ufficio: una sistemazione attrezzata per
      -- esigenze particolari resta scegliibile, ma non si assegna a chi non l'ha
      -- chiesta (SqlScripts/611).
      AND NOT a.mai_proposta
    -- A parita' di capienza si preferisce quella senza supplemento: e' la piu'
    -- economica per chi viaggia, e resta cambiabile.
    ORDER BY a.supplemento, a.tipo_id
    LIMIT 1;
$$;

COMMENT ON FUNCTION fn_alloggi_tipo_predefinito(INTEGER, INTEGER) IS
'La sistemazione da mettere d''ufficio a un gruppo di N persone su questa partenza, o NULL se
non ce n''e'' una adatta — e allora non si propone niente, invece di proporre una capienza che
poi viene rifiutata. ⚠️ Unica fonte per il sito e per il gestionale: il sito non fa scegliere
il tipo (chi si iscrive non sa se quell''albergo ha le singole), e il gestionale la usa come
proposta. ⛔️ Il tipo non si riconosce MAI dalla descrizione.';


-- ---------------------------------------------------------------------------
-- 3. I tipi di una certa capienza, per l'ultimo passo del sito
-- ---------------------------------------------------------------------------
-- Dove esiste piu' di un tipo per la stessa capienza — matrimoniale o due letti
-- singoli, tripla con matrimoniale o tre singoli — la scelta la puo' fare chi si
-- iscrive: quella la sa. ⚠️ Il filtro sta qui e non nel JavaScript, altrimenti il
-- sito e il gestionale mostrerebbero elenchi diversi.
CREATE OR REPLACE FUNCTION fn_alloggi_tipi_per_capienza(
    p_data_viaggio_id INTEGER,
    p_capienza        INTEGER
)
RETURNS TABLE(tipo_id INTEGER, descrizione VARCHAR, supplemento BOOLEAN, predefinito BOOLEAN)
LANGUAGE sql STABLE AS $$
    SELECT a.tipo_id, a.descrizione, a.supplemento,
           (a.tipo_id = fn_alloggi_tipo_predefinito(p_data_viaggio_id, p_capienza))
    FROM fn_alloggi_tipi_ammessi(p_data_viaggio_id) a
    WHERE a.posti = p_capienza
    -- ⚠️ Le varianti DISABILI ci sono: si mostrano SEMPRE, per rispetto verso chi le
    -- usera' e per non obbligare nessuno a dichiararsi (analisi del 2026-09-05).
    -- Non sono proposte, ma sono in elenco.
    ORDER BY a.mai_proposta, a.supplemento, a.tipo_id;
$$;

COMMENT ON FUNCTION fn_alloggi_tipi_per_capienza(INTEGER, INTEGER) IS
'I tipi di sistemazione che ospitano esattamente N persone su questa partenza, con il segno
di quello predefinito. Le varianti attrezzate per esigenze particolari sono in elenco ma non
predefinite. Sostituisce il filtro che il sito faceva nel JavaScript.';
