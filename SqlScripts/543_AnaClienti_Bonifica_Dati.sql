-- =============================================================================
-- 543 — ana_clienti: bonifica dei dati (idempotente)
-- =============================================================================
-- Ripulisce cio' che i vincoli di 541/542 hanno fatto emergere. Misurato su PROD
-- il 2026-08-20 e autorizzato dal committente. Idempotente: rieseguirlo non fa
-- danni e non cambia nulla se e' gia' stato applicato.
--
-- ⚠️ cliente_preftelint NON viene toccato, deliberatamente. Ha 447 righe con uno
--    spazio in coda, ma NON e' sporcizia: e' formattazione voluta. La newsletter
--    concatena prefisso e numero (fn_web_destinatari_newsletter), quindi "+39 "
--    produce "+39 3931557715" mentre un btrim darebbe "+393931557715".
--    Ripulirlo avrebbe peggiorato 435 numeri. Semmai l'incoerenza e' al contrario:
--    33 righe hanno il prefisso senza spazio. Da decidere a parte.
-- =============================================================================

BEGIN;

-- ⚠️ ORDINE OBBLIGATORIO: prima si sanano i valori non validi, poi si normalizza.
--    I vincoli NOT VALID di 542 scattano su QUALSIASI update della riga, anche su un
--    semplice btrim del cognome: una scheda con spazi nel nome E codice fiscale
--    malformato verrebbe respinta prima di arrivare al passo che sana il codice
--    fiscale. (Successo davvero, in locale, al primo tentativo.)

-- 1. Codici fiscali che non sono codici fiscali ------------------------------------
-- Tre troncati e uno di sole cifre. Non si possono indovinare, e un CF sbagliato e'
-- peggio di nessun CF: sembra valido, e il controllo anti-omonimia ci si appoggia.
UPDATE ana_clienti SET cliente_codicefiscale = NULL
 WHERE cliente_codicefiscale IS NOT NULL AND length(btrim(cliente_codicefiscale)) <> 16;

-- 2. Indirizzi che non sono indirizzi ----------------------------------------------
-- "32", "A", "VIA", "QQQ". Toglierli rende visibile che l'indirizzo manca, invece
-- di far credere che ci sia.
UPDATE ana_clienti SET cliente_indirizzo_residenza = NULL
 WHERE cliente_indirizzo_residenza IS NOT NULL AND length(btrim(cliente_indirizzo_residenza)) < 5;
-- 3. Stringa vuota: non e' un valore, e' rumore -----------------------------------
UPDATE ana_clienti SET cliente_codicefiscale = NULL WHERE btrim(cliente_codicefiscale) = '';
UPDATE ana_clienti SET cliente_indirizzo_residenza = NULL WHERE btrim(cliente_indirizzo_residenza) = '';
UPDATE ana_clienti SET cliente_email = NULL WHERE btrim(cliente_email) = '';
UPDATE ana_clienti SET cliente_telefono = NULL WHERE btrim(cliente_telefono) = '';
UPDATE ana_clienti SET cliente_iban = NULL WHERE btrim(cliente_iban) = '';

-- 4. Spazi in testa e in coda: non sono informazione ------------------------------
UPDATE ana_clienti SET cliente_cognome = btrim(cliente_cognome)
 WHERE cliente_cognome <> btrim(cliente_cognome);
UPDATE ana_clienti SET cliente_nome = btrim(cliente_nome)
 WHERE cliente_nome <> btrim(cliente_nome);
UPDATE ana_clienti SET cliente_indirizzo_residenza = btrim(cliente_indirizzo_residenza)
 WHERE cliente_indirizzo_residenza <> btrim(cliente_indirizzo_residenza);
UPDATE ana_clienti SET cliente_documento_rilasciato_da = btrim(cliente_documento_rilasciato_da)
 WHERE cliente_documento_rilasciato_da <> btrim(cliente_documento_rilasciato_da);
UPDATE ana_clienti SET cliente_documento_numero = btrim(cliente_documento_numero)
 WHERE cliente_documento_numero <> btrim(cliente_documento_numero);

COMMIT;
