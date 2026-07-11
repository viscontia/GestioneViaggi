# Blocco 13 — Contenuti per edizione (viaggio+data), Anteprima, Pubblica, Clona

> **Design doc — DA VALIDARE prima dell'implementazione.** Data: 2026-07-10.
> Checkpoint finale dell'Estensione Web. Questo blocco **re-modella** la relazione contenuto↔viaggio
> introdotta nel Blocco 5 (oggi 1:1) e impatta i Blocchi 5–11.

## 1. Principio di fondo (deciso con Adriano)

Un **contenuto web è figlio della coppia (viaggio + data_viaggio)**. Lo stesso viaggio (`ana_viaggi`, es. "Tour in Barbagia") ha **n date** (`ana_date_viaggi`) e quindi può avere **n contenuti editoriali**, uno per l'edizione in cui si è svolto.

**Fonte unica di verità — attributi NON editabili nel contenuto web (riferimento vivo, non copia):**
- **Prezzi** (costo pilota/passeggero/bambini) → `ana_date_viaggi`. Sono **denaro**: la pagina web deve rifletterli, mai duplicarli. Vietato avere 100 in anagrafica e 150 sul web (implicazioni contabili).
- **Date** (inizio/fine) → `ana_date_viaggi`.
- **Categoria sportiva** (4x4 / trekking / …) → `ana_viaggi.viaggio_tipo_viaggio_fk` → `ana_tipo_viaggi` → `web_tipi_viaggio_descrizioni` (tassonomia condivisa globale, Blocco 8). Non modificabile lato web.
- **Difficoltà** (turistica / media / medio_alta / alta) → **NUOVO campo `ana_viaggi.difficolta`** (vedi §2.5). È un attributo intrinseco del viaggio (Barbagia è "media" a prescindere dalla data), quindi vive in anagrafica come la categoria, non è editabile lato web.

Se l'utente corregge un prezzo/una data/il tipo/la difficoltà in anagrafica, **la pagina si adegua automaticamente** (letti via join al display, non congelati).

**Contenuto editoriale — per-edizione, editabile e copiato al clone:**
- `web_tour_contenuti` (sottotitolo, descrizione_html, durata_testo, luoghi, info_*_html, slug, meta_*), `web_tour_itinerario` (+passi), `web_tour_immagini`, `web_tour_mappa`, `web_traduzioni`.
- Questi **possono cambiare da un'edizione all'altra**; clonando si ottengono **copie indipendenti**.

## 2. Schema — evoluzione

### 2.1 `web_tour_contenuti`
- **Aggiungere** `data_viaggio_id_fk INTEGER NOT NULL REFERENCES ana_date_viaggi(...)`.
- **Rimuovere** il vincolo 1:1 `UNIQUE(viaggio_id_fk)`.
- **Aggiungere** `UNIQUE(data_viaggio_id_fk)` (una data-edizione → un contenuto) e mantenere `viaggio_id_fk` (comodo per liste/RLS; integrità: la data deve appartenere al viaggio → CHECK via trigger o FK composita).
- `stato_pubblicazione` / `data_pubblicazione` restano (pubblicazione per-edizione).
- **RIMUOVERE** la colonna `difficolta` (+ relativo CHECK): si sposta in `ana_viaggi` (§2.5).
- **NIENTE** colonne prezzo/date/categoria/difficoltà (restano in anagrafica, lette via join).

### 2.2 Re-keying tabelle figlie (il ripple più pesante)
Oggi `web_tour_immagini`, `web_tour_itinerario` (+`web_tour_itinerario_passaggi`), `web_tour_mappa` pendono da **`viaggio_id_fk`**. Diventano per-edizione → devono pendere dal **contenuto** (`web_tour_contenuti_id_fk`).
- Impatto: FK, funzioni CRUD (`fn_web_tour_*`), reorder/set-principale, servizi C# (`WebTourImmaginiService`, `WebTourItinerarioService`, `WebTourMappaService`), UI tab dei Blocchi 6/7/9 (che oggi ricevono `viaggioId`, riceveranno `contenutoId`).
- `web_traduzioni`: verificare la chiave (entità/entità_id/campo/lingua) — l'entità_id dei campi editoriali deve seguire il contenuto, non il viaggio.

### 2.3 `fn_web_tour_pubblicati` (strato pubblico)
- Diventa **per-edizione**: una riga per contenuto pubblicato, con **join a `ana_date_viaggi`** per prezzi+date e ad `ana_viaggi`→tipo→`web_tipi_viaggio_descrizioni` per la categoria.
- Le immagini/mappa/itinerario si leggono per `web_tour_contenuti_id`.

### 2.4 Migrazione dati esistenti — NON NECESSARIA
**Non esistono contenuti web per nessuna azienda** (confermato). Lo schema change e il re-keying delle tabelle figlie sono quindi **a freddo**: nessun dato da migrare, nessun contenuto/immagine/itinerario/mappa esistente da ricollegare. Si possono applicare le alter/ricreazioni liberamente. Nuovi script `SqlScripts/467+` + aggiornamento **Checklist Go-Live PROD**.

### 2.5 `ana_viaggi.difficolta` (NUOVO campo anagrafica)
La difficoltà diventa un attributo del viaggio (non del contenuto web).
- `ALTER TABLE ana_viaggi ADD COLUMN difficolta VARCHAR(20)` + CHECK `IN ('turistica','media','medio_alta','alta')` (nullable).
- Aggiornare CRUD viaggio (`fn`/`SpAnaViaggiCrud`), model `AnaViaggi`, e la **UI del dialog viaggio** (`AnaViaggiDialog`) con una select difficoltà.
- Anteprima e `fn_web_tour_pubblicati` leggono la difficoltà da qui (live).
- **Consegue** (accettato): si tocca l'anagrafica core `ana_viaggi` (campo + CRUD + UI).

## 3. Flussi UI

### 3.1 Crea (nuovo contenuto)
- L'utente sceglie **viaggio** (`ana_viaggi`) + **data** (`ana_date_viaggi`) **senza contenuto**.
- **Controlli:** viaggio e data devono esistere in anagrafica; la data non deve già avere un contenuto (UNIQUE). **Vietato** creare per viaggi/date non in anagrafica.
- Parte uno **scheletro guidato** (wizard): sezioni vuote da compilare (sottotitolo, descrizione, itinerario, galleria, mappa, SEO). Prezzi/date/categoria mostrati in sola lettura dall'anagrafica.

### 3.2 Clona
- L'utente sceglie un **contenuto sorgente dello stesso viaggio** (tra gli n esistenti) e una **nuova data** del viaggio (tra le `ana_date_viaggi` **non ancora usate** da un contenuto).
- **Controlli:** stesso viaggio; data destinazione esistente e libera. Vietato clonare tra viaggi diversi (Barbagia→Bosnia).
- **Copia TUTTO l'editoriale** (contenuti + itinerario/passi + immagini + mappa + traduzioni) su un nuovo `web_tour_contenuti` legato alla nuova data. Prezzi/date/categoria/difficoltà **non** si copiano: vengono dalla nuova data/viaggio (live).
- **Slug**: slug sorgente + **date complete dal–al** dell'edizione destinazione (non solo il mese: lo stesso viaggio può ripetersi più volte nello stesso mese), es. `tour-barbagia-2026-06-10_2026-06-14`. Univoco per azienda; in caso di collisione, suffisso progressivo.

### 3.3 Anteprima
- **Dialog completo in IT, speculare al web.** Assembla: titolo/sottotitolo, categoria sportiva (live), **prezzi e date dell'edizione** (live da `ana_date_viaggi`), descrizione, itinerario giorno-per-giorno con passi, galleria, mappa.
- Nessuna dipendenza dal sito Fase 3: rende esattamente ciò che `fn_web_tour_pubblicati` esporrà.

### 3.4 Pubblica
- Azioni di stato sul contenuto-edizione: **Pubblica** (`bozza→pubblicato`, `data_pubblicazione=now`), **Riporta in bozza**, **Archivia**.
- Pre-condizione pubblicazione: `data_viaggio_id_fk` valorizzato (serve prezzo/date).
- La revalidation on-demand del sito (Fase 3) è fuori scope: qui solo il cambio stato che rende il contenuto visibile allo strato pubblico.

## 4. Impatto sui blocchi precedenti (checklist implementazione)
- **Blocco 5** (contenuti): dialog contenuti passa da per-viaggio a per-edizione; selezione viaggio+data.
- **Blocco 6** (itinerario), **7** (galleria), **9** (mappa): tab e servizi ricablati su `contenutoId`.
- **Blocco 8** (categoria): invariato lato dati (resta su `ana_viaggi`→tipo); l'anteprima/pubblico la legge live.
- **Blocco 10** (traduzioni): entità_id dei campi editoriali segue il contenuto.
- **Blocco 3** (strato pubblico): `fn_web_tour_pubblicati` per-edizione con join date/prezzi/categoria.

## 5. Ordine di lavoro proposto
1. Script SQL: alter `web_tour_contenuti` (data_viaggio_id_fk, vincoli) + re-key figlie + `fn_*` CRUD aggiornate + migrazione dati locali.
2. Modelli/servizi C# ricablati (viaggioId → contenutoId dove serve).
3. UI: selezione viaggio+data, wizard **Crea**, azione **Clona**, dialog **Anteprima**, azioni **Pubblica/Bozza/Archivia**.
4. `fn_web_tour_pubblicati` per-edizione.
5. Doc: ComponentiShared, Funzioni_DB, Piano Test (§Blocco 13), Checklist Go-Live (nuovi script + migrazione), Piano Operativo (nota re-model).

## 6. Punti aperti — RISOLTI in validazione (2026-07-10)
- **Migrazione dati esistenti** → **non necessaria**: nessun contenuto web esistente per alcuna azienda (§2.4). Schema change a freddo.
- **Difficoltà** → spostata in **`ana_viaggi`** (§2.5), letta live dal web, non editabile; rimossa da `web_tour_contenuti`.
- **Slug** al clone → slug sorgente + **date dal–al complete** dell'edizione (§3.2), con suffisso progressivo in caso di collisione.

## 7. Piano d'implementazione dettagliato (mappa workflow, validato 2026-07-11)

Mappa prodotta da un workflow di 7 reader paralleli (uno per sottosistema). Findings chiave:
- **`web_tour_contenuti_id` è BIGINT** → le FK figlie diventano `web_tour_contenuti_id_fk BIGINT`; in C# `int → long`, cast Dapper `::integer → ::bigint` (rischio 42883 se disallineato).
- **`web_traduzioni` non cambia** (schema/funzioni/service/model): è polimorfica su `(entita, entita_id, campo, lingua)` con `entita_id` = PK del contenuto/passaggio (già per-contenuto). Cambia solo lo scope di raccolta nell'orchestrator e la **copia re-keyed al clone**.
- **`web_tour_itinerario_passaggi` non cambia schema** (pende da `itinerario_id_fk`; cascade dal contenuto via giornata). Solo `web_tour_itinerario` si ri-ancora al contenuto.
- **Nessun consumatore C#/Razor** di `fn_web_tour_pubblicati` (solo sito esterno) → cambiarne l'output è sicuro.
- **Nessuna routine di clone** esiste: va creata.

### Ordine di deploy (vincolante — le FK figlie puntano al PK contenuti)
- **Fase A — Contenuti (DB):** `410` (+`data_viaggio_id_fk`→`ana_date_viaggi(data_viaggio_id)`, via `UNIQUE(viaggio_id_fk)`, +`UNIQUE(data_viaggio_id_fk)`, −colonna `difficolta`+CHECK); `432` (fn insert/update: +`p_data_viaggio_id_fk`, −`p_difficolta`; +`fn_web_tour_contenuti_get_by_data_viaggio`; `get_by_viaggio` ora N righe).
- **Fase B — Figlie (DB):** immagini `413`+`435`+`457`+`458`; itinerario `411`+`456`+`433`+`454` (giornate → contenuto, vincolo `UNIQUE(web_tour_contenuti_id_fk, giorno_numero)` DEFERRABLE mantenuto); mappa `414`+`436` (`get_by_viaggio`→`get_by_contenuto`). FK `viaggio_id_fk`→`web_tour_contenuti_id_fk BIGINT`, indici/parziali ricreati per-contenuto. Passaggi `412/434/455` invariati.
- **Fase C — Public/RLS/Clone (DB):** `461` per-edizione (JOIN `ana_date_viaggi` per date/prezzo, `difficolta` da `ana_viaggi.viaggio_difficolta`, immagine via `web_tour_contenuti_id_fk`, traduzioni invariate); nuova `fn_web_prezzo_da_data(p_data_viaggio_id)` (LEAST 6 tariffe della singola data) + GRANT anon; `450/452/453` RLS ricablate (figlie gated via `web_tour_contenuti_id_fk`; GRANT: −`difficolta`/+`data_viaggio_id_fk` su contenuti, +`viaggio_difficolta` su ana_viaggi; `ana_date_viaggi` stretta alla sola data pubblicata); **nuova `fn_web_tour_contenuti_clona(p_contenuto_sorgente, p_data_viaggio_dest, p_azienda_id)`** che copia contenuto + immagini + itinerario/passaggi + mappa + traduzioni (re-key `entita_id` vecchia→nuova PK), slug nuovo.
- **Fase D — C# model/service:** `WebTourContenuto`(+`DataViaggioIdFk`, −`Difficolta`), `WebTourImmagine`/`WebTourItinerario`/`WebTourMappa` (`ViaggioIdFk int` → `WebTourContenutiIdFk long`); service: `*ByViaggio`→`*ByContenuto`, cast `::bigint`, `MapFromReader` GetInt64; `WebTraduzioneOrchestratorService` per-edizione.
- **Fase E — UI:** in `AnaViaggiDialog`, sopra i tab web, **selettore edizione** (Opzione A) + i 5 tab su `contenutoId`; **Crea** (wizard scheletro per data senza contenuto), **Clona** (sorgente + data libera), **Anteprima** IT speculare, **Pubblica/Bozza/Archivia**. Rimuovere select difficoltà dal tab contenuti.
- **Fase F — Doc + build + commit.**

### Selettore edizione (Fase E) — requisiti
Per ogni data del viaggio (`ana_date_viaggi`) il selettore mostra:
- range **dal–al** (`data_viaggio_data_inizio`/`_data_fine`);
- **stato contenuto**: "con contenuto" vs "senza contenuto" (LEFT JOIN `web_tour_contenuti` su `data_viaggio_id_fk`), con evidenza visiva (chip/icona);
- **stato effettuazione**: "effettuato" vs "da effettuare" da `data_viaggio_effettuato_sino` (Y/N), con evidenza visiva.
- Supporto DB: nuova `fn_web_edizioni_per_viaggio(p_viaggio_id, p_azienda_id)` → righe (data_viaggio_id, data_inizio, data_fine, effettuato_sino, web_tour_contenuti_id NULL-able, stato_pubblicazione). Alimenta il selettore.
- Azioni contestuali: data **senza** contenuto → "Crea" o "Clona da…"; data **con** contenuto → apre i tab; sempre disponibili Anteprima/Pubblica sul contenuto selezionato.

### Default adottati (validati)
- Prezzo per-edizione via nuova `fn_web_prezzo_da_data`.
- RLS `ana_date_viaggi` stretta alla sola data pubblicata.
- Storage immagini/mappa **per-contenuto** (`{azienda}/{contenuto}/…`) per evitare collisioni tra edizioni.

## 8. Stato implementazione + dettaglio Fase D/E (per ripresa)

**FATTO (committato):**
- Fase 1 difficoltà `ana_viaggi` (commit `0dde963`, script 467).
- Fase A/B/C DB re-model (commit `8f16e91`, script 468–474): contenuti per-edizione, figlie su `web_tour_contenuti_id_fk` (BIGINT), public per-edizione, RLS ricablata, `fn_web_tour_contenuti_clona` (clone **testato** ok), `fn_web_edizioni_per_viaggio` (selettore).

**DA FARE — Fase D (C#, un unico commit build-verde con E):**
- Models: `WebTourContenuto` (+`DataViaggioIdFk` int, −`Difficolta`); `WebTourImmagine`/`WebTourItinerario`/`WebTourMappa`: `ViaggioIdFk` (int) → `WebTourContenutiIdFk` (**long**).
- `WebTourContenutiService`: SQL insert/update (+`@DataViaggioIdFk::integer`, −`@Difficolta`, ordine param allineato a fn 468), `BindWritableParams`, `MapFromReader` (+`data_viaggio_id_fk`, −`difficolta`); `GetByViaggioAsync` → `GetByDataViaggioAsync(int dataViaggioId,int aziendaId)` su `fn_web_tour_contenuti_get_by_data_viaggio`; aggiungere `ClonaAsync(long src,int dataDest,int azienda)` su `fn_web_tour_contenuti_clona` e `ListEdizioniAsync(int viaggioId,int azienda)` su `fn_web_edizioni_per_viaggio`.
- `WebTourImmaginiService`/`WebTourItinerarioService`/`WebTourMappaService`: `*ByViaggioAsync` → `*ByContenutoAsync(long)`; cast `::integer`→`::bigint`; `MapFromReader` `GetInt64`; reorder/set_principale/get_by param `long`; `WebTourMappaService.GetByViaggioAsync`→`GetByContenutoAsync` su `fn_web_tour_mappa_get_by_contenuto`.
- `WebTourMappaGeneratorService.GenerateAsync(int viaggioId,…)` → `(long contenutoId,…)`; storage path per-contenuto.
- `WebTraduzioneOrchestratorService.GetTranslatableItemsAsync`: per-edizione (risolve il contenuto, `ListByContenutoAsync`); entita_id invariati.

**DA FARE — Fase E (UI, stesso commit):**
- `WebTourContenutiTab`: `ViaggioId`→`DataViaggioId`; `GetByDataViaggioAsync`; set `DataViaggioIdFk`; **rimuovere select Difficoltà** (ora su ana_viaggi).
- `WebTourItinerarioTab`/`WebTourGalleriaTab`/`WebTourMappaTab`/`WebTraduzioniTab`: `ViaggioId`→`ContenutoId (long)`; aggiornare le chiamate ai service.
- `WebTourPassoEditDialog`: `ViaggioId`→`ContenutoId` (picker galleria).
- `AnaViaggiDialog`: sopra i 5 tab web, **selettore edizione** (via `fn_web_edizioni_per_viaggio`: mostra dal–al, chip "con/senza contenuto", chip "effettuato/da effettuare" da `data_viaggio_effettuato_sino`); scelta data → risolve/crea il contenuto e passa `contenutoId` ai tab. Nuovi: **Crea** (contenuto per data senza contenuto), **Clona** (sorgente+data libera → `ClonaAsync`), **Anteprima** (dialog IT speculare a `fn_web_tour_pubblicati`), **Pubblica/Bozza/Archivia** (stato).
- Nota: cambiare le firme dei service rompe il build dei tab → Fase D+E vanno completate insieme prima del build/commit.

**Fase F:** ComponentiShared, Funzioni_DB (già rigenerato dai deploy), Piano Test §10, Go-Live (script 467–474), Piano Operativo.
