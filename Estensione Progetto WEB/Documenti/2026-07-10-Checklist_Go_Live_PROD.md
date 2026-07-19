# Checklist Go-Live PROD — Estensione Web

> **Scopo.** Documento **operativo e vivo**: elenca *tutto* ciò che va modificato/configurato in produzione (Supabase) prima di rilasciare l'Estensione Web. Va aggiornato **a ogni nuovo script SQL o requisito di deploy**. In locale si lavora su Docker (`postgres_db`); la PROD è Supabase/PgBouncer.
>
> **Ultimo aggiornamento:** 2026-07-10 (chiusura Blocco 11). **Stato:** NON ancora rilasciato. I test si faranno tutti alla fine.

---

## 1. Migrazione DB — script da applicare in ordine

L'Estensione Web + hardening introducono gli script **`SqlScripts/406` → `486`** (i numeri 445–449 non esistono; `475` = cifratura segreti; `476–481` = aggiunte CMS post-Blocco 13; `482` = CRUD DB-first `ana_tipo_viaggi`; `483` = lettura password SMTP decifrate via pgcrypto; `484` = fix troncamento `cliente_lingua`; `485` = `cliente_lingua` auto-deriva da nazione + `NOT NULL`; `486` = `fn_web_tour_pubblicati` espone `meta_title`/`meta_description` con fallback, Blocco 5 Fase 2). Su un DB PROD che non li ha mai visti, il deploy = applicarli **tutti, in ordine numerico crescente**. Sono per la maggior parte idempotenti (function `CREATE OR REPLACE`, `IF NOT EXISTS`), ma **alcuni richiedono attenzione manuale** (vedi §2).

> **Blocco 13 (467–474)** — re-model contenuti web **per edizione** (viaggio+data): `467` `ana_viaggi.viaggio_difficolta`; `468` `web_tour_contenuti` +`data_viaggio_id_fk`/−difficoltà/CRUD; `469–471` figlie ri-ancorate a `web_tour_contenuti_id_fk` (BIGINT); `472` public per-edizione + `fn_web_prezzo_da_data`; `473` RLS anon per-contenuto; `474` `fn_web_tour_contenuti_clona`. ⚠️ `468`+`469–471` cambiano colonne/vincoli su tabelle **presunte vuote** (nessun contenuto web esistente): su PROD applicare **prima** che esistano contenuti.

> **Blocco 5 Fase 2 — SEO assistita (486)** — `fn_web_tour_pubblicati` espone `meta_title`/`meta_description` **in coda** al `RETURNS TABLE` con fallback DB-side (`COALESCE(NULLIF(btrim(...),''), titolo/sottotitolo)`); `SECURITY INVOKER`, nessun nuovo grant colonnare necessario (`web_tour_contenuti.meta_title`/`meta_description` sono colonne originarie della tabella, già coperte dal grant `SELECT` colonnare ad `anon` — vedi §2.1). Meta non tradotti in questo pass. Nessun consumer C# nel gestionale mappa questa funzione (letta solo dal frontend pubblico via RPC).

> **Aggiunte CMS (476–479)** — §A.1/§A.2: `476` `ana_viaggi.viaggio_incluso`/`viaggio_escluso`; `477` `fn_web_tour_pubblicati` espone incluso/escluso tradotti; `478` `ana_viaggi.viaggio_capienza_max`/`viaggio_capienza_alert` + trigger `trg_mov_clienti_viaggi_posti` (solo `pg_notify('web_tour_revalidate')`); `479` `fn_web_mezzi_occupati_data` (**SECURITY DEFINER**, `EXECUTE` a `anon`) + `fn_web_tour_pubblicati` espone `posti_rimasti`/`posti_stato`; `480` `ana_tipo_viaggi.tipo_viaggio_breve` (flag tour brevi) + `fn_web_ha_tour_brevi_pubblicati` (`EXECUTE` a `anon`) + `fn_web_tour_pubblicati` espone `is_tour_breve`; `481` `fn_web_recensioni_config` (**SECURITY DEFINER**, `EXECUTE` a `anon`): config recensioni Google/TripAdvisor dal JSONB `web_aziende_funzioni.parametri` (solo se `attiva`). Tutti idempotenti (`ADD COLUMN IF NOT EXISTS`, `CREATE OR REPLACE`). ⚠️ I `GRANT EXECUTE ... TO anon` su `fn_web_mezzi_occupati_data`, `fn_web_ha_tour_brevi_pubblicati` e `fn_web_recensioni_config` vanno verificati dopo l'hardening (§ RLS anon). Il canale `web_tour_revalidate` sarà consumato dal frontend Fase 3 (Next.js on-demand revalidation). `482` converte la CRUD di `ana_tipo_viaggi` in funzioni DB (`fn_ana_tipo_viaggi_create`/`update`), nessun impatto su `anon`. `483` aggiunge `fn_ana_aziende_smtp_secrets_get` (lettura password SMTP outbound/inbound decifrate via `pgp_sym_decrypt`; nessun impatto su `anon`). `484` è un **repair dati**: rimappa i `cliente_lingua` troncati a 1 carattere dal vecchio bug del cast `::char` ai codici ISO a 2 lettere (idempotente, solo valori di lunghezza 1; `'E'`→`'EN'` di default, ambiguo con `ES`) — richiede anche il deploy dell'app col fix del cast (vedi §2.5).

Comando (adattare host/credenziali PROD — NON usare il container Docker locale):

```bash
for f in $(ls SqlScripts/*.sql | awk -F_ '$1>=406 && $1<=466' | sort -t_ -k1 -n); do
  echo "==> $f"; psql "$PROD_CONN" -v ON_ERROR_STOP=1 -f "$f" || break
done
```

### Elenco ordinato (406–466)

| # | Script | Note |
|---|--------|------|
| 406 | Setup_RoleAnon | ⚠️ ruolo `anon` — vedi §2.1 (su Supabase esiste già) |
| 407 | Create_FnTrgWebAudit | trigger di audit tabelle web |
| 408 | Create_WebCategorieSport | ⚠️ poi rimodellata da 459 |
| 409 | Alter_AnaTipoViaggi_WebCategoria | |
| 410 | Create_WebTourContenuti | |
| 411 | Create_WebTourItinerario | |
| 412 | Create_WebTourItinerarioPassaggi | |
| 413 | Create_WebTourImmagini | Storage: vedi §2.4 |
| 414 | Create_WebTourMappa | Storage: vedi §2.4 |
| 415 | Create_WebTraduzioni | |
| 416 | Create_WebNewsletterIscritti | |
| 417 | Create_WebNewsletterInvii | |
| 418 | Create_WebNewsletterInviiDestinatari | |
| 419 | Create_WebNewsletterSoppressioni | |
| 420 | Create_WebAziendeFunzioni | |
| 421 | Create_AnaAziendeEsp | ⚠️ campi `_enc` FINTI (plaintext) — §2.2 |
| 422 | Create_WebPagamentiConfig | ⚠️ campi `_enc` FINTI (plaintext) — §2.2 |
| 423 | Create_WebPagamentiRegole | |
| 424 | Create_WebPagamentiReminderRegole | |
| 425 | Create_WebPagamentiTransazioni | |
| 426 | Create_WebPagamentiReminderLog | |
| 427 | Create_WebBlogArticoli | |
| 428 | Alter_AnaClienti_Web | |
| 429 | Alter_AnaAziende_Token | `token_iscrizione` per azienda — §2.3 |
| 430 | Fix_Web_LinguaCheck_FkOnDelete | |
| 431 | Create_FnWebCategorieSport_Crud | ⚠️ superata da 459/460 |
| 432 | Create_FnWebTourContenuti_Crud | |
| 433 | Create_FnWebTourItinerario_Crud | |
| 434 | Create_FnWebTourItinerarioPassaggi_Crud | |
| 435 | Create_FnWebTourImmagini_Crud | |
| 436 | Create_FnWebTourMappa_Crud | |
| 437 | Create_FnWebTraduzioni_Crud | |
| 438 | Create_FnWebNewsletterIscritti_Crud | |
| 439 | Create_FnWebNewsletterInvii_Crud | |
| 440 | Create_FnWebNewsletterInviiDestinatari_Crud | |
| 441 | Create_FnWebNewsletterSoppressioni_Crud | |
| 442 | Create_FnWebAziendeFunzioni_Crud | |
| 443 | Create_FnAnaAziendeEsp_Crud | |
| 444 | Create_FnWebServizio | |
| 450 | Rls_AnonRead_WebContenuti | ⚠️ RLS anon — §2.1 |
| 451 | Rls_AnonInsert_NewsletterIscritti | ⚠️ RLS anon — §2.1 |
| 452 | Rls_AnonRead_TourOperativiGated | ⚠️ RLS anon — §2.1 |
| 453 | Rls_Harden_AnonExecute | ⚠️ RLS anon — §2.1 |
| 454 | Create_FnWebTourItinerarioReorder | |
| 455 | Create_FnWebTourItinerarioPassaggiReorder | |
| 456 | Alter_UqWebTourItinerarioGiorno_Deferrable | constraint DEFERRABLE |
| 457 | Create_FnWebTourImmaginiReorder | |
| 458 | Create_FnWebTourImmaginiSetPrincipale | |
| 459 | Reshape_WebCategorieSport_To_TipiViaggioDescrizioni | ⚠️ **RESHAPE** tabella (rename + colonne) |
| 460 | Create_FnWebTipiViaggioDescrizioni_Crud | |
| 461 | Update_FnWebTourPubblicati_DescrizioneWeb | |
| 462 | Blocco10_Traduzioni_ClaudeKey_Upsert_Obsolete | ⚠️ chiave Claude `_enc` FINTA — §2.2 |
| 463 | Create_FnAnaAziendeClaudeKey | ⚠️ chiave Claude `_enc` FINTA — §2.2 |
| 464 | Create_FnWebTraduzioniMarcaObsoleteGlobal | |
| 465 | Blocco11_ClienteLingua_Destinatari | ⚠️ **BACKFILL DATI** su clienti reali — §2.5 |
| 466 | Create_FnAnaClientiLingua | |

> La verità sulle *funzioni* DB resta `Documents/Funzioni_DB.md` (rigenerato da `deploy_sql.sh`). Questo documento traccia il **deploy**, non la definizione.

---

## 2. Voci che richiedono attenzione MANUALE (oltre al semplice apply)

### 2.1 — Ruolo `anon` + RLS (406, 450–453)
- Su **Supabase** il ruolo `anon` **esiste già** (usato da PostgREST). Lo script `406_Setup_RoleAnon` va **riconciliato**: NON ricreare il ruolo, applicare solo i `GRANT`/policy mancanti. Verificare che i `GRANT EXECUTE` verso `anon` (hardening 453) combacino con la config Supabase.
- Le policy RLS anon (450–453) espongono in lettura solo i contenuti web pubblicati e consentono l'insert delle iscrizioni newsletter. **Verificare in staging** che nessuna tabella per-azienda sia leggibile da `anon` oltre il previsto (invariante silos: [[multitenancy-invariant-silos]]).
- ⚠️ **Grant colonnari anon da ESTENDERE (aggiunte CMS 467–480)**: `fn_web_tour_pubblicati` e `fn_web_ha_tour_brevi_pubblicati` sono **SECURITY INVOKER** e leggono colonne **nuove** non incluse nel grant colonnare originale dello script `452`. Su PROD/Supabase aggiungere ad `anon` il `SELECT` (column-level) su:
  - `ana_viaggi`: `viaggio_difficolta` (467), `viaggio_incluso`, `viaggio_escluso` (476), `viaggio_capienza_max`, `viaggio_capienza_alert` (478);
  - `ana_tipo_viaggi`: `tipo_viaggio_breve` (480).
  Senza questi grant, la lettura pubblica fallisce con *permission denied for column …*. NB: `fn_web_mezzi_occupati_data` e `fn_web_recensioni_config` sono **SECURITY DEFINER** e **non** richiedono grant su `mov_clienti_viaggi`/`web_aziende_funzioni`. (In locale il ruolo `anon` non ha i grant colonnari: la verifica va fatta in staging Supabase.)
- ✅ **`meta_title`/`meta_description` (script 486, Blocco 5 Fase 2)**: NON richiedono grant aggiuntivo — sono colonne **originarie** di `web_tour_contenuti` (script `410`), già incluse nel grant colonnare `anon` esistente. Verificato in locale (`\dp web_tour_contenuti`): `anon=r` presente su entrambe.

### 2.2 — Cifratura segreti (`_enc`) — **FATTA (script 475, 2026-07-11)**
Cifratura reale implementata con **pgcrypto** (`pgp_sym_encrypt/decrypt`), master key dall'ambiente. Vedi design `Documents/2026-07-11-Cifratura_Segreti_design.md`. Coperti: SMTP (`ana_aziende_smtp.password_enc`/`inbound_password_enc`), ESP (`ana_aziende_esp.api_key_enc`), Claude (`ana_aziende.claude_api_key_enc`). Colonne `_enc` ora **bytea**; i valori finti sono stati **azzerati** dalla migrazione. Esclusi: Geoapify (deciso), `sys_redis_endpoints` (infra).

**Da fare in PROD (go-live):**
- [ ] Impostare la variabile d'ambiente **`GV_SECRET_KEY`** (stringa forte, es. base64 di 32 byte), **la STESSA su tutte le installazioni** che condividono il DB. Senza, le operazioni sui segreti falliscono con errore chiaro (fail-fast).
- [ ] **Re-inserire** i segreti reali (SMTP/Claude/ESP) dalle form dopo il deploy di `475` (i finti sono stati azzerati; in PROD non c'erano segreti reali cifrati).
- [ ] `web_pagamenti_config.stripe_*_enc`: formato bytea pronto (Fase 4), nessun valore.

> **ESP-come-provider abbandonato (deciso 2026-07-12):** il canale email (incluse le newsletter) è lo **SMTP del cliente** (`ana_aziende_smtp`, già in anagrafica), instradato da `EmailSenderFactory` (SMTP configurato → usato; fallback Resend). **Nessun provider ESP esterno** (Brevo/Mailchimp/SES) da wire-are. La tabella `ana_aziende_esp` resta **predisposta ma inutilizzata** (schema/funzioni già cifrati, pronta per un eventuale uso futuro): nessun tab UI, nessun wiring nel factory. Niente da fare qui per il go-live.

### 2.3 — `token_iscrizione` per azienda (429)
Serve come **segreto HMAC** per il link di disiscrizione newsletter (`NewsletterUnsubscribe`). Ogni azienda in PROD deve avere un `token_iscrizione` valorizzato (random, per-azienda). Verificare che il backfill/valore non sia NULL prima di inviare newsletter.

### 2.4 — Supabase Storage (immagini WebP, mappe GPX)
Blocco 7 (immagini tour, WebP) e Blocco 9 (mappe da GPX) salvano su **Supabase Storage**. In PROD devono esistere i **bucket** corrispondenti con le policy corrette. La `Service Key` Supabase va configurata lato app (NON committata). Verificare bucket + permessi prima di caricare media.

### 2.5 — Backfill `ana_clienti.cliente_lingua` (465)
Lo script 465 fa `UPDATE ana_clienti SET cliente_lingua = COALESCE(fn_lingua_da_comune(...), 'IT') WHERE cliente_lingua IS NULL`. **Va eseguito sui clienti reali di PROD** (in locale ha popolato 740 clienti Docker). È **idempotente** (`WHERE cliente_lingua IS NULL`). Vedi [[prod-backfill-cliente-lingua]]. Dopo il backfill, verificare la distribuzione lingue prima del primo invio newsletter.

**Fix troncamento `cliente_lingua` (script 484 + app):** il vecchio `ClienteLinguaService.SetAsync` usava il cast `@L::char` (= `char(1)`), che troncava `'IT'`→`'I'` **prima** della funzione DB → il select in `ClienteDialog` mostrava il codice grezzo al rientro. Corretto in `::varchar`. Lo **script 484** ripara le righe già salvate corrotte (rimappa il singolo carattere → ISO 2 lettere; `'E'`→`'EN'` di default, ambiguo con `ES`). Su PROD: eseguire 484 **dopo** aver rilasciato l'app col fix del cast, poi riverificare la distribuzione lingue.

**`cliente_lingua` mai NULL (script 485):** `fn_ana_clienti_set_lingua` auto-deriva dalla nazione di residenza quando il campo è vuoto (`fn_lingua_da_comune`, fallback `IT`); backfilla i NULL residui; imposta colonna `DEFAULT 'IT'` + `NOT NULL`. La newsletter legge `cliente_lingua` senza ragionare (il `COALESCE` in `fn_web_destinatari_newsletter` resta solo come fallback difensivo). Applicare 485 su PROD **dopo** 484.

---

## 3. Configurazione applicativa PROD (fuori dal DB)

Da impostare lato app / ambiente (NON in git):

- [ ] **`GV_SECRET_KEY`** (env var, master key cifratura segreti — stessa su tutte le installazioni). Vedi §2.2.
- [ ] **Supabase**: connection string PROD, `Service Key` (Storage), eventuale `anon key`.
- [ ] **Geoapify** API key (Blocco 9, generazione mappe statiche).
- [ ] **Chiave Claude per-azienda** (Blocco 10/11 traduzioni + newsletter) — via UI form azienda, salvata cifrata (§2.2).
- [ ] **SMTP / ESP (Resend) per-azienda** (invio email/newsletter) — via config azienda, cifrata (§2.2).
- [ ] **`sito_web` azienda** valorizzato: base URL usata per costruire il link di disiscrizione (`{sito_web}/unsubscribe?...`). La verifica HMAC lato sito è **Fase 3** (sito pubblico) — non ancora implementata.
- [ ] Connection pool PROD: MaxPoolSize=10, MinPoolSize=0, IdleLifetime=180s, ConnectionLifetime=600s (già in config).

---

## 4. Checklist finale di rilascio

- [ ] Applicati in ordine gli script 406–486 su PROD (§1) senza errori.
- [ ] Ruolo `anon` + RLS riconciliati e verificati in staging (§2.1).
- [ ] **Cifratura reale segreti implementata** e segreti caricati (§2.2). ← bloccante
- [ ] `token_iscrizione` valorizzato per ogni azienda (§2.3).
- [ ] Bucket Supabase Storage creati + policy (§2.4).
- [ ] Backfill `cliente_lingua` eseguito e verificato (§2.5).
- [ ] Config app PROD completata (§3).
- [ ] Eseguito il Piano di Test (`2026-07-09-Piano_Test_Estensione_Web.md`) end-to-end.
- [ ] `Documents/Funzioni_DB.md` allineato allo stato PROD.

---

## 5. Manutenzione di questo documento

Ogni volta che si aggiunge uno script SQL all'Estensione Web (numero > 466) o un nuovo requisito di configurazione:
1. aggiungere la riga in §1 (con eventuale ⚠️ e rimando a §2 se serve azione manuale);
2. se comporta backfill/segreti/config, aggiungere la voce in §2/§3 e la spunta in §4;
3. aggiornare la data in testa.
