-- =============================================================================
-- Fix trigger BEFORE INSERT: preserva l'ID originale se già fornito
-- Problema: i trigger assegnavano sempre nextval(), sovrascrivendo l'ID
--           passato durante l'importazione da Excel (migrazione Oracle).
-- Fix:      la sequence viene chiamata SOLO se l'ID è NULL.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ana_mezzi
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ana_mezzi_tgr1_func()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.ana_mezzi_id IS NULL THEN
        NEW.ana_mezzi_id := nextval('ana_mezzi_seq');
    END IF;
    RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. ana_mezzi_modelli
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ana_mezzi_modelli_trg1_func()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.mezzo_modello_id IS NULL THEN
        NEW.mezzo_modello_id := nextval('ana_mezzi_modelli_seq');
    END IF;
    RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. ana_viaggi
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ana_viaggi_trg1_func()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.viaggio_id IS NULL THEN
            NEW.viaggio_id := nextval('ana_viaggi_seq');
        END IF;
        IF NEW.created_by IS NULL THEN
            NEW.created_by := current_user;
        END IF;
        IF NEW.created IS NULL THEN
            NEW.created := now();
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        NEW.updated_by := current_user;
        NEW.updated    := now();
    END IF;
    RETURN NEW;
END;
$$;
