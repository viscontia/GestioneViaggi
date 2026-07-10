# Checklist Go-Live PROD — Estensione Web

> **Scopo.** Documento **operativo e vivo**: elenca *tutto* ciò che va modificato/configurato in produzione (Supabase) prima di rilasciare l'Estensione Web. Va aggiornato **a ogni nuovo script SQL o requisito di deploy**. In locale si lavora su Docker (`postgres_db`); la PROD è Supabase/PgBouncer.
>
> **Ultimo aggiornamento:** 2026-07-10 (chiusura Blocco 11). **Stato:** NON ancora rilasciato. I test si faranno tutti alla fine.

---

## 1. Migrazione DB — script da applicare in ordine

L'Estensione Web introduce gli script **`SqlScripts/406` → `466`** (i numeri 445–449 non esistono). Su un DB PROD che non li ha mai visti, il deploy = applicarli **tutti, in ordine numerico crescente**. Sono per la maggior parte idempotenti (function `CREATE OR REPLACE`, `IF NOT EXISTS`), ma **alcuni richiedono attenzione manuale** (vedi §2).

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

### 2.2 — Cifratura segreti (`_enc` FINTI) — **BLOCCANTE PRE-RELEASE**
I campi `*_enc` di `ana_aziende_esp` (421), `web_pagamenti_config` (422) e la chiave Claude azienda (462/463) sono **JSONB in chiaro (placeholder)**, NON cifrati. Prima del rilascio va implementata la **cifratura reale** (SMTP, ESP/Resend, chiave Claude, credenziali pagamenti). Vedi memoria [[encrypt-smtp-esp-before-release]]. Finché è finto, **non caricare segreti reali in un DB PROD accessibile**.

> **ESP rimandato (deciso in Blocco 12, 2026-07-10):** il **tab di configurazione ESP** (`ana_aziende_esp`) e il **wiring nell'`EmailSenderFactory`** (usare l'ESP quando `attivo` per gli invii bulk/newsletter) NON sono stati implementati nel Blocco 12 — la newsletter usa l'**SMTP aziendale esistente**. Vanno realizzati **qui, insieme alla cifratura reale**, prima del rilascio. Finché non esistono, la config ESP non è disponibile in UI.

### 2.3 — `token_iscrizione` per azienda (429)
Serve come **segreto HMAC** per il link di disiscrizione newsletter (`NewsletterUnsubscribe`). Ogni azienda in PROD deve avere un `token_iscrizione` valorizzato (random, per-azienda). Verificare che il backfill/valore non sia NULL prima di inviare newsletter.

### 2.4 — Supabase Storage (immagini WebP, mappe GPX)
Blocco 7 (immagini tour, WebP) e Blocco 9 (mappe da GPX) salvano su **Supabase Storage**. In PROD devono esistere i **bucket** corrispondenti con le policy corrette. La `Service Key` Supabase va configurata lato app (NON committata). Verificare bucket + permessi prima di caricare media.

### 2.5 — Backfill `ana_clienti.cliente_lingua` (465)
Lo script 465 fa `UPDATE ana_clienti SET cliente_lingua = COALESCE(fn_lingua_da_comune(...), 'IT') WHERE cliente_lingua IS NULL`. **Va eseguito sui clienti reali di PROD** (in locale ha popolato 740 clienti Docker). È **idempotente** (`WHERE cliente_lingua IS NULL`). Vedi [[prod-backfill-cliente-lingua]]. Dopo il backfill, verificare la distribuzione lingue prima del primo invio newsletter.

---

## 3. Configurazione applicativa PROD (fuori dal DB)

Da impostare lato app / ambiente (NON in git):

- [ ] **Supabase**: connection string PROD, `Service Key` (Storage), eventuale `anon key`.
- [ ] **Geoapify** API key (Blocco 9, generazione mappe statiche).
- [ ] **Chiave Claude per-azienda** (Blocco 10/11 traduzioni + newsletter) — via UI form azienda, salvata cifrata (§2.2).
- [ ] **SMTP / ESP (Resend) per-azienda** (invio email/newsletter) — via config azienda, cifrata (§2.2).
- [ ] **`sito_web` azienda** valorizzato: base URL usata per costruire il link di disiscrizione (`{sito_web}/unsubscribe?...`). La verifica HMAC lato sito è **Fase 3** (sito pubblico) — non ancora implementata.
- [ ] Connection pool PROD: MaxPoolSize=10, MinPoolSize=0, IdleLifetime=180s, ConnectionLifetime=600s (già in config).

---

## 4. Checklist finale di rilascio

- [ ] Applicati in ordine gli script 406–466 su PROD (§1) senza errori.
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
