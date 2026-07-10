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
