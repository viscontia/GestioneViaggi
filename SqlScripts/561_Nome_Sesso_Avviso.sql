-- =============================================================================
-- 561 — L'avviso nome/sesso scende nel database (una regola, un posto solo)
-- =============================================================================
-- La regola esisteva solo in C#, in CoerenzaNomeSessoValidator: quindi il sito di
-- iscrizione non ce l'aveva, e chi si registrava da li' poteva restare "SIG."
-- chiamandosi FRANCESCA senza che nessuno lo notasse. Il gestionale lo segnalava,
-- il sito no: la stessa persona, due comportamenti.
--
-- La lista dei nomi maschili in -a sta in tabella, non nel codice della funzione:
-- e' un dato anagrafico, cambia col tempo, e non deve servire un rilascio per
-- aggiungere un nome. Vale per tutte le aziende — e' lingua italiana, non
-- politica commerciale — quindi e' GLOBALE, come ana_tipo_viaggi.
--
-- Senza la lista l'avviso sarebbe dannoso: misurato sui clienti reali scattava
-- 53 volte su 53 a torto, e 38 erano Andrea e Luca. Un avviso che sbaglia sempre
-- insegna solo a ignorarlo.
--
-- Resta un AVVISO, mai un blocco: Andrea e Luca devono poter passare, e un nome
-- che non sta in lista non e' per questo sbagliato.
-- =============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS ana_nomi_maschili_in_a (
    nome VARCHAR(50) PRIMARY KEY,
    note TEXT
);

COMMENT ON TABLE ana_nomi_maschili_in_a IS
    'Nomi maschili italiani che finiscono in -a. Eccezioni all''avviso nome/sesso. GLOBALE (non per azienda).';

INSERT INTO ana_nomi_maschili_in_a (nome, note) VALUES
    ('ANDREA', NULL), ('LUCA', NULL), ('NICOLA', NULL), ('ELIA', NULL),
    ('MATTIA', NULL), ('ENEA', NULL), ('ISAIA', NULL), ('GEREMIA', NULL),
    ('ZACCARIA', NULL), ('BATTISTA', NULL), ('EVANGELISTA', NULL), ('COSMA', NULL),
    ('GIANLUCA', 'composto attaccato'), ('PIERLUCA', 'composto attaccato'),
    ('GIANANDREA', 'composto attaccato'), ('GIANMARIA', 'composto attaccato'),
    ('PIERMARIA', 'composto attaccato')
ON CONFLICT (nome) DO NOTHING;

-- Restituisce il messaggio d'avviso, oppure NULL se non c'e' nulla da segnalare.
CREATE OR REPLACE FUNCTION fn_nome_sesso_avviso(p_nome VARCHAR, p_sesso CHAR)
RETURNS TEXT AS $$
DECLARE
    v_pulito  TEXT;
    v_pezzi   TEXT[];
    v_ultimo  TEXT;
    v_finale  CHAR;
BEGIN
    v_pulito := btrim(COALESCE(p_nome, ''));
    IF v_pulito = '' OR p_sesso IS NULL THEN
        RETURN NULL;
    END IF;

    -- Conta l'ultima parola: "MARIA GIUSEPPE" e' maschile, "GIUSEPPE MARIA" no.
    v_pezzi  := regexp_split_to_array(upper(v_pulito), '\s+');
    v_ultimo := v_pezzi[array_length(v_pezzi, 1)];
    v_finale := right(v_ultimo, 1);

    IF v_finale = 'A' AND p_sesso = 'M' THEN
        IF EXISTS (SELECT 1 FROM ana_nomi_maschili_in_a WHERE nome = v_ultimo) THEN
            RETURN NULL;
        END IF;
        -- MARIA come secondo nome e' maschile: GIUSEPPE MARIA, CARLO MARIA.
        IF array_length(v_pezzi, 1) > 1 AND v_ultimo = 'MARIA' THEN
            RETURN NULL;
        END IF;
        RETURN format('«%s» sembra un nome femminile, ma il titolo scelto imposta il sesso a M. Controlla il titolo.', v_pulito);
    END IF;

    IF v_finale = 'O' AND p_sesso = 'F' THEN
        RETURN format('«%s» sembra un nome maschile, ma il titolo scelto imposta il sesso a F. Controlla il titolo.', v_pulito);
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

COMMIT;
