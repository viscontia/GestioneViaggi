-- ============================================================================
-- Seed configurazione Resend Email Service in ana_api_config
-- ============================================================================

INSERT INTO ana_api_config (service_code, service_name, config_key, config_value, config_type, config_description, is_secret, is_active, display_order)
VALUES
    ('RESEND', 'Resend Email Service', 'API_KEY', 're_hHApVEDM_Q2d3bGhoYHtqZH7jTqSM1dC2', 'API_KEY', 'API Key per Resend email service', true, true, 1),
    ('RESEND', 'Resend Email Service', 'FROM_EMAIL', 'onboarding@resend.dev', 'TEXT', 'Email mittente Resend (default)', false, true, 2)
ON CONFLICT (service_code, config_key) DO NOTHING;
