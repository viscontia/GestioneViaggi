# Piano di Test — Estensione Web SFT

> **USO INTERNO (Adriano + AI).** Documento vivo: si aggiorna man mano che i blocchi vengono testati.
> **Creato:** 2026-07-09 · **Aggiornato:** 2026-08-08 (§8 Newsletter: esito del **primo giro** e piano del **secondo** — bug dello stato campagna corretto, selettore azienda SuperAdmin, elenco destinatari con telefono, sito web bloccante, logo con conferma, bottone Log e avanzamento invio).
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

> **Lacuna colmata il 2026-08-08 (script `510`).** Del Blocco 11-B era implementata solo la metà
> "lingua": `consenso_marketing` (+ `_data`/`_fonte`, creati dal `428`) esisteva solo a schema e
> poteva essere scritto unicamente via SQL. Ora ha `fn_ana_clienti_get_consenso` /
> `fn_ana_clienti_set_consenso` → `ClienteConsensoService` → checkbox nella scheda cliente,
> accanto alla lingua. Le verifiche del consenso sono le ultime quattro righe qui sotto.

**Lingua newsletter:**
- ☐ Apri una scheda cliente esistente → la **Lingua newsletter** è precompilata (backfill geo: IT per residenti Italia, DE/EN per esteri).
- ☐ Cambia la lingua (override, es. ticinese/rumeno italofono → **IT**) → salva → riapri → il valore è persistito.
- ☐ Svuota il campo ("auto") → salva → la newsletter userà poi la lingua derivata dalla nazione di residenza.
- ☐ Nuovo cliente: crea uno con lingua "auto" e uno con lingua esplicita → verifica coerenza.

**Consenso marketing (script `510`):**
- ☐ La scheda cliente mostra la checkbox **"Consenso newsletter/marketing"** accanto alla lingua;
  su un cliente mai toccato è **spenta** e senza scritta sotto.
- ☐ Attivala → salva → riapri: è accesa e sotto compare **"Concesso il gg/mm/aaaa hh:mm (gestionale)"**.
- ☐ **Risalva la scheda senza toccare la checkbox** (cambia solo il telefono) → riapri: la data del
  consenso **non deve cambiare**. È la garanzia che il registro dei consensi resti attendibile.
- ☐ Spegnila → salva → riapri: la scritta diventa **"Revocato il … (revoca_gestionale)"** e il cliente
  sparisce dal conteggio destinatari della newsletter (§8 C4).

## 2. Blocco 5 — Contenuti Web del tour

- ✅ Salva/rilegge i contenuti (chiudi/riapri il dialog).
- ✅ Slug/"indirizzo web" duplicato su due edizioni → messaggio d'errore chiaro ("Esiste già un tour con questo indirizzo web…").
- ✅ Resa dei 5 editor Quill (altezze/scroll, HTML ricaricato).

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

> **Dati di test preparati (2026-08-07).** Seed applicato al DB locale — destinatari attesi:
>
> | azienda | email | lingua | fonte |
> |---|---|---|---|
> | 2 (SFT, **con** chiave Claude) | info@sardegnafuoritraccia.it | IT | cliente |
> | 2 | mirania008@gmail.com | EN | cliente |
> | 2 | visconti.adriano+de@gmail.com | DE | iscritto |
> | 2 | visconti.adriano@gmail.com | EN | **entrambi** (cliente *e* iscritto → prova la dedup) |
> | 6 (**senza** chiave Claude) | mirania008@gmail.com | EN | cliente |
> | 6 | visconti.adriano@gmail.com | EN | cliente |
>
> `visconti.adriano+de@` è plus-addressing Gmail: consegna nella stessa inbox ma vale come
> iscritto tedesco. L'azienda 6 non ha chiave Claude → è lo scenario di fallback IT.
>
> ⚠️ **Spegnere la VPN prima di ogni invio**: il server di posta blocca i range VPN/datacenter
> sulle porte 465/587 e `Connect` va in timeout (sembra un bug SMTP, è routing).
> ⚠️ "Invia a tutti" sull'azienda 2 manda una mail **vera ad Antonio**.

**Ordine consigliato:** A → B → C → D → E → F → G → H → I → J → K → L.
I gruppi E/F/G inviano posta vera: falli in una sessione sola, a VPN spenta.

---

### Esito del primo giro (2026-08-08) e cosa è cambiato

Il primo collaudo ha trovato **un bug che bloccava metà delle verifiche** e ha prodotto sette
richieste di modifica. Tutto è stato corretto: questo è il piano del **secondo giro**.

| Cosa | Esito primo giro | Ora |
|---|---|---|
| Stato campagna | `SendCampaignAsync` scriveva `"inviato"` ma il CHECK ammette `"inviata"` → l'UPDATE finale falliva **sempre** (23514), campagne ferme in `in_invio`, Storico senza data e destinatari | corretto (`70cd5d4`) |
| SMTP azienda 6 | password mai salvata (`password_enc` NULL) → nessuna mail | **da sistemare a mano**: Gmail vuole una *app password* |
| Selettore azienda SuperAdmin | assente | aggiunto (`AziendaSelect`, solo se SuperAdmin) |
| Elenco destinatari | solo il numero | chip cliccabile → dialog con Cognome, Nome, Mail, Telefono, Lingua (script `511`) |
| Sito web mancante | mail inviata con link di disiscrizione rotto | **bloccante**, in UI e nel servizio |
| Logo mancante | mail inviata senza logo, in silenzio | conferma esplicita "Invia comunque" |
| Bottone Log | sembrava una label | bottone con bordo e icona |
| Avanzamento invio | nessun feedback | "Invio in corso: N di M" + barra |

**Già verificate nel primo giro, non ripetere:** C1, C2, C5 (e C5-bis), D1–D5, E1–E5, F3, F4, F5.
Le campagne di prova sono state cancellate: lo Storico riparte vuoto.

---

### A. Accesso e gating

- ☐ **A1** — Menu "Estensione Web > Newsletter" presente; `/newsletter` si apre senza errori e la
  status bar mostra `web_newsletter_invii`.
- ☐ **A2** — La pagina carica conteggio, storico, iscritti e soppressioni senza eccezioni.
- ☐ **A3** — Azienda con `newsletter` disattivata (§9) → "non attiva", nessuna query.

**SuperAdmin (nuovo):**
- ☐ **A4** — Da SuperAdmin la pagina mostra in alto il **selettore azienda**; da utente normale
  **non compare**.
- ☐ **A5** — Senza azienda scelta resta l'avviso "Seleziona un'azienda" e **nessun tab** è operativo.
- ☐ **A6** — Scelta un'azienda → conteggio, storico, iscritti e soppressioni si popolano.
- ☐ **A7** — **Cambio azienda** → tutto si ricarica e **non resta niente della precedente** (è il
  punto che rompe l'invariante silos se sbagliato: guarda soprattutto lo Storico).
- ☐ **A8** — Scelta un'azienda con newsletter **disattivata** → compare "non attiva" anche
  cambiando dal selettore, non solo all'apertura della pagina.

### B. Composizione e validazioni (nessuna mail parte)

- ☐ **B1** — Oggetto vuoto + *Invia prova* → warning "Inserisci l'oggetto.".
- ☐ **B2** — Corpo Quill vuoto → warning "Il corpo è vuoto.".
- ☐ **B3** — Corpo con **solo un a-capo** (`<p><br></p>`) → deve contare come vuoto.
- ☐ **B4** — *Invia prova* senza email di prova → warning.
- ☐ **B5** — L'oggetto viene trimmato prima dell'invio.
- ☐ **B6** — Durante l'invio i pulsanti sono disabilitati: niente doppio invio a doppio clic.

### C. Destinatari, dedup ed elenco

- ✅ **C1** — Conteggio azienda 2 = **4**, non 5: la dedup regge (`entrambi` contato una volta).
- ✅ **C2** — Conteggio azienda 6 = **2**.
- ✅ **C5** — Iscritto `disiscritto` o `consenso=false` → escluso (4 → 3, ripristino a 4).
- ✅ **C6 (già C5-bis)** — La disiscrizione **non basta** se la persona è anche cliente con consenso:
  resta destinataria e `fonte` scivola da `entrambi` a `cliente`. Non è un difetto oggi (il flusso
  reale passa dalle soppressioni), ma è un requisito per la Fase 3 → Checklist Go-Live §2.3.
- ☐ **C3** — Cliente senza email → mai nel conteggio.
- ☐ **C4** — Togli il consenso dall'anagrafica → riapri `/newsletter` → il conteggio cala; rimettilo
  → risale. *(Ricorda: gli **iscritti** non dipendono dal consenso cliente — vedi C6.)*

**Elenco destinatari (nuovo):**
- ☐ **C7** — Il chip "Destinatari: N" è **cliccabile** (cursore e tooltip "Vedi l'elenco dei
  destinatari"); con 0 destinatari è disabilitato.
- ☐ **C8** — Si apre un elenco **in sola lettura** con le colonne, da sinistra:
  **Cognome, Nome, Mail, Telefono, Lingua**.
- ☐ **C9** — Le righe sono **le stesse** del conteggio: stesso numero, nessun duplicato.
  Su azienda 2 devono essere 4, con `visconti.adriano@gmail.com` **una volta sola**.
- ☐ **C10** — Il **telefono** compare per chi è cliente e **è vuoto (—) per `visconti.adriano+de@`**,
  che è solo un iscritto: è il comportamento voluto, non un dato mancante.
- ☐ **C11** — La **lingua** in elenco coincide con quella con cui la mail arriverà davvero
  (verificabile dopo F).
- ☐ **C12** — L'elenco è ordinato per Cognome e non è modificabile (nessun campo editabile).

### D. Soppressioni

- ✅ **D1–D3, D5** — Aggiunta con e senza motivo (default `manuale`), email vuota rifiutata,
  rimozione: conteggio 4 → 3 → 4.
- ✅ **D4** — L'indirizzo soppresso **non riceve**: le campagne 2/3/4 avevano esattamente
  `info@`, `mirania008@` e `visconti.adriano+de@`, senza `visconti.adriano@`. La mail arrivata in
  quella casella era quella all'alias `+de`, che Gmail consegna nella stessa inbox.
- ☐ **D6** — Doppia soppressione della stessa email → atteso in snackbar:
  **"Questo indirizzo è già soppresso per questa azienda."** *(Se rivedi
  "Esiste già un record per web_newsletter_soppressioni", la voce nel dizionario dei vincoli è
  andata persa.)*
- ☐ **D7** — Dopo aver soppresso un indirizzo, l'**elenco destinatari (C7)** non lo mostra più:
  conteggio ed elenco devono raccontare la stessa cosa.

### E. Invio di prova *(mail vera — VPN spenta)*

- ✅ **E1–E5** — Prova inviata, oggetto con `[TEST]`, sempre in italiano, non registrata nello
  Storico, indipendente da consensi e soppressioni.
- ☐ **E6** — Con SMTP mal configurato → snackbar rossa "Invio di prova fallito (verifica config email)."

### F. Campagna multilingua — azienda 2 (con chiave Claude) *(mail vere)*

- ✅ **F3** — Nella inbox arrivano **2** mail (la tua `EN` e quella `+de` in `DE`), non 3: dedup ok.
- ✅ **F4** — Lingue corrette: Antonio in `IT`, Anna in `EN`, `+de` in `DE`, oggetto e corpo tradotti.
- ✅ **F5** — L'HTML del corpo sopravvive alla traduzione.
- ☐ **F1** — *Invia a tutti* → conferma "Inviare la newsletter a **4** destinatari?"; *Annulla* non manda nulla.
- ☐ **F2** — **La verifica chiave del secondo giro:** esito **snackbar VERDE "Inviate 4/4"**, senza
  errori. Se ricompare "Un valore inserito per web_newsletter_invii non rispetta le regole di
  validità", la correzione dello stato è stata persa.
- ☐ **F6** — Il consumo Claude finisce nel registro con causale "Newsletter (EN)" / "Newsletter (DE)".
- ☐ **F7** — Tab Storico: riga con stato **`inviata`** (chip **verde**), **Data invio valorizzata**,
  **Destinatari = 4**, canale `smtp`. Erano le due colonne vuote del primo giro.
- ☐ **F8** — **Avanzamento (nuovo)**: durante l'invio compare prima "Preparazione dell'invio
  (traduzione dei testi)…" e poi **"Invio in corso: N di 4"** con la barra che avanza. A fine invio
  sparisce tutto.

### G. Fallback senza chiave Claude — azienda 6 *(mail vere)*

> **Prerequisito:** salvare la **password SMTP** dell'azienda 6 (Gmail → *app password*).
> Senza, G2–G4 falliscono per configurazione, non per codice.

- ☐ **G1** — Conteggio azienda 6 = **2**.
- ☐ **G2** — *Invia a tutti* → snackbar **arancione**: "Inviate 2/2 (alcune lingue inviate in IT:
  chiave Claude mancante/errore)".
- ☐ **G3** — Tu e Anna, entrambi `EN`, ricevete la versione **italiana**.
- ☐ **G4** — Nel log per-destinatario la lingua registrata è **`IT`**, non `EN`.
  *(Nel primo giro questo funzionava già: il log c'era, era lo Storico a non mostrarlo.)*

### H. Template, logo e link di disiscrizione

- ☐ **H1** — L'email usa `CompanyEmailTemplate`: logo, ragione sociale, sito e telefono nel footer.
- ☐ **H2** — **(cambiato)** Azienda **senza logo** → prima di inviare compare il dialogo
  **"Logo mancante"**: *Invia comunque* prosegue, *Annulla* interrompe senza spedire nulla.
  *(Deciso di non bloccare: impedire l'invio per un logo lascerebbe l'azienda muta verso i clienti.)*
- ☐ **H3** — In coda al corpo c'è "Non desideri più ricevere la nostra newsletter? **Disiscriviti**".
- ☐ **H4** — Il link punta a `<sito_web>/unsubscribe?email=…&sig=…`, con l'email URL-encoded.
- ☐ **H5** — **Firma reale**: stessa email inviata da azienda 2 e da azienda 6 → i `sig` devono
  essere **diversi**. Se sono identici, `token_iscrizione` è NULL e l'HMAC gira a chiave vuota.
  *(Ora verificabile: nel primo giro le mail non partivano.)*
- ☐ **H6** — **(cambiato: ora bloccante)** Azienda **senza `sito_web`** → l'invio **non parte** e
  compare "Questa azienda non ha un sito web: il link di disiscrizione sarebbe rotto…".
  Vale sia per *Invia prova* sia per *Invia a tutti*.
- ☐ **H7** — Il blocco è **autoritativo**: sta anche nel servizio, non solo nella UI. Non c'è
  percorso che spedisca con un link a `example.com`.

### I. Storico e log

- ☐ **I1** — Storico con oggetto, stato, data, n. destinatari, canale — **tutte valorizzate**.
- ☐ **I2** — **(cambiato)** Il pulsante **Log** si vede che è un pulsante (bordo, colore, icona) e
  apre il dialogo con una riga per destinatario: email, lingua, stato consegna.
- ☐ **I3** — I destinatari nel log sono esattamente quelli attesi (soppressi esclusi, dedup applicata).
- ☐ **I4** — Il log di un invio dell'azienda 2 non è visibile dall'azienda 6.

### J. Iscritti

- ☐ **J1** — Tab Iscritti mostra i 2 iscritti con email, nome, lingua, stato, consenso.
- ☐ **J2** — Elenco **read-only**: nessun pulsante di modifica o inserimento.

### K. Multi-tenant (silos)

- ☐ **K1** — Storico, iscritti e soppressioni dell'azienda 2 non compaiono sull'azienda 6 e viceversa.
- ☐ **K2** — Una soppressione su un'azienda non filtra i destinatari dell'altra, a parità di email.
  *(Già confermato a DB: il vincolo unico è su `(azienda_id, email)`.)*
- ☐ **K3** — **(nuovo, SuperAdmin)** Passando da azienda 2 a azienda 6 col selettore e tornando
  indietro, i dati mostrati sono sempre quelli dell'azienda selezionata. Nessun residuo.

### L. Errori e casi limite

- ☐ **L1** — Azienda **senza destinatari** → *Invia a tutti* → snackbar rossa "Errore invio: Nessun
  destinatario…" e **nessuna riga** nello Storico.
  ⚠️ Per arrivare davvero a zero sull'azienda 2 non basta togliere il consenso ai clienti: vanno
  disattivati anche i **due iscritti**, che non hanno UI. Via SQL:
  `UPDATE web_newsletter_iscritti SET stato='disiscritto' WHERE azienda_id=2;`
  *(Nel primo giro erano loro i 2 destinatari che restavano.)*
- ☐ **L2** — **SMTP irraggiungibile** (o VPN accesa apposta) → "Inviate 0/4, 4 errori", log con
  tutti `errore`.
  ⚠️ **Ora verificabile davvero** (prima era mascherato dal bug dello stato): controlla se la riga
  di Storico risulta comunque **`inviata`**. Lo stato è messo a fine ciclo **senza guardare gli
  esiti**, quindi una campagna interamente fallita si archivia come inviata. Se confermato, è da
  correggere — il CHECK non prevede un valore `errore`, quindi serve uno script.
- ☐ **L3** — **Errore prima del ciclo** → la riga di Storico può restare appesa in **`in_invio`**.
  Riproducibile togliendo il `sito_web`: ora però il blocco scatta **prima** che la riga venga
  creata, quindi lo Storico deve restare pulito. Verifica che sia così.
- ☐ **L5** — Conteggio del dialogo di conferma **stantio**: apri `/newsletter`, aggiungi una
  soppressione da un'altra sessione, poi invia → il dialogo annuncia il vecchio numero.
- ☐ **L6** — Traduzione fallita su **una sola** lingua → quella degrada a IT, le altre restano
  tradotte, snackbar con l'avviso.

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
- ✅ Apri un viaggio esistente → il dialog mostra la select **Difficoltà** (turistica/media/medio_alta/alta); vuota se mai impostata.
- ✅ Imposta / cambia / svuota (Clearable) la difficoltà → salva → riapri: valore coerente (NULL ammesso).
- ✅ Nuovo viaggio con date: crea con difficoltà impostata → salvata (path create-con-date).
- ✅ La difficoltà è **solo** in anagrafica viaggio: non è editabile nei contenuti web (letta live dalla pagina/anteprima).

**Contenuti per edizione (dialog viaggio → tab "Contenuti Web"):**
- ✅ **Selettore edizione**: elenca le date del viaggio con **dal–al**, chip **con/senza contenuto** e chip **effettuato/da effettuare** (da `data_viaggio_effettuato_sino`).
- ✅ Data **senza contenuto** → **Crea contenuto**: crea una bozza per quella data → compaiono i 5 sotto-tab (Contenuti/Itinerario/Galleria/Mappa/Traduzioni).
- ✅ Data senza contenuto → **Clona da** un'altra edizione (con contenuto) → copia contenuti+itinerario+galleria+mappa+traduzioni sulla nuova data.
- ✅ **Vincoli clone**: consentito solo tra date dello **stesso viaggio**; una data già con contenuto non è selezionabile come destinazione.
- ✅ **Indipendenza edizioni**: crea 2 edizioni dello stesso viaggio e verifica che modificare una **non** tocchi l'altra.
- ✅ Nel tab Contenuti **non** c'è più la difficoltà; prezzi/date **non** editabili qui (vengono dall'anagrafica).
- ✅ **Anteprima**: mostra il contenuto assemblato (sottotitolo, descrizione, itinerario+passi, galleria, mappa) in IT.
- ✅ **Pubblicazione**: porta lo **Stato** del contenuto a "pubblicato" → lo strato pubblico (`fn_web_tour_pubblicati`) espone **una riga per edizione** con prezzo/date della singola data e difficoltà dall'anagrafica (verifica via query DB o Fase 3).
- ✅ **Multi-tenant**: un'azienda non vede le edizioni/contenuti di un'altra.

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

- ✅ **Chip nel selettore edizione**: mostra il numero di voci; giallo se c'è almeno una segnalazione, azzurro se solo suggerimenti; cliccandolo si apre l'elenco.
- ✅ **Anteprima**: in cima compare il pannello "Verifica contenuti" con le stesse voci.
- ✅ **Pubblicazione**: passando lo stato a "pubblicato" con contenuti completi ma segnalazioni aperte, compare il dialogo "Prima di pubblicare".
  - ✅ *"Pubblica lo stesso"* → il salvataggio prosegue e lo stato resta "pubblicato".
  - ✅ *"Torna e correggi"* → il salvataggio si annulla, **nulla va perso** e si resta nella form.
- ✅ **Gating obbligatorio prima delle verifiche**: se manca un campo obbligatorio, resta il blocco esistente (salva come bozza) e il dialogo delle verifiche **non** compare.
- ✅ **Le voci si aggiornano**: aggiungi la foto alla giornata che ne era priva → la segnalazione sparisce alla successiva apertura/pubblicazione (sono ricalcolate, non memorizzate).
- ✅ **Concordanza dei messaggi**: "1 giornata su 5 non ha foto" al singolare, "3 giornate su 5 non hanno" al plurale.
- ✅ **Tour completo**: nessuna voce → il chip non compare e l'anteprima non mostra il pannello.

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

## 22. Revisione traduzioni senza HTML a vista (2026-07-29)

- ☐ **Campo HTML** (Descrizione, Pernottamento, Passo…): aprendo una cella, la traduzione si modifica in un **editor visuale** con i pulsanti di formattazione — **nessun tag visibile**. Il sorgente italiano appare formattato, non come codice.
- ☐ **Campo di testo puro** (Sottotitolo, Meta title, Durata, Titolo giornata, Descrizione mappa): resta una casella di testo semplice, senza editor.
- ☐ **Incluso / Escluso**: pur non chiamandosi `*_html` contengono formattazione → devono aprirsi con l'**editor visuale**, non con i tag a vista (era il caso sfuggito alla prima versione).
- ☐ **Rete di sicurezza**: qualunque traduzione il cui testo contenga tag si apre con l'editor visuale, anche se il campo non è nell'elenco.
- ☐ **La formattazione sopravvive**: modificata una parola e salvato, riaprendo la traduzione grassetti ed elenchi sono ancora al loro posto; l'anteprima del tour mostra il testo formattato.
- ☐ **Non si può svuotare**: cancellato tutto il contenuto, il salvataggio viene rifiutato con un avviso (un editor vuoto produce `<p><br></p>`, che pubblicherebbe un paragrafo vuoto).
- ☐ **Riparazione automatica**: su una traduzione con markup corrotto, aprirla e salvarla la normalizza (Quill ricostruisce i tag).
- ☐ **Segnalazione a monte**: dopo un "Traduci tutto", se il modello ha alterato dei tag il messaggio finale lo dice ("N con formattazione alterata: aprile e ricontrollale"). Le voci segnalate vanno aperte e verificate.

## 23. Anteprima: prossime partenze e scelta lingua (script `502`)

- ☐ **Con partenze future**: in testa all'anteprima compaiono le date `gg/mm/aaaa – gg/mm/aaaa` in ordine crescente; l'edizione su cui si sta lavorando è evidenziata.
- ☐ **Senza partenze future**: compare "Nessuna data in calendario per le prossime partenze di questo viaggio" (avviso, non errore).
- ☐ **Solo date future**: una partenza già passata **non** compare.
- ☐ **Lingua — nessuna completa**: la combo è disabilitata e il tooltip invita a completare e confermare le traduzioni.
- ☐ **Lingua — completa**: scelta una lingua, sottotitolo, durata, luoghi, descrizione, testi dei passi e descrizioni delle mappe passano nella lingua scelta; compare il chip "Traduzione approvata".
- ☐ **Ritorno a IT**: riportando la combo su "Italiano (originale)" si rivede il testo originale.
- ☐ **Solo traduzioni approvate**: una lingua con traduzioni presenti ma **non revisionate** (o obsolete) **non** compare nella combo.
- ☐ **Titoli giornate**: in anteprima straniera restano in italiano e l'avviso lo dichiara (limite noto: non sono fra i campi traducibili).

## 24. Titoli delle giornate tradotti (script `503`)

- ☐ **Nuovo campo**: il tab Traduzioni elenca una voce "Titolo Giorno N" per ogni giornata dell'itinerario.
- ☐ **Regressione voluta**: un tour già tradotto e approvato torna **Parziale** (e non pubblicabile) finché i titoli non vengono tradotti — il denominatore è cresciuto.
- ☐ **Traduzione**: dopo "Traduci tutto" e approvazione, il semaforo torna verde.
- ☐ **Anteprima in lingua**: i titoli delle giornate compaiono tradotti; non c'è più l'avviso che restano in italiano.
- ☐ **Obsolescenza**: modificando il titolo di una giornata già tradotta, le sue traduzioni diventano **obsolete** e il tour torna non pubblicabile (come per gli altri campi). Modificando solo l'ordine delle giornate, invece, le traduzioni **non** vengono invalidate.

## 25. "Traduci mancanti" non distrugge la revisione (2026-07-29)

Il caso che rendeva inutile il lavoro di revisione: rilanciare la traduzione ritraduceva tutto e l'upsert rimetteva `revisionato = FALSE`.

- ☐ **Niente da fare**: con tutte le voci tradotte e non obsolete, il pulsante "Traduci mancanti" è **disabilitato** e accanto al contatore non compare "da tradurre".
- ☐ **Solo il mancante**: aggiunta una giornata (o un campo) nuova, il contatore mostra le voci da tradurre e premendo il pulsante vengono tradotte **solo quelle**; il messaggio finale riporta "N già a posto (non ritradotte)".
- ☐ **La revisione sopravvive**: dopo una traduzione parziale, le voci già approvate restano **revisionate** (il semaforo non torna indietro per quelle).
- ☐ **Obsolete incluse**: modificato un testo italiano già tradotto, le sue traduzioni diventano obsolete e rientrano fra quelle da tradurre.
- ☐ **Costo**: nel registro consumi la sessione registra solo le chiamate effettivamente fatte, non una per ogni campo.

## 26. Stato della partenza: flag incrociato col calendario (2026-07-31)

Il chip accanto al selettore edizione non riporta solo la spunta "Viaggio Effettuato": la incrocia con la data di fine, perché le due possono contraddirsi.

- ☐ **Coerente, conclusa** (flag SI + data fine passata): chip azzurro "Partenza effettuata"; il tooltip ricorda che curarne la scheda web di solito non serve più.
- ☐ **Anomalia più comune** (flag NO + data fine passata): chip **giallo** "Conclusa ma non registrata"; il tooltip spiega le due cause possibili (flag non aggiornato / viaggio non realizzato) e dove correggere.
- ☐ **Coerente, in programma** (flag NO + data fine futura): chip **neutro** "Partenza da effettuare" — è lo stato normale e non deve allarmare.
- ☐ **Anomalia inversa** (flag SI + data fine futura): chip giallo "Effettuata ma non ancora conclusa".
- ☐ **Confine**: una partenza che termina **oggi** è ancora in corso, quindi non è "conclusa".
- ☐ **Tooltip sempre presente** su entrambi i chip (contenuto e partenza), con indicazione di dove si imposta il valore.

## 27. Pubblicabilità legata alle date della partenza (2026-07-31)

Regola: si pubblica solo una partenza che **deve ancora iniziare** (data di inizio dal giorno successivo a oggi) e **non già effettuata**.

- ☐ **Partenza futura, non effettuata**: la pubblicazione procede normalmente (restano gli altri controlli su contenuti e traduzioni).
- ☐ **Partenza di oggi**: passando lo stato a "pubblicato" il salvataggio lo **riporta a bozza** con il messaggio che indica la data e la regola.
- ☐ **Partenza già passata** (es. l'edizione 02/05/2026): stesso blocco.
- ☐ **Partenza futura ma segnata effettuata**: bloccata con motivo "questa partenza risulta già effettuata".
- ☐ **Ordine dei controlli**: con partenza non pubblicabile **e** contenuti incompleti, compare il messaggio sulla partenza — e **non** il dialogo "Prima di pubblicare".
- ☐ **Chip riusabile**: lo stato della partenza accanto al selettore edizione è lo stesso componente (`StatoPartenzaChip`), con tooltip.

## 28. Clonazione della scheda web su un'altra partenza (script `504`)

Il modo normale di riproporre un viaggio che si ripete: si clona e, se serve, si ritocca.

- ☐ **Clone riuscito**: da un'edizione con contenuti, immagini, itinerario, **mappe** e traduzioni, la copia si crea senza errori. *(Prima del 504 falliva con "null value in column descrizione".)*
- ☐ **Copia in bozza**: la nuova scheda nasce sempre **Bozza** con "Prima pubblicazione" vuota, anche clonando da un'edizione pubblicata.
- ☐ **Completezza**: giornate, passi, immagini e mappe della copia coincidono per numero con l'originale.
- ☐ **Mappe di giornata**: ogni mappa della copia è abbinata a una **giornata della copia**, non a quella dell'originale.
- ☐ **Traduzioni**: la copia risulta **già tradotta e approvata** (semaforo Traduzioni verde) — il testo è identico, non va rivisto da capo. Verificare che compaiano anche i **titoli delle giornate** e le **descrizioni delle mappe**.
- ☐ **Pubblicabilità**: se la data di destinazione è futura, la copia può essere portata a "Pubblicato" senza ulteriori traduzioni.
- ☐ **Vincoli**: clonare su una data che ha già un contenuto viene rifiutato con messaggio chiaro; clonare su una data di un altro viaggio è rifiutato.
- ☐ **Nota**: immagini e mappe della copia puntano agli **stessi file** dell'originale. Eliminando un media dall'edizione sorgente si rompe anche quello della copia (comportamento preesistente).

## 29. Clonazione fra partenze di durata diversa (script `505`)

Due partenze dello stesso viaggio possono avere durate diverse. Non si crea a mano: il trigger
`trg_validate_date_viaggio_duration` rifiuta una data che non rispetti `ana_viaggi.viaggio_numero_giorni`.
Ma quel controllo scatta solo sull'inserimento/modifica della data: cambiando il numero di giorni in
anagrafica, le partenze già esistenti restano com'erano. *(Verificato in locale: stesso viaggio con una
partenza di 6 giorni e una di 4.)* Ci si arriva anche più banalmente, con un itinerario di origine incompleto.

**Come preparare il caso**: su un viaggio con contenuti già pronti, cambiare `viaggio_numero_giorni`
in anagrafica (es. da 6 a 4) e aggiungere una nuova data coerente con la nuova durata.

- ☐ **Rilevazione**: scegliendo l'edizione di origine e premendo *Clona*, compare il dialogo
  "Le giornate non coincidono" con i numeri corretti (giornate di itinerario dell'origine, giorni della destinazione)
  e le date delle due partenze.
- ☐ **Rinuncia**: "Non clonare" e la X chiudono senza creare nulla; l'edizione di destinazione resta *Senza contenuto*.
- ☐ **Clone parziale**: "Clona le prime N giornate" crea la copia con **solo N giornate**. Le mappe abbinate alle
  giornate escluse **non** vengono copiate (verificato: clonando 1 giornata su 6, la mappa del GIORNO 2 sparisce).
- ☐ **Nessuna mappa orfana**: nel tab Mappa della copia non compaiono mappe "intero viaggio" inattese —
  una mappa di giornata scartata non deve trasformarsi in mappa generale.
- ☐ **Avvertimento**: dopo il clone parziale lo snackbar ricorda di rivedere l'ultima giornata clonata.
  Aprendo l'Itinerario, la giornata N descrive ancora una **tappa intermedia**: va riscritta come conclusione
  (si rientra al punto di partenza? ci si ferma dove si è arrivati?). È una scelta logistica, non automatizzabile.
- ☐ **Caso inverso** (destinazione più lunga dell'origine): il dialogo avvisa che resteranno giornate da scrivere
  a mano; "Clona comunque" copia tutte le giornate disponibili e il semaforo Itinerario resta giallo.
- ☐ **Nessuna regressione**: quando le durate coincidono il dialogo **non** compare e il clone si comporta
  come nella sezione 28.

## 30. Il sito non mostra partenze già iniziate (script `506`)

Prima del `506` la lettura pubblica filtrava solo su azienda e `stato_pubblicazione='pubblicato'`: una scheda
pubblicata restava visibile anche a viaggio concluso. Non è risolvibile con un trigger — il tempo che passa non
produce nessun evento sul database — quindi il taglio è in lettura. Confine scelto: la **data di inizio**, lo
stesso della regola di scrittura (si pubblica solo una partenza che deve ancora iniziare).

Test lato database (il sito pubblico non è ancora collegato):

```sql
SELECT contenuto_id, titolo, data_inizio FROM fn_web_tour_pubblicati(<azienda>);
SELECT fn_web_ha_tour_brevi_pubblicati(<azienda>);
```

- ☐ **Partenza passata**: una scheda pubblicata la cui partenza è già iniziata **non** compare nell'elenco.
- ☐ **Partenza di oggi**: nemmeno quella che inizia oggi compare (coerente con il gating in scrittura).
- ☐ **Partenza da domani**: compare regolarmente, con tutti i campi valorizzati.
- ☐ **Tour brevi**: `fn_web_ha_tour_brevi_pubblicati` segue lo stesso taglio, così la sezione "Tour giornalieri"
  del sito non compare vuota per via di partenze ormai passate.
- ☐ **Da comunicare al cliente prima del go-live**: al primo deploy in PROD, le schede pubblicate con partenza
  già iniziata spariranno dal sito. È l'effetto voluto.

## 31. Guardie sulla cancellazione di una partenza (script `507`)

Si elimina **solo** una partenza che deve ancora iniziare, non segnata come effettuata, senza scheda web
e senza prenotazioni. Ogni rifiuto è un avviso **giallo** con il motivo, non un errore rosso.

Dalla scheda **Date del viaggio**, icona cestino:

- ☐ **Partenza effettuata**: rifiutata con "è segnata come effettuata e fa parte dello storico aziendale",
  anche se non ha né prenotazioni né scheda web.
- ☐ **Partenza già iniziata** (flag non spuntato, data di inizio passata): rifiutata con "è già iniziata
  e fa parte dello storico".
- ☐ **Partenza che inizia oggi**: rifiutata anch'essa — coerente con il gating di pubblicazione, che
  considera pubblicabile solo ciò che deve ancora iniziare.
- ☐ **Partenza futura con scheda web in bozza**: rifiutata indicando lo stato della scheda.
- ☐ **Partenza futura con scheda web pubblicata**: rifiutata con il messaggio dedicato ("PUBBLICATA:
  riportala a bozza ed elimina la scheda").
- ☐ **Partenza futura con prenotazioni**: rifiutata come prima (messaggio clienti/alloggi, invariato).
- ☐ **Partenza futura e pulita**: si elimina regolarmente e sparisce dall'elenco.
- ☐ **Colore dell'avviso**: tutti i rifiuti sopra compaiono in **giallo**. Prima quello sui contenuti web
  compariva in rosso, perché arrivava dal vincolo del database invece che dal controllo.
- ☐ **Ultima data rimasta**: se è l'unica data del viaggio, la conferma avverte che verrà eliminato anche
  il viaggio. Con una guardia attiva, il rifiuto è giallo e **il viaggio resta al suo posto**.
- ☐ **Correzione di una data sbagliata**: inserita per errore una data nel passato, la si sposta nel futuro
  e allora si può eliminare. È voluto che siano due passaggi.

> ⚠️ **Conseguenza da conoscere**: un viaggio le cui date sono tutte passate non è più eliminabile dal
> programma. È la contropartita della protezione dello storico.

> Il comando per eliminare una scheda web — che all'inizio non esisteva in nessuna schermata, pur essendo
> già pronto nel database e nel servizio — è stato aggiunto: vedi **sezione 32**.

## 32. Eliminare una scheda di contenuti web (script `508`)

Pulsante **Elimina scheda** nella barra dell'edizione, accanto ad *Anteprima*. Serve anche a sbloccare
la cancellazione di una partenza futura (sezione 31), che i contenuti web tengono ferma.

- ✅ **Solo su bozza/archiviato**: con la scheda in **bozza** il pulsante è attivo e rosso; portandola a
  **pubblicato** diventa **disabilitato**, con tooltip che dice di riportarla a bozza. Togliere una pagina
  dal sito resta un atto in due mosse, non un clic solo.
- ✅ **La conferma dice cosa si perde**: il dialogo elenca giornate, immagini, mappe e traduzioni con i
  **numeri reali** di quella scheda, e avverte che l'operazione non è reversibile.
- ✅ **Annulla non tocca nulla**: la scheda resta intatta, semaforo compreso.
- ✅ **Eliminazione**: confermando, l'edizione torna **Senza contenuto**, ricompaiono i pulsanti
  *Crea contenuto* / *Clona* e i semafori dei sotto-tab si spengono.
- ✅ **Nessuna traduzione orfana** — il motivo per cui esiste lo script `508`. Da verificare in SQL:

  ```sql
  SELECT entita, COUNT(*) FROM web_traduzioni t
   WHERE (entita='web_tour_contenuti'  AND NOT EXISTS (SELECT 1 FROM web_tour_contenuti  x WHERE x.web_tour_contenuti_id  = t.entita_id))
      OR (entita='web_tour_itinerario' AND NOT EXISTS (SELECT 1 FROM web_tour_itinerario x WHERE x.web_tour_itinerario_id = t.entita_id))
      OR (entita='web_tour_itinerario_passaggi' AND NOT EXISTS (SELECT 1 FROM web_tour_itinerario_passaggi x WHERE x.web_tour_itinerario_passaggi_id = t.entita_id))
      OR (entita='web_tour_mappa'      AND NOT EXISTS (SELECT 1 FROM web_tour_mappa x WHERE x.web_tour_mappa_id = t.entita_id))
   GROUP BY 1;
  ```

  Deve restituire **zero righe**. *(Prima del `508` ne restavano 96 dopo una sola eliminazione.)*
- ✅ **Le altre schede non si toccano**: eliminando una scheda **clonata**, quella di origine conserva
  giornate, mappe e traduzioni. E viceversa.
- ✅ **Sblocco della partenza**: eliminata la scheda, la partenza futura si elimina (sezione 31) — sempre
  che non abbia prenotazioni.
- ✅ **Attenzione ai file condivisi**: dopo aver eliminato una scheda clonata, aprire la scheda di origine e
  controllare che **foto e mappe si vedano ancora**. I file su Storage non vengono cancellati proprio
  perché possono essere condivisi fra originale e copia.

## 33. Stato web nella griglia delle date e scorciatoia "crea o clona"

Nasce da una difficoltà reale emersa in collaudo: il clone esisteva solo dentro il selettore edizione
dei contenuti web, e compariva **solo** selezionando un'edizione priva di contenuti. Chi non ci capitava
per caso non sapeva che il clone esistesse.

Scheda **Date e Costi** del viaggio, colonna AZIONI (ultima icona):

- ☐ **L'icona riflette lo stato** della scheda web di quella partenza: grigia barrata *senza scheda*,
  gialla *bozza*, verde *pubblicata*, grigia con scatola *archiviata*.
- ☐ **Tooltip sempre presente**, diverso per ogni stato. Su *pubblicata* ricorda che la scheda sparisce
  dal sito da sola quando la partenza inizia; su *archiviata* che per il sito è come una bozza.
- ☐ **Cliccabile solo quando manca la scheda**: sulle partenze che ce l'hanno l'icona è informativa e
  non risponde al clic.
- ☐ **Clic su "senza scheda"** → si apre "Nuova scheda web" con le due opzioni.
- ☐ **Con almeno una sorgente disponibile**, il dialogo parte già su *Clona*, e con una sola sorgente la
  preseleziona. Con nessuna sorgente l'opzione *Clona* è disabilitata e spiega perché.
- ☐ **Crea da zero** → l'icona diventa gialla (bozza) senza ricaricare la form.
- ☐ **Clona** → stessa cosa, e la scheda risulta già compilata aprendo Contenuti Web.
- ☐ **Durate diverse**: clonando su una partenza di durata diversa compare il dialogo della sezione 29
  anche da qui — è lo stesso codice, non una seconda copia.
- ☐ **Coerenza con la scheda Contenuti Web**: il pulsante "Crea contenuto" del selettore edizione apre
  **lo stesso** dialogo. Le due strade devono comportarsi in modo identico.
- ☐ **Modalità non-live** (viaggio nuovo, non ancora salvato): l'icona web non compare, come le altre
  azioni che richiedono una data salvata.
- ☐ **Spaziatura**: le icone della colonna AZIONI sono più ravvicinate e la colonna resta leggibile con
  tutte e sette le icone.

## 34. Date di partenza: anno plausibile e conferme (script `509`)

Nasce dal caso reale della partenza salvata con anno **262** invece di 2026, passata senza un avviso.
Dettaglio tecnico dell'indagine in `Documents/Digitazione_Date.md`.

Scheda **Date e Costi** → *Aggiungi Data* / matita:

- ☐ **Anno assurdo bloccato**: digitando `01120262` (che la maschera accetta come 01/12/**0262**) la conferma
  è rifiutata con un messaggio che invita a controllare l'anno. Stessa cosa per la data di fine.
- ☐ **Limiti**: 2000 e 2100 sono ammessi; 1999 e 2101 no.
- ☐ **Anno precedente a quello in corso**: si può salvare, ma **solo dopo conferma esplicita** ("Sì, è corretta"
  / "Correggo"). Rispondendo *Correggo* si resta nella form con i dati intatti.
- ☐ **Oltre 5 anni nel futuro**: stessa conferma.
- ☐ **Date ordinarie**: dentro l'anno in corso o nei prossimi 5 anni si salvano **senza** alcuna domanda —
  la conferma non deve diventare un fastidio quotidiano.
- ☐ **Calendario**: la navigazione non permette di uscire da 2000–2100.
- ☐ **Digitazione rapida**: digitando le 8 cifre `01122026` senza separatori il campo mostra `01/12/2026` e
  salva il **1° dicembre 2026** (non il 12 gennaio). Verifica che `DateFormat` sia efficace.
- ☐ **Rete del database**: il vincolo vale anche fuori dalla form.

  ```sql
  -- deve fallire con violates check constraint "chk_data_viaggio_anno_plausibile"
  INSERT INTO ana_date_viaggi (viaggio_id_fk, data_viaggio_data_inizio, data_viaggio_data_fine,
         data_viaggio_costo_pilota, data_viaggio_costo_passeggero, created_by, azienda_id)
  VALUES (<viaggio>, DATE '0262-12-01', DATE '0262-12-06', 100, 100, 'test', <azienda>);
  ```

### Stesse verifiche in contabilità

I controlli sono stati estesi a **Transazioni** (Data Transazione, Documento, Scadenza, Pagamento) e al
dialogo **Paga Ora**, con una tolleranza diversa: in contabilità l'anno precedente è lavoro ordinario.

- ☐ **Anno assurdo bloccato** anche qui: una data pagamento nel 2202 viene rifiutata con il campo indicato
  nel messaggio. *(È il caso realmente trovato in produzione: transazione 72, pagamento 20/02/2202 su un
  movimento del 20/02/2022.)*
- ☐ **Anno precedente senza conferma**: a inizio anno, registrare un movimento datato l'anno scorso **non**
  deve chiedere nulla — è la chiusura dell'esercizio. *(A differenza dei viaggi, dove la conferma c'è sempre.)*
- ☐ **Due anni indietro**: la conferma compare.
- ☐ **Oltre 5 anni nel futuro**: la conferma compare.
- ☐ **Il campo indicato è quello giusto**: il messaggio dice quale delle quattro date è fuori scala.
- ☐ **"Correggo"** riporta nella form senza salvare e senza perdere gli altri dati inseriti.
- ☐ **Dialoghi di stampa** (bilancio, scadenzario, registro IVA, movimenti): i campi data mostrano e
  interpretano `gg/mm/aaaa`. Qui non c'è validazione di plausibilità perché sono filtri, non dati salvati.

### Stesse verifiche in anagrafica clienti e aziende

Qui il pavimento è **1900**, non 2000: chi è nato nel 1960 o un'azienda costituita nel 1975 sono dati
normali e non devono essere rifiutati.

**Anagrafica Azienda** (Data Costituzione, Inizio Attività, Iscrizione REA):

- ☐ **Anno assurdo bloccato**: `01011875` sulla costituzione viene rifiutato; `01011975` viene accettato.
- ☐ **Data futura bloccata**: una costituzione o un inizio attività con data di domani è rifiutata.
  *(Prima non c'era: `DataCostituzioneFutura` esisteva fra i messaggi ma non era usata da nessuna parte.)*
- ☐ **Costituzione ora validata**: prima quel campo non aveva **alcun** controllo. Provare a metterci un
  anno sbagliato e verificare che il messaggio compaia sotto il campo.
- ☐ **I confronti esistenti reggono ancora**: inizio attività o REA precedenti alla costituzione restano
  segnalati come prima.
- ☐ **Oltre 100 anni indietro**: compare l'avviso di verifica, ma **si può salvare** — un'azienda del 1910 esiste.

**Anagrafica Cliente** (Data Nascita, Rilascio e Scadenza documento):

- ☐ **Cliente di 91 anni accettato**: prima veniva **rifiutato** da un limite relativo di 90 anni.
  Data di nascita 1935 → si salva.
- ☐ **Nascita prima del 1900 o futura**: rifiutata.
- ☐ **Rilascio documento con anno assurdo nel passato**: rifiutato **anche lasciando vuota la data di
  nascita**. *(Prima passava: l'unico controllo era il confronto con la nascita.)*
- ☐ **Scadenza documento nel 2202**: rifiutata. *(Prima passava: si controllava solo che non fosse già scaduto.)*
- ☐ **Scadenza documento nel 2035**: accettata, è una scadenza legittima nel futuro.

> ⚠️ **Da rifare sulla partizione Windows 11**: senza `DateFormat` il campo seguiva la lingua del sistema
> operativo. Sul Mac italiano non si notava; su un Windows configurato in inglese giorno e mese si sarebbero
> scambiati in silenzio. Il test della digitazione rapida va ripetuto **sulla macchina del cliente**, e vale
> la pena provarlo anche con la lingua di sistema impostata su inglese.

---

## 35. Collegamento facoltativo e posizione del pulsante (script `525`)

Il collegamento di un blocco **non è obbligatorio**: un'immagine può essere solo un'immagine.
Fa eccezione il pulsante, che senza indirizzo non esiste.

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| 35.1 | Blocco **immagine**, apri "Dove porta il collegamento" | La prima voce è **«Nessun collegamento»** |
| 35.2 | Blocco immagine appena creato, senza collegamento: riaprilo | La tendina legge «Nessun collegamento». *Prima leggeva «Home page del sito» pur non avendone uno* |
| 35.3 | Scegli «Nessun collegamento» | Spariscono "Testo del pulsante" e "Posizione del pulsante": senza collegamento non c'è pulsante |
| 35.4 | Anteprima del blocco al punto 35.3 | L'immagine si vede e **non è cliccabile**; nessun pulsante sotto |
| 35.5 | Blocco con collegamento in rubrica → passa a «Nessun collegamento» → Salva → riapri | Resta «Nessun collegamento». Il legame con la rubrica è sciolto: cambiando quell'indirizzo in rubrica il blocco non torna a puntarci |
| 35.6 | Blocco **pulsante**, apri la stessa tendina | «Nessun collegamento» **non** compare; senza indirizzo il salvataggio è rifiutato |
| 35.7 | Blocco immagine con pulsante, immagine "Sopra, a piena larghezza", posizione pulsante **Al centro** | Nell'anteprima e nella mail il pulsante è centrato, con l'immagine a piena larghezza |
| 35.8 | Stesso blocco, posizione pulsante **vuota** | Il pulsante segue la posizione dell'immagine (comportamento dei blocchi già composti) |
| 35.9 | Blocchi **riquadro informativo** e **tour** con pulsante | "Posizione del pulsante" **non** compare: lì il pulsante sta nella colonna del testo e la segue |
| 35.10 | Clona una newsletter che usa le posizioni dei pulsanti | Le posizioni si ritrovano identiche nella copia |

> Verificato a monte: `fn_web_newsletter_blocchi_update` **assegna** `link_url` invece di
> `COALESCE`-arlo, quindi il NULL cancella davvero il collegamento; `layout` invece è in COALESCE
> e resta quello di prima. Provato in transazione annullata sul DB locale.

---

## 36. Colore di titolo e sottotitolo (script `526`)

Il colore del titolo era una costante del renderer — blu `#2171A5` — e l'utente non poteva
cambiarlo. Ora titolo e sottotitolo hanno un colore proprio; il testo del corpo ce l'aveva già,
glielo mette l'editor.

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| 36.1 | Apri un **riquadro informativo** già esistente | Titolo e sottotitolo mostrano «Predefinito» con il pallino del colore. **Nessun codice esadecimale a vista** |
| 36.2 | Titolo → scegli «Rosso» dalla tendina → Salva → Anteprima | Le voci sono nomi con il colore accanto. Il titolo del riquadro diventa rosso, il sottotitolo resta grigio |
| 36.3 | Sottotitolo → colore diverso → Salva → Anteprima | I due colori sono indipendenti |
| 36.4 | Torna a **«Predefinito»** sul titolo → Salva → riapri | Il titolo è di nuovo blu e la tendina legge «Predefinito» |
| 36.5 | Scegli a mano «Blu del modello» (non «Predefinito») | Aspetto identico, ma il blocco ha ora un colore **dichiarato**: non seguirà più il modello se il modello cambia |
| 36.5b | **«Altro colore…»** → prendi un colore qualsiasi → conferma | È l'unico punto in cui compare un codice colore. Tornato nella form, la voce legge «Colore personalizzato» e resta selezionata riaprendo il blocco |
| 36.6 | Stessa prova su **testata** e **riquadro tour** | Funziona uguale. Nella testata il predefinito del sottotitolo è più scuro (`#333333`) che negli altri blocchi (`#888888`): il pallino deve mostrare quello giusto |
| 36.7 | **Invio di prova** di una newsletter con i colori | I colori arrivano nella mail, non solo nell'anteprima |
| 36.8 | **Clona** una newsletter con i colori | La copia ha gli stessi colori |
| 36.9 | Blocco **testo** e blocco **pulsante** | Nessuna scelta di colore: non hanno titolo né sottotitolo |

> Verificato a monte, eseguendo il renderer: senza colore dichiarato l'HTML esce identico a prima
> (`#2171A5` titolo, `#888888` sottotitolo, `#333333` sottotitolo di testata); un valore non valido
> come `rosso` ricade sul predefinito invece di finire nella mail; `#C0392B80` perde la trasparenza
> e diventa `#C0392B`, l'unica forma che il vincolo sul database accetta.

---

## 37. Modelli di newsletter e riaggancio della partenza

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| 37.1 | **Nuova newsletter** | Si apre una form che chiede l'oggetto **e da dove partire**: vuota / da un modello / copiando una esistente |
| 37.2 | Nessun modello salvato | La voce «Da un modello» è disabilitata e dice «non ne hai ancora salvati» |
| 37.3 | Su una newsletter riuscita → icona **segnalibro** → dai un nome | Nasce un modello. Con «Mostra i modelli» lo ritrovi; l'originale resta dov'era |
| 37.4 | **Nuova newsletter → da un modello** | Con almeno un modello, è la scelta già selezionata |
| 37.5 | Crea da un modello che ha blocchi agganciati a una partenza | Per **ogni** blocco viene chiesto a quale partenza agganciarlo, dicendo di quale blocco si tratta |
| 37.6 | Scegli una partenza | Titolo, sottotitolo (date nuove), immagine e collegamento si aggiornano da quel tour |
| 37.7 | **Annulla** su uno dei riquadri | Quel blocco resta agganciato all'originale; un messaggio dice quanti sono rimasti da sistemare |
| 37.8 | Crea da un modello **senza** blocchi agganciati | Nessuna domanda: si apre direttamente la composizione |
| 37.9 | **Duplica** una newsletter con blocchi agganciati | Stessa domanda della creazione da modello: anche una copia dell'anno scorso ha le partenze vecchie |
| 37.10 | Un modello nella lista | Il pulsante Invia resta bloccato: un modello si duplica, non si invia |
| 37.11 | Apri un blocco con **social, icona, posizione del pulsante o colori**, salva senza cambiare niente, guarda l'anteprima | Resta tutto. *Prima quei campi venivano azzerati dalla copia di lavoro* |

---

## 38. Collegamenti ai tour: integrità e verifica prima di spedire (script `527`)

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| 38.1 | Newsletter **in bozza** con un blocco agganciato a una partenza → prova a eliminare la **scheda web** di quel tour | Rifiutato, con il nome della newsletter che lo impedisce |
| 38.2 | Togli o riaggancia quel blocco → riprova | L'eliminazione va a buon fine |
| 38.3 | Solo una newsletter **già inviata** punta a quella partenza → elimina la scheda web | Consentito: la mail spedita è congelata e non si rompe |
| 38.4 | Newsletter con un blocco che punta a un tour la cui scheda è **in bozza** → **Invia a tutti** | Invio **bloccato**, con posizione e nome del blocco |
| 38.5 | Stesso caso → **Invio di prova** | Parte lo stesso, con un **avviso**: comporre prima di pubblicare il tour è una sequenza legittima |
| 38.6 | Pubblica la scheda del tour → **Invia a tutti** | Nessun avviso, l'invio procede |
| 38.7 | Blocco con un indirizzo **scritto a mano** che contiene `/tour/` ma non è un nostro link (es. `/it/tour/fuoristrada/autunno-gallura`) | **Nessun falso allarme**: non è un collegamento che abbiamo composto noi |
| 38.8 | Newsletter con più di 4 blocchi problematici | Ne elenca 4 e dice quanti altri ce ne sono |

> Verificato sul database locale, in transazioni annullate: l'eliminazione della scheda è stata
> rifiutata con la bozza agganciata e consentita con la sola inviata. Sulle newsletter reali la
> verifica ha trovato 3 collegamenti morti veri e — dopo aver stretto l'estrazione dello slug —
> nessun falso allarme.

---

## 39. Invii selettivi: a chi spedire (script `529`)

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| 39.1 | Apri una newsletter in bozza | Riquadro **Destinatari**: «Nessun criterio: va a tutti quelli che ne hanno diritto», col conteggio spaccato fra anagrafica e iscritti dal sito |
| 39.2 | **Aggiungi un criterio** | La form avvisa in testa che i criteri guardano l'anagrafica clienti |
| 39.3 | «In anagrafica da una certa data» → scegli una data | Compare come frase leggibile e il conteggio cala |
| 39.4 | Aggiungi un secondo criterio | I criteri si **sommano**: ricevono solo i clienti che li soddisfano **tutti** |
| 39.5 | «Iscritti a una partenza» | Si apre il **selettore viaggio/partenza** già usato altrove |
| 39.6 | «Residenti in una nazione» | Solo le nazioni dove risiede almeno un cliente, **Italia per prima**, con i nomi in italiano e il numero di clienti |
| 39.7 | Con un filtro attivo e almeno un iscritto dal sito | Avviso: «N iscritti restano fuori». Il numero **non** è zero se ne esistono |
| 39.8 | Attiva **«Includi comunque gli iscritti dal sito»** | Il conteggio risale e l'avviso sparisce |
| 39.9 | Chiudi e riapri la newsletter | Criteri e interruttore sono **ancora quelli**, il conteggio pure |
| 39.10 | **Vedi l'elenco** | Si apre l'elenco dei destinatari **filtrati**, non di tutti |
| 39.11 | **Invia a tutti** | Parte solo ai destinatari filtrati: il numero sul pulsante è quello del pannello |
| 39.12 | Apri una newsletter **già inviata** | Il pannello mostra i criteri usati ma **non si modifica** |
| 39.13 | Cliente disiscritto che soddisfa tutti i criteri | **Non** riceve: i filtri restringono, non scavalcano |

> Verificato sul database, in transazioni annullate (azienda 2, consenso esteso a tutti i 167
> clienti per avere una popolazione): senza filtri 157 destinatari (156 + 1 iscritto); «residenti
> all'estero» → 3, con **1 iscritto segnalato come escluso**; «iscritti a ICHNUSA TOUR del
> 25/04/2026» → 20, sommando «in anagrafica dal 01/01/2026» → 13; «nel 2025 non hanno viaggiato»
> → 83. Le descrizioni si leggono come frasi compiute.

---

## 40. Selettore viaggio/partenza — scheda «Per Anno» *(bug 14, componente condiviso)*

Il difetto è **anteriore** all'estensione web e il componente è usato da sei schermate: va riprovato
ovunque, non solo dalla newsletter.

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| 40.1 | Filtri destinatari → «Iscritti a una partenza» → scheda **«Per Anno»** → apri un anno, un viaggio, clicca una **partenza** | La partenza risulta **scelta**: il pulsante di conferma si abilita |
| 40.2 | Conferma | Il criterio viene aggiunto con il nome del viaggio e la data giusti |
| 40.3 | Stessa prova dalla scheda **«Ricerca Rapida»** | Funziona come prima: non deve essere peggiorata |
| 40.4 | Scegli dall'albero, poi passa a «Ricerca Rapida» | Le due tendine mostrano **lo stesso** viaggio e la stessa partenza |
| 40.5 | Clicca un nodo **anno** o **viaggio** | Si apre e si chiude come prima; non conta come scelta di una partenza |
| 40.6 | Stessa prova dalle **stampe** (menu), dalla **dashboard** e dal **blocco tour** della newsletter | Stesso comportamento: il componente è lo stesso |

---

## 41. Selettore partenze: leggibilità dell'albero e riscontro della scelta (script `530`)

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| 41.1 | Apri il selettore → scheda **«Per Anno»** → espandi fino alle partenze | Ogni riga mostra **date**, **numero di iscritti** e lo **stato** con etichetta leggibile («Partenza da effettuare», «Partenza effettuata») |
| 41.2 | Passa il mouse sullo stato | Tooltip che spiega il caso e **dove si corregge** |
| 41.3 | Una partenza **futura** | **Non** è più gialla d'allarme: il caso normale non si segnala come anomalia |
| 41.4 | Una partenza **conclusa e non spuntata** come effettuata | Compare come **anomalia**, con la spiegazione |
| 41.5 | Una partenza **senza iscritti** | Si legge «nessun iscritto», non uno zero da interpretare |
| 41.6 | Scheda **«Ricerca Rapida»**, tendina delle date | Stesso stato e stessa etichetta dell'albero. *Prima l'icona non compariva affatto* |
| 41.7 | Filtri destinatari → «Iscritti a una partenza» → scegli dall'albero → torna alla form | Compare **il nome del viaggio e la data** scelti, non un generico «Partenza scelta» |
| 41.8 | Aggiungi il criterio | La frase del criterio nell'elenco è **la stessa** che avevi letto scegliendo |
| 41.9 | Stessa prova dalle **stampe** e dal **blocco tour** della newsletter | Identico: il selettore è lo stesso componente |

---

## 42. Calendario viaggi: stesso stato di tutto il resto

Non riguarda la newsletter: è il completamento dell'allineamento del §41. Il calendario usava lo
stesso schema di colori fuorviante del selettore.

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| 42.1 | Apri il **calendario viaggi**, mese con partenze **future** | Targhette **neutre** (grigie): una partenza in programma non è un allarme. *Prima erano arancioni* |
| 42.2 | Mese con partenze **concluse e spuntate** | Targhette **blu**. *Prima verdi* |
| 42.3 | Partenza **conclusa e non spuntata** come effettuata | Targhetta **ambra**: è l'unica situazione da guardare. *Prima rossa come un errore* |
| 42.4 | Passa il mouse su una targhetta | Il tooltip riporta date, partecipanti, l'etichetta di stato **e la spiegazione**, con l'indicazione di dove si corregge |
| 42.5 | Confronta con l'elenco date e con l'albero del selettore | **Stessa etichetta e stesso colore** per la stessa partenza, ovunque |

---

## 43. Caricamento file: un solo componente per tutta l'applicazione

Tocca sei schermate, tre delle quali **fuori** dall'estensione web: vanno riprovate tutte.

| # | Dove | Cosa fare | Cosa deve succedere |
|---|---|---|---|
| 43.1 | **Foto cliente** | Carica una foto normale | Si carica e compare l'anteprima, come prima |
| 43.2 | Foto cliente | Carica un file **oltre 5 MB** | Messaggio che nomina il limite. *Prima: oltre 10 MB spariva in silenzio* |
| 43.3 | **Logo azienda** | Carica un logo **oltre 10 MB** | Messaggio esplicito. *Prima: nessun limite dichiarato, spariva* |
| 43.4 | **Import Oracle** | Scegli un `.xlsx` | Nome e dimensione compaiono subito; il file viene copiato in cache **alla scelta**, non all'import |
| 43.5 | Import Oracle | Scegli un file **non** `.xlsx` | Rifiutato con un messaggio che dice cosa serve |
| 43.6 | Import Oracle | Scegli un `.xlsx` **oltre 10 MB** (fino a 50) | Si carica: il limite ora è 50 MB. *Prima: scartato in silenzio* |
| 43.7 | **Galleria tour** | Carica più foto insieme | Attesa con contatore e nome del file; le foto arrivano tutte |
| 43.8 | Galleria tour | Ricarica una foto **già presente** | «Saltate N foto già presenti», con l'elenco |
| 43.9 | Galleria tour | Carica foto senza titolo/alt | Resta il promemoria di compilarli |
| 43.10 | **Mappa GPX** | Carica un `.gpx` | Funziona come prima |
| 43.11 | Mappa GPX | Rinomina un `.txt` in `.gpx`… anzi: carica un file **non** `.gpx` trascinandolo | Rifiutato lato applicazione, non solo dal filtro del browser |
| 43.12 | Tutte | Riseleziona **lo stesso file** appena caricato | Riparte il caricamento (senza `ClearAsync` il controllo sembrerebbe non funzionare più) |

---

## 44. Traduzione della newsletter (fasi 4.1 e 4.2, script `531`)

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| 44.1 | Apri una newsletter in bozza | Riquadro **Lingue** con EN/DE/ES/FR e il conteggio `0/N` |
| 44.2 | **Traduci quello che manca** | Avanzamento testo per testo; a fine i quattro contatori vanno a `N/N` |
| 44.3 | Rilancia subito la traduzione | Dice «già a posto»: non ritraduce, così non butta via la revisione |
| 44.4 | **Invio di prova** a un indirizzo con lingua diversa da IT | La mail arriva con **oggetto e testi** in quella lingua |
| 44.5 | Modifica il **titolo** di un blocco già tradotto → guarda il riquadro Lingue | Compare l'avviso «testi cambiati dopo la traduzione»; quel campo torna in **italiano** nella mail, gli altri restano tradotti |
| 44.6 | Ritraduci | L'avviso sparisce, il contatore torna pieno |
| 44.7 | Newsletter **senza** traduzioni → **Invia a tutti** | Avviso non bloccante: «Traduzioni incomplete (EN 0/18, …)»; l'invio **procede** |
| 44.8 | Registro dei destinatari dopo l'invio | La colonna lingua riporta la lingua di ciascun destinatario, non più «IT» per tutti |
| 44.9 | Riquadro **tour**: guarda i campi tradotti | Il **periodo** («Dal 2 al 7 maggio 2026») **non** compare fra i traducibili: è generato |
| 44.10 | Newsletter **già inviata** | Il riquadro Lingue è in sola lettura: non si ritraduce ciò che è partito |

> Verificato sul database in transazioni annullate: copertura 18 campi traducibili; tradotti
> oggetto + due campi in DE → `DE 3/18`, le altre lingue a zero; modificato il titolo tradotto →
> la traduzione diventa obsoleta e **sparisce dalla lettura di rendering**, quindi si ricade
> sull'italiano.

---

## 45. Archivio per lingua e clonazione delle traduzioni (fase 4.4, script `532`)

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| 45.1 | Traduci una newsletter, poi **Invia a tutti** con destinatari di lingue diverse | In `web_newsletter_invii_corpi` c'è **una riga per lingua usata**, con oggetto, corpo e numero di destinatari |
| 45.2 | Confronta il corpo archiviato in DE con la mail ricevuta da un destinatario tedesco | Stesso testo. Cambia solo il collegamento di disiscrizione, che nell'archivio è generico |
| 45.3 | Invio a destinatari **tutti italiani** | Una riga sola, `IT` |
| 45.4 | **Clona** una newsletter con traduzioni | La copia nasce **già tradotta**: il riquadro Lingue mostra gli stessi contatori |
| 45.5 | Nella newsletter d'origine rendi obsoleta una traduzione (modifica il testo italiano), poi clona | Quella traduzione **non** viene copiata: era già disallineata |
| 45.6 | Nella copia, controlla una traduzione che nell'originale era **revisionata** | Risulta ancora revisionata: il testo è identico, riapprovarlo sarebbe lavoro inutile |
| 45.7 | Clona e verifica l'**oggetto** | La copia ha l'oggetto nuovo che hai scritto, **senza** traduzioni ereditate |
| 45.8 | Crea da **modello** con blocchi agganciati a una partenza | Traduzioni copiate **e** riaggancio della partenza: le due cose non si escludono |

> Verificato in transazione annullata: blocco con 2 traduzioni valide + 1 obsoleta → la copia (16
> blocchi) riceve **solo le 2 valide**, con `revisionato` preservato.

---

## 46. Anteprima nella lingua del destinatario (fase 4.5, prima parte)

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| 46.1 | Apri l'**Anteprima** di una newsletter | In cima, le cinque lingue. L'italiano è selezionato |
| 46.2 | Guarda le etichette delle lingue | Ognuna riporta la copertura (`DE 18/18`, `FR 0/18`): non si può credere tradotta una lingua che non lo è |
| 46.3 | Clicca **DE** | Ricompone e mostra la versione tedesca: torna il velo di attesa finché le immagini non sono pronte |
| 46.4 | Con DE selezionato | Compare l'avviso «I testi non tradotti restano in italiano» |
| 46.5 | Lingua **non tradotta** (es. FR 0/18) | L'anteprima si vede lo stesso, tutta in italiano **tranne** disiscrizione ed etichette dei pulsanti, che sono in francese |
| 46.6 | Torna su **IT** | Ricompone l'originale |
| 46.7 | Clicca ripetutamente fra due lingue | Nessun accavallamento: mentre ricompone i pulsanti sono disabilitati |

---

## 47. Riquadro tour nelle altre lingue (fase 4.3, script `533`)

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| 47.1 | Riquadro tour agganciato a una partenza → **Anteprima in DE** | Il periodo è in tedesco: «Vom 2. bis 7. Mai 2026», non «Dal 2 al 7 maggio 2026» |
| 47.2 | Stessa prova in EN, ES, FR | «From 2 to 7 May 2026» · «Del 2 al 7 de mayo de 2026» · «Du 2 au 7 mai 2026» |
| 47.3 | Partenza **a cavallo di due anni** (Capodanno) | Entrambi gli anni compaiono: «Dal 30 dicembre 2025 al 4 gennaio 2026» |
| 47.4 | Partenza di **un solo giorno** | Forma breve, senza «Dal … al …» |
| 47.5 | Anteprima in **IT** | Il periodo resta quello memorizzato: se l'avevi corretto a mano, la correzione non viene sovrascritta |
| 47.6 | Inserisci un riquadro tour di un tour **già tradotto**, senza toccare i testi → riquadro **Lingue** | Il testo del riquadro risulta **già tradotto**: ereditato dalla scheda, senza spendere una traduzione |
| 47.7 | Guarda quella traduzione ereditata | Se sulla scheda era **revisionata**, lo è anche qui: il testo è identico, riapprovarlo sarebbe lavoro inutile |
| 47.8 | **Riscrivi** il testo del riquadro | Le traduzioni ereditate diventano **obsolete** e non vengono riereditate: ora il testo è tuo |
| 47.9 | Riporta il testo esattamente a quello del tour | Torna a ereditare |
| 47.10 | Modifica la **scheda del tour** dopo aver composto la newsletter | Nella newsletter **non cambia nulla**: è una fotografia. Per aggiornarla si riseleziona il tour |

> Verificato sul database in transazione annullata: inserito un riquadro tour col testo della
> scheda → il trigger eredita **4 lingue** con `revisionato` conservato; riscritto il testo → le 4
> diventano obsolete e non si rieredita.

### 47 bis — Posizione del pulsante nel riquadro tour

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| 47.11 | Apri un riquadro tour con il collegamento compilato | Compare **«Posizione del pulsante»**, con nota «Vuoto = al centro» |
| 47.12 | Lascia la posizione vuota → Anteprima | Il pulsante è **al centro**, non più a sinistra |
| 47.13 | Scegli *A destra* → Anteprima | Il pulsante si sposta a destra, dentro la colonna del testo |
| 47.14 | Riquadro **informativo** con pulsante | Lì la scelta **non** compare: il pulsante chiude un testo che scorre accanto all'icona, e spostarlo lo staccherebbe dal discorso |

