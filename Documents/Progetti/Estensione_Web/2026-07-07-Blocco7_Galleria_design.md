# Blocco 7 — Galleria immagini — DESIGN DOC

> **USO INTERNO (Adriano + AI).** Design consolidato e approvato prima dell'implementazione.
> **Versione:** 1.0 · **Data:** 2026-07-07
> **Base:** `2026-07-03-Piano_Operativo_Estensione_Web_design.md` (Blocco 7, Fase 2.4; decisione C2 storage), seam Blocco 0, tabella/service Blocchi 1/4.

---

## 1. Scope

Scheda **"Galleria"** nel dialog viaggio: upload multiplo di immagini → ottimizzazione → Supabase Storage; alt/titolo, foto **principale** (copertina), riordino DnD. Più il **picker passo→galleria** rimasto in sospeso dal Blocco 6.

**Decisioni prese (brainstorming):**
- **Sicurezza ServiceKey**: la service-role key resta in `appsettings` contro il **bucket di TEST** (decisione C2). Rischio nullo sui dati veri. **DEBITO documentato** per la produzione/go-live (Fase 5): chiave scoped al bucket o upload server-side — la key service-role non deve restare nel binario MAUI (estraibile).
- **Pipeline**: 1 WebP ottimizzato per immagine (lato lungo ≤2000px, q~80) + cattura `larghezza/altezza`. Originale non conservato.
- **Scope**: include il picker passo→galleria (chiude il Blocco 6).

**Stato scoperto:** seam `IWebMediaStorage` (interfaccia, senza impl), `WebMediaStorageOptions` (BaseUrl/Bucket/ServiceKey), tabella/funzioni CRUD `web_tour_immagini` + service (Blocco 4), ImageSharp 3.1.12 presente. CHECK DB `tipo IN ('principale','galleria')` → **copertina = `principale`**. Nessun unique su `ordine` → reorder atomico semplice (niente deferrable). Config: BaseUrl/Bucket impostati, **ServiceKey placeholder** (upload reale richiede una vera key del bucket di test).

## 2. SupabaseMediaStorage (impl del seam)

`Services/Shared/Storage/SupabaseMediaStorage.cs : IWebMediaStorage`, **Singleton** con `HttpClient` (no SDK, HTTP REST). `apiRoot` = `BaseUrl` senza il suffisso `/public`.
- `UploadAsync(storagePath, stream, contentType)` → `PUT {apiRoot}/{bucket}/{storagePath}`; header `Authorization: Bearer {ServiceKey}`, `Content-Type`, `x-upsert: true`. Ritorna `storagePath` (verità).
- `BuildPublicUrl(storagePath)` → `{BaseUrl}/{bucket}/{storagePath}` (ricomposto a runtime dall'ambiente).
- `DeleteAsync(storagePath)` → `DELETE {apiRoot}/{bucket}/{storagePath}`.
- Registrato in `MauiProgram` (sostituisce la nota "nessuna implementazione").

## 3. Pipeline immagini (ImageSharp)

`Services/Shared/Storage/WebImageProcessor.cs` (statico): `stream → Image.Load → se lato lungo >2000 ridimensiona (aspect) → encode WebP q80`. Ritorna bytes + `larghezza/altezza` + mime `image/webp`. `storagePath = {aziendaId}/{viaggioId}/{guid}.webp`.

## 4. DB (457/458) + service

- `fn_web_tour_immagini_reorder(p_azienda_id, p_viaggio_id_fk, p_ids BIGINT[])` — riordino atomico `ordine` via UNNEST WITH ORDINALITY. Nessun unique su ordine → nessun deferrable.
- `fn_web_tour_immagini_set_principale(p_id, p_azienda_id, p_viaggio_id_fk)` — imposta l'immagine `principale` e retrocede le altre del viaggio a `galleria`, in un solo statement (atomico).
- `WebTourImmaginiService`: `ReorderAsync`, `SetPrincipaleAsync`. `Funzioni_DB.md` aggiornato.

## 5. UI — 5° tab "Galleria"

`Components/Shared/WebTourGalleriaTab.razor` (+ `.razor.css`), montato come 5° `MudTabPanel` in `AnaViaggiDialog`, **solo edit mode**.
- `MudFileUpload` multiplo (accept image/*). Per file: `WebImageProcessor` → `IWebMediaStorage.UploadAsync` → `WebTourImmaginiService.CreateAsync` (url = BuildPublicUrl). Progress/spinner durante l'upload.
- Griglia thumbnail con **DnD reorder** (MudDropContainer, 1 zona, `AllowReorder`) → `ReorderAsync`. Per immagine: `alt_text`/`titolo` editabili (no uppercase, web), azione **copertina** (`SetPrincipaleAsync`, badge sulla principale), elimina (record + `DeleteAsync` dallo storage).
- **Live-save** (come Blocchi 5/6). MUST UI: setupTabNavigation, BackdropClick=false dal chiamante.

## 6. Picker passo→galleria (chiude Blocco 6)

`WebTourPassoEditDialog` riceve `ViaggioId`/`AziendaId`; carica la galleria (`ListByViaggioAsync`) e mostra un selettore (griglia thumbnail o select). Scelta un'immagine → valorizza `immagine_storage_path` + `immagine_url` (`BuildPublicUrl`) sul passo (opzionale: precompila la didascalia). `WebTourItinerarioTab` passa i parametri e la card del passo mostra la thumbnail.

## 7. Edge cases / note

- Upload fallito (key placeholder / rete): snackbar d'errore, nessun record inserito.
- Elimina immagine → prima record poi storage (o viceversa con best-effort sullo storage); l'orfano residuo è tollerato (purge orfani = funzione differita, non in questo blocco).
- Immagine principale eliminata → nessuna principale finché non se ne imposta un'altra (accettabile).
- Formati non-immagine caricati → ImageSharp fallisce → errore gestito.

## 8. Verifica (criteri del blocco)

- Immagini ridimensionate/convertite (WebP, ≤2000px), `larghezza/altezza`/`mime` salvati.
- `storage_path` salvato; URL ricomposto valido (apre l'immagine).
- alt/titolo salvati; ordinamento persistito e stabile; una sola `principale`.
- Picker passo: seleziona dalla galleria, il passo mostra la thumbnail.
- Build `net9.0-maccatalyst`: 0 errori. (Upload reale a runtime richiede una ServiceKey vera del bucket di test.)

## 9. Deliverable

1. SqlScripts `457`/`458` + `Funzioni_DB.md`.
2. `SupabaseMediaStorage`, `WebImageProcessor`; registrazione DI.
3. `ReorderAsync`/`SetPrincipaleAsync` nel service.
4. `WebTourGalleriaTab.razor` + `.razor.css`; 5° tab in `AnaViaggiDialog`.
5. Picker in `WebTourPassoEditDialog` + wiring `WebTourItinerarioTab`.
6. `ComponentiShared.md` aggiornato; nota sicurezza (debito go-live).
