# Blocco 6 — Itinerario giorno-per-giorno — DESIGN DOC

> **USO INTERNO (Adriano + AI).** Design consolidato e approvato prima dell'implementazione.
> **Versione:** 1.0 · **Data:** 2026-07-05
> **Base:** `2026-07-03-Piano_Operativo_Estensione_Web_design.md` (Blocco 6, Fase 2.3), schema Blocco 1, funzioni/servizi Blocchi 2 e 4.

---

## 1. Scope

Scheda **"Itinerario"** nel dialog viaggio: struttura a due livelli **Giornate → Passi**, con drag&drop su entrambi i livelli.

- **In scope:** UI del tab, wiring ai servizi esistenti, due funzioni DB di reorder atomico.
- **Fuori scope (rinviato):** UI immagine del passo (upload/galleria) → **Blocco 7**. Nel Blocco 6 il passo ha solo testo RichText + didascalia; le colonne `immagine_url`/`immagine_storage_path` restano pronte ma non cablate in UI.

Tutto lo strato dati/servizi esiste già:
- Tabelle: `web_tour_itinerario` (giornate: `giorno_numero`, `titolo_giornata`, `ordine`), `web_tour_itinerario_passaggi` (passi: `testo_html`, `immagine_didascalia`, `ordine`, `itinerario_id_fk`). Id **bigint**.
- Servizi: `WebTourItinerarioService` (`ListByViaggioAsync`, Create/Update/Delete), `WebTourItinerarioPassaggiService` (`ListByItinerarioAsync`, Create/Update/Delete). Entrambi Scoped, DB-first.

## 2. Architettura UI

Nuovo componente shared **`WebTourItinerarioTab.razor`**, montato come **4° `MudTabPanel` "Itinerario"** in `AnaViaggiDialog`, **solo in edit mode** (FK su viaggio salvato, stesso motivo di "Contenuti Web").

**Pattern "Sidebar + Main Board" — due `MudDropContainer` PARALLELI (non annidati):**

- **Sidebar `MudItem xs=3` — `MudDropContainer<GiornataVM>`** (1 zona): riordino giornate con DnD vero. Card compatta con `DragIndicator` + `titolo_giornata` + "Giorno N".
- **Board `MudItem xs=9` — `MudDropContainer<PassoVM>`** (1 zona **per giornata**, generate da `@foreach _giornate.OrderBy(Ordine)`): i passi si trascinano dentro **e tra** le giornate.

**Perché funziona (deterministico):** i due container sono paralleli → nessun conflitto di puntatore sulla WebView MAUI. Il riordino delle giornate è **implicito**: `OnGiornataDropped` aggiorna solo `Ordine`, il `@foreach ... OrderBy(Ordine)` della board ridisegna le zone nel nuovo ordine. Le zone dei passi hanno `Identifier = giornata.Id` → i passi restano legati alla loro giornata a prescindere dalla posizione visiva. La posizione visiva è solo un riflesso dei dati.

## 3. Persistenza — live-save real-time

Ogni azione persiste subito (coerente col tab Date già live in edit mode); **nessun pulsante "Salva" globale**, nessun dirty-state.

- **Aggiungi/elimina giornata, aggiungi/elimina passo, modifica contenuto** → `Create/Update/Delete` dei servizi esistenti.
- **Riordino/spostamento** → **due nuove funzioni DB di reorder atomico** (scelta raccomandata; alternativa = N `UpdateAsync`, ma non atomica → rischio `ordine` incoerente):
  - `fn_web_tour_itinerario_reorder(p_azienda_id, p_viaggio_id_fk, p_ids bigint[])` → riscrive `ordine` (e `giorno_numero`) = posizione nell'array, in un colpo, scopato per azienda+viaggio.
  - `fn_web_tour_itinerario_passaggi_reorder(p_azienda_id, p_itinerario_id_fk, p_ids bigint[])` → per la zona/giornata indicata riscrive per ogni id `itinerario_id_fk = p_itinerario_id_fk` e `ordine` = posizione. Il **cross-day** è un id che compare nell'array della giornata di arrivo (viene reparentato); sul drop si chiama il reorder della zona di **arrivo** e di quella di **partenza**.
  - Script SQL nuovi numerati da **454**; aggiornare `Documents/Funzioni_DB.md` (parte curata) dopo il deploy.
  - Metodi `ReorderAsync(...)` aggiunti ai due service (unica SQL = chiamata a funzione).

## 4. Editing contenuto del passo

Le **card dei passi restano leggere** (snippet di testo + didascalia): niente Quill inline nella card trascinabile (30 passi = 30 init JS + guerra eventi puntatore Quill↔MudBlazor → ghost drag). Il click sulla card apre un **piccolo `MudDialog` on-demand** con **editor Quill** (`testo_html`, stesso pattern di Blocco 5) + campo `immagine_didascalia`. Salva → `UpdateAsync` del passo → aggiorna la card.

## 5. Dettagli MudBlazor da rispettare

- **DropZone vuota — collasso a zero pixel:** una giornata senza passi collassa e diventa un bersaglio di drop inesistente. CSS zona passi con **`min-height`** + feedback hover:
  ```css
  .drop-zone-passo { min-height: 100px; transition: background-color .2s ease; }
  .drop-zone-passo.mud-dropzone-hover {
      background-color: var(--mud-palette-action-default-hover) !important;
      border: 2px dashed var(--mud-palette-primary);
  }
  ```
- **API 8.15 da verificare in fase di implementazione** contro il pacchetto installato (niente API inventate): tipo dell'event args (`MudItemDropInfo<T>`), esistenza di helper tipo `.UpdateOrder(...)`/`ItemsSelector`/`Refresh()`. Se assenti → renumber a mano (equivalente).
- VM di UI (`GiornataVM`/`PassoVM`) mappati sullo schema reale (Id **bigint**, `titolo_giornata`, `testo_html`, `immagine_didascalia`), non sui placeholder della sketch.

## 6. MUST UI (checkpoint overview §3.3)

- `AutoFocus` sul primo campo (titolo prima giornata / campo di aggiunta).
- `dialogFormHelper.setupTabNavigation` all'attivazione del tab.
- **Niente uppercase forzato** sui campi editoriali (titolo giornata, testo, didascalia → destinati al web; eccezione documentata come in Blocco 5).
- `BackdropClick=false` già impostato dal chiamante del dialog.
- Riuso componenti shared; `ComponentiShared.md` aggiornato a fine blocco.

## 7. Edge cases

- Viaggio senza itinerario → stato vuoto con invito "Aggiungi la prima giornata".
- Elimina giornata con passi → conferma (`DeleteConfirmationDialog`); i passi seguono (FK) o vanno spostati prima (decidere: cascade DB vs blocco con avviso — verificare vincolo FK esistente).
- Riordino durante un salvataggio in corso → live-save sequenziale, disabilita interazione mentre persiste.

## 8. Verifica (criteri del blocco)

- Ordine giornate e passi **persistito** (chiudi/riapri dialog → stesso ordine).
- **Riordino stabile:** trascinamenti ripetuti, cross-day, giornate vuote → nessun `ordine` incoerente, nessuno stato spurio.
- Editor Quill nel dialog: carica/salva `testo_html`, didascalia.
- Build `net9.0-maccatalyst`: 0 errori.

## 9. Deliverable

1. SqlScripts `454_*`, `455_*` (reorder giornate + passi) + `Funzioni_DB.md`.
2. `ReorderAsync` nei due service.
3. `WebTourItinerarioTab.razor` + CSS zona.
4. Dialog editor passo (Quill + didascalia).
5. 4° tab in `AnaViaggiDialog` (edit mode).
6. `ComponentiShared.md` aggiornato.
