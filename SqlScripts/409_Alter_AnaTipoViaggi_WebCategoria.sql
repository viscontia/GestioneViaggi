ALTER TABLE ana_tipo_viaggi
    ADD COLUMN web_categoria_fk BIGINT NULL
    REFERENCES web_categorie_sport(web_categorie_sport_id) ON DELETE SET NULL;
