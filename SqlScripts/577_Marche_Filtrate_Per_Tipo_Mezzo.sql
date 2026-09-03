-- =============================================================================
-- 577 — Le marche che hanno almeno un mezzo di quel tipo
-- =============================================================================
--
-- All'iscrizione si sceglieva la marca su un elenco unico di 27 voci: chi parte
-- con un'auto 4x4 si trovava davanti prima tutte le marche di moto, e per
-- arrivare alla propria doveva scorrerle tutte o sapere gia' cosa digitare.
-- Sul sito di iscrizione questo passaggio era gia' stato sanato; nel gestionale
-- no, ed e' il difetto che si corregge qui.
--
-- Il tipo (ana_tipo_mezzi) non sta sulla marca ma sul MODELLO
-- (ana_mezzi_modelli.mezzo_modello_tipo_fk): una marca come Suzuki fa sia moto
-- che 4x4, e come tale va bene per entrambi i tipi. Quindi le marche non si
-- filtrano, si DERIVANO: sono quelle che hanno almeno un modello di quel tipo.
--
-- La derivazione sta qui e non in C# perche' e' la stessa domanda che fara' il
-- sito di iscrizione, e due copie della stessa query divergono sempre.
-- =============================================================================

DROP FUNCTION IF EXISTS fn_ana_mezzi_marche_per_tipo(INTEGER);

CREATE OR REPLACE FUNCTION fn_ana_mezzi_marche_per_tipo(
    p_tipo_mezzo_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    ana_mezzi_id          INTEGER,
    ana_mezzi_descrizione VARCHAR
)
LANGUAGE sql
STABLE
AS $$
    SELECT m.ana_mezzi_id, m.ana_mezzi_descrizione
    FROM ana_mezzi m
    WHERE p_tipo_mezzo_id IS NULL
       OR EXISTS (
            SELECT 1
            FROM ana_mezzi_modelli mm
            WHERE mm.mezzo_modello_mezzo_fk = m.ana_mezzi_id
              -- Un modello senza tipo indicato vale per qualunque tipo. Nasconderlo
              -- sarebbe peggio del disordine che evita: impedirebbe di iscrivere chi
              -- parte davvero con quel mezzo, per un dato mancante in tabella.
              AND (mm.mezzo_modello_tipo_fk = p_tipo_mezzo_id
                   OR mm.mezzo_modello_tipo_fk IS NULL)
       )
    ORDER BY m.ana_mezzi_descrizione;
$$;

COMMENT ON FUNCTION fn_ana_mezzi_marche_per_tipo(INTEGER) IS
'Marche (ana_mezzi) che hanno almeno un modello del tipo richiesto. Con NULL le restituisce
tutte. Il tipo sta sul modello, non sulla marca: una marca puo'' fare sia moto che 4x4.';
