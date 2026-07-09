# Blocco 11 — Newsletter — DESIGN DOC

> **USO INTERNO (Adriano + AI).** Design consolidato prima dell'implementazione.
> **Versione:** 1.0 · **Data:** 2026-07-09
> **Base:** Piano Operativo (Blocco 11, Fase 2.8), tabelle/funzioni newsletter (Blocchi 1/2), infra email (SMTP/Resend), client Claude (Blocco 10).

---

## 1. Scope

Pagina Newsletter **per-azienda** (silos): comporre una campagna (oggetto + corpo HTML), risolvere i destinatari (clienti-con-consenso + iscritti − soppressioni, dedup), inviarla **multilingua** via SMTP/ESP dell'azienda, loggare la consegna per-destinatario, con storico invii, gestione iscritti/soppressioni, invio di prova e link di disiscrizione.

## 2. Decisioni prese (brainstorming 2026-07-09)

- **Multilingua** (ottimale): la lingua di ciascun destinatario è —
  - **iscritto** → `web_newsletter_iscritti.lingua` (scelta esplicita, precedenza);
  - **cliente** → nuovo campo **`ana_clienti.cliente_lingua`** (char 2, **editabile** nella scheda cliente). Default scritto da noi con le regole geo; l'operatore può sovrascriverlo (es. ticinese italofono → IT, rumeno che parla IT → IT). Fallback a runtime: `COALESCE(cliente_lingua, fn_lingua_da_comune(comune), 'IT')`.
  - **Regola default (mappa `iso_alpha2 → lingua`, in `fn_lingua_da_comune`):** `IT→IT`; `DE/AT/CH→DE` (CH multilingua → default tedesco); `FR/BE→FR`; `ES→ES`; paesi anglofoni (`GB/IE/US/AU/NZ/CA/ZA…`)→`EN`; **default (non coperti: RO/BG/…)→EN** (internazionale — "se vogliono se la traducono").
  - Geo-chain (verificato): `ana_clienti.cliente_comune_residenza_fk` → `ana_geo_comuni.comune_provincia_fk` → `ana_geo_province.regione_id_fk` → `ana_geo_regioni_ita.country_id_fk` → `eba_countries.iso_alpha2` (comuni esteri: `comune_estero='Y'`).
- **Corpo**: l'operatore scrive **oggetto + corpo in IT**; per ogni lingua ≠ IT presente tra i destinatari lo **traduco una volta** via Claude (client Blocco 10, chiave azienda). Anteprima per lingua prima dell'invio.
- **Disiscrizione**: link **firmato HMAC** sull'email — `…/unsubscribe?email=<email>&sig=HMAC_SHA256(email, segreto-azienda)`. Segreto = `ana_aziende.token_iscrizione` (per-azienda). Il click lo gestisce il sito (Fase 3): verifica firma → aggiunge una soppressione. Funziona per clienti e iscritti uniformemente.
- **UI**: pagina completa — campagna+invio, storico invii + log, gestione iscritti (CRUD), gestione soppressioni (CRUD).
- **Canale**: `EmailSenderFactory.GetSenderAsync(role, azienda)` sceglie SMTP/Resend dell'azienda; salvato in `web_newsletter_invii.canale`.

## 3. Componenti nuovi

- **DB**:
  - **`ALTER TABLE ana_clienti ADD COLUMN cliente_lingua CHAR(2)`** + **`fn_lingua_da_comune(p_comune_id)`** (geo-chain + CASE iso→lingua, fallback IT) + **backfill** `UPDATE ana_clienti SET cliente_lingua = fn_lingua_da_comune(cliente_comune_residenza_fk) WHERE cliente_lingua IS NULL`.
  - Estendere `fn_web_destinatari_newsletter(p_azienda_id)` per restituire la **lingua effettiva** del destinatario: iscritto → `iscritti.lingua`; cliente → `COALESCE(cliente_lingua, fn_lingua_da_comune(comune), 'IT')`.
- **Scheda cliente**: `ClienteLingua` nel model + persistenza (Cliente service) + **select lingua editabile** nella form cliente.
- **`Services/Web/NewsletterSenderService.cs`** (orchestratore): risolve destinatari → calcola lingua per ciascuno → raggruppa per lingua → traduce oggetto+corpo per lingua (Claude) → per destinatario: wrap `CompanyEmailTemplate` + link disiscrizione HMAC → `IEmailSender.SendHtmlEmailAsync` (per-destinatario) → log `web_newsletter_invii_destinatari` (stato_consegna, lingua) → crea/aggiorna `web_newsletter_invii` (stato, numero_destinatari, data_invio, canale). Invio di prova = a un solo indirizzo, senza log campagna.
- **`Services/Shared/NewsletterUnsubscribe.cs`**: helper HMAC per costruire l'URL di disiscrizione.
- **Mappa nazione→lingua** (Dictionary in C#, nel sender o un piccolo helper).
- **UI**: `Components/Pages/NewsletterPage.razor` (`/newsletter`, per-azienda) con tab/sezioni:
  - **Campagna**: oggetto + editor Quill (corpo IT) + "Anteprima per lingua" + "Invio di prova" + "Invia a tutti" (con conteggio destinatari da `fn_web_destinatari_newsletter`).
  - **Storico**: lista `web_newsletter_invii` + drill-down log destinatari.
  - **Iscritti**: CRUD `web_newsletter_iscritti`.
  - **Soppressioni**: CRUD `web_newsletter_soppressioni`.
  - Avviso se manca la chiave Claude (traduzione non disponibile → invio solo IT) o la config email dell'azienda.

## 4. Flusso invio (dettaglio)

1. Risolvi destinatari (`fn_web_destinatari_newsletter`) → per ciascuno calcola `lingua` effettiva.
2. Lingue distinte ≠ IT → traduci (oggetto, corpo) via Claude una volta per lingua (se chiave assente → tutti in IT con avviso).
3. Crea `web_newsletter_invii` (stato `in_invio`, canale dal factory).
4. Per destinatario: `CompanyEmailTemplate.GetHtmlBody(corpo_lingua + link disiscrizione)` → invia → inserisci `web_newsletter_invii_destinatari` (email, lingua, stato_consegna).
5. Aggiorna `web_newsletter_invii` (stato `inviato`, numero_destinatari, data_invio).

## 5. Note / rischi

- **Volume**: invio per-destinatario (personalizza disiscrizione) → N chiamate. OK per liste operatore; per liste grandi valutare batch/ESP.
- **HMAC**: segreto per-azienda in chiaro (`token_iscrizione`) — accettabile (identifica la disiscrizione, non un segreto forte). Il sito (Fase 3) deve usare lo stesso schema.
- **Fallback traduzione**: chiave Claude mancante → invio in IT a tutti (con avviso), non blocco.
- **GDPR**: solo destinatari con consenso (la fn già filtra); disiscrizione sempre presente nel footer.

## 6. Verifica (criteri del blocco)

- Dedup destinatari corretto (clienti+iscritti−soppressioni, per email).
- Invio di prova funzionante.
- Multilingua: iscritto in lingua sua, cliente estero nella lingua della nazione (CH→DE, non-coperti→EN), IT per i residenti Italia.
- Link disiscrizione presente e firmato.
- Storico + log per-destinatario popolati. Build `net9.0-maccatalyst`: 0 errori. (Invio reale richiede config email valida + chiave Claude per la traduzione.)

## 7. Deliverable

1. SQL: colonna `ana_clienti.cliente_lingua` + `fn_lingua_da_comune` + backfill + `fn_web_destinatari_newsletter` esteso (lingua effettiva) + `ClienteLingua` nel model/form cliente + `Funzioni_DB.md`.
2. `NewsletterSenderService` + `NewsletterUnsubscribe` (HMAC) + mappa nazione→lingua + DI.
3. UI `NewsletterPage` (campagna/storico/iscritti/soppressioni) + dialog dove serve + voce menu.
4. Doc: `ComponentiShared.md`.
