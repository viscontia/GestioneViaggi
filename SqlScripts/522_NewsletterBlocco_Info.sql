-- Nuovo tipo di blocco: "info" — immagine piccola a sinistra, titolo e testo a destra.
--
-- Ricalcato sulla newsletter reale di SFT, dove ricorre tre volte: CHI PUO' PARTECIPARE, COSTI,
-- ADESIONI. Non era coperto dai tipi esistenti: il riquadro tour e' legato a un'edizione e porta
-- un pulsante, il blocco immagine occupa tutta la larghezza e il testo starebbe sotto, non a
-- fianco.
--
-- Differenza dal blocco 'tour', che pure ha immagine a fianco: qui l'immagine e' un'ICONA di
-- accompagnamento (un centinaio di pixel), non una copertina, e non c'e' nessun collegamento.

ALTER TABLE web_newsletter_blocchi DROP CONSTRAINT IF EXISTS chk_web_newsletter_blocchi_tipo;
ALTER TABLE web_newsletter_blocchi
    ADD CONSTRAINT chk_web_newsletter_blocchi_tipo
    CHECK (tipo IN ('intestazione','testata','testo','info','tour','immagine','pulsante','separatore','footer'));

CREATE OR REPLACE FUNCTION fn_web_newsletter_tipi_blocco()
RETURNS TABLE(tipo VARCHAR, etichetta VARCHAR, obbligatorio BOOLEAN, max_occorrenze INTEGER, ordine_catalogo INTEGER)
LANGUAGE sql IMMUTABLE AS $$
    SELECT * FROM (VALUES
        ('intestazione'::VARCHAR, 'Intestazione (logo)'::VARCHAR,      true,  1,    10),
        ('testata',               'Testata con immagine',              false, NULL, 20),
        ('testo',                 'Testo',                             false, NULL, 30),
        ('info',                  'Riquadro informativo (icona + testo)', false, NULL, 35),
        ('tour',                  'Riquadro tour',                     false, NULL, 40),
        ('immagine',              'Immagine',                          false, NULL, 50),
        ('pulsante',              'Pulsante',                          false, NULL, 60),
        ('separatore',            'Separatore',                        false, NULL, 70),
        ('footer',                'Footer societario',                 true,  1,    80)
    ) AS t(tipo, etichetta, obbligatorio, max_occorrenze, ordine_catalogo);
$$;
