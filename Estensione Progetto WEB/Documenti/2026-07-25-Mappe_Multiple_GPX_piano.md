# Mappe multiple da GPX — piano di implementazione

> **Per Claude:** SUB-SKILL RICHIESTA: usare `superpowers:executing-plans` per eseguire questo piano task per task.

**Goal:** portare `web_tour_mappa` da una mappa per edizione a N mappe, ognuna abbinata all'intero viaggio o a una singola giornata dell'itinerario, con descrizione tradotta, blocco dei duplicati e tracciato più generalizzato.

**Architettura:** i vincoli semantici (una mappa per giornata, una sola d'insieme, descrizione obbligatoria per l'insieme, no doppioni) sono **imposti dal DB**, non dalla form. L'abbinamento è una FK verso `web_tour_itinerario`; la data della giornata si **deriva** da `data_viaggio_data_inizio + (giorno_numero − 1)`, garantita dal trigger `trg_validate_date_viaggio_duration`.

**Stack:** PostgreSQL 17 (Docker `postgres_db`, deploy con `./deploy_sql.sh`), .NET MAUI Blazor Hybrid, MudBlazor, Dapper/Npgsql, QuestPDF, Supabase Storage, Geoapify Static Maps.

**Design di riferimento:** `Estensione Progetto WEB/Documenti/2026-07-25-Mappe_Multiple_GPX_design.md`

**Vincolo di verifica noto:** il progetto xUnit non gira da CLI (NU1201). Verifica: asserzioni SQL su Docker + `dotnet build -f net9.0-maccatalyst` + prova a runtime. Vedi memoria `unit-tests-cli-blocked-nu1201`.

---

## Task 1 — Campioni visivi di semplificazione (decisione utente) — ✅ FATTO 2026-07-25

Eseguito replicando la pipeline C# in Python (script nello scratchpad): la replica ha prodotto **220 punti** con i parametri attuali, identici a `parametri_render` della generazione reale → campioni attendibili.

Esito: la tolleranza in metri è stata **scartata** (su una tappa di un giorno 600 m collassano la traccia a 6 punti). Si usa il **budget di punti**, già presente come `MaxPolylinePoints`. **Valore scelto dall'utente: 70.** Dettagli e tabella dei campioni nel design, §Semplificazione.

---

## Task 2 — Ritaratura del budget di punti

**Files:**
- Modifica: `Services/Shared/Geo/GeoapifyOptions.cs`
- Modifica: `appsettings.json`, `appsettings.Development.json`

`DouglasPeucker.cs` **non** si tocca: con la semantica "budget" l'uscita anticipata su tracce già sotto la soglia è corretta.

**Step 1.** In `GeoapifyOptions` portare `MaxPolylinePoints` da 280 a **70**, aggiornando il commento: non è più solo un cap per la lunghezza dell'URL, è il criterio di generalizzazione del tracciato.

**Step 2.** Esporre `"MaxPolylinePoints": 70` nella sezione `Geoapify` dei due appsettings, così è ritoccabile senza ricompilare.

**Step 3.** Verifica: `dotnet build -f net9.0-maccatalyst -v q --nologo` → 0 errori. Poi, a runtime, "Rigenera" sulla mappa esistente e controllo del conteggio punti:

```bash
docker exec -i postgres_db psql -U postgres -d gestione_viaggi \
  -c "select parametri_render->>'punti_originali', parametri_render->>'punti_semplificati' from web_tour_mappa"
```

Atteso: `punti_semplificati` ≈ 70 (era 220).

**Step 4. Commit:** `feat(mappa): budget di 70 punti per generalizzare il tracciato`

---

## Task 3 — Modello dati, vincoli e backfill

**Files:**
- Create: `SqlScripts/493_WebTourMappa_Multiple.sql`

**Step 1 (test-first).** Scrivere le asserzioni che oggi **falliscono**, e verificarlo:

```sql
-- atteso PRIMA: fallisce (esiste UNIQUE su web_tour_contenuti_id_fk)
SELECT 'multi-mappa' AS check,
       NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conrelid='web_tour_mappa'::regclass AND contype='u'
                     AND pg_get_constraintdef(oid) = 'UNIQUE (web_tour_contenuti_id_fk)') AS ok;
-- atteso PRIMA: fallisce (colonne assenti)
SELECT 'colonne' AS check,
       COUNT(*) = 3 AS ok FROM information_schema.columns
 WHERE table_name='web_tour_mappa'
   AND column_name IN ('web_tour_itinerario_id_fk','descrizione','gpx_bytes');
```

Eseguirle e annotare `ok = false`.

**Step 2.** Scrivere `493_WebTourMappa_Multiple.sql` con, in quest'ordine:

1. `ALTER TABLE web_tour_mappa DROP CONSTRAINT IF EXISTS web_tour_mappa_web_tour_contenuti_id_fk_key;`
2. `ADD COLUMN IF NOT EXISTS` per le tre colonne (`web_tour_itinerario_id_fk BIGINT`, `descrizione VARCHAR(255)`, `gpx_bytes INTEGER`);
3. FK: `web_tour_itinerario_id_fk` → `web_tour_itinerario(web_tour_itinerario_id)` **ON DELETE RESTRICT**;
4. **backfill prima dei vincoli**: `UPDATE web_tour_mappa SET descrizione = COALESCE(NULLIF(btrim(gpx_filename),''), 'Mappa del tour') WHERE web_tour_itinerario_id_fk IS NULL AND COALESCE(btrim(descrizione),'') = '';`
5. i quattro vincoli del design (unique giornata; unique parziale insieme; check descrizione; unique dedup su `(contenuto, lower(gpx_filename), gpx_bytes)`).

Tutto idempotente (`IF NOT EXISTS`, `DROP ... IF EXISTS` prima di `CREATE INDEX`).

**Step 3.** Deploy: `./deploy_sql.sh SqlScripts/493_WebTourMappa_Multiple.sql`

**Step 4.** Rieseguire le asserzioni dello Step 1 → `ok = true`. Poi verificare che i vincoli **mordano** davvero:

```sql
-- deve fallire: seconda mappa d'insieme sulla stessa edizione
INSERT INTO web_tour_mappa (web_tour_contenuti_id_fk, azienda_id, created_by, descrizione)
VALUES (11, 2, 'test', 'doppione insieme');
-- deve fallire: mappa d'insieme senza descrizione
-- deve fallire: stesso (contenuto, filename, bytes)
```

Ognuna deve dare errore; annotare il messaggio per il passo successivo.

**Step 5.** Rieseguire lo script per confermare l'idempotenza (secondo giro senza errori).

**Step 6.** Aggiungere i nuovi constraint a `Helpers/DatabaseExceptionHelper` (messaggi in italiano) — vedi `Documents/Gestione_check.md`, mai traduzioni inline nei componenti.

**Step 7. Commit:** `feat(db): web_tour_mappa multipla con abbinamento giornata (493)`

---

## Task 4 — CRUD DB aggiornata

**Files:**
- Create: `SqlScripts/494_FnWebTourMappa_Crud_Multiple.sql`

**Step 1.** `DROP FUNCTION` esplicito delle firme precedenti di `fn_web_tour_mappa_insert` e `_update` (convenzione Blocco 13), poi ricrearle con i tre parametri nuovi in coda.

**Step 2.** Nuova `fn_web_tour_mappa_list_by_contenuto(p_contenuto_id BIGINT, p_azienda_id INTEGER)` che ritorna le mappe dell'edizione ordinate: prima l'insieme (`web_tour_itinerario_id_fk IS NULL`), poi le giornate per `giorno_numero` (join su `web_tour_itinerario`).

**Step 3.** Deploy con `./deploy_sql.sh` e verifica:

```sql
SELECT * FROM fn_web_tour_mappa_list_by_contenuto(11, 2);
```

**Step 4. Commit:** `feat(db): CRUD mappe multiple + list per contenuto (494)`

---

## Task 5 — Model e Service C#

**Files:**
- Modifica: `Models/Web/WebTourMappa.cs`
- Modifica: `Services/Web/WebTourMappaService.cs`

**Step 1.** Aggiungere al model `WebTourItinerarioIdFk` (`long?`), `Descrizione` (`string?`), `GpxBytes` (`int?`), con mapping snake_case coerente al resto.

**Step 2.** In `WebTourMappaService`: nuova `ListByContenutoAsync(long contenutoId, int aziendaId)` sul modello di `WebTourContenutiService.ListByAziendaAsync`; aggiornare i parametri di insert/update.

**Step 3.** Verifica: `dotnet build -f net9.0-maccatalyst` → 0 errori.

**Step 4. Commit:** `feat(mappa): model e service per mappe multiple`

---

## Task 6 — Generator: dedup, abbinamento, Storage

**Files:**
- Modifica: `Services/Web/WebTourMappaGeneratorService.cs:36-89`

**Step 1.** Firma: `GenerateAsync(long contenutoId, int aziendaId, string gpxText, string? gpxFilename, long? itinerarioId, string? descrizione, CancellationToken ct)`.

**Step 2.** Controllo duplicato **prima** di chiamare Geoapify: `ListByContenutoAsync` e confronto su `lower(gpxFilename)` + `gpx_bytes` (dimensione in byte del testo GPX). Se esiste ed è una mappa diversa da quella che si sta rigenerando → `InvalidOperationException` con messaggio chiaro. Il vincolo DB resta come difesa.

**Step 3.** Percorso Storage per abbinamento invece del fisso `mappa.webp` (riga 54):

```csharp
var suffisso = itinerarioId == null ? "viaggio" : $"g{giornoNumero}";
var storagePath = $"{aziendaId}/{contenutoId}/mappa-{suffisso}.webp";
```

**Step 4.** Upsert per *(contenuto, giornata)* invece del 1:1 (riga 71).

**Step 5.** Eliminazione: cancellare anche l'oggetto dallo Storage (`IWebMediaStorage`) quando si elimina la mappa.

**Step 6.** Verifica build + prova runtime: caricare due GPX diversi sulla stessa edizione e controllare che coesistano; ricaricare lo stesso e verificare il rifiuto.

**Step 7. Commit:** `feat(mappa): dedup GPX, abbinamento giornata, storage per mappa`

---

## Task 7 — UI tab Mappa

**Files:**
- Modifica: `Components/Shared/WebTourMappaTab.razor`

**Step 1.** Da mappa singola a elenco: `_mappe` (List) al posto di `_mappa`, card per ciascuna con immagine, descrizione, abbinamento, GPX, data, Rigenera, Elimina.

**Step 2.** Form di caricamento con `MudRadioGroup` (Intero viaggio / Una giornata), `MudSelect` delle giornate del contenuto etichettate "Giorno N — ddd dd/MM/yyyy — titolo", e campo descrizione precompilato dal titolo della giornata.

**Step 3.** Regole UI: descrizione obbligatoria per l'intero viaggio; giornate già usate escluse dal select; nota in chiaro sui GPX per porzioni di giornata (design §UI).

**Step 4.** Rispettare le regole form del progetto (`overview.md` §3.3): errore ⇒ restare nella form, messaggi da `DatabaseExceptionHelper`.

**Step 5.** Verifica build + runtime.

**Step 6. Commit:** `feat(mappa): elenco mappe e form di abbinamento nel tab Mappa`

---

## Task 8 — Data reale accanto alle giornate

**Files:**
- Modifica: `Components/Shared/WebTourItinerarioTab.razor`
- Modifica: `Components/Shared/WebEdizioniManager.razor:92-95`

**Step 1.** Nuovo `[Parameter] public DateTime? DataInizio` su `WebTourItinerarioTab`; il manager passa `_selected.DataInizio`.

**Step 2.** Helper locale: `DataGiorno(int giornoNumero) => DataInizio?.AddDays(giornoNumero - 1)`; se `giornoNumero > NumeroGiorni` ritorna null (giornata extra, l'app le consente con avviso).

**Step 3.** Mostrare "Giorno N — sab 02/05/2026" nel sommario laterale e nell'intestazione della giornata. Formato italiano (`it-IT`).

**Step 4.** Verifica build + runtime sull'edizione 02/05–07/05: Giorno 1 = sab 02/05/2026, Giorno 6 = gio 07/05/2026.

**Step 5. Commit:** `feat(itinerario): data reale della giornata derivata dall'edizione`

---

## Task 9 — Descrizione mappa tradotta

Da fare **insieme** in entrambi i punti: se il denominatore delle traduzioni diverge, il semaforo Traduzioni conta male.

**Files:**
- Modifica: `Services/Web/WebTraduzioneOrchestratorService.cs:66-113`
- Create: `SqlScripts/495_FnWebTourStatoSezioni_Mappe.sql`

**Step 1.** In `GetTranslatableItemsAsync` aggiungere le descrizioni delle mappe del contenuto: entità `web_tour_mappa`, campo `descrizione`, label "Mappa — {descrizione}".

**Step 2.** In `495` ricreare `fn_web_tour_stato_sezioni` con un `UNION ALL` in più nella CTE `traducibili` per `web_tour_mappa.descrizione` (stesso test `~ '[^[:space:]]'`).

**Step 3.** Verifica incrociata: il conteggio `n_traducibili` della funzione deve coincidere con `_items.Count` del tab Traduzioni sullo stesso contenuto.

**Step 4. Commit:** `feat(traduzioni): descrizione mappa nei campi tradotti (495)`

---

## Task 10 — Anteprima con N mappe

**Files:**
- Modifica: `Components/Shared/WebTourAnteprimaDialog.razor:86-90,129`

**Step 1.** Da `GetByContenutoAsync` a `ListByContenutoAsync`; rendere le mappe in sequenza con la loro descrizione, l'insieme per prima.

**Step 2.** Verifica build + runtime.

**Step 3. Commit:** `feat(anteprima): mostra tutte le mappe dell'edizione`

---

## Task 11 — Documentazione

**Files:**
- Modifica: `Documents/Funzioni_DB.md` (parte curata: `fn_web_tour_mappa_*` aggiornate, `list_by_contenuto`, `fn_web_tour_stato_sezioni` con il ramo mappe)
- Modifica: `Documents/ComponentiShared.md` (tab Mappa a elenco, data nelle giornate)
- Modifica: `Estensione Progetto WEB/Documenti/2026-07-10-Checklist_Go_Live_PROD.md` (script 493–495 in §1, range del loop)
- Modifica: `Estensione Progetto WEB/Documenti/2026-07-09-Piano_Test_Estensione_Web.md` (casi: due mappe, doppione rifiutato, eliminazione giornata con mappa, date giornate)

**Step 1.** Aggiornare i quattro documenti.

**Step 2.** Verifica: `grep` dei numeri script per coerenza del range nella checklist.

**Step 3. Commit:** `docs(mappe): allinea Funzioni_DB, ComponentiShared, checklist e piano test`

**Step 4.** Ricordare all'utente `/graphify --update` (le modifiche documentali non sono coperte dall'hook).

---

## Note di esecuzione

- Ogni script SQL va sempre deployato con `./deploy_sql.sh`, mai con `docker exec` a mano (rigenera l'appendice di `Funzioni_DB.md`).
- Nessun SQL inline nel C#: ogni query è una funzione DB (`overview.md` §3.1).
- I task 3, 4, 9 toccano il DB: se si esegue su un DB già popolato, verificare il backfill prima dei vincoli.
- Il Task 1 richiede una decisione dell'utente: non proseguire al Task 2 senza il valore scelto.
