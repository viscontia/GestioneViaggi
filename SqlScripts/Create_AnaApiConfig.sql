-- ============================================================================
-- Creazione Tabella ana_api_config
-- Scopo: Configurazione API esterne (chiavi, URL, parametri) - Solo SuperAdmin
-- Tabella globale (non multi-tenant, no azienda_fk)
-- Creato: 20/02/2026
-- Autore: Adriano Visconti
-- ============================================================================

CREATE TABLE IF NOT EXISTS ana_api_config (
    config_id          SERIAL PRIMARY KEY,
    service_code       VARCHAR(50) NOT NULL,
    service_name       VARCHAR(100) NOT NULL,
    config_key         VARCHAR(100) NOT NULL,
    config_value       TEXT,
    config_type        VARCHAR(20) NOT NULL DEFAULT 'TEXT',
    config_description VARCHAR(255),
    is_secret          BOOLEAN DEFAULT FALSE,
    is_active          BOOLEAN DEFAULT TRUE,
    display_order      SMALLINT DEFAULT 0,
    created_at         TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by         VARCHAR(50),
    updated_at         TIMESTAMP WITH TIME ZONE,
    updated_by         VARCHAR(50),

    -- Vincoli
    CONSTRAINT uk_api_config_service_key UNIQUE (service_code, config_key)
);

-- Indici
CREATE INDEX IF NOT EXISTS idx_api_config_service ON ana_api_config(service_code);
CREATE INDEX IF NOT EXISTS idx_api_config_active ON ana_api_config(is_active) WHERE is_active = TRUE;

-- Commenti
COMMENT ON TABLE ana_api_config IS 'Configurazione API esterne (chiavi, URL, parametri). Tabella globale, gestita solo dal SuperAdmin.';
COMMENT ON COLUMN ana_api_config.service_code IS 'Codice identificativo del servizio (es. EXCHANGE_RATE, EMAIL_SERVICE)';
COMMENT ON COLUMN ana_api_config.service_name IS 'Nome descrittivo del servizio (es. Tassi di Cambio, Servizio Email)';
COMMENT ON COLUMN ana_api_config.config_key IS 'Chiave della configurazione (es. API_KEY, BASE_URL, PROVIDER)';
COMMENT ON COLUMN ana_api_config.config_value IS 'Valore della configurazione';
COMMENT ON COLUMN ana_api_config.config_type IS 'Tipo di configurazione: TEXT, API_KEY, URL, SECRET, BOOLEAN';
COMMENT ON COLUMN ana_api_config.is_secret IS 'Se TRUE, il valore viene mascherato nella UI';
COMMENT ON COLUMN ana_api_config.display_order IS 'Ordine di visualizzazione nella UI';

-- Trigger per updated_at automatico
CREATE TRIGGER trg_touch_updated_at_api_config
    BEFORE UPDATE ON ana_api_config
    FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at_simple();
