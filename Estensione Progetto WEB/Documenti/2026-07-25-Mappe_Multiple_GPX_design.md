# Mappe multiple da GPX — design

> Da una mappa per edizione a **N mappe**, ognuna con un significato dichiarato: o l'intero viaggio, o una singola giornata dell'itinerario. Più descrizione tradotta, blocco dei GPX duplicati e semplificazione più aggressiva del tracciato. Validato con Adriano il 2026-07-25.

## Problema

Il tab Mappa sembra accettare più GPX, ma **non è così**: `web_tour_mappa` ha `UNIQUE (web_tour_contenuti_id_fk)` e `WebTourMappaGeneratorService.GenerateAsync` fa un upsert 1:1. Caricando un secondo GPX si **perde il primo**, e anche l'immagine si sovrascrive perché il percorso su Storage è fisso (`{azienda}/{contenuto}/mappa.webp`). La UI lo dice già ("Sostituisci con un nuovo GPX"), ma è facile fraintenderlo.

Servono più mappe perché un tour di più giorni ha una traccia per giornata. Ma N file GPX senza una semantica dichiarata sono inutilizzabili a valle: dal GPX non si può dedurre a cosa si riferisca (le tracce sono spesso ricognizioni o costruite a tavolino, con date che non c'entrano col viaggio venduto). Dedurre = indovinare.

Tre richieste, decise insieme:
1. descrizione della mappa caricata (es. "Giorno 1 — da Milano a Torino");
2. impedire il caricamento dello stesso GPX due volte (stesso nome + stessa dimensione);
3. tracciato **meno fedele al reale**, per non renderlo replicabile da chi conosce il territorio.

## Decisioni

**Due soli casi ammessi.** Ogni mappa è o *dell'intero viaggio*, o *di una singola giornata*. I GPX che coprono porzioni di giornata (o che uniscono più giornate) sono **esclusi**: sarebbero difficili da rappresentare in modo relazionale e soprattutto incomprensibili per il cliente sul sito e sul flyer. La regola è scritta in chiaro nella form e **imposta dal DB**, non lasciata alla buona volontà dell'utente.

**L'abbinamento è alla giornata dell'itinerario, non a una data.** `ana_date_viaggi` contiene una riga per **partenza** (`data_viaggio_data_inizio`/`_fine`), non una riga per giornata: le giornate esistono solo come righe di `web_tour_itinerario`. Quindi la mappa punta alla giornata con una FK vera, e la data si **deriva**.

**Le giornate sono già ancorate a date reali.** Il trigger `trg_validate_date_viaggio_duration` rifiuta ogni edizione la cui durata (`data_fine − data_inizio + 1`) non coincida con `ana_viaggi.viaggio_numero_giorni`; dal Blocco 13 il contenuto web è figlio di *(viaggio + data_viaggio)*. Quindi:

```
Giorno N  →  data_viaggio_data_inizio + (N − 1)
```

è esatto e non può divergere. Mancava solo mostrarlo nella UI. **Non** si memorizza la data sulla riga di itinerario: sarebbe un duplicato derivabile che va fuori sincrono se si spostano le date della partenza, e soprattutto `fn_web_tour_contenuti_clona` copierebbe su un'altra edizione delle date sbagliate. Derivare è più robusto che memorizzare.

**La descrizione è testo per il cliente → va tradotta** come sottotitolo e descrizione (`web_traduzioni`, entità `web_tour_mappa`, campo `descrizione`).

## Modello dati (`SqlScripts/493`)

Su `web_tour_mappa`: rimosso il `UNIQUE` su `web_tour_contenuti_id_fk`; aggiunte

- `web_tour_itinerario_id_fk BIGINT NULL` → FK a `web_tour_itinerario`, **ON DELETE RESTRICT**;
- `descrizione VARCHAR(255) NULL`;
- `gpx_bytes INTEGER NULL` (dimensione del file caricato, per il dedup).

Vincoli — le decisioni sopra diventano regole DB:

| Vincolo | Impedisce |
|---|---|
| `UNIQUE (web_tour_itinerario_id_fk)` | due mappe sulla stessa giornata → niente GPX spezzettati |
| `UNIQUE (web_tour_contenuti_id_fk) WHERE web_tour_itinerario_id_fk IS NULL` | più di una mappa "intero viaggio" per edizione |
| `CHECK (web_tour_itinerario_id_fk IS NOT NULL OR descrizione valorizzata)` | mappa d'insieme senza descrizione |
| `UNIQUE (web_tour_contenuti_id_fk, lower(gpx_filename), gpx_bytes)` | stesso GPX caricato due volte nella stessa edizione |

`ON DELETE RESTRICT` sulla giornata: eliminando una giornata che ha una mappa il DB blocca con messaggio tradotto da `DatabaseExceptionHelper`, invece di far sparire in silenzio una mappa generata lasciando il WebP orfano nel bucket. Stessa linea già adottata per le foto in uso nell'itinerario (`fn_web_immagini_in_uso`).

**Backfill nello stesso script**: le mappe esistenti diventano mappe d'insieme con `descrizione = COALESCE(NULLIF(gpx_filename,''), 'Mappa del tour')`, altrimenti il `CHECK` non passerebbe.

Nota: il dedup è per edizione, quindi la stessa traccia non è riusabile su due giornate della stessa edizione (caso "anello ripetuto"). Accettato: è raro e l'alternativa indebolirebbe il controllo richiesto.

## Pipeline e servizi

`GenerateAsync(contenutoId, aziendaId, gpxText, gpxFilename, itinerarioId?, descrizione, ct)`:

1. **controllo duplicato prima di Geoapify** (nome + dimensione) → un doppione non consuma una chiamata API;
2. parse GPX → Douglas-Peucker → bbox → Geoapify → WebP → Storage;
3. percorso Storage parlante e stabile: `{azienda}/{contenuto}/mappa-viaggio.webp` oppure `mappa-g{N}.webp` — rigenerare sovrascrive, non accumula;
4. upsert per *(contenuto, giornata)* invece che 1:1.

`WebTourMappaService`: nuova `ListByContenutoAsync`; `GetByContenutoAsync` resta per la mappa d'insieme. `fn_web_tour_mappa_insert`/`_update` cambiano firma (drop + create, convenzione Blocco 13). Su eliminazione si cancella anche l'oggetto dallo Storage.

## UI — tab Mappa

Da riquadro singolo a **elenco**: una card per mappa con immagine, descrizione, abbinamento ("Intero viaggio" / "Giorno 3 — lun 04/05/2026"), nome GPX, data di generazione, Rigenera, Elimina. Ordine naturale: prima l'insieme, poi le giornate per `giorno_numero`.

```
Carica un GPX
  [ Scegli GPX ]  Colle-Follonica-G1.GPX

  Questa mappa si riferisce a:
   ( ) Intero viaggio        → descrizione obbligatoria
   (•) Una giornata          → [ Giorno 1 — sab 02/05/2026 — Colle Val d'Elsa ▾ ]

  Descrizione  [ Giorno 1 — Colle Val d'Elsa            ]   ← proposta, modificabile

  Nota: una mappa per giornata, oppure una per l'intero viaggio.
        Non sono ammessi GPX che coprono porzioni di giornata.

  [ Genera mappa ]
```

La descrizione è **proposta** dal titolo della giornata scelta e resta modificabile; per l'intero viaggio è obbligatoria.

## Itinerario — data accanto alla giornata

`WebEdizioniManager` passa la data di inizio dell'edizione a `WebTourItinerarioTab`, che mostra "Giorno 1 — sab 02/05/2026" nel sommario e nell'intestazione della giornata. Nessun dato nuovo sul DB. Le giornate eccedenti la durata prevista (l'app le consente con avviso) restano senza data.

## Traduzioni

`web_tour_mappa.descrizione` entra nell'insieme dei campi traducibili. Due punti da toccare **insieme**, altrimenti il semaforo Traduzioni conta un denominatore sbagliato:

- `WebTraduzioneOrchestratorService.GetTranslatableItemsAsync` — aggiungere le descrizioni delle mappe del contenuto (entità `web_tour_mappa`);
- `fn_web_tour_stato_sezioni` (`SqlScripts/492`) — aggiungere lo stesso ramo nella CTE `traducibili`.

## Semplificazione del tracciato

Oggi `DouglasPeucker.Simplify` alza la tolleranza finché i punti scendono sotto `MaxPolylinePoints = 280`, che è un cap nato per la **lunghezza dell'URL Geoapify**, non per l'occultamento: la traccia di prova è passata da 5.239 a **220 punti**, circa un punto ogni 270 m, con i tornanti ancora leggibili.

Si aggiunge a `GeoapifyOptions` un **pavimento di tolleranza** (`MinSimplifyEps`, in gradi, configurabile in appsettings) da cui `Simplify` parte, invece di 0,00005° (~5 m). La generalizzazione diventa una scelta esplicita e non un effetto collaterale del cap URL.

**I valori si scelgono guardando**: prima di fissarli si rigenera la traccia reale già in DB a 2-3 livelli (~150 m, ~300 m, ~600 m) e si confrontano le immagini. Compromesso da tenere presente: più si generalizza, più la linea taglia i tornanti e si stacca visibilmente dalle strade — meno interpretabile per chi vuole copiare, ma anche meno gradevole per chi guarda.

## Fuori scope

- **Impaginazione su sito e flyer PDF**: nessuno dei due consumatori esiste ancora (il sito è Fase 3/Next.js; in `Services/Printing/` ci sono solo stampe gestionali). Qui si decide *quale informazione catturare*, non come impaginarla — proprio perché chi impaginerà non debba tornare a chiedere mappa per mappa a cosa si riferisce.
- GPX che coprono porzioni di giornata.
- Ordinamento manuale delle mappe (l'ordine è naturale).

## File coinvolti

- `SqlScripts/493_*` — modello + vincoli + backfill; aggiornamento `fn_web_tour_mappa_*`
- `SqlScripts/49x` — aggiornamento `fn_web_tour_stato_sezioni` (ramo traduzioni mappe)
- `Models/Web/WebTourMappa.cs`, `Services/Web/WebTourMappaService.cs`, `Services/Web/WebTourMappaGeneratorService.cs`
- `Services/Web/WebTraduzioneOrchestratorService.cs`
- `Services/Shared/Geo/DouglasPeucker.cs`, `GeoapifyOptions.cs`, `appsettings*.json`
- `Components/Shared/WebTourMappaTab.razor` (elenco + form), `WebTourItinerarioTab.razor` (data), `WebEdizioniManager.razor` (passaggio data), `WebTourAnteprimaDialog.razor` (N mappe)
- `Documents/Funzioni_DB.md`, `Documents/ComponentiShared.md`, checklist go-live
