# Piano di Test — Estensione Web SFT

> **USO INTERNO (Adriano + AI).** Documento vivo: si aggiorna man mano che i blocchi vengono completati/testati.
> **Data:** 2026-07-09 · Verifiche **a runtime** (l'AI non guida la WebView MAUI: le esegue Adriano).
> Legenda esito: ☐ da fare · ✅ ok · ❌ da correggere.

---

## 0. Prerequisiti (chiavi/config per i test end-to-end)

- **Supabase `ServiceKey`** (bucket di test `tour-media-dev`) → `appsettings.Development.json` → `WebMediaStorage:ServiceKey`. Serve per Galleria (Blocco 7) e Mappa (Blocco 9). ⚠️ Non committare (skip-worktree attivo).
- **Geoapify `ApiKey`** → già in `appsettings.Development.json` → `Geoapify:ApiKey`. Serve per Mappa (Blocco 9).
- **Claude `ApiKey` per-azienda** → scheda **Aziende → Traduzioni** (o tab Traduzioni del viaggio). Serve per Traduzioni (Blocco 10) e newsletter multilingua (Blocco 11).
- **PROD:** applicare `SqlScripts/465` in produzione per il backfill di `ana_clienti.cliente_lingua` sui clienti veri (idempotente).
- **Go-Live PROD:** l'elenco completo di *cosa* modificare/configurare in produzione (script 406–466, cifratura segreti, RLS anon, Storage, backfill, config app) è tracciato in `2026-07-10-Checklist_Go_Live_PROD.md`.

---

## 1. Anagrafica cliente — campo `cliente_lingua` (Blocco 11-B)

- ☐ Apri una scheda cliente esistente → la **Lingua newsletter** è precompilata (backfill geo: IT per residenti Italia, DE/EN per esteri).
- ☐ Cambia la lingua (override, es. ticinese/rumeno italofono → **IT**) → salva → riapri → il valore è persistito.
- ☐ Svuota il campo ("auto") → salva → la newsletter userà poi la lingua derivata dalla nazione di residenza.
- ☐ Nuovo cliente: crea con lingua "auto" e uno con lingua esplicita → verifica coerenza.

## 2. Blocco 5 — Contenuti Web del tour

- ☐ Salva/rilegge i contenuti (chiudi/riapri il dialog).
- ☐ Slug/"indirizzo web" duplicato su due viaggi → messaggio d'errore chiaro ("Esiste già un tour con questo indirizzo web…").
- ☐ Resa dei 5 editor Quill (altezze/scroll, HTML ricaricato).

## 3. Blocco 6 — Itinerario giorno-per-giorno

- ☐ Riordino **giornate** (drag) → persistito.
- ☐ Spostamento **passi** dentro la stessa giornata e **TRA** giornate diverse.
- ☐ Riordino **stabile** (trascinamenti ripetuti, giornate vuote) → chiudi/riapri: stesso ordine.
- ☐ Editor Quill del passo (dialog) carica/salva.

## 4. Blocco 7 — Galleria immagini *(serve ServiceKey Supabase)*

- ☐ Upload multiplo → immagini ridimensionate/WebP.
- ☐ Riordino DnD stabile; **copertina** (una sola `principale`).
- ☐ Alt/titolo salvati; elimina (record + storage).
- ☐ Picker immagine nel **passo** dell'itinerario → thumbnail nella card.

## 5. Blocco 8 — Descrizioni web dei tipi

- ☐ Mappatura `tipo → descrizione` (select nel dialog tipo, colonna in griglia).
- ☐ Due tipi possono condividere la stessa descrizione (es. 4X4 + 4X4SUV → "Viaggi 4x4").
- ☐ Descrizione **condivisa/globale** coerente tra aziende (unico caso condiviso).

## 6. Blocco 9 — GPX → mappa statica *(serve ApiKey Geoapify + ServiceKey Supabase)*

- ☐ Upload `.gpx` → **Genera mappa** → anteprima mappa centrata con traccia + attribuzione OSM.
- ☐ Rigenera (da GPX salvato) ed elimina.
- ☐ Nessun dato GPX raggiunge il browser (solo l'immagine).

## 7. Blocco 10 — Traduzioni Claude *(serve chiave Claude sull'azienda)*

- ☐ "Traduci tutto" → 4 lingue (EN/DE/FR/ES), **HTML preservato**, **nomi propri non tradotti**.
- ☐ Modifica un testo IT (Contenuti/Itinerario) → le sue traduzioni diventano **obsolete**.
- ☐ Revisione: edita traduzione + marca **revisionato**.
- ☐ Traduzione della **descrizione tipo** dalla pagina Descrizioni Web.

## 8. Blocco 11 — Newsletter *(pagina `/newsletter`, menu "Estensione Web")*

- ☐ **Conteggio destinatari** in tab Campagna corretto (dedup clienti-con-consenso + iscritti − soppressioni, per email).
- ☐ **Invio di prova** a un indirizzo (oggetto con prefisso `[TEST]`, solo IT).
- ☐ **Invia a tutti**: dialog di conferma con conteggio → invio → snackbar con inviate/errori.
- ☐ **Multilingua**: iscritto nella sua lingua; cliente estero nella lingua della nazione (CH→DE, non coperti→EN); residenti IT in italiano.
- ☐ **Template brandizzato**: l'email usa `CompanyEmailTemplate` (logo azienda, nome, sito/telefono nel footer) — **non** più il wrapper minimale.
- ☐ **Senza chiave Claude** sull'azienda: i destinatari non-IT ricevono la versione **italiana** e lo snackbar segnala "alcune lingue inviate in IT".
- ☐ **Link di disiscrizione** presente in coda al corpo e firmato (HMAC su `token_iscrizione` azienda).
- ☐ Tab **Storico**: invii elencati (oggetto/stato/data/n.destinatari/canale) + azione **Log** → dialog con esito per-destinatario.
- ☐ Tab **Iscritti**: elenco read-only (email/nome/lingua/stato/consenso).
- ☐ Tab **Soppressioni**: aggiungi email+motivo, rimuovi → un indirizzo soppresso è escluso dal conteggio e dall'invio.

## 9. Trasversale — Multi-tenant (silos)

- ☐ Isolamento dati tra aziende (un'azienda non vede/modifica i dati di un'altra).
- ☐ Unico condiviso/globale = tipi viaggio (`ana_tipo_viaggi`) + descrizioni web + loro traduzioni. Nient'altro.
