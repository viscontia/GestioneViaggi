# Piano di Test — Estensione Web SFT

> **USO INTERNO (Adriano + AI).** Documento vivo: si aggiorna man mano che i blocchi vengono testati.
> **Creato:** 2026-07-09 · **Aggiornato:** 2026-07-14 (Blocchi 5–13 + cifratura segreti + aggiunte CMS §A: Incluso/Escluso §13, Capienza/posti rimasti §14, Tour brevi §15, Recensioni §16; CRUD DB-first Tipologie Viaggio §17).
> Verifiche **a runtime**: l'AI non guida la WebView MAUI → le esegue Adriano.

**Come usare questo piano:** imposta prima i prerequisiti (§0), poi procedi sezione per sezione. Segna l'esito di ogni riga: ☐ da fare · ✅ ok · ❌ da correggere (annota accanto cosa non va). Le sezioni sono indipendenti: puoi testare un blocco alla volta.

---

## 0. Prerequisiti (chiavi/config per i test end-to-end)

- **`GV_SECRET_KEY`** (variabile d'ambiente) — **OBBLIGATORIA**: master key della cifratura segreti. Impostala nell'ambiente **prima di avviare l'app** (una stringa forte qualsiasi in locale). Senza, salvare SMTP / chiave Claude **fallisce con errore chiaro** (fail-fast). In locale usa sempre la **stessa** stringa tra un avvio e l'altro, altrimenti non rileggi i segreti già cifrati.
- **Supabase `ServiceKey`** (bucket di test `tour-media-dev`) → `appsettings.Development.json` → `WebMediaStorage:ServiceKey`. Serve per Galleria (Blocco 7) e Mappa (Blocco 9). ⚠️ Non committare (skip-worktree attivo).
- **Geoapify `ApiKey`** → già in `appsettings.Development.json` → `Geoapify:ApiKey`. Serve per Mappa (Blocco 9).
- **Claude `ApiKey` per-azienda** → scheda **Aziende → Traduzioni**. Serve per Traduzioni (Blocco 10) e newsletter multilingua (Blocco 11).
- **SMTP azienda** → scheda **Aziende → SMTP** (server di posta del cliente). È il canale email/newsletter (nessun provider ESP esterno).
- **Go-Live PROD:** cosa modificare/configurare in produzione (script `406–482`, cifratura segreti + `GV_SECRET_KEY`, RLS anon, Storage, backfill `cliente_lingua`, config app) è tracciato in `2026-07-10-Checklist_Go_Live_PROD.md`.

---

## 1. Anagrafica cliente — campo `cliente_lingua` (Blocco 11-B)

- ☐ Apri una scheda cliente esistente → la **Lingua newsletter** è precompilata (backfill geo: IT per residenti Italia, DE/EN per esteri).
- ☐ Cambia la lingua (override, es. ticinese/rumeno italofono → **IT**) → salva → riapri → il valore è persistito.
- ☐ Svuota il campo ("auto") → salva → la newsletter userà poi la lingua derivata dalla nazione di residenza.
- ☐ Nuovo cliente: crea uno con lingua "auto" e uno con lingua esplicita → verifica coerenza.

## 2. Blocco 5 — Contenuti Web del tour

- ☐ Salva/rilegge i contenuti (chiudi/riapri il dialog).
- ☐ Slug/"indirizzo web" duplicato su due edizioni → messaggio d'errore chiaro ("Esiste già un tour con questo indirizzo web…").
- ☐ Resa dei 5 editor Quill (altezze/scroll, HTML ricaricato).

> Nota Blocco 13: i contenuti sono ora **per edizione** (viaggio+data). Vedi §10 per crea/clona/anteprima.

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
- ☐ Revisione: edita una traduzione + marca **revisionato**.
- ☐ Traduzione della **descrizione tipo** dalla pagina Descrizioni Web.

## 8. Blocco 11 — Newsletter *(pagina `/newsletter`, menu "Estensione Web")*

- ☐ **Conteggio destinatari** in tab Campagna corretto (dedup clienti-con-consenso + iscritti − soppressioni, per email).
- ☐ **Invio di prova** a un indirizzo (oggetto con prefisso `[TEST]`, solo IT).
- ☐ **Invia a tutti**: dialog di conferma con conteggio → invio → snackbar con inviate/errori.
- ☐ **Canale = SMTP del cliente**: l'invio parte dallo SMTP aziendale configurato (fallback Resend se assente); il tab Storico mostra il canale usato.
- ☐ **Multilingua**: iscritto nella sua lingua; cliente estero nella lingua della nazione (CH→DE, non coperti→EN); residenti IT in italiano.
- ☐ **Template brandizzato**: l'email usa `CompanyEmailTemplate` (logo azienda, nome, sito/telefono nel footer).
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
- ☐ *(Nessun tab ESP: canale email = SMTP del cliente — vedi Go-Live §2.2.)*

## 10. Blocco 13 — Contenuti web per edizione (viaggio+data)

**Anagrafica viaggio — campo Difficoltà (`ana_viaggi.viaggio_difficolta`):**
- ☐ Apri un viaggio esistente → il dialog mostra la select **Difficoltà** (turistica/media/medio_alta/alta); vuota se mai impostata.
- ☐ Imposta / cambia / svuota (Clearable) la difficoltà → salva → riapri: valore coerente (NULL ammesso).
- ☐ Nuovo viaggio con date: crea con difficoltà impostata → salvata (path create-con-date).
- ☐ La difficoltà è **solo** in anagrafica viaggio: non è editabile nei contenuti web (letta live dalla pagina/anteprima).

**Contenuti per edizione (dialog viaggio → tab "Contenuti Web"):**
- ☐ **Selettore edizione**: elenca le date del viaggio con **dal–al**, chip **con/senza contenuto** e chip **effettuato/da effettuare** (da `data_viaggio_effettuato_sino`).
- ☐ Data **senza contenuto** → **Crea contenuto**: crea una bozza per quella data → compaiono i 5 sotto-tab (Contenuti/Itinerario/Galleria/Mappa/Traduzioni).
- ☐ Data senza contenuto → **Clona da** un'altra edizione (con contenuto) → copia contenuti+itinerario+galleria+mappa+traduzioni sulla nuova data.
- ☐ **Vincoli clone**: consentito solo tra date dello **stesso viaggio**; una data già con contenuto non è selezionabile come destinazione.
- ☐ **Indipendenza edizioni**: crea 2 edizioni dello stesso viaggio e verifica che modificare una **non** tocchi l'altra.
- ☐ Nel tab Contenuti **non** c'è più la difficoltà; prezzi/date **non** editabili qui (vengono dall'anagrafica).
- ☐ **Anteprima**: mostra il contenuto assemblato (sottotitolo, descrizione, itinerario+passi, galleria, mappa) in IT.
- ☐ **Pubblicazione**: porta lo **Stato** del contenuto a "pubblicato" → lo strato pubblico (`fn_web_tour_pubblicati`) espone **una riga per edizione** con prezzo/date della singola data e difficoltà dall'anagrafica (verifica via query DB o Fase 3).
- ☐ **Multi-tenant**: un'azienda non vede le edizioni/contenuti di un'altra.

## 11. Cifratura segreti (pgcrypto + `GV_SECRET_KEY`)

- ☐ **Fail-fast senza key**: avvia l'app **senza** `GV_SECRET_KEY` → salvare una config SMTP o la chiave Claude **fallisce con messaggio chiaro** (non crash silenzioso).
- ☐ **SMTP cifrato**: con `GV_SECRET_KEY` impostata, salva una **password SMTP** (Aziende → SMTP) → nel DB `ana_aziende_smtp.password_enc` è **bytea illeggibile** (non testo in chiaro); l'**invio email** funziona (la decifra correttamente).
- ☐ **Claude cifrato**: salva la **chiave Claude** (Aziende → Traduzioni) → `ana_aziende.claude_api_key_enc` è bytea; la **traduzione** funziona (decifra).
- ☐ **Key sbagliata**: riavvia con una `GV_SECRET_KEY` **diversa** → i segreti non sono più leggibili (errore "Wrong key or corrupt data"): conferma che senza la key giusta i segreti restano protetti.

> Verifica "bytea illeggibile" via query rapida sul DB, es.:
> `SELECT left(encode(password_enc,'hex'),16) FROM ana_aziende_smtp LIMIT 1;` → deve iniziare con `c30d0407…` (header pgp), non essere testo leggibile.

## 12. Trasversale — Multi-tenant (silos)

- ☐ Isolamento dati tra aziende (un'azienda non vede/modifica i dati di un'altra).
- ☐ Unico condiviso/globale = tipi viaggio (`ana_tipo_viaggi`) + descrizioni web + loro traduzioni. Nient'altro.

## 13. Aggiunte CMS — Incluso / Escluso (§A.1, script `476`/`477`)

Attributo del **viaggio** (uguale per tutte le edizioni, come la difficoltà). Due editor Quill nel dialog viaggio (tab "Dati Generali", sezione **Incluso / Escluso**), contenuto editoriale **non uppercase**, letto live dal sito e tradotto.

**Anagrafica viaggio (`ana_viaggi.viaggio_incluso`/`viaggio_escluso`):**
- ☐ Apri un viaggio esistente → in "Dati Generali" compaiono i due editor **La quota comprende** / **La quota non comprende** (vuoti se mai impostati).
- ☐ Scrivi un elenco puntato in entrambi (toolbar: grassetto/corsivo, lista puntata/numerata, pulisci) → **Salva** → riapri il viaggio: l'HTML è ricaricato correttamente in ciascun editor.
- ☐ **Nessun uppercase forzato**: il testo resta come digitato (minuscole/maiuscole preservate), a differenza di descrizione/note.
- ☐ Svuota completamente un editor → salva → riapri: il campo è **NULL** (Quill vuoto normalizzato, niente `<p><br></p>`).
- ☐ **Nuovo viaggio con date**: crea un viaggio compilando incluso/escluso → salvati (path create-con-date atomico).
- ☐ **Condivisione tra edizioni**: incluso/escluso è a livello viaggio → è lo stesso per tutte le date/edizioni di quel viaggio (non per edizione).

**Traduzioni (Blocco 10 — serve chiave Claude sull'azienda):**
- ☐ Da una qualunque edizione del viaggio, **"Traduci tutto"** → incluso/escluso vengono tradotti in EN/DE/FR/ES (entità `ana_viaggi`), **HTML/elenchi preservati**.
- ☐ Modifica l'**incluso** (o escluso) in italiano → salva il viaggio → le sue traduzioni diventano **obsolete** (come per i campi contenuto).
- ☐ Traduci una sola volta: tradurre da un'altra edizione dello stesso viaggio non duplica le traduzioni (chiave `ana_viaggi`+`viaggio_id`+campo+lingua).

**Strato pubblico (`fn_web_tour_pubblicati`):**
- ☐ Con un contenuto **pubblicato**, la funzione espone le colonne **`incluso`/`escluso`** (verifica via query DB): in `IT` = testo anagrafica; in altra lingua = traduzione se presente e non obsoleta, **fallback IT** altrimenti.
  > es.: `SELECT incluso, escluso FROM fn_web_tour_pubblicati(<azienda_id>, 'DE') LIMIT 5;`

## 14. Aggiunte CMS — Capienza / "posti rimasti" (§A.2, script `478`/`479`)

Capienza a livello **viaggio** (uguale per tutte le edizioni), in **equipaggi/mezzi**. **1 posto = 1 pilota** (`tipo_partecipante` 4/5); passeggeri e staff (guide 21/22) NON contano. Occupazione per **edizione/data** letta **live** (nessuna cache). NULL su capienza = capienza **non gestita** (il sito non mostra nulla).

**Anagrafica viaggio (dialog → "Dati Generali", accanto a Difficoltà):**
- ☐ Compaiono i campi **Capienza (mezzi)** e **Soglia ultimi posti** (numerici, vuoti se mai impostati, Clearable).
- ☐ Imposta capienza=es. 8, soglia=2 → salva → riapri: valori persistiti. Svuota (Clearable) → salva → riapri: NULL (capienza non gestita).
- ☐ Nuovo viaggio con date: crea con capienza/soglia → salvati (path create-con-date).
- ☐ La capienza è a livello viaggio: **la stessa** per tutte le edizioni; l'occupazione invece è **per data**.

**Occupazione e badge (verifica via query DB — l'occupazione dipende dagli iscritti reali):**
- ☐ `fn_web_mezzi_occupati_data(<data_id>)` = numero di **piloti** (tipi 4,5) su quella data (≠ totale persone; esclude passeggeri e guide).
- ☐ Su un'edizione **pubblicata** con capienza impostata: `SELECT posti_rimasti, posti_stato FROM fn_web_tour_pubblicati(<azienda_id>,'IT');`
  - `posti_rimasti` = `max(capienza − piloti, 0)`; **0** quando pieno/overbooking.
  - `posti_stato`: `'disponibile'` (rimasti > soglia) · `'ultimi'` (0 < rimasti ≤ soglia) · `'sold_out'` (0) · `NULL` (capienza non gestita).
- ☐ Aggiungi/rimuovi un **pilota** su una data (dal gestionale) → `posti_rimasti` cambia di conseguenza (calcolo live).
- ☐ Un **passeggero** o una **guida** aggiunti NON cambiano `posti_rimasti` (solo i piloti contano).

**Trigger / revalidation (concetto Fase 3):**
- ☐ Ogni INSERT/UPDATE/DELETE su una prenotazione emette `NOTIFY web_tour_revalidate` con `{viaggio_id, data_viaggio_id}` (verificabile con `LISTEN web_tour_revalidate;` in una sessione psql, poi una modifica prenotazione). Senza listener è un no-op: **non** rompe il salvataggio prenotazioni.
- ☐ **Regressione**: inserire/modificare prenotazioni su una data con storico "durata giorni" incoerente **funziona ancora** (il trigger posti non scrive su `ana_date_viaggi`, quindi non innesca `trg_validate_date_viaggio_duration`).

## 15. Aggiunte CMS — Tour brevi / giornalieri (§A.3, script `480`)

Flag sul **tipo viaggio** (`ana_tipo_viaggi.tipo_viaggio_breve`) che marca le "esperienze brevi 1–3 gg". Il sito userà il flag per una **sezione condizionale "Tour giornalieri"**.

**Gestionale (Tipologie Viaggio → dialog tipo):**
- ☐ Il dialog mostra la checkbox **"Tour giornaliero / esperienza breve (1–3 gg)"** (default OFF sui tipi esistenti).
- ☐ Marca un tipo come breve → salva → riapri: il flag è persistito. Togli il flag → salva → riapri: persistito.
- ☐ Nuovo tipo con flag ON alla creazione → salvato correttamente (il create ora include il flag).
- ☐ Il flag **non** intacca le altre funzioni del tipo (descrizione, mapping descrizione web).

**Strato pubblico (verifica via query DB):**
- ☐ `fn_web_ha_tour_brevi_pubblicati(<azienda_id>)` = `false` finché nessun tipo marcato ha tour **pubblicati**; diventa `true` dopo aver marcato il tipo di un tour pubblicato.
  > es.: `SELECT fn_web_ha_tour_brevi_pubblicati(<azienda_id>);`
- ☐ `fn_web_tour_pubblicati(<azienda_id>,'IT')` espone `is_tour_breve` = `true` per le edizioni di tipi marcati, `false` altrimenti (serve al sito per instradare i tour nella sezione "Tour giornalieri").

## 16. Aggiunte CMS — Recensioni Google / TripAdvisor (§A.4, script `481`)

Nessuna tabella recensioni interna: si usano le schede Google/TripAdvisor. Config per-azienda nel JSONB `web_aziende_funzioni.parametri` della funzione `recensioni`; il flag `attiva` (Blocco 12) governa on/off.

**Gestionale (Anagrafica Aziende → tab "Funzioni Web"):**
- ☐ Con il toggle **Recensioni** OFF: la card di configurazione schede **non** è visibile.
- ☐ Attiva il toggle **Recensioni** → compare la card **"Schede recensioni (Google / TripAdvisor)"** con i campi **Google Place ID** e **URL scheda TripAdvisor**.
- ☐ Inserisci Place ID + URL TripAdvisor → **Salva schede recensioni** → snackbar di conferma → riapri il dialog azienda: i valori sono **persistiti**.
- ☐ **Persistenza sul toggle**: disattiva e riattiva il toggle Recensioni → i valori Place ID/TripAdvisor **restano** (il toggle non azzera i `parametri`).
- ☐ Svuota entrambi i campi → Salva → i `parametri` tornano a `NULL` (config rimossa).
- ☐ Il salvataggio config **non** altera gli altri toggle (newsletter/blog/pagamenti).

**Strato pubblico (verifica via query DB):**
- ☐ Con Recensioni **attiva** e config salvata: `SELECT fn_web_recensioni_config(<azienda_id>);` ritorna il JSONB `{"google_place_id":"…","tripadvisor_url":"…"}`.
- ☐ Con Recensioni **disattivata**: la stessa funzione ritorna `NULL` (il sito non mostrerà il widget recensioni).
- ☐ **Multi-tenant**: `fn_web_recensioni_config` di un'azienda non ritorna la config di un'altra.

## 17. CRUD Tipologie Viaggio dalla UI (DB-first, script `482`)

La CRUD di `ana_tipo_viaggi` è stata portata a **funzioni DB** (`fn_ana_tipo_viaggi_create`/`fn_ana_tipo_viaggi_update`, niente più SQL inline). Verifica end-to-end dalla pagina **Tipologie Viaggio**:

- ☐ **Create**: nuovo tipo (Tipo max 6 char maiuscolo forzato + Descrizione) → salva → compare in griglia; riapri: valori corretti.
- ☐ **Read/lista**: la griglia elenca i tipi con Tipo, Descrizione, mapping "Descrizione web" e (se mostrato) flag breve.
- ☐ **Update**: modifica Tipo/Descrizione → salva → la griglia riflette le modifiche; riapri il dialog: coerente.
- ☐ **Mapping web (Blocco 8)**: imposta/cambia/azzera la "Descrizione web (sito)" → salva → persistito (in create resta vuota, si imposta in modifica).
- ☐ **Flag breve (§A.3)**: marca/smarca "Tour giornaliero / esperienza breve" → salva → persistito (vedi anche §15).
- ☐ **Delete**: elimina un tipo **non usato** → rimosso. Elimina un tipo **usato da un viaggio** → l'operazione è **bloccata** con messaggio chiaro (trigger `ana_tipo_viaggi_check_delete`).
- ☐ **Validazioni**: Tipo obbligatorio (max 6), Descrizione obbligatoria (max 100) → errori di form corretti.
- ☐ **Regressione DB-first**: create e update passano dalle funzioni `fn_ana_tipo_viaggi_*` (nessun errore di mapping; la riga tornata popola correttamente griglia/dialog).

## 18. Mappe multiple da GPX (script `493`–`495`)

Da una mappa per edizione a **N**: una dell'**intero viaggio** e una per **giornata** dell'itinerario. Design: `2026-07-25-Mappe_Multiple_GPX_design.md`. *(Ogni generazione consuma una chiamata Geoapify reale.)*

**Tab Mappa — caricamento e abbinamento:**
- ☐ Edizione senza mappe: l'elenco dice "Nessuna mappa caricata"; scelto un GPX compaiono le opzioni di abbinamento.
- ☐ **Intero viaggio**: senza descrizione il pulsante "Genera mappa" resta **disabilitato**; con descrizione la mappa si genera e compare in cima all'elenco.
- ☐ **Una giornata**: il select elenca le giornate come "Giorno N — Sabato 2 Maggio 2026 — titolo"; scegliendone una la **descrizione si precompila** dal titolo e resta modificabile.
- ☐ Caricata la mappa d'insieme, l'opzione "Intero viaggio" appare **disabilitata** con "(già presente)".
- ☐ Caricata la mappa di una giornata, quella giornata **non compare più** nel select.
- ☐ Con tutte le giornate occupate, l'opzione "Una giornata" è disabilitata con "(nessuna giornata libera)".
- ☐ **Ordine elenco**: prima la mappa d'insieme, poi le giornate in ordine di giornata (indipendente dall'ordine di caricamento).

**Duplicati e vincoli (il DB è la difesa finale):**
- ☐ Ricaricare lo **stesso file GPX** nella stessa edizione → rifiutato con messaggio sul doppione, **prima** di chiamare Geoapify (nessuna immagine nuova generata).
- ☐ Stesso file con il **nome in maiuscolo/minuscolo diverso** → comunque rifiutato (confronto case-insensitive).
- ☐ Stesso file su un'**altra edizione** → consentito.
- ☐ Dal tab Itinerario, eliminare una **giornata che ha una mappa** → bloccato con messaggio in italiano (non un errore tecnico).
- ☐ **Rigenera** su una mappa esistente → si aggiorna senza segnalare falsi doppioni; l'immagine sostituisce la precedente (nessun file accumulato).
- ☐ **Elimina** → sparisce dall'elenco e la giornata torna disponibile nel select.
- ☐ **Modifica — solo descrizione**: cambia il testo → salva → nessuna attesa di generazione (non chiama Geoapify), la card mostra il nuovo nome e il file GPX resta invariato.
- ☐ **Modifica — abbinamento**: sposta una mappa da "Intero viaggio" a una giornata (o viceversa) → l'avviso annuncia la rigenerazione → la mappa compare nella nuova posizione dell'elenco e il posto liberato torna disponibile.
- ☐ **Nome file vs descrizione**: un GPX chiamato `provaG1.gpx` può avere descrizione "Mappa Giorno 1"; il nome del file resta visibile nella card e nel dialogo, **non modificabile**.
- ☐ **Overlay di attesa**: durante "Genera mappa", "Rigenera" e la modifica con rigenerazione compare la sovrapposizione "Generazione mappa in corso..." che impedisce i clic.
- ☐ **Descrizione proposta**: scegliendo la giornata compare `GIORNO 1 : Olbia - Monte Limbara - Tempio (Sabato 2 Maggio 2026)` — il titolo dell'itinerario più la data fra parentesi, **senza** doppie intestazioni. Vale sia al caricamento sia nel dialogo Modifica.
- ☐ **Descrizione obbligatoria**: svuotandola, "Genera mappa"/"Salva" restano disabilitati; a livello DB la colonna è `NOT NULL` con CHECK sul non-vuoto (script `497`).
- ☐ **Badge dell'abbinamento**: riquadro colorato affiancato alla mappa e centrato verticalmente, con "Giorno 2 / Domenica 3 Maggio 2026" (azzurro "Intero viaggio / tutte le giornate" per la mappa d'insieme); su finestra stretta va a capo sotto l'immagine.

**Tracciato generalizzato (script Task 2, `MaxPolylinePoints = 70`):**
- ☐ Rigenerando una mappa esistente, `parametri_render->>'punti_semplificati'` è ≈ 70 (era 220): `SELECT descrizione, parametri_render->>'punti_semplificati' FROM web_tour_mappa;`
- ☐ Il tracciato è **visibilmente generalizzato**: i tornanti non sono più ricostruibili, ma il percorso resta credibile — sia sulla mappa d'insieme sia su quella di una singola giornata (che copre un'area molto più piccola).

**Date delle giornate (tab Itinerario):**
- ☐ Ogni giornata mostra la data **per esteso** ("Sabato 2 Maggio 2026"), non modificabile, con icona calendario.
- ☐ **Spostando** una giornata (frecce o trascinamento) le date si **ricalcolano subito** e restano coerenti con la partenza.
- ☐ Una giornata **oltre la durata** del viaggio mostra "oltre la durata prevista" invece di una data.
- ☐ **Clone su un'altra edizione** (`fn_web_tour_contenuti_clona`): il contenuto clonato mostra le date della **nuova** partenza, non quelle di origine.

**Traduzioni e anteprima:**
- ☐ Il tab **Traduzioni** elenca le descrizioni delle mappe fra i campi da tradurre ("Mappa — …").
- ☐ Il **semaforo Traduzioni** conta le stesse voci: dopo aver aggiunto una mappa con descrizione il totale sale di 1 (una descrizione di soli spazi non conta).
- ☐ L'**Anteprima** mostra **tutte** le mappe con la loro descrizione, titolo "Mappe" al plurale.

## 19. Verifiche non bloccanti sui contenuti (script `496`)

Controlli che nessun vincolo può fare, perché non sono dati incoerenti ma **dimenticanze** (5 giornate e 4 con foto). Non impediscono mai la pubblicazione: obbligano solo a vederle.

- ☐ **Chip nel selettore edizione**: mostra il numero di voci; giallo se c'è almeno una segnalazione, azzurro se solo suggerimenti; cliccandolo si apre l'elenco.
- ☐ **Anteprima**: in cima compare il pannello "Verifica contenuti" con le stesse voci.
- ☐ **Pubblicazione**: passando lo stato a "pubblicato" con contenuti completi ma segnalazioni aperte, compare il dialogo "Prima di pubblicare".
  - ☐ *"Pubblica lo stesso"* → il salvataggio prosegue e lo stato resta "pubblicato".
  - ☐ *"Torna e correggi"* → il salvataggio si annulla, **nulla va perso** e si resta nella form.
- ☐ **Gating obbligatorio prima delle verifiche**: se manca un campo obbligatorio, resta il blocco esistente (salva come bozza) e il dialogo delle verifiche **non** compare.
- ☐ **Le voci si aggiornano**: aggiungi la foto alla giornata che ne era priva → la segnalazione sparisce alla successiva apertura/pubblicazione (sono ricalcolate, non memorizzate).
- ☐ **Concordanza dei messaggi**: "1 giornata su 5 non ha foto" al singolare, "3 giornate su 5 non hanno" al plurale.
- ☐ **Tour completo**: nessuna voce → il chip non compare e l'anteprima non mostra il pannello.

## 20. Traduzioni — attesa, revisione e gating (script `498`/`499`)

- ☐ **Attesa visibile**: "Traduci tutto" copre la scheda con l'overlay, impedisce i clic, dice che può volerci 1-2 minuti e mostra l'avanzamento ("12 di 80 — Descrizione (EN)").
- ☐ **HTML leggibile**: aprendo una cella di un campo *Descrizione*/*Pernottamento*/*Passo*, il sorgente italiano si legge **formattato** e non come tag; sotto la traduzione compare l'anteprima resa. Nei campi non-HTML (Sottotitolo, Meta) nulla cambia.
- ☐ **Tag conservati**: modificando una traduzione HTML e salvando, la formattazione resta (l'anteprima lo mostra subito).
- ☐ **Gating — il caso che prima passava**: con tutte le traduzioni generate ma **nessuna revisionata**, il semaforo Traduzioni è **rosso** e la pubblicazione è bloccata.
- ☐ **Condizione del campione**: "Approva tutte" resta disabilitato finché non si è revisionata almeno una traduzione **per ogni lingua**; l'avviso elenca le lingue mancanti e il tooltip lo ripete.
- ☐ **Approvazione in blocco**: dopo il campione, il pulsante si attiva, chiede conferma dichiarando quante traduzioni verranno approvate, e al termine il semaforo diventa **verde** e il tour è pubblicabile.
- ☐ **Idempotenza**: ripremendo "Approva tutte" quando è già tutto revisionato, il pulsante è disabilitato ("Tutte le traduzioni sono già revisionate").
- ☐ **Obsolescenza**: modificando un testo italiano già tradotto, le sue traduzioni tornano obsolete → il semaforo torna rosso e la pubblicazione si blocca di nuovo.
- ☐ **Contatore**: la riga "Revisionate N di M" segue le operazioni.

## 21. Consumo Claude e soglia di spesa (script `500`)

Il credito della chiave è precaricato e l'API **non** espone il residuo: il gestionale conta i token che ogni risposta riporta già, quindi il tracciamento non consuma crediti.

- ☐ **Registrazione**: dopo un "Traduci tutto", il pannello in *Anagrafica azienda → Traduzioni* mostra chiamate, token e spesa stimata coerenti con il numero di traduzioni fatte.
- ☐ **Riquadro nel tour**: il tab Traduzioni del viaggio mostra in cima la spesa stimata e dichiara che è una stima, non il saldo Anthropic.
- ☐ **Newsletter inclusa**: anche le traduzioni della newsletter incrementano il contatore (non solo quelle dei tour).
- ☐ **Soglia**: impostata una soglia bassa (es. 0,10) e tradotto qualcosa, il riquadro diventa **arancione** al superamento del 90%.
- ☐ **Email una sola volta**: parte **una** email all'indirizzo principale dell'azienda; traducendo ancora **non** ne arrivano altre; il pannello mostra "Avviso già inviato il ...".
- ☐ **Riarmo**: premendo *"Ho ricaricato: riparti da oggi"* il conteggio della soglia riparte, l'avviso torna disponibile e **lo storico totale resta invariato**.
- ☐ **Cambio soglia**: salvando una soglia diversa l'avviso si riarma (altrimenti alzando il tetto non si verrebbe più avvisati).
- ☐ **Nessuna soglia**: con il campo vuoto non arrivano avvisi e il riquadro resta neutro.
- ☐ **Prezzi**: modificando i prezzi in appsettings, le **nuove** traduzioni usano i nuovi valori mentre lo storico resta com'era (il costo è congelato alla chiamata).
