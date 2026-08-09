-- Il layout dei blocchi ammette anche 'centro'.
--
-- Nasce da una segnalazione di collaudo: sul blocco "testo" la tendina proponeva
-- "Piena larghezza / Immagine a sinistra / Immagine a destra", che su un blocco senza immagine
-- non vuole dire niente. Per testo, pulsante e immagine la stessa proprieta' significa
-- ALLINEAMENTO, e un allineamento senza "centro" non e' un allineamento.
--
-- Nessuna migrazione dati: 'centro' e' un valore nuovo, i blocchi esistenti restano com'erano.

ALTER TABLE web_newsletter_blocchi
    DROP CONSTRAINT IF EXISTS chk_web_newsletter_blocchi_layout;

ALTER TABLE web_newsletter_blocchi
    ADD CONSTRAINT chk_web_newsletter_blocchi_layout
    CHECK (layout IN ('sinistra','destra','centro','pieno'));

COMMENT ON COLUMN web_newsletter_blocchi.layout IS
'Su tour/immagine: posizione dell''immagine (sinistra|destra|pieno). Su testo/pulsante: allineamento (sinistra|centro|destra).';
