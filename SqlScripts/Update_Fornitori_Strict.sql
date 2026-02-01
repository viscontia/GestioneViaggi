-- =========================================================================================
-- MIGRATION SCRIPT: Enforce Tenant Isolation for Supplier Types
-- Objective:
-- 1. Remove concept of "Global Types" (NULL azienda_fk).
-- 2. Assign existing Global Types to Company 2.
-- 3. Duplicate all Types and Suppliers from Company 2 to Company 6.
-- =========================================================================================

-- Wrapped in DO block for PL/pgSQL support
DO $$
BEGIN
    -- 1. Assign existing Global Types to Azienda 2
    RAISE NOTICE 'Updating existing Global Types to Azienda 2...';
    UPDATE ana_tipo_fornitore
    SET azienda_fk = 2
    WHERE azienda_fk IS NULL;

    -- 2. Clean up Indexes that supported Global Types
    DROP INDEX IF EXISTS idx_uniq_tipo_fornitore_sys;

    -- 3. Duplicate Types for Azienda 6 (from Azienda 2)
    -- Check if they exist first to avoid duplication loop if re-run
    IF NOT EXISTS (SELECT 1 FROM ana_tipo_fornitore WHERE azienda_fk = 6) THEN
        RAISE NOTICE 'Duplicating types from Azienda 2 to Azienda 6...';
        INSERT INTO ana_tipo_fornitore (
            azienda_fk,
            descrizione,
            categoria,
            conto_contabile_default
        )
        SELECT 
            6,                      
            descrizione,
            categoria,
            conto_contabile_default
        FROM ana_tipo_fornitore
        WHERE azienda_fk = 2;
    END IF;

    -- 4. Duplicate Suppliers for Azienda 6 (from Azienda 2)
    IF NOT EXISTS (SELECT 1 FROM ana_fornitori WHERE azienda_fk = 6) THEN
        RAISE NOTICE 'Duplicating suppliers from Azienda 2 to Azienda 6...';
        INSERT INTO ana_fornitori (
            azienda_fk,
            ragione_sociale,
            nome_breve,
            indirizzo,
            comune_fk,
            telefono_prefisso,
            telefono_numero,
            email,
            pec,
            sito_web,
            codice_destinatario_sdi,
            partita_iva,
            codice_fiscale,
            tipo_fornitore_fk, 
            attivo,
            priorita,
            note,
            created_by
        )
        SELECT 
            6, 
            f.ragione_sociale,
            f.nome_breve,
            f.indirizzo,
            f.comune_fk,
            f.telefono_prefisso,
            f.telefono_numero,
            f.email,
            f.pec,
            f.sito_web,
            f.codice_destinatario_sdi,
            f.partita_iva,
            f.codice_fiscale,
            -- Subquery to find the corresponding Type ID for Azienda 6
            (
                SELECT new_t.tipo_fornitore_id 
                FROM ana_tipo_fornitore new_t 
                WHERE new_t.azienda_fk = 6 
                  AND new_t.descrizione = old_t.descrizione
                LIMIT 1
            ),
            f.attivo,
            f.priorita,
            f.note,
            f.created_by
        FROM ana_fornitori f
        JOIN ana_tipo_fornitore old_t ON f.tipo_fornitore_fk = old_t.tipo_fornitore_id
        WHERE f.azienda_fk = 2;
    END IF;

    -- 5. Enforce constraints
    RAISE NOTICE 'Enforcing NOT NULL constraint on ana_tipo_fornitore.azienda_fk...';
    ALTER TABLE ana_tipo_fornitore ALTER COLUMN azienda_fk SET NOT NULL;
    
    -- Ensure ana_fornitori.azienda_fk is also NOT NULL
    ALTER TABLE ana_fornitori ALTER COLUMN azienda_fk SET NOT NULL;

    RAISE NOTICE 'Migration completed successfully.';
END $$;
