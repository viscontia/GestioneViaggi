-- Correzioni da review consolidata Blocco 1:
-- (1) CHECK lingua (convenzione Dettaglio_Tabelle_DB §CONVENZIONI: IT/FR/EN/DE/ES) su newsletter/reminder.
-- (2) ON DELETE SET NULL sulle FK di arricchimento nullable (cancellare cliente/email non deve essere bloccato).

-- (1) CHECK lingua (NULL passa il CHECK: le colonne nullable restano valide)
ALTER TABLE web_newsletter_iscritti
    ADD CONSTRAINT chk_web_newsletter_iscritti_lingua
    CHECK (lingua IN ('IT','FR','EN','DE','ES'));
ALTER TABLE web_newsletter_invii_destinatari
    ADD CONSTRAINT chk_web_newsletter_invii_destinatari_lingua
    CHECK (lingua IN ('IT','FR','EN','DE','ES'));
ALTER TABLE web_pagamenti_reminder_log
    ADD CONSTRAINT chk_web_pagamenti_reminder_log_lingua
    CHECK (lingua IN ('IT','FR','EN','DE','ES'));

-- (2) FK di arricchimento → ON DELETE SET NULL
ALTER TABLE web_newsletter_iscritti
    DROP CONSTRAINT web_newsletter_iscritti_cliente_fk_fkey,
    ADD  CONSTRAINT web_newsletter_iscritti_cliente_fk_fkey
         FOREIGN KEY (cliente_fk) REFERENCES ana_clienti(cliente_id) ON DELETE SET NULL;
ALTER TABLE web_pagamenti_reminder_regole
    DROP CONSTRAINT web_pagamenti_reminder_regole_ccn_email_fk_fkey,
    ADD  CONSTRAINT web_pagamenti_reminder_regole_ccn_email_fk_fkey
         FOREIGN KEY (ccn_email_fk) REFERENCES ana_aziende_email(email_id) ON DELETE SET NULL;
