# Piano di Test — Estensione Web SFT

> **USO INTERNO (Adriano + AI).** Documento vivo: si aggiorna man mano che i blocchi vengono testati.
> **Creato:** 2026-07-09 · **Aggiornato:** 2026-08-07 (contenuti web §2/§10/§19/§32 collaudati ✅; §8 Newsletter riscritta come piano eseguibile A–L con dati di test preparati).
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

### A. Accesso e gating

- ☐ **A1** — Menu "Estensione Web > Newsletter" presente; `/newsletter` si apre senza errori e la
  status bar mostra la tabella corrente `web_newsletter_invii`.
- ☐ **A2** — La pagina carica 4 blocchi senza eccezioni: conteggio, storico, iscritti, soppressioni.
  *(Se una delle 4 query fallisce compare una snackbar rossa "Errore caricamento: …" e la pagina resta
  su valori vuoti anziché rompersi.)*
- ☐ **A3** — Azienda con `newsletter` disattivata (§9) → la pagina mostra "non attiva" e **non**
  esegue nessuna query. Ri-attivando, torna operativa.

### B. Composizione e validazioni (nessuna mail parte)

- ☐ **B1** — Oggetto vuoto + *Invia prova* → snackbar **warning** "Inserisci l'oggetto." e nient'altro.
- ☐ **B2** — Oggetto valorizzato ma corpo Quill vuoto → warning "Il corpo è vuoto.".
- ☐ **B3** — Corpo con **solo un a-capo** (Quill produce `<p><br></p>`) → deve contare come **vuoto**
  e dare lo stesso warning: è il caso che sfugge più facilmente.
- ☐ **B4** — *Invia prova* con oggetto e corpo validi ma **email di prova vuota** → warning
  "Inserisci un'email di prova.".
- ☐ **B5** — L'oggetto viene **trimmato** prima dell'invio (spazi iniziali/finali non finiscono in mail).
- ☐ **B6** — Durante un invio i pulsanti sono disabilitati (`_busy`): niente doppio invio a doppio clic.

### C. Destinatari e deduplicazione

- ☐ **C1** — Azienda 2: il conteggio in tab Campagna dice **4** (non 5). Sono 3 clienti con consenso
  + 2 iscritti, ma `visconti.adriano@gmail.com` è **entrambi** e va contato una volta sola.
- ☐ **C2** — Azienda 6: il conteggio dice **2**.
- ☐ **C3** — Cliente **senza email** o con email vuota → non compare mai nel conteggio.
- ☐ **C4** — Togli il consenso a un cliente dall'anagrafica → riapri `/newsletter` → il conteggio cala.
  Rimettilo → risale. *(Il conteggio si ricarica a `OnInitializedAsync` e dopo invio/soppressioni,
  non in tempo reale: se cambi il consenso con la pagina già aperta, devi rientrare.)*
- ✅ **C5** — Iscritto con `stato='disiscritto'` o `consenso=false` → escluso. *(Verificato il 2026-08-08
  su `visconti.adriano+de@gmail.com`, iscritto puro dell'azienda 2: 4 → 3 in entrambi i casi, 4 al
  ripristino. Non c'è UI per gli iscritti — il tab è read-only — quindi si prova via SQL:
  `UPDATE web_newsletter_iscritti SET stato='disiscritto' WHERE azienda_id=… AND email='…';`)*
- ⚠️ **C5-bis — la disiscrizione NON basta se la persona è anche cliente con consenso.**
  Verificato il 2026-08-08 sull'azienda 6: creato l'iscritto per un indirizzo che lì è già cliente
  con consenso (`fonte` diventa `entrambi`), poi messo `stato='disiscritto'` → **resta destinatario**,
  `fonte` torna `cliente`. La `FULL JOIN` di `fn_web_destinatari_newsletter` toglie la riga
  dell'iscritto ma quella del cliente sopravvive, senza alcun segnale che una revoca è stata ignorata.
  **Oggi non è un difetto attivo**, perché il flusso reale di disiscrizione passa da
  `NewsletterUnsubscribe` → **soppressione**, che blocca qualunque fonte.
  **Lo diventa in Fase 3** se chi implementa `/unsubscribe` si limita a mettere
  `stato='disiscritto'`: la persona continuerebbe a ricevere dopo aver cliccato "Disiscriviti".
  → requisito registrato nella Checklist Go-Live §2.3.

### D. Soppressioni

- ☐ **D1** — Tab Soppressioni → aggiungi `mirania008@gmail.com` con motivo → snackbar "Soppressione
  aggiunta." → il conteggio scende a **3**.
- ☐ **D2** — Aggiungi una soppressione **senza motivo** → viene salvata con motivo `manuale`.
- ☐ **D3** — Email vuota → warning "Inserisci un'email.", niente inserimento.
- ☐ **D4** — Con la soppressione attiva fai un invio → quell'indirizzo **non riceve** e **non compare**
  nel log dei destinatari.
- ☐ **D5** — Rimuovi la soppressione → snackbar "Soppressione rimossa." → conteggio di nuovo **4**.
- ☐ **D6** — Doppia soppressione della stessa email → non deve creare doppioni né rompere il conteggio.

### E. Invio di prova *(mail vera — VPN spenta)*

- ☐ **E1** — Prova a `visconti.adriano@gmail.com` → snackbar verde "Email di prova inviata."
- ☐ **E2** — L'email arriva con oggetto **`[TEST] <oggetto>`**.
- ☐ **E3** — È in **italiano** anche se il destinatario è EN: la prova non traduce mai.
- ☐ **E4** — L'invio di prova **non** compare nel tab Storico (non registra la campagna).
- ☐ **E5** — L'invio di prova ignora consensi e soppressioni: funziona anche verso un indirizzo
  soppresso o sconosciuto. *(È voluto: serve a provare la configurazione.)*
- ☐ **E6** — Con SMTP mal configurato → snackbar rossa "Invio di prova fallito (verifica config email)."

### F. Campagna multilingua — azienda 2 (con chiave Claude) *(mail vere)*

- ☐ **F1** — *Invia a tutti* → dialogo di conferma "Inviare la newsletter a **4** destinatari?" con
  pulsante **Invia**. *Annulla* non manda nulla.
- ☐ **F2** — Esito: snackbar verde "Inviate 4/4", senza la coda sulle lingue.
- ☐ **F3** — Arrivano **4 email**, e nella tua inbox ne arrivano **2** (la tua EN + quella `+de`),
  non 3: se ne arrivano 3 la dedup è rotta.
- ☐ **F4** — Lingue: Antonio in **IT** (testo originale), Anna in **EN**, `+de` in **DE**.
  Oggetto **e** corpo tradotti, non solo il corpo.
- ☐ **F5** — L'HTML del corpo sopravvive alla traduzione (grassetti, liste, link non si sfaldano).
- ☐ **F6** — Il consumo Claude della newsletter finisce nel **registro consumi** con causale
  "Newsletter (EN)" / "Newsletter (DE)" — 2 chiamate per lingua (oggetto + corpo).
- ☐ **F7** — Tab Storico: nuova riga con canale **`smtp`**, stato `inviato`, n. destinatari **4**.

### G. Fallback senza chiave Claude — azienda 6 *(mail vere)*

- ☐ **G1** — Cambia azienda in **Offroad Adventures** → conteggio **2**.
- ☐ **G2** — *Invia a tutti* → snackbar **arancione**: "Inviate 2/2 (alcune lingue inviate in IT:
  chiave Claude mancante/errore)".
- ☐ **G3** — Tu e Anna, entrambi `EN`, ricevete la versione **italiana**. Nessun errore, nessuna
  mail mancata: il fallback degrada, non blocca.
- ☐ **G4** — Nel log per-destinatario la lingua registrata è **`IT`**, non `EN`: deve riflettere
  la lingua *realmente inviata*.

### H. Template brandizzato e link di disiscrizione

- ☐ **H1** — L'email usa `CompanyEmailTemplate`: logo azienda in testa, ragione sociale, e in footer
  sito e telefono.
- ☐ **H2** — Azienda **senza logo** → l'email parte comunque, solo senza immagine (il logo è
  non-critical: viene loggato un warning e si prosegue).
- ☐ **H3** — In coda al corpo c'è il separatore e "Non desideri più ricevere la nostra newsletter?
  **Disiscriviti**".
- ☐ **H4** — Il link punta a `<sito_web>/unsubscribe?email=…&sig=…`, con l'email URL-encoded.
- ☐ **H5** — **Firma reale**: la stessa email inviata da azienda 2 e da azienda 6 deve produrre
  `sig` **diversi**. Se sono identici, `token_iscrizione` è tornato NULL e l'HMAC sta usando chiave
  vuota (link forgiabile e uguale per tutti i tenant).
- ☐ **H6** — Azienda senza `sito_web` → il link cade sul placeholder `https://www.example.com`
  anziché generare un URL rotto. *(Comportamento accettato: il click lo gestirà il sito in Fase 3.)*

### I. Storico e log

- ☐ **I1** — Tab Storico elenca gli invii con oggetto, stato, data, n. destinatari, canale.
- ☐ **I2** — Azione **Log** → dialogo con una riga per destinatario: email, lingua, stato consegna.
- ☐ **I3** — I destinatari nel log sono **esattamente** quelli attesi (soppressi esclusi, dedup applicata).
- ☐ **I4** — Il log di un invio dell'azienda 2 non è apribile né visibile dall'azienda 6.

### J. Iscritti

- ☐ **J1** — Tab Iscritti mostra i 2 iscritti seed con email, nome, lingua, stato, consenso.
- ☐ **J2** — L'elenco è **read-only**: nessun pulsante di modifica/inserimento (gli iscritti arrivano
  dal sito pubblico, Fase 3).

### K. Multi-tenant (silos)

- ☐ **K1** — Storico, iscritti e soppressioni dell'azienda 2 **non** compaiono sull'azienda 6 e viceversa.
- ☐ **K2** — Una soppressione inserita su un'azienda **non** filtra i destinatari dell'altra, anche a
  parità di indirizzo email.

### L. Errori e casi limite

- ☐ **L1** — Azienda **senza destinatari** (togli tutti i consensi) → *Invia a tutti* → snackbar rossa
  "Errore invio: Nessun destinatario (verifica consensi clienti / iscritti / soppressioni)." e
  **nessuna riga** creata nello storico.
- ☐ **L2** — **SMTP irraggiungibile** (o VPN accesa apposta) → tutti gli invii falliscono →
  snackbar "Inviate 0/4, 4 errori", log con tutti `errore`.
  ⚠️ **Da verificare:** la riga di storico risulta comunque in stato **`inviato`**, perché lo stato
  è impostato a fine ciclo senza guardare gli esiti. Se lo confermi, è una segnalazione da aprire:
  una campagna interamente fallita non dovrebbe archiviarsi come inviata.
- ☐ **L3** — **Errore prima del ciclo** (es. configurazione email assente e il factory lancia) → la
  riga di storico può restare bloccata in **`in_invio`** senza che nulla la chiuda. Verifica se
  succede e se resta appesa nell'elenco.
- ☐ **L4** — Stato della campagna in corso: durante un invio lungo la riga è visibile come `in_invio`.
- ☐ **L5** — Conteggio del dialogo di conferma **stantio**: apri `/newsletter` in una sessione,
  aggiungi una soppressione da un'altra, poi invia dalla prima → il dialogo annuncia il vecchio
  numero mentre l'invio parte su quello aggiornato. Verifica quanto è fastidioso in pratica.
- ☐ **L6** — Traduzione fallita su **una sola** lingua (es. chiave Claude revocata a metà) → quella
  lingua degrada a IT, le altre restano tradotte, snackbar con l'avviso.

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
