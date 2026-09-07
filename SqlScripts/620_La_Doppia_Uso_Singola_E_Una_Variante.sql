-- =============================================================================
-- 620 — La doppia uso singola è una VARIANTE, non una sistemazione da scegliere
-- =============================================================================
--
-- Adriano, 2026-09-07: «per una persona sola mostra solo la predefinita: camera
-- singola oppure singola disabili. Se poi l'albergo assegnera' una doppia uso
-- singola al cliente poco interessa: quello che vuole e' dormire in camera da solo».
--
-- ⚠️ Il problema e' che il catalogo mescola due assi, ed e' scritto nell'analisi del
-- 2026-09-05:
--
--   CAMERA SINGOLA             una STANZA: esiste o non esiste in quella struttura
--   CAMERA DOPPIA USO SINGOLA  un PRODOTTO: una doppia venduta a una persona sola
--
-- Sono la stessa cosa per chi si iscrive — «dormo da solo» — e cose diverse per
-- l'albergo. Chiedere a chi prenota di scegliere fra le due e' chiedergli di sapere
-- che camere ha quella struttura, che e' l'unica domanda a cui non puo' rispondere.
--
-- ⛔️ **E non si riconosce dalla descrizione.** «USO SINGOLA» nel nome e' esattamente
-- il tipo di regola che questo progetto ha tolto quattro volte in tre giorni: basta
-- rinominare una riga e il filtro sparisce in silenzio.
--
-- La colonna per dirlo c'e' gia': `ana_tipo_alloggio.tipo_alloggio_fk`, un
-- riferimento a se stessa **mai valorizzato in 17 righe**. Sembra nata proprio per
-- questo — «questa e' una variante di quella» — e finalmente la si usa.
-- =============================================================================

COMMENT ON COLUMN ana_tipo_alloggio.tipo_alloggio_fk IS
'Se valorizzata, questa sistemazione e'' una VARIANTE COMMERCIALE di un''altra: la stessa
stanza venduta con un trattamento diverso. Il caso tipico e'' la doppia uso singola, che e''
una doppia occupata da una persona.
⚠️ Le varianti NON si propongono a chi si iscrive: sceglierebbe fra «dormo da solo» e «dormo
da solo», con l''unica differenza che una dipende da che camere ha l''albergo — cosa che chi
prenota non puo'' sapere. Restano disponibili al gestionale, che parla con la struttura.
⛔️ Non si riconoscono dal nome: si riconoscono da questa colonna.';

-- La doppia uso singola e' una variante della doppia a letti singoli: stessa stanza,
-- un occupante invece di due. Si riconosce QUI una volta sola, dai dati di oggi.
UPDATE ana_tipo_alloggio v
   SET tipo_alloggio_fk = (SELECT b.tipo_alloggio_id FROM ana_tipo_alloggio b
                            WHERE upper(b.tipo_alloggio_descrizione) = 'CAMERA DOPPIA LETTI SINGOLI')
 WHERE upper(v.tipo_alloggio_descrizione) = 'CAMERA DOPPIA USO SINGOLA'
   AND v.tipo_alloggio_fk IS NULL;


-- ---------------------------------------------------------------------------
-- Chi si iscrive non vede le varianti
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_alloggi_tipi_per_capienza(INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION fn_alloggi_tipi_per_capienza(
    p_data_viaggio_id INTEGER,
    p_capienza        INTEGER
)
RETURNS TABLE(tipo_id INTEGER, descrizione VARCHAR, supplemento BOOLEAN, predefinito BOOLEAN)
LANGUAGE sql STABLE AS $$
    SELECT a.tipo_id, a.descrizione, a.supplemento,
           (a.tipo_id = fn_alloggi_tipo_predefinito(p_data_viaggio_id, p_capienza))
    FROM fn_alloggi_tipi_ammessi(p_data_viaggio_id) a
    JOIN ana_tipo_alloggio t ON t.tipo_alloggio_id = a.tipo_id
    WHERE a.posti = p_capienza
      -- ⚠️ Fuori le varianti commerciali: la differenza fra una singola e una doppia
      -- uso singola la decide l'albergo, non chi prenota. Per una persona sola
      -- restano CAMERA SINGOLA e CAMERA SINGOLA DISABILI.
      AND t.tipo_alloggio_fk IS NULL
    -- ⚠️ Le varianti attrezzate per esigenze particolari CI SONO: si mostrano sempre,
    -- non sono predefinite, e non si nascondono dietro una domanda.
    ORDER BY a.mai_proposta, a.supplemento, a.tipo_id;
$$;

COMMENT ON FUNCTION fn_alloggi_tipi_per_capienza(INTEGER, INTEGER) IS
'I tipi di sistemazione che chi si iscrive puo'' scegliere per un gruppo di N persone, con il
segno di quello predefinito. ⚠️ Esclude le VARIANTI COMMERCIALI (tipo_alloggio_fk valorizzata):
la doppia uso singola e'' la stessa richiesta della singola — «dormo da solo» — e sceglierla
richiederebbe di sapere che camere ha l''albergo. Il gestionale usa invece
fn_alloggi_tipi_ammessi, che le mostra tutte: SFT con la struttura ci parla.';


-- ---------------------------------------------------------------------------
-- E non si propone mai una variante d'ufficio
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_alloggi_tipo_predefinito(
    p_data_viaggio_id INTEGER,
    p_persone         INTEGER
)
RETURNS INTEGER
LANGUAGE sql STABLE AS $$
    SELECT a.tipo_id
    FROM fn_alloggi_tipi_ammessi(p_data_viaggio_id) a
    JOIN ana_tipo_alloggio t ON t.tipo_alloggio_id = a.tipo_id
    WHERE p_persone > 0
      AND a.posti = p_persone
      AND NOT a.mai_proposta
      -- Una variante commerciale non si mette mai d'ufficio: e' una decisione
      -- dell'albergo, e finche' non l'ha presa la richiesta e' «una stanza per N».
      AND t.tipo_alloggio_fk IS NULL
    ORDER BY a.supplemento, a.tipo_id
    LIMIT 1;
$$;
