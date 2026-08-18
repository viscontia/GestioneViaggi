-- Le traduzioni di una newsletter eliminata devono sparire con lei.
--
-- web_traduzioni e' polimorfica — indirizza (entita, entita_id, campo, lingua) — quindi non puo'
-- avere una chiave esterna verso i blocchi: nessun vincolo le porta via. Eliminando una
-- newsletter i blocchi se ne vanno in CASCADE e le loro traduzioni restano, senza piu' niente a
-- cui riferirsi.
--
-- Non e' un problema di correttezza — nessuno le legge, gli id sono "generated always as
-- identity" e non vengono riusati — ma di accumulo: le newsletter si creano e si buttano di
-- continuo, e ogni giro lascia dietro le sue righe. Se ne accorge anche la traduzione, che per
-- decidere cosa e' gia' fatto rilegge tutte le traduzioni dell'azienda.
--
-- Un trigger e non una chiamata da qualche parte: i blocchi spariscono anche per CASCADE, cioe'
-- senza che nessun codice nostro se ne accorga. Una pulizia da ricordare sarebbe una pulizia che
-- non avviene proprio nel caso piu' frequente.

-- Due funzioni e non una parametrica: plpgsql risolve OLD.<campo> sul record REALE, quindi un
-- riferimento a una colonna che quella tabella non ha fa fallire il trigger anche se sta in un
-- ramo di CASE che non verrebbe scelto. Provato: cancellare un blocco dava
-- "record old has no field web_newsletter_invii_id". La condivisione era un falso risparmio.
CREATE OR REPLACE FUNCTION trg_web_newsletter_blocchi_pulizia_trad() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM web_traduzioni
     WHERE entita = 'web_newsletter_blocchi' AND entita_id = OLD.web_newsletter_blocchi_id;
    RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION trg_web_newsletter_invii_pulizia_trad() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM web_traduzioni
     WHERE entita = 'web_newsletter_invii' AND entita_id = OLD.web_newsletter_invii_id;
    RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_web_newsletter_blocchi_pulizia_traduzioni ON web_newsletter_blocchi;
CREATE TRIGGER trg_web_newsletter_blocchi_pulizia_traduzioni
    AFTER DELETE ON web_newsletter_blocchi
    FOR EACH ROW EXECUTE FUNCTION trg_web_newsletter_blocchi_pulizia_trad();

-- L'oggetto della newsletter e' tradotto sull'invio, non sui blocchi: va tolto anche quello.
DROP TRIGGER IF EXISTS trg_web_newsletter_invii_pulizia_traduzioni ON web_newsletter_invii;
CREATE TRIGGER trg_web_newsletter_invii_pulizia_traduzioni
    AFTER DELETE ON web_newsletter_invii
    FOR EACH ROW EXECUTE FUNCTION trg_web_newsletter_invii_pulizia_trad();

DROP FUNCTION IF EXISTS trg_web_newsletter_traduzioni_pulizia();

-- Pulizia di quanto gia' rimasto indietro. Cancella SOLO cio' che non ha piu' un padre: e'
-- scritto come condizione, non come elenco di id, perche' deve valere anche su PROD dove le
-- righe orfane sono altre.
DO $$
DECLARE v_blocchi INTEGER; v_invii INTEGER;
BEGIN
    DELETE FROM web_traduzioni t
     WHERE t.entita = 'web_newsletter_blocchi'
       AND NOT EXISTS (SELECT 1 FROM web_newsletter_blocchi b
                        WHERE b.web_newsletter_blocchi_id = t.entita_id);
    GET DIAGNOSTICS v_blocchi = ROW_COUNT;

    DELETE FROM web_traduzioni t
     WHERE t.entita = 'web_newsletter_invii'
       AND NOT EXISTS (SELECT 1 FROM web_newsletter_invii i
                        WHERE i.web_newsletter_invii_id = t.entita_id);
    GET DIAGNOSTICS v_invii = ROW_COUNT;

    RAISE NOTICE 'Traduzioni orfane rimosse: % dai blocchi, % dagli invii.', v_blocchi, v_invii;
END $$;
