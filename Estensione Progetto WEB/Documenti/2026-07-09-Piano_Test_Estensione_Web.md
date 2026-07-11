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

## 9. Blocco 12 — Config per-azienda (tab "Funzioni Web")

- ☐ **Anagrafica Aziende → tab "Funzioni Web"**: i 4 toggle (newsletter/recensioni/blog/pagamenti_online) si caricano; `newsletter` di default **ON**, gli altri **OFF** (se mai configurati).
- ☐ Attiva/disattiva un toggle → snackbar di conferma → riapri il dialog azienda: lo stato è **persistito**.
- ☐ **Gating newsletter**: disattiva `newsletter` per l'azienda → la voce di menu "Estensione Web > Newsletter" **sparisce** e la pagina `/newsletter` mostra "non attiva" (guardia autoritativa).
- ☐ Ri-attiva `newsletter` → menu e pagina tornano disponibili.
- ☐ **Opt-out**: un'azienda **senza** riga `newsletter` (es. SFT prima di toccare il tab) vede comunque la newsletter (default visibile).
- ☐ I flag `recensioni`/`blog`/`pagamenti_online` **non cambiano nulla** nel gestionale (sono per la Fase 3): solo persistenza.
- ☐ Card **"Regole di pagamento"** visibile ma **disabilitata** (placeholder Fase 4).
- ☐ *(ESP rimandato: nessun tab ESP in questa fase — vedi Checklist Go-Live §2.2.)*

## 10. Blocco 13 — Contenuti per edizione (viaggio+data) *(in corso)*

**Anagrafica viaggio — nuovo campo Difficoltà (`ana_viaggi.viaggio_difficolta`)** *(fatto, commit 0dde963)*:
- ☐ Apri un viaggio esistente → il dialog mostra la select **Difficoltà** (turistica/media/medio_alta/alta); vuota se mai impostata.
- ☐ Imposta una difficoltà → salva → riapri: il valore è **persistito**.
- ☐ Cambia la difficoltà su un viaggio esistente → salva → riapri: aggiornata.
- ☐ Svuota la difficoltà (Clearable) → salva → riapri: torna vuota (NULL ammesso).
- ☐ Nuovo viaggio con date: crea con difficoltà impostata → verifica che sia salvata (path create con date).
- ☐ La difficoltà è **solo** in anagrafica viaggio: non compare (editabile) nei contenuti web — verrà letta live dalla pagina/anteprima.

**Contenuti web per edizione (re-model DB + UI, commit DB `8f16e91`):**
- ☐ **Selettore edizione** (dialog viaggio → tab "Contenuti Web"): elenca le date del viaggio con **dal–al**, chip **con/senza contenuto** e chip **effettuato/da effettuare**.
- ☐ Data **senza contenuto** → pulsante **Crea contenuto**: crea una bozza per quella data → compaiono i 5 sotto-tab.
- ☐ Data senza contenuto → **Clona da** un'altra edizione (con contenuto) → copia contenuti+itinerario+galleria+mappa+traduzioni sulla nuova data; prezzi/date restano quelli della nuova data.
- ☐ **Vincoli clone**: consentito solo tra date dello **stesso viaggio**; data già con contenuto non selezionabile come destinazione.
- ☐ I 5 sotto-tab operano sul contenuto dell'edizione selezionata (creare 2 edizioni dello stesso viaggio e verificare che i contenuti siano **indipendenti**).
- ☐ Nel tab Contenuti **non** c'è più la difficoltà (è in anagrafica viaggio); prezzi/date **non** editabili qui.
- ☐ **Anteprima**: mostra il contenuto assemblato (descrizione, itinerario+passi, galleria, mappa) in IT.
- ☐ **Pubblicazione**: cambiando lo **Stato** del contenuto a "pubblicato", lo strato pubblico (`fn_web_tour_pubblicati`) espone **una riga per edizione** con prezzo/date della singola data e difficoltà dall'anagrafica.
- ☐ **Multi-tenant**: un'azienda non vede le edizioni/contenuti di un'altra.

## 11. Trasversale — Multi-tenant (silos)

- ☐ Isolamento dati tra aziende (un'azienda non vede/modifica i dati di un'altra).
- ☐ Unico condiviso/globale = tipi viaggio (`ana_tipo_viaggi`) + descrizioni web + loro traduzioni. Nient'altro.
