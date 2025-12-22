CREATE OR REPLACE FUNCTION ana_tipo_viaggi_check_delete()
RETURNS TRIGGER AS $$
DECLARE
    v_count_viaggi INTEGER;
    v_count_date_viaggi INTEGER;
    v_count_clienti_viaggi INTEGER;
    v_count_clienti_alloggi INTEGER;
    v_total_count INTEGER;
    v_error_msg TEXT;
BEGIN
    -- 1. Controlla se il tipo di viaggio è utilizzato in ANA_VIAGGI
    SELECT COUNT(*) 
    INTO v_count_viaggi 
    FROM ana_viaggi 
    WHERE viaggio_tipo_viaggio_fk = OLD.tipo_viaggi_id;
    
    -- 2. Controlla se ci sono date viaggi per viaggi che usano questo tipo di viaggio
    SELECT COUNT(*) 
    INTO v_count_date_viaggi 
    FROM ana_date_viaggi dv
    JOIN ana_viaggi v ON dv.viaggio_id_fk = v.viaggio_id
    WHERE v.viaggio_tipo_viaggio_fk = OLD.tipo_viaggi_id;
    
    -- 3. Controlla se ci sono clienti iscritti a viaggi che usano questo tipo di viaggio
    SELECT COUNT(*) 
    INTO v_count_clienti_viaggi 
    FROM mov_clienti_viaggi mcv
    JOIN ana_viaggi v ON mcv.viaggio_id_fk = v.viaggio_id
    WHERE v.viaggio_tipo_viaggio_fk = OLD.tipo_viaggi_id;
    
    -- 4. Controlla se ci sono alloggi per viaggi che usano questo tipo di viaggio
    SELECT COUNT(*) 
    INTO v_count_clienti_alloggi 
    FROM mov_clienti_alloggi mca
    JOIN ana_viaggi v ON mca.viaggio_id_fk = v.viaggio_id
    WHERE v.viaggio_tipo_viaggio_fk = OLD.tipo_viaggi_id;
    
    v_total_count := v_count_viaggi + v_count_date_viaggi + v_count_clienti_viaggi + v_count_clienti_alloggi;
    
    IF v_total_count > 0 THEN
        v_error_msg := 'Impossibile cancellare il tipo di viaggio "' || 
                      OLD.tipo_viaggi_descrizione || '": ';
        
        IF v_count_viaggi > 0 THEN
            v_error_msg := v_error_msg || v_count_viaggi || ' viaggi';
        END IF;
        
        IF v_count_date_viaggi > 0 THEN
            IF v_count_viaggi > 0 THEN
                v_error_msg := v_error_msg || ', ';
            END IF;
            v_error_msg := v_error_msg || v_count_date_viaggi || ' date viaggi';
        END IF;
        
        IF (v_count_clienti_viaggi + v_count_clienti_alloggi) > 0 THEN
            IF v_count_viaggi > 0 OR v_count_date_viaggi > 0 THEN
                v_error_msg := v_error_msg || ' e ';
            END IF;
            v_error_msg := v_error_msg || (v_count_clienti_viaggi + v_count_clienti_alloggi) || 
                          ' prenotazioni clienti collegati';
        END IF;
        
        RAISE EXCEPTION '%', v_error_msg;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER ana_tipo_viaggi_trg2
BEFORE DELETE ON ana_tipo_viaggi
FOR EACH ROW
EXECUTE FUNCTION ana_tipo_viaggi_check_delete();
