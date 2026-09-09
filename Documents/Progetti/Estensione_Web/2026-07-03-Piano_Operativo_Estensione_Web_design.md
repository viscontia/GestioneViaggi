# Piano Operativo — Estensione Web SFT (Gestionale + DB) — DESIGN DOC

> **USO INTERNO (Adriano + AI).** Design consolidato e approvato prima dell'implementazione.
> **Versione:** 1.0 · **Data:** 2026-07-03
> **Base:** `Analisi Tecnica Dettagliata.md` (playbook), `Dettaglio_Tabelle_DB.md` (spec campo-per-campo), `Documents/overview.md` (architettura gestionale).

---

## 1. Scope (deciso)

- **In scope (questo repo, MAUI + DB):** strato dati (tabelle, funzioni PL/pgSQL, RLS di lettura pubblica) + feature del gestionale per creare/gestire/pubblicare contenuti web dei tour, traduzioni e newsletter. Predisposizione (sole tabelle) per pagamenti e blog.
- **Fuori scope (binario parallelo, piano separato):** sito Next.js (Fase 3), logica pagamenti Stripe + integrazione contabile (Fase 4), import dal vecchio sito e go-live (Fase 5).
- **Strategia:** sequenziale per Fasi (ordine del playbook).
- **1° rilascio:** **Contenuti + Newsletter**. Pagamenti/blog creati come tabelle vuote non cablate.

## 2. Scoperte architetturali che guidano il design

Verificato sul DB reale e sul codice:

1. **Le RLS esistenti sono role-based native, NON "stile Supabase".** Nessun uso di `auth.uid()`/`auth.role()`. `superadmin_bypass_all` ha `qual = true` sul ruolo Postgres `app_superadmin`. Il contesto tenant passa da un GUC custom: `set_config('my.app_user', @email, true)` (in `Services/Database/PostgreSqlService.cs`).
2. **Il gestionale si connette come `postgres` (superuser)** in dev e prod → le RLS sono **bypassate** per il gestionale. L'isolamento multi-tenant reale vive **nelle funzioni PL/pgSQL**, non nelle RLS.
3. **Conseguenza:** le RLS diventano il confine di sicurezza **solo** per la lettura pubblica del sito (ruolo `anon`, non-superuser). Essendo role-based pure, si comportano **identiche su Postgres liscio e su Supabase** → testabili in locale senza Supabase CLI né schema `auth`.
4. **Nessuno schema `auth`/`storage` Supabase in locale.** Lo Storage è l'unica capability realmente Supabase-specifica.
5. **`mov_transazioni`** compatibile con la futura integrazione contabile (`transazione_tipo_movimento`, `transazione_fattura_fk`, `transazione_controparte_id`, `transazione_viaggio_id`) — rilevante solo per Fase 4 (differita).

## 3. Decisioni tecniche chiuse

### C2 — Storage media: Opzione A+ (bucket Supabase di test dietro un seam)
- Backend = **bucket Supabase di test reale** (URL veri, comportamento identico a prod).
- Accesso via **seam `IWebMediaStorage`** con **una sola** implementazione (Supabase Storage via **HTTP REST + service key**, niente SDK).
- **`storage_path` = sorgente di verità** (es. `aziende/123/tour/45/foto.webp`). L'URL pubblico si **ricompone a runtime dal base-URL dell'ambiente** → nessun dato "sporco" legato al progetto di test; migrazioni/dump dev↔prod non rompono i puntamenti.
- Naming path `azienda_id/viaggio_id/...` + funzione di **purge orfani** contro l'accumulo nel bucket.
- **No Supabase CLI:** troppo invasiva su una toolchain di deploy consolidata (400+ script numerati, `deploy_sql.sh`, `generate_db_functions_doc.sh`, backup). Non giustificata per l'unica capability Supabase-specifica.

### C3 — RLS lettura pubblica: ruolo `anon` locale
- `CREATE ROLE anon NOLOGIN;` + `GRANT USAGE ON SCHEMA public` + `GRANT SELECT` sulle sole tabelle-contenuto web.
- Policy **`TO anon` role-based** (es. `USING (stato_pubblicazione='pubblicato')`), **senza `auth.*`** → coerenti con il pattern esistente e identiche in prod.
- Test con `SET ROLE anon;`. **FORCE RLS non necessario** (anon non è owner; il gestionale gira come superuser e bypassa comunque).

### Package (approccio lean)
- Presenti: `SkiaSharp`, `SixLabors.ImageSharp`, `Blazored.TextEditor`, `QuestPDF`, `Npgsql`.
- Da aggiungere/implementare quando servono: **Supabase Storage via HTTP REST** (no SDK), **Douglas-Peucker a mano** (~30 righe, no NetTopologySuite), **Claude API via HttpClient** (no SDK).
- Cifratura segreti (ESP/Stripe) = **riuso pattern `password_enc`** di `ana_aziende_smtp`.

## 4. Capability nuove da costruire (zone di rischio)

| # | Capability | Rischio | Note |
|---|-----------|---------|------|
| 1 | Cifratura segreti per-azienda | Basso | riuso `password_enc` |
| 2 | Upload Supabase Storage da C# (seam REST) | Medio | nuovo; `storage_path` canonico. **Vincolo Blocco 7 (da review Task 0.4):** la `ServiceKey` service-role NON va nel binario MAUI client (estraibile) → instradare upload/delete server-side o usare una chiave scoped al bucket; documentare il return di `UploadAsync` (= `storage_path` effettivo). |
| 3 | GPX → mappa statica (Douglas-Peucker → Geoapify → WebP → Storage) | **Alto** | pezzo più complesso; spike prima della UI |
| 4 | Traduzione Claude API per-campo (5 lingue, obsolescenza) | Medio | nuova integrazione HTTP |
| 5 | Strato lettura pubblica + RLS `anon` | Medio | testabile in locale (vedi C3) |
| 6 | Drag&drop annidato itinerario | Medio | pattern MudBlazor nuovo |
| 7 | Newsletter dedup + unsubscribe + SMTP/ESP | Medio | nuovo |

## 5. Decisioni ancora aperte (non bloccanti)

1. **Token iscrizione** per-azienda da allineare al `.env` Flask su Hetzner (`app.py` ~riga 353). Serve solo al link "Iscriviti".
2. **Provider ESP** concreto per SFT (brevo/mailchimp/ses) — la tabella è generica, l'invio reale ne richiede uno.

## 6. Piano a blocchi sequenziali

Ogni blocco: *Obiettivo · Deliverable · Verifica*. Sequenziali; dentro il blocco alcune attività sono parallelizzabili. Script SQL numerati da **406**.

### BLOCCO 0 — Preparazione
- Branch `feature/estensione-web`; backup DB locale; allineare `Funzioni_DB.md`.
- Creare ruolo `anon` locale (C3); definire il seam `IWebMediaStorage` (C2, solo interfaccia + config base-URL/bucket).
- **Verifica:** ambiente parte, backup ripristinabile, `SET ROLE anon` funziona.

### BLOCCO 1 — Schema DB completo (Fase 1.1)
- Tutte le tabelle dell'estensione (incluse predisposizioni pagamenti/blog), nell'ordine FK del `Dettaglio_Tabelle_DB.md`: `web_categorie_sport` → alter `ana_tipo_viaggi` → `web_tour_contenuti` → `web_tour_itinerario` → `_passaggi` → `web_tour_immagini` → `web_tour_mappa` → `web_traduzioni` → newsletter (iscritti/invii/destinatari/soppressioni) → `web_aziende_funzioni` → `ana_aziende_esp` → predisposizioni pagamenti → `web_blog_articoli` → alter `ana_clienti` (consenso + `controparte_fk`) → alter `ana_aziende` (`token_iscrizione`). Con `azienda_id`, audit, indici, trigger audit.
- **Verifica:** deploy locale senza errori; vincoli/unique testati; rollback pronto; `Funzioni_DB.md` aggiornato.

### BLOCCO 2 — Funzioni CRUD + di servizio (Fase 1.2)
- `get/list/insert/update/delete` per ogni entità del 1° rilascio + funzioni servizio: `fn_web_tour_pubblicati(azienda,lingua)`, `fn_web_destinatari_newsletter(azienda)` (unione+dedup−soppressioni), prezzo "da" minimo. (Funzioni pagamenti differite.)
- **Verifica:** ogni funzione con dati di test; isolamento multi-azienda; `Funzioni_DB.md` aggiornato.

### BLOCCO 3 — Strato lettura pubblica + RLS (Fase 1.3) — *checkpoint*
- Policy `TO anon` (lettura solo `stato_pubblicazione='pubblicato'`; deny su operativo/contabile/pagamenti/newsletter/config); viste/funzioni di lettura per lista/dettaglio/itinerario/immagini/mappa/categorie/traduzioni.
- **Verifica:** bozza non leggibile da anon; anon non vede dati operativi; multilingua corretta.

### BLOCCO 4 — Servizi C# (Fase 2.1)
- Modelli + service Dapper (Singleton) sopra le funzioni del Blocco 2; registrazione in `MauiProgram.cs`.
- **Verifica:** CRUD end-to-end da codice.

### BLOCCO 5 — Contenuti Web del tour (Fase 2.2) — *checkpoint*
- Scheda "Contenuti Web" nel viaggio: campi editoriali + RichText (Blazored.TextEditor), SEO (slug/meta), stato pubblicazione.
- **MUST UI:** campi editoriali/RichText **NON** in maiuscolo forzato (eccezione documentata); set-focus primo campo; tabulazione via helper JS; `BackdropClick=false`; riuso componenti shared.
- **Verifica:** salva/rilegge, slug univoco, anteprima coerente.

### BLOCCO 6 — Itinerario giorno-per-giorno (Fase 2.3)
- Giornate → N passaggi (RichText + immagine + didascalia); drag&drop a due livelli.
- **Verifica:** ordine persistito, riordino stabile.

### BLOCCO 7 — Galleria immagini (Fase 2.4)
- Upload multiplo, resize/ottimizzazione (ImageSharp), alt/titolo, foto principale, ordinamento → `IWebMediaStorage` → bucket Supabase.
- **Verifica:** immagini ridimensionate/ordinate, alt salvati, `storage_path` + URL ricomposto validi.

### BLOCCO 8 — Mappatura categoria "Sport" (Fase 2.5)
- UI mappatura `ana_tipo_viaggi` → `web_categorie_sport`.
- **Verifica:** ogni tipo tecnico mappato.

### BLOCCO 9 — GPX → mappa statica (Fase 2.6) — *checkpoint, rischio più alto*
- **Spike tecnico prima della UI:** parse GPX + Douglas-Peucker + 1 chiamata Geoapify su 1 GPX reale.
- Poi UI completa: upload GPX → decimazione → bbox+margine → Geoapify Static Maps (colori outdoor) → WebP (ImageSharp) → Storage → salva `storage_path`/bbox/parametri in `web_tour_mappa`. GPX mai al browser; attribuzione OSM.
- **Verifica:** mappa centrata su più GPX reali; traccia semplificata; nessun dato vettoriale esposto.

### BLOCCO 10 — Traduzione automatica Claude API (Fase 2.7)
- Pulsante "Traduci" → salvataggio per-campo in `web_traduzioni` con flag auto/revisionato; modifica IT → traduzioni obsolete; UI revisione.
- **Verifica:** 5 lingue prodotte, flag obsolescenza, nomi propri non tradotti.

### BLOCCO 11 — Newsletter (Fase 2.8)
- Elenco iscritti+filtri, editor, unione+dedup clienti+iscritti−soppressioni, invio SMTP/ESP per-azienda, disiscrizione via token, storico invii.
- **Verifica:** dedup corretto, invio di prova, link disiscrizione attivo.

### BLOCCO 12 — Config per-azienda (Fase 2.9)
- UI toggle `web_aziende_funzioni`; config ESP; UI predisposta (non attiva) per regole pagamento.
- **Verifica:** flag riflessi nel comportamento.
- **Scelta (2026-07-10) — scope gating flag:** solo il flag **`newsletter`** ha comportamento nel gestionale ORA (se OFF → voce di menu/pagina Newsletter nascosta/disabilitata per quell'azienda; gating **opt-out**: se non esiste riga esplicita la newsletter resta visibile). Gli altri flag (`recensioni`, `blog`, `pagamenti_online`) sono **stored-only**: persistiti come configurazione predisposta, ma il loro wiring comportamentale è del **sito pubblico (Fase 3)** → vedi §8.
- **Scelta (2026-07-10) — ESP rimandato:** la **config ESP** (`ana_aziende_esp`: Brevo/Mailchimp/SES…) è **rimandata**. Motivo: la newsletter oggi parte via **SMTP aziendale esistente** (`EmailSenderFactory`), sufficiente per i volumi attuali; e la `api_key_enc` è ancora finta (cifratura reale = bloccante pre-release). Il tab ESP + il wiring nell'`EmailSenderFactory` si faranno **insieme alla cifratura**, pre-release → tracciato nel Checklist Go-Live PROD. Blocco 12 realizza quindi: **toggle funzioni** (gating `newsletter`) + **placeholder regole pagamento** (Fase 4).

### BLOCCO 13 — Anteprima / Pubblica / Clona (Fase 2.10) — *checkpoint finale*
- Anteprima; "Pubblica" (cambia stato → futura revalidation on-demand del sito); "Clona" esteso ai contenuti web.
- **Verifica:** clona copia itinerario+gallerie; pubblica rende visibile via strato pubblico.

## 7. Sequenza e checkpoint di revisione

`0 → 1 → 2 → 3` (fondamenta dati, verificabili senza UI) → `4` (servizi) → `5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 → 13`.

**Checkpoint** (ci si ferma e si mostrano i risultati): dopo **Blocco 3**, **Blocco 5**, **Blocco 9**, fine **Blocco 13**.

## 8. Fuori dal piano (da pianificare a parte)
- Sito Next.js (Fase 3 intera).
  - **Wiring flag `web_aziende_funzioni` → comportamento sito** (rimandato da Blocco 12): i flag `recensioni`, `blog`, `pagamenti_online` sono già salvati per-azienda ma oggi NON attivano nulla nel gestionale. In Fase 3 il sito pubblico dovrà leggerli e mostrare/nascondere le relative sezioni (recensioni, blog, checkout online). Solo `newsletter` è già collegato lato gestionale.
- Pagamenti + integrazione contabile + fattura (Fase 4) — tabelle predisposte qui, logica differita.
- Import vecchio sito, traduzioni batch, SEO migration, go-live (Fase 5).

## 9. "Definizione di fatto" per ogni blocco
Codice + DB aggiornati in locale · funzioni documentate in `Funzioni_DB.md` · componenti in `ComponentiShared.md` · validazioni in `Gestione_check.md` · test del blocco verdi · (a fine fase) deploy in produzione verificato con backup preventivo.
