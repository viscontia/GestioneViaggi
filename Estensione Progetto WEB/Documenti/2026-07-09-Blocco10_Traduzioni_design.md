# Blocco 10 — Traduzione automatica Claude API — DESIGN DOC

> **USO INTERNO (Adriano + AI).** Design consolidato prima dell'implementazione.
> **Versione:** 1.0 · **Data:** 2026-07-09
> **Base:** Piano Operativo (Blocco 10, Fase 2.7), Analisi Tecnica, tabella/service `web_traduzioni` (Blocchi 1/4), `fn_web_tour_pubblicati` (legge già le traduzioni).

---

## 1. Scope e obiettivo

Pulsante "Traduci" che genera, via **Claude API** (HTTP REST, no SDK), le traduzioni dei campi editoriali del tour, salvandole **per-campo/lingua** in `web_traduzioni` con flag `tradotto_auto`. Quando l'italiano sorgente cambia, le sue traduzioni diventano **obsolete**. UI di revisione per correggere e marcare `revisionato`.

## 2. Decisioni prese (brainstorming 2026-07-09)

- **Lingue target: EN, DE, FR, ES** (italiano = sorgente; 5 lingue totali sul sito). `web_traduzioni.lingua` = char(2).
- **Chiave Claude: per-azienda**, **nuova colonna `ana_aziende.claude_api_key`** (niente tabella nuova; si edita con la form Aziende esistente). In chiaro per ora → **aggiunta al debito "cifrare pre-rilascio"** (memoria `encrypt-smtp-esp-before-release`, con SMTP/ESP).
- **Scope campi traducibili:** `web_tour_contenuti` (sottotitolo, descrizione_html, durata_testo, luoghi_visitati, info_pernottamento_html, info_pasti_html, info_equipaggiamento_html, altre_info_html, meta_title, meta_description), `web_tour_itinerario_passaggi` (testo_html), `web_tipi_viaggio_descrizioni` (descrizione_web).
- **Obsolescenza:** nel salvataggio C# (confronto campi cambiati) → `fn_web_traduzioni_marca_obsolete`.
- **Modello:** Claude **Haiku 4.5** (traduzione semplice/economica), configurabile.

## 3. Componenti nuovi

- **DB**: `ALTER TABLE ana_aziende ADD COLUMN claude_api_key TEXT`. Nuova `fn_web_traduzioni_marca_obsolete(p_azienda_id, p_entita, p_entita_id, p_campo)` (marca `obsoleto=true` le traduzioni del campo). Eventuale `fn_web_traduzioni_upsert` per (entita,entita_id,campo,lingua) se non già coperto dal CRUD.
- **`Services/Shared/Ai/ClaudeTranslationClient.cs`** (HttpClient, no SDK): chiama l'API Messages di Anthropic con la chiave dell'azienda; prompt che **preserva l'HTML** e **non traduce i nomi propri** (toponimi, nomi di tour/marchi). Modello da opzioni.
- **`Services/Web/WebTraduzioneOrchestratorService.cs`**: per ogni (campo × lingua) legge il sorgente IT, chiama Claude, upsert `web_traduzioni` (`tradotto_auto=true`, `revisionato=false`, `obsoleto=false`, `data_traduzione`). Salta i campi IT vuoti.
- **Model/Service azienda**: aggiungere `ClaudeApiKey` al model azienda + persistenza nella form Aziende (`AziendaDialog`/service).
- **Obsolescenza**: in `WebTourContenutiService`/`WebTourItinerarioPassaggiService`/`WebTipiViaggioDescrizioniService` Update: se un campo traducibile IT cambia → chiama `fn_web_traduzioni_marca_obsolete`. (Confronto col valore precedente letto prima dell'update.)
- **UI — 7° tab "Traduzioni"** in `AnaViaggiDialog` (solo edit): tabella campi × lingue con **stato** (tradotto / da revisionare / obsoleto / mancante); pulsante "Traduci tutto" e per lingua; per voce: edit testo + toggle `revisionato`. Avviso se `claude_api_key` dell'azienda non è configurata.

## 4. Prompt (traduzione)

Sistema: "Sei un traduttore per un sito di tour offroad. Traduci dall'italiano a {lingua}. **Conserva l'HTML** inalterato (tag/attributi). **Non tradurre nomi propri**: toponimi, nomi di tour, marchi. Rendi solo il testo, senza commenti." Input = il valore del campo. Output = solo la traduzione.

## 5. Note / rischi

- **Costo/quota**: chiamate multiple (campi × 4 lingue). Traduci on-demand (pulsante), non automatico. Haiku per contenere i costi.
- **HTML**: verificare che Claude non alteri i tag (il prompt lo impone; validare in revisione).
- **Chiave mancante/errata** → messaggio chiaro; nessuna traduzione parziale salvata a metà (per-campo atomico).
- `entita` in `web_traduzioni`: usare i nomi tabella (`web_tour_contenuti`, `web_tour_itinerario_passaggi`, `web_tipi_viaggio_descrizioni`); `entita_id` = PK della riga sorgente.

## 6. Verifica (criteri del blocco)

- 4 lingue prodotte per i campi valorizzati; `tradotto_auto=true`.
- Modifica dell'IT → traduzioni del campo marcate `obsoleto`.
- Nomi propri non tradotti; HTML preservato.
- Revisione: edita + `revisionato=true`.
- Build `net9.0-maccatalyst`: 0 errori. (Test reale richiede una `claude_api_key` valida sull'azienda.)

## 7. Deliverable

1. SQL: colonna `ana_aziende.claude_api_key` + `fn_web_traduzioni_marca_obsolete` (+ eventuale upsert) + `Funzioni_DB.md`.
2. `ClaudeTranslationClient` + opzioni/DI.
3. `WebTraduzioneOrchestratorService`.
4. `ClaudeApiKey` nel model/form azienda.
5. Marcatura obsolescenza nei service sorgente.
6. UI `WebTraduzioniTab.razor` + 7° tab.
7. Doc: `ComponentiShared.md`.
