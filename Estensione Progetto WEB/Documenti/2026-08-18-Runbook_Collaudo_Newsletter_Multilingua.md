# Runbook — Collaudo newsletter multilingua

> **USO INTERNO.** Sequenza operativa passo-passo per il collaudo del 2026-08-18 e successivi.
> Complementa `2026-07-09-Piano_Test_Estensione_Web.md` (§8, §44-47), che resta il piano di
> riferimento: qui ci sono gli stessi controlli in forma eseguibile — da dove parti, cosa fai,
> cosa deve succedere, e cosa guardare se non succede.
>
> **Creato:** 2026-08-18 · **Copre:** invio di prova multilingua, obsolescenza delle traduzioni,
> anteprima, riquadro tour nelle lingue, invio reale a 6 destinatari, casi limite.

---

## Stato di partenza

Verificato sul DB locale il 2026-08-18 in tarda serata. Se non corrisponde, allinea prima di partire.

| Cosa | Valore |
|---|---|
| Newsletter di lavoro | id **32** — «TEST 18 Ago 2026 (notte piena e buia)», **bozza** |
| Blocchi | 5: intestazione · **tour** (CAPODANNO 2026-2027 IN SARDEGNA) · pulsante · testo · footer |
| Traduzioni | EN/DE/ES/FR tutte a **6/6**, nessuna obsoleta |
| Destinatari azienda 2 | **6** — IT Antonio · EN Anna · EN Adriano (*entrambi*) · DE `+de@` · ES `offadventure@` · FR `+fr@` |
| Applicazione | build del 18/08: tendina **Lingua** sull'invio di prova, tooltip sul bottone di traduzione |
| Database | `SqlScripts/537` deployato (obsolescenza dell'oggetto) |

Verifica rapida da terminale:

```bash
docker exec -i postgres_db psql -U postgres -d gestione_viaggi \
  -c "SELECT * FROM fn_web_newsletter_traduzioni_stato(32::bigint,2::integer);" \
  -c "SELECT email, lingua, fonte FROM fn_web_destinatari_newsletter(2) ORDER BY lingua;"
```

**Il blocco tour è a cavallo d'anno** (Capodanno 2026-2027): serve al gruppo E, non sostituirlo.

---

## A — Prerequisiti

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| A1 | App chiusa | Avvia l'applicazione | Parte senza schermo nero; nessun errore all'avvio |
| A2 | App aperta | **VPN spenta** (verifica nella barra di sistema) | Necessario da qui in poi: il server di posta rifiuta i range VPN sulle porte 465/587 e `Connect` va in timeout |
| A3 | App aperta | Menu **Estensione Web → Newsletter**, tab **Newsletter** | La pagina si apre; la status bar cita `web_newsletter_invii` |
| A4 | Pagina aperta | Guarda il chip **Destinatari** | Dice **6**. Se dice altro, fermati: i gruppi F e G contano su quel numero |
| A5 | Pagina aperta | Clicca il chip Destinatari | Elenco di **6** righe — Cognome, Nome, Mail, Telefono, Lingua — ordinate per cognome, non modificabili. Cinque lingue diverse. `+de@` ha il telefono vuoto (—): è solo un iscritto |

---

## B — Invio di prova multilingua *(§44.4 — la funzione nuova)*

Manda posta vera, ma solo a te. Un invio per riga.

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| B1 | Newsletter 32 aperta in composizione | Nel riquadro in fondo: indirizzo `visconti.adriano@gmail.com`, tendina **Lingua** = `DE`, premi **Invia prova** | Snackbar verde **«Prova inviata in DE»** |
| B2 | Mail ricevuta | Aprila | **Oggetto in tedesco** e testi dei blocchi in tedesco. **Nessun prefisso `[TEST]`**: è il rendering reale |
| B3 | Stessa pagina | Ripeti con **Lingua = `IT`** | Tutto in italiano, oggetto compreso. È il default: chi non usa le traduzioni non deve accorgersi della tendina |
| B4 | Stessa pagina | Ripeti con **Lingua = `ES`** | Oggetto e testi in spagnolo |
| B5 | Stessa pagina | Ripeti con una lingua **non tradotta** — se tutte sono a 6/6, salta a C e torna qui dopo aver aggiunto un blocco nuovo non tradotto | Parte lo stesso: i campi non tradotti restano **in italiano**, mentre disiscrizione ed etichette dei pulsanti sono nella lingua scelta |

> **Se B1 fallisce con un errore di posta:** non è la lingua. Controlla VPN spenta e la configurazione
> SMTP dell'azienda 2. Se il messaggio parla di **sito web mancante**, è il blocco voluto: senza
> `sito_web` il link di disiscrizione sarebbe rotto e l'invio non parte, né di prova né reale.

---

## C — Obsolescenza e fallback per campo *(§44.5, §44.5-bis, §44.5-ter — verifica di `537`)*

Il cuore del collaudo: quando l'italiano cambia, la traduzione precedente non deve più partire.

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| C1 | Newsletter 32, traduzioni a 6/6 | Apri il blocco **tour**, cambia il **titolo** (es. aggiungi « — RIVISTO»), salva. **Resta nella newsletter** | Nel riquadro **Lingue**: avviso arancione «testi cambiati dopo la traduzione», contatori da `6/6` a **`5/6`**, bottone **riacceso**. Tutto **senza uscire e rientrare** |
| C2 | Stato di C1 | *(44.5-bis)* Cambia l'**oggetto** nel campo in alto e premi **Salva oggetto** | Stessa reazione: i contatori calano ancora. L'oggetto è un testo tradotto come gli altri |
| C3 | Stato di C2, **senza ritradurre** | *(44.5-ter)* **Invia prova** in `DE` | **Oggetto in italiano** e **titolo del tour in italiano**; tutto il resto ancora in tedesco. È il fallback **per campo**: cade solo ciò che è cambiato, non l'intera mail. Mai la vecchia traduzione |
| C4 | Stato di C3 | Clicca **Traduci quello che manca**. Lo snackbar dura 4 secondi, ma **non serve più prenderlo al volo** | Con 2 campi obsoleti su 6 e quattro lingue: **«Tradotti 8 testi, 16 già a posto.»** Il numero dei saltati prova che non ha ritradotto ciò che era valido |
| C4-bis | Subito dopo C4 | Guarda in fondo al riquadro **Lingue** | C'è la riga con l'orario: **«07:41 — Tradotti 8 testi, 16 già a posto.»** Resta lì finché non cambi newsletter. È la correzione al fatto che il 19/08 il messaggio non è stato visto affatto |
| C4-ter | Se anche la riga non compare | `grep -i traduzione ~/Library/Logs/gestioneviaggi-$(date +%F).log` | La stessa frase nel registro. Se non c'è nemmeno lì, l'operazione non è arrivata in fondo: è un difetto vero e ora c'è la traccia per dimostrarlo |
| C5 | Traduzione finita | Guarda il riquadro Lingue | Avviso sparito, contatori pieni, bottone **spento**; passandoci sopra: «Tutte le lingue sono a posto: non c'è niente da tradurre» |
| C6 | Traduzione finita | **Invia prova** in `DE` | Ora l'oggetto e il titolo arrivano tradotti, con il testo nuovo |

> **Se C1 non mostra niente:** è la regressione corretta oggi. Prima di dirlo, controlla a DB —
> `SELECT * FROM fn_web_newsletter_traduzioni_stato(32::bigint,2::integer);` — perché distingue le
> due cause: `obsoleti > 0` significa che il difetto è nell'interfaccia che non rilegge;
> `obsoleti = 0` significa che è il database a non marcare.

---

## D — Anteprima nelle cinque lingue *(§46 — nessuna mail)*

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| D1 | Newsletter 32 in composizione | Premi **Anteprima** | Si apre con le **cinque lingue** in cima e **IT** selezionato |
| D2 | Anteprima aperta | Guarda le etichette delle lingue | Ognuna riporta la copertura (`DE 18/18`, `FR 0/18`): non si può credere tradotta una lingua che non lo è |
| D3 | Anteprima aperta | Clicca **DE** | Ricompone in tedesco; compare il velo d'attesa finché le immagini non sono pronte |
| D4 | Anteprima in DE, **copertura piena** | Guarda sotto la riga dei chip | **Nessun avviso.** Prima compariva sempre, anche quando non c'era niente da segnalare |
| D4-bis | Anteprima in una lingua **incompleta** (vedi la premessa di D5) | Guarda sotto la riga dei chip | Avviso arancione vero: **«N testi non ancora tradotti in DE: restano in italiano dentro una mail per il resto in DE»**, con il numero giusto |
| D5 | **Premessa: serve una lingua incompleta.** Se sono tutte piene, aggiungi un **blocco di testo nuovo con del contenuto** e **non tradurlo**: i contatori scendono a `6/7` | In anteprima clicca quella lingua | Si vede tutta nella lingua scelta **tranne il blocco nuovo**, che resta in italiano — e disiscrizione ed etichette dei pulsanti sono comunque tradotte |
| D6 | Anteprima aperta | Clicca **ripetutamente** fra due lingue | Nessun accavallamento: mentre ricompone i pulsanti sono disabilitati |
| D7 | Anteprima aperta | Torna su **IT** | Ricompone l'originale |

---

## E — Riquadro tour nelle lingue *(§47 — usa il blocco Capodanno)*

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| E1 | Anteprima, blocco tour agganciato alla partenza | Guarda il **periodo** in **DE** | In tedesco: «Vom … bis …», non «Dal … al …» |
| E2 | Anteprima | Stessa lettura in **EN**, **ES**, **FR** | «From … to …» · «Del … al … de …» · «Du … au …» |
| E3 | Anteprima | *(47.3)* Il blocco è **Capodanno 2026-2027**: guarda gli anni | Compaiono **entrambi gli anni**, in tutte le lingue |
| E4 | Una traduzione in corso *(o il terminale)* | *(44.9)* Guarda le righe di avanzamento, che nominano ogni campo: «Blocco 2 — Titolo (EN)», «Blocco 3 — Testo del pulsante (DE)»… | Il **periodo non compare mai**: è generato dalla partenza. ⚠️ Il riquadro Lingue **non elenca i campi** — mostra solo i chip per lingua: non cercarlo lì. Verifica equivalente a DB: i traducibili sono **6** e il `sottotitolo` del blocco tour (il periodo) non è fra questi |
| E5 | Anteprima in **IT** | Guarda il periodo | Resta quello memorizzato: una correzione fatta a mano non viene sovrascritta |

---

## F — Invio reale *(§8-F, §45 — una sessione sola, VPN spenta)*

Da qui parte posta vera **anche verso Antonio** (`info@sardegnafuoritraccia.it`). Fallo in un colpo solo.

> ⚠️ **Premessa obbligatoria (scoperta al collaudo del 19/08).** La newsletter 32 ha un blocco tour
> agganciato alla partenza 1898, e **la sua scheda web è in bozza**: l'invio viene rifiutato con
> «Blocco in posizione 10 (…): la scheda web di quel tour non è pubblicata». È il test **§38.4** che
> funziona, non un difetto — un pulsante che porta a una pagina non pubblicata non deve partire.
> Nell'azienda 2 **nessuna scheda è pubblicata**, quindi prima di F serve una di queste due:
> - **pubblica la scheda** (Viaggi → viaggio → contenuti web → edizione 28/12/2026 → Pubblicazione →
>   Stato = *Pubblicato* → salva). Il controllo scatta al **salvataggio**: tutti i sotto-tab devono
>   essere *Completo*, tipicamente manca la foto di copertina;
> - **togli il collegamento dal blocco tour** (o elimina il blocco): la Fase F verifica lingue e
>   destinatari, non i link — ma allora il gruppo E va fatto prima.

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| F0 | **Una lingua tradotta a metà**: il blocco non tradotto della premessa di D5, ancora lì (`DE 6/7`) | Premi **Invia a tutti** | **Errore rosso e nessun invio:** «Traduzioni incomplete (DE 6/7, …): completa le traduzioni prima di inviare, oppure togli dai destinatari le lingue non pronte». Poi guarda lo **Storico**: nessuna riga, nemmeno appesa in `in_invio` |
| F0-ter | **Una lingua a zero.** Crea una bozza nuova con un blocco di testo e **non tradurla affatto** (`EN 0/1`, `DE 0/1`…) | Premi **Invia a tutti** | **Parte.** Le mail escono tutte in italiano: coerente e comprensibile. Il blocco riguarda solo il miscuglio, non l'italiano — altrimenti un'azienda senza chiave Claude non potrebbe spedire mai |
| F0-bis | Stato di F0 | Traduci quello che manca **oppure** elimina il blocco non tradotto | I contatori tornano pieni e l'invio ridiventa possibile |
| F1 | Newsletter 32, traduzioni complete | Premi **Invia a tutti (6)**, poi **Annulla** | Conferma «Inviare la newsletter a **6** destinatari?»; annullando **non parte nulla** e lo Storico resta invariato |
| F2 | Stessa pagina | **Invia a tutti** → conferma | Snackbar **verde «Inviate 6/6»**, senza errori |
| F3 | Durante l'invio | Guarda il riquadro | Prima «Preparazione dell'invio (traduzione dei testi)…», poi **«Invio in corso: N di 6»** con la barra che avanza. A fine invio sparisce tutto |
| F4 | Dopo l'invio | Conta le mail | **3 nella tua inbox**: `EN`, `DE` (`+de@`), `FR` (`+fr@`). **1** su `offadventure@gmail.com` in `ES`. **1** ad Antonio in `IT`. Cinque leggibili su sei destinatari: `visconti.adriano@` è contato **una volta sola** |
| F5 | Mail ricevute | Confronta i cinque oggetti | Cinque lingue diverse. Se due sono identici, la risoluzione della lingua per destinatario non ha funzionato |
| F6 | Tab **Storico** | Guarda la riga | Stato **`inviata`** (chip verde), **Data invio valorizzata**, **Destinatari = 6**, canale `smtp` |
| F7 | Tab Storico | Premi **Log** | Una riga per destinatario con email, **lingua** e stato consegna. Le lingue devono essere **cinque diverse**, non «IT» per tutti |
| F8 | Terminale | `SELECT lingua, stato_consegna, count(*) FROM web_newsletter_invii_destinatari WHERE invio_id_fk = 32 GROUP BY 1,2 ORDER BY 1;` | Cinque lingue, tutte con `stato_consegna` riuscito. Deve raccontare la stessa cosa del Log (F7) |
| F9 | Terminale | `SELECT lingua, destinatari, oggetto FROM web_newsletter_invii_corpi WHERE invio_id_fk = 32 ORDER BY lingua;` | **5 righe** — `EN` con **2** destinatari, le altre con **1**; l'oggetto archiviato è quello nella lingua della riga |
| F10 | Mail tedesca aperta | Confronta il corpo con la riga `DE` dell'archivio | Stesso testo. Cambia **solo** il link di disiscrizione, che nell'archivio è generico |
| F11 | Mail ricevuta | Guarda in fondo | «Non desideri più ricevere la nostra newsletter? **Disiscriviti**», con link a `<sito_web>/unsubscribe?email=…&sig=…` ed email codificata |
| F12 | Due mail della stessa email da aziende diverse | Confronta i `sig` | Devono essere **diversi**. Se identici, `token_iscrizione` è NULL e la firma gira a chiave vuota |
| F13 | Registro consumo Claude | Apri il registro | Una causale per lingua: «Newsletter (EN)», «(DE)», **«(ES)»**, **«(FR)»** |
| F14 | Newsletter appena spedita | Riaprila | Riquadro **Lingue in sola lettura**; il tooltip dice «La newsletter è già partita: non si ritraduce ciò che è stato spedito» |

---

## G — Casi limite *(§L — dopo F, perché sporcano lo stato)*

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| G1 | Nuova bozza | **VPN accesa** apposta → *Invia a tutti* | «Inviate 0/6, 6 errori», log con tutti `errore`. ⚠️ **Guarda lo stato nello Storico:** se risulta `inviata`, è il difetto noto — lo stato è messo a fine ciclo senza guardare gli esiti. Va segnalato, serve uno script |
| G2 | Azienda 2 | Togli il consenso ai clienti **e** disattiva i due iscritti: `UPDATE web_newsletter_iscritti SET stato='disiscritto' WHERE azienda_id=2;` → *Invia a tutti* | Snackbar rossa «Errore invio: Nessun destinatario…» e **nessuna riga** nello Storico. Poi **ripristina** |
| G3 | Azienda senza `sito_web` | Prova *Invia prova* e *Invia a tutti* | Entrambi **bloccati** con «Questa azienda non ha un sito web…». Lo Storico deve restare **pulito**: il blocco scatta prima che la riga venga creata |
| G4 | Soppressioni | Aggiungi due volte lo stesso indirizzo | «Questo indirizzo è già soppresso per questa azienda.» Se rivedi il messaggio grezzo con `web_newsletter_soppressioni`, la voce nel dizionario dei vincoli è andata persa |

---

## Rilievi aperti dal collaudo del 18-19/08

Emersi eseguendo i gruppi C e D. Non sono difetti di funzionamento — le cose fanno quello che il
codice dice — ma tre hanno la stessa radice: **informazioni che contano affidate a un messaggio che
svanisce o a una didascalia grigia.**

| # | Rilievo | Stato |
|---|---|---|
| R1 | **Mail mista IT/lingua**: il fallback per campo poteva far arrivare a un tedesco il 90% in tedesco e una frase in italiano | **Chiuso il 19/08 — decisione del committente: non si spedisce affatto.** Vedi R2 |
| R2 | L'avviso «Traduzioni incomplete» era uno snackbar da quattro secondi e l'invio partiva comunque | **Fatto:** invio **bloccato**, in pagina e nel motore (`LingueIncompleteAsync`, guardia autoritativa come per il sito web). Blocca solo le lingue **tradotte a metà** e **con destinatari veri**: una lingua a zero parte tutta in italiano |
| R3 | L'esito della traduzione viveva solo in uno snackbar che svaniva | **Fatto:** resta scritto nel riquadro Lingue con l'orario, e finisce nel registro dell'app |
| R4 | La frase dell'anteprima compariva sempre, anche a copertura piena, come didascalia in coda ai chip | **Fatto:** ora è un avviso vero, **solo** a lingua incompleta, e dice quanti testi mancano |
| R5 | `SendCampaignAsync` (motore testuale con fallback IT) senza più chiamanti | **Rimosso il 19/08**, con `BuildBodiesAsync`, `BuildHtml`, `UnsubFooter`, `SendTestAsync`, quattro dipendenze rimaste orfane e il flag `TradottoIncompleto`: 123 righe. Il §8-G del piano va riscritto |
| R6 | **Conseguenza del blocco:** un'azienda **senza chiave Claude** non poteva più spedire a destinatari non italiani | **Chiuso il 19/08:** blocca solo la mezza traduzione. A zero traduzioni si spedisce in italiano, quindi l'azienda 6 torna a funzionare |
| R7 | **«Chiudi» che non chiude** nella scheda Contenuti Web del viaggio: il pulsante del footer chiamava sempre `GoToContenuti()`, che porta alla sotto-scheda 0. Stando **già** sui Contenuti metteva 0 a 0 e non faceva niente. La X in alto era invece scritta bene | **Corretto il 19/08:** il pulsante usa la stessa logica della X e cambia nome — «Torna ai contenuti» da un sotto-tab, «Chiudi» dai Contenuti. Da collaudare: vedi H1-H3 |

---

## Se qualcosa fallisce

Prima di aprire il codice, raccogli questi tre elementi: separano quasi sempre le cause.

1. **Stato a DB** — `fn_web_newsletter_traduzioni_stato(32::bigint, 2::integer)`: distingue «il database non marca» da «l'interfaccia non rilegge».
2. **Ora esatta** del sintomo — serve a incrociare `~/Library/Logs/gestioneviaggi-<data>.log` con il registro di sistema.
3. **Cosa dice lo snackbar**, parola per parola: i messaggi sono distinti apposta, e quale compare identifica il percorso di codice.

---

## H — La via d'uscita dai contenuti web *(corretta il 19/08)*

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| H1 | Viaggio aperto → **Contenuti Web** → sotto-scheda **Contenuti** | Guarda il pulsante in basso e premilo | Si chiama **«Chiudi»** e **chiude davvero** il dialog del viaggio. Era questo il difetto: non faceva niente |
| H2 | Viaggio aperto → Contenuti Web → un **sotto-tab** (Galleria, Itinerario, Mappa, Traduzioni) | Guarda il pulsante in basso e premilo | Si chiama **«Torna ai contenuti»** e riporta alla sotto-scheda Contenuti, restando nel viaggio |
| H3 | Come H1 ma con **modifiche non salvate** | Premi Chiudi | Chiede prima cosa fare delle modifiche — salva o scarta — esattamente come la X in alto |

---

# Parte seconda — il §8 che resta *(scritta il 2026-08-19)*

La parte multilingua è chiusa. Restano i controlli che il primo runbook non toccava: gating della
funzione, validazioni di composizione, i casi dei destinatari, template e logo, silos.
**Il percorso SuperAdmin è escluso** — vedi la nota in testa al gruppo I.
Nessuno di questi manda posta vera **tranne L3**, quindi si possono fare a VPN accesa.

## Preparazione — cosa serve avere sottomano

| # | Cosa serve | Come ottenerlo |
|---|---|---|
| P1 | Una **credenziale utente dell'azienda 6** (o di un'altra azienda con dati propri) | Serve per il gruppo M: i silos si provano entrando come utente, non dal selettore SuperAdmin |
| P2 | Un'azienda con la newsletter **disattivata** | Anagrafica Aziende → tab **Funzioni Web** → togli `newsletter` a un'azienda che non sia la 2 |
| P3 | Un cliente **senza email** e con consenso | Anagrafica clienti: creane uno o svuota l'email a uno esistente (annota quale, va ripristinato) |
| P4 | Un'azienda **senza logo** | L'azienda 6 va bene se non ne ha uno; altrimenti togli il logo temporaneamente |
| P5 | L'azienda **6** con i suoi 2 destinatari | È il termine di paragone per i silos: ha clienti ma nessun dato web |

---

## I — Gating della funzione newsletter *(§8-A3, A6-A7)*

> **Il percorso SuperAdmin è escluso dal collaudo (decisione del 2026-08-19).** Il SuperAdmin è
> Adriano, lo usa di rado e quasi solo per le tabelle comuni a tutte le aziende; l'assistenza si fa
> **entrando con le credenziali dell'utente** o prendendo il suo computer da remoto. Il selettore
> azienda vive quindi solo sul computer dello sviluppatore: un difetto lì costa poco, lo stesso
> difetto sul percorso dell'utente costa un cliente. Restano fuori: la comparsa del selettore, il
> cambio azienda e i residui fra un'azienda e l'altra (§8-A4, A5, A8, K3).

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| I1 | Utente **normale** su `/newsletter` | Guarda in cima alla pagina | **Nessun selettore azienda**: vede solo la sua, e non deve nemmeno sapere che esistono le altre |
| I2 | Utente dell'azienda **P2** (newsletter disattivata) | Apri il menu | La voce **Estensione Web → Newsletter sparisce** |
| I3 | Stesso utente | Forza l'indirizzo `/newsletter` | La pagina dice **«non attiva»** e non interroga niente: la guardia è nella pagina, non solo nel menu |
| I4 | Riattiva `newsletter` su P2 | Rientra | Menu e pagina tornano disponibili |

## J — Validazioni di composizione *(§8-B — nessuna mail parte)*

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| J1 | Newsletter in bozza, **oggetto vuoto** | *Invia prova* | Avviso «Inserisci l'oggetto.» |
| J2 | Corpo Quill **vuoto** | *Invia prova* | Avviso «Il corpo è vuoto.» |
| J3 | Corpo con **solo un a-capo** (`<p><br></p>`) | *Invia prova* | Conta come vuoto: stesso avviso di J2 |
| J4 | Oggetto valido, **email di prova vuota** | *Invia prova* | Avviso sull'indirizzo mancante |
| J5 | Oggetto con **spazi in testa e in coda** | Salva e guarda cosa arriva | L'oggetto viene ripulito prima dell'invio |
| J6 | Invio in corso | **Doppio clic** sui pulsanti | Restano disabilitati: niente doppio invio |

## K — Destinatari: i casi che mancavano *(§8-C3, C4, D7)*

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| K1 | Cliente **P3, senza email**, con consenso | Apri `/newsletter` e guarda il conteggio | **Non compare**: senza indirizzo non è un destinatario. Né nel numero né nell'elenco |
| K2 | Un cliente con consenso | Togli il consenso in anagrafica → riapri `/newsletter` | Il conteggio **cala di uno**. Rimettilo → risale. *(Gli iscritti non dipendono dal consenso cliente)* |
| K3 | Conteggio a 6 | Sopprimi uno dei sei indirizzi, poi apri l'**elenco destinatari** | Il soppresso **non c'è più nell'elenco**, non solo nel numero: conteggio ed elenco devono raccontare la stessa cosa |
| K4 | Stato di K3 | Togli la soppressione | Torna tutto come prima |

## L — Template, logo e prova fallita *(§8-H1, H2, E6)*

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| L1 | Una mail ricevuta dai giri precedenti | Guardala tutta | Usa `CompanyEmailTemplate`: **logo, ragione sociale, sito e telefono** nel footer |
| L2 | Azienda **P4, senza logo** | *Invia a tutti* | Prima di spedire compare il dialogo **«Logo mancante»**: *Invia comunque* prosegue, *Annulla* interrompe **senza spedire niente** |
| L3 | SMTP volutamente sbagliato *(cambia la porta e salva)* | *Invia prova* | Snackbar rossa **«Invio di prova fallito (verifica la configurazione email).»** Poi **ripristina la configurazione** |

## M — Silos multi-tenant *(§8-I4, J1, J2, K1, K2)*

> Si collaudano **accedendo come utente di ciascuna azienda**, non passando dal selettore del
> SuperAdmin: è così che il software viene usato davvero, ed è lì che un travaso di dati farebbe
> danno. Serve una credenziale utente dell'azienda 6 (o di un'altra azienda con dati propri).

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| M1 | Utente dell'azienda 2, tab **Iscritti** | Guardalo | I **2 iscritti** con email, nome, lingua, stato, consenso |
| M2 | Stesso tab | Cerca un pulsante di modifica o inserimento | **Non c'è**: l'elenco è in sola lettura |
| M3 | **Esci e rientra come utente dell'azienda 6** | Apri Storico, Iscritti, Soppressioni | **Niente dell'azienda 2**: né campagne, né iscritti, né soppressioni. È la verifica che conta |
| M4 | Ancora come utente dell'azienda 6 | Cerca il **Log** di un invio dell'azienda 2 | Non è raggiungibile in nessun modo dall'interfaccia |
| M5 | Un'email soppressa sull'azienda 2, presente anche fra i clienti della 6 | Guarda i destinatari dell'azienda 6 | **Non è filtrata**: le soppressioni non attraversano le aziende — il vincolo unico è su `(azienda_id, email)` |

## N — L'ultimo caso limite *(§8-L5)*

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| N1 | `/newsletter` aperta con il conteggio a video | Da **un'altra sessione** (o via SQL) aggiungi una soppressione, poi torna e premi *Invia a tutti* | ⚠️ Il dialogo annuncia il **vecchio numero**: è il difetto atteso. Verifica poi **quanti ne parte davvero** — il motore rilegge i destinatari, quindi il numero reale dovrebbe essere quello aggiornato |

> **§8-L6 non è più eseguibile.** Diceva: «traduzione fallita su una sola lingua → quella degrada a
> IT, le altre restano tradotte». Descriveva il motore che traduceva **al momento dell'invio**
> (`BuildBodiesAsync`), rimosso il 2026-08-19. Oggi le traduzioni si fanno prima, e una lingua
> tradotta a metà **blocca l'invio** invece di degradare (§44.7). Stessa sorte del §8-G.
