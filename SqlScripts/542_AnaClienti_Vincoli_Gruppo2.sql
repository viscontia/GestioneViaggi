-- =============================================================================
-- 542 — ana_clienti: i vincoli che lo storico non rispetta
-- =============================================================================
-- Secondo passo della centralizzazione. Qui stanno le regole che sui dati reali
-- di PROD hanno qualche violazione: 14 righe in tutto, misurate il 2026-08-20.
--
-- Il telefono si e' rivelato un caso diverso dagli altri due: le uniche due
-- violazioni erano numeri veri scritti col punto e con la barra (339.1277321,
-- 338/7320531), separatori italiani comunissimi. Li' era la REGOLA a essere
-- troppo stretta, non il dato — quindi si allarga la regola e il vincolo nasce
-- gia' valido su tutte le righe.
--
-- Codice fiscale e indirizzo sono invece difetti veri, e non si possono indovinare:
-- tre CF troncati e uno che non e' un CF; indirizzi come "32", "A", "VIA", "QQQ" e
-- uno stringa vuota. Per questi si usa NOT VALID.
--
--   NOT VALID non e' un vincolo piu' debole: su INSERT e UPDATE e' identico a
--   uno normale. Semplicemente non torna indietro a bocciare le righe gia' scritte.
--   Serve esattamente a questo: la regola vale da adesso, lo storico resta com'e'.
--
--   ⚠️ Conseguenza da conoscere: riaprendo e salvando una di quelle 12 schede il
--   vincolo scatta, e il dato va sistemato prima di poter salvare. E' una bonifica
--   graduale, non un blocco permanente. Per validarle tutte in un secondo momento:
--       ALTER TABLE ana_clienti VALIDATE CONSTRAINT <nome>;
--   che riesce solo quando non resta piu' nessuna violazione.
-- =============================================================================

BEGIN;

-- 1. Telefono: cifre, spazi, + ( ) - e anche . e / --------------------------------
ALTER TABLE ana_clienti DROP CONSTRAINT IF EXISTS ana_clienti_telefono_caratteri_check;
ALTER TABLE ana_clienti ADD CONSTRAINT ana_clienti_telefono_caratteri_check
    CHECK (cliente_telefono IS NULL OR btrim(cliente_telefono) = ''
           OR cliente_telefono ~ '^[0-9 +()./-]+$');

-- 2. Codice fiscale: se c'e', sono 16 caratteri ------------------------------------
ALTER TABLE ana_clienti DROP CONSTRAINT IF EXISTS ana_clienti_codicefiscale_lunghezza_check;
ALTER TABLE ana_clienti ADD CONSTRAINT ana_clienti_codicefiscale_lunghezza_check
    CHECK (cliente_codicefiscale IS NULL OR btrim(cliente_codicefiscale) = ''
           OR length(btrim(cliente_codicefiscale)) = 16) NOT VALID;

-- 3. Indirizzo di residenza: se c'e', dice qualcosa ---------------------------------
ALTER TABLE ana_clienti DROP CONSTRAINT IF EXISTS ana_clienti_indirizzo_minimo_check;
ALTER TABLE ana_clienti ADD CONSTRAINT ana_clienti_indirizzo_minimo_check
    CHECK (cliente_indirizzo_residenza IS NULL OR btrim(cliente_indirizzo_residenza) = ''
           OR length(btrim(cliente_indirizzo_residenza)) >= 5) NOT VALID;

COMMENT ON CONSTRAINT ana_clienti_codicefiscale_lunghezza_check ON ana_clienti IS
'NOT VALID: su PROD 4 codici fiscali storici sono troncati o non sono codici fiscali. La regola vale sui nuovi e sulle modifiche, lo storico resta.';
COMMENT ON CONSTRAINT ana_clienti_indirizzo_minimo_check ON ana_clienti IS
'NOT VALID: su PROD 8 indirizzi storici sono spazzatura ("32", "A", "VIA", "QQQ"). Stessa logica del vincolo sul codice fiscale.';

COMMIT;
