# Piano di test — Il sito di iscrizione (Flask), da cima a fondo

**Scritto il 2026-09-07**, dopo l'unificazione fra gestionale e sito. È il collaudo che
Adriano ha chiesto: «farò un test completo, altrimenti il rischio è che io continui a trovare
errori come nei giorni precedenti, perché le correzioni si fanno tutte a pezzettini».

⚠️ **Segnala solo ciò che non funziona.** Dove serve un dato da cercare, chiedi.

Riferimenti: §2.8 della Checklist Go-Live PROD (il sito era un **prerequisito** di go-live),
`Estensione Progetto WEB/Documenti/2026-09-05-Analisi_Scelta_Camere_Step5.md`,
`Documents/2026-08-20-Analisi_Validazioni_e_CRUD_AnaClienti.md`.

Il piano del gestionale (`2026-09-06-Piano_Test_Sistemazioni.md`) è **chiuso**: da lì in poi
vale come non-regressione. Questo è il suo gemello sul sito.

### Stato

| Gruppo | Esito |
|---|---|
| **A** — L'ambiente prima di cominciare | ☐ |
| **B** — Passo 1: viaggio, data, email | ☐ |
| **C** — Passo 2: l'anagrafica di chi guida | ☐ |
| **D** — Il consenso all'invio di email | ☐ |
| **E** — Passo 3: i passeggeri | ☐ |
| **F** — Passo 4: mezzo, cane, note | ☐ |
| **G** — Passo 5: le sistemazioni | ☐ |
| **H** — La conferma: cosa resta scritto | ☐ |
| **I** — Che le due strade dicano la stessa cosa | ☐ |

---

## Prima di cominciare

Il database locale deve avere gli script fino al **627** applicati.

⛔️ **`MAIL_DIROTTA_A` deve essere impostata.** Il sito manda posta vera. Verifica prima di
qualsiasi prova che l'indirizzo di dirottamento ci sia, altrimenti le conferme partono verso
gli indirizzi veri dei clienti di prova.

⚠️ **`GV_SECRET_KEY` deve essere nell'ambiente del processo Flask**, altrimenti la
configurazione SMTP non si decifra e **non parte nessuna conferma** — con l'aria di un difetto,
mentre è una chiave mancante. All'avvio deve comparire nel registro
`Flask-Mail inizializzato da DB (Server=…, Porta=…, Security=…)`.

⚠️ **Dal 2026-09-07 il passo 5 non contiene più regole sulle camere**: le chiede al database,
le stesse che applica il gestionale. Se una prova del gruppo G fallisce, il difetto è quasi
certamente nella funzione di database — quindi si vedrà **anche** nel gestionale. Provalo lì
prima di segnalarlo come difetto del sito: la risposta cambia.

**Un cliente nuovo per ogni giro.** Molte prove dipendono da «è la prima volta che questa
persona si iscrive». Riusando lo stesso cliente il secondo giro non prova quello che credi.

---

## A — L'ambiente prima di cominciare

| ID | Cosa fare | Cosa deve succedere | ☐ |
|---|---|---|---|
| A1 | Aprire la pagina iniziale | Il sito si apre senza errori in console | ☐ |
| A2 | Guardare il piè di pagina | Dice **v4.0.0** — non 3.1 | ☐ |
| A3 | Leggere il registro all'avvio | Compare `Flask-Mail inizializzato da DB`, non `GV_SECRET_KEY non impostata` | ☐ |
| A4 | Verificare `MAIL_DIROTTA_A` | È impostata su un indirizzo tuo | ☐ |

---

## B — Passo 1: viaggio, data, email

| ID | Cosa fare | Cosa deve succedere | ☐ |
|---|---|---|---|
| B1 | Aprire l'elenco dei viaggi | Compaiono solo i viaggi con partenze future e pubblicabili | ☐ |
| B2 | Scegliere un viaggio | Le date proposte sono solo quelle di **quel** viaggio | ☐ |
| B3 | Scegliere una data al completo (se ce n'è una) | Non è scegliibile, o lo dice chiaramente | ☐ |
| B4 | Inserire un'email malformata (`pippo@`, `pippo`, uno spazio in mezzo) | Rifiutata | ☐ |
| B5 | Inserire `mailto:qualcuno@dominio.it` | ⚠️ **Rifiutata.** È il caso vero di PERINI ELENA: un collegamento incollato al posto dell'indirizzo, rimasto due anni in anagrafica | ☐ |
| B6 | Inserire l'email di un cliente **già esistente** | Riconosce la persona e ne propone i dati | ☐ |
| B7 | Inserire l'email di un cliente nuovo | Prosegue e apre l'anagrafica vuota | ☐ |
| B8 | Tornare indietro al passo 1 e cambiare viaggio | I dati dei passi successivi si azzerano di conseguenza — non restano quelli del viaggio precedente | ☐ |

---

## C — Passo 2: l'anagrafica di chi guida

È il gruppo più importante: qui il sito e il gestionale scrivono la **stessa** tabella.

| ID | Cosa fare | Cosa deve succedere | ☐ |
|---|---|---|---|
| C1 | Lasciare vuoto un campo obbligatorio | Rifiutato, e il messaggio dice **quale** campo | ☐ |
| C2 | Scrivere nome e cognome in minuscolo | Diventano maiuscoli, come nel gestionale | ☐ |
| C3 | Codice fiscale palesemente errato (lunghezza sbagliata, carattere di controllo errato) | Rifiutato | ☐ |
| C4 | Codice fiscale **formalmente valido ma incoerente** con nome/data/sesso indicati | Segnalato | ☐ |
| C5 | Codice fiscale di una persona **già in anagrafica**, con email diversa | ⚠️ Deve accorgersene: non deve nascere un doppione. È il caso MAIORCA MARIA | ☐ |
| C6 | Scegliere `SIG.` con nome femminile (o viceversa) | ⚠️ Compare l'**avviso** nome/sesso — che avvisa, non blocca (§2.8.2) | ☐ |
| C7 | Salvare comunque dopo l'avviso di C6 | Passa, e a database vince il **sesso**, non il titolo | ☐ |
| C8 | Cercare un comune di nascita | La ricerca trova, e selezionando si compilano provincia e regione | ☐ |
| C9 | Comune estero / nato all'estero | Gestito senza errori | ☐ |
| C10 | Data di nascita nel futuro | Rifiutata | ☐ |
| C11 | Data di nascita che darebbe meno di 18 anni | Rifiutata o segnalata secondo la regola del gestionale | ☐ |
| C12 | Lasciare vuoto il documento | ⚠️ **Rifiutato**: il documento serve per legge a **ogni** occupante della stanza, pilota o passeggero | ☐ |
| C13 | Documento scaduto, o con scadenza prima del rientro dal viaggio | Segnalato | ☐ |
| C14 | Prefisso telefonico e numero | Il prefisso si sceglie da elenco; il numero accetta solo cifre | ☐ |
| C15 | Salvare tutto corretto | Salva, e il messaggio non è generico: ⚠️ se compare «Un valore inserito non rispetta le regole di validità» senza dire quale, **è un difetto** | ☐ |

---

## D — Il consenso all'invio di email

⛔️ **È il punto che non si recupera dopo** (§2.8.1): un consenso mancante non si sistema con un
riempimento a posteriori, perché nessuno può dire quando e come è stato dato.

| ID | Cosa fare | Cosa deve succedere | ☐ |
|---|---|---|---|
| D1 | Iscrivere un cliente **nuovo** senza spuntare il consenso | Si iscrive lo stesso. A database: `consenso_marketing = false`, con **data e fonte valorizzate** — anche il no si registra | ☐ |
| D2 | Iscrivere un cliente nuovo **spuntando** il consenso | `consenso_marketing = true`, più data e fonte | ☐ |
| D3 | Riprendere un cliente che aveva **già** risposto (sì o no) | ⚠️ **Non gli si richiede**: si chiede solo a chi non ha mai risposto | ☐ |
| D4 | Riprendere un cliente che non ha **mai** risposto | Gli viene chiesto | ☐ |
| D5 | Dare il consenso, poi **cambiare l'indirizzo email** nello stesso modulo | ⚠️ Il consenso valeva per l'indirizzo di prima: deve riferirsi al nuovo, o essere richiesto di nuovo | ☐ |
| D6 | Guardare la fonte scritta a database | Dice che è arrivato dal **sito**, non dal gestionale | ☐ |

---

## E — Passo 3: i passeggeri

| ID | Cosa fare | Cosa deve succedere | ☐ |
|---|---|---|---|
| E1 | Zero passeggeri | Si prosegue | ☐ |
| E2 | Un passeggero nuovo | Chiede la sua anagrafica, con gli stessi controlli del gruppo C — ⚠️ **documento compreso** | ☐ |
| E3 | Un passeggero con l'email **del pilota** | Rifiutato o gestito: non devono diventare la stessa persona | ☐ |
| E4 | Un passeggero già cliente | Riconosciuto, dati proposti | ☐ |
| E5 | Due passeggeri con la stessa email fra loro | Rifiutato | ☐ |
| E6 | Aggiungere passeggeri fino a superare la capienza del mezzo | Segnalato | ☐ |
| E7 | Aggiungere passeggeri fino a **7 persone in tutto** | ⚠️ Il limite di 6 per sistemazione è strutturale: il sito deve dirlo qui, non farlo scoprire al passo 5 | ☐ |
| E8 | Tornare indietro e ridurre il numero di passeggeri | Le anagrafiche in più spariscono, e non restano assegnazioni orfane al passo 5 | ☐ |

---

## F — Passo 4: mezzo, cane, note

| ID | Cosa fare | Cosa deve succedere | ☐ |
|---|---|---|---|
| F1 | Scegliere tipo mezzo, poi mezzo, poi modello | Ogni elenco dipende dal precedente | ☐ |
| F2 | Cambiare il tipo di mezzo dopo aver scelto il modello | Il modello si azzera — non resta quello di prima | ☐ |
| F3 | Dichiarare un cane su un viaggio che non li ammette | Segnalato | ☐ |
| F4 | Note libere con apostrofi e accenti (`l'auto è così`) | Salvate come scritte, senza rompere niente | ☐ |
| F5 | Note molto lunghe | Troncate con avviso, o rifiutate — non salvate a metà in silenzio | ☐ |

---

## G — Passo 5: le sistemazioni

⚠️ Riscritto il 2026-09-07: da 890 righe a 401, e **senza più regole proprie**. Le tre domande
sono: che forma (una camera sola o più d'una), chi con chi, e di che tipo — e le ultime due
compaiono **solo quando servono davvero**.

| ID | Caso | Cosa deve succedere | ☐ |
|---|---|---|---|
| G1 | Una persona sola, viaggio in albergo | Nessuna domanda inutile: propone la **singola**. ⚠️ Non deve proporre per prima la singola disabili | ☐ |
| G2 | Una persona sola, viaggio **solo tenda** | Propone la tenda singola — non l'albergo | ☐ |
| G3 | Due persone, stesso mezzo | ⚠️ **Devono poter scegliere come dormire**: matrimoniale o due letti. Se il sito decide da solo, è un difetto | ☐ |
| G4 | Due persone che vogliono due camere separate | Possibile, e ognuna diventa una singola | ☐ |
| G5 | Tre persone | Le combinazioni proposte sono solo quelle che esistono davvero per quel viaggio | ☐ |
| G6 | Quattro persone | Idem, e nessuna combinazione lascia qualcuno senza posto | ☐ |
| G7 | Viaggio in tenda con più persone | Propone solo tende, mai camere d'albergo | ☐ |
| G8 | Provare a lasciare qualcuno **senza** sistemazione | Non si prosegue | ☐ |
| G9 | Tornare indietro al passo 3 e cambiare il numero di persone | Il passo 5 si ricalcola: non resta la scelta fatta per un numero diverso di persone | ☐ |
| G10 | Un viaggio dove esiste **un solo** tipo possibile | La terza domanda non compare affatto | ☐ |

---

## H — La conferma: cosa resta scritto

Qui si guarda il database, non lo schermo. È il gruppo che dice se il sito scrive **come** il
gestionale.

| ID | Cosa controllare dopo aver concluso un'iscrizione | Cosa deve risultare | ☐ |
|---|---|---|---|
| H1 | `ana_clienti` — la riga del pilota | Nomi in maiuscolo, email valida, sesso coerente, `cliente_lingua` valorizzata | ☐ |
| H2 | `ana_clienti` — `created_by` | ⚠️ Dice chi ha scritto (il sito), non è vuoto: entrambe le applicazioni impostano `my.app_user` | ☐ |
| H3 | `mov_clienti_viaggi` | Una riga per ogni partecipante, tutte sulla stessa partenza | ☐ |
| H4 | `mov_clienti_alloggi` | ⚠️ **La capienza torna esattamente**: nessuna camera con più o meno occupanti del suo tipo | ☐ |
| H5 | Il consenso | Le **tre** colonne valorizzate insieme: valore, data, fonte | ☐ |
| H6 | L'email di conferma | Arriva all'indirizzo di `MAIL_DIROTTA_A`, nella lingua del cliente, e i dati dentro corrispondono | ☐ |
| H7 | Chiudere l'iscrizione **due volte** (ricaricare la pagina di conferma, ripremere) | ⚠️ Non nascono due iscrizioni | ☐ |
| H8 | Interrompere a metà (chiudere il browser al passo 4) e ricominciare | Non restano righe a metà: o l'iscrizione c'è tutta, o non c'è | ☐ |

---

## I — Che le due strade dicano la stessa cosa

È il gruppo che verifica l'unificazione. Ogni riga si fa **due volte**: una dal sito, una dal
gestionale, e si confronta l'esito.

| ID | La stessa cosa, dalle due parti | Deve succedere lo stesso | ☐ |
|---|---|---|---|
| I1 | Un'email malformata | Rifiutata da entrambi, con lo stesso criterio | ☐ |
| I2 | Un codice fiscale sbagliato | Rifiutato da entrambi | ☐ |
| I3 | Un cliente senza documento | Rifiutato da entrambi | ☐ |
| I4 | Una camera con più occupanti della sua capienza | Rifiutata da entrambi | ☐ |
| I5 | Nome femminile con titolo `SIG.` | Stesso avviso, e a database vince il sesso in entrambi i casi | ☐ |
| I6 | Un tipo di sistemazione non ammesso da quel viaggio | Non proposto da nessuna delle due | ☐ |
| I7 | Aprire nel **gestionale** un'iscrizione fatta dal **sito** | Si apre, si modifica e si risalva senza che nulla venga rifiutato | ☐ |
| I8 | Aprire nel **sito** un cliente creato dal **gestionale** | Riconosciuto, dati proposti correttamente | ☐ |

⚠️ **I7 è la prova che conta di più.** Un'iscrizione fatta dal sito che il gestionale non
riesce a risalvare significa che il sito ha scritto qualcosa che le regole non accettano — ed
è esattamente il difetto che l'unificazione doveva togliere.

---

## Cosa questo piano NON copre

- **La contabilità**: rimandata a una release successiva. ⚠️ La form delle transazioni chiama
  una funzione che non esiste (§2.19 della Checklist): è un difetto noto, non da segnalare.
- **La protezione dei dati personali** (§0-bis della Checklist): con la sola email si ottengono
  codice fiscale, indirizzo e documento. È un lavoro a sé, già analizzato, e mescolarlo qui
  renderebbe illeggibile il collaudo.
- **La parte CMS nel gestionale** (contenuti web, edizioni, newsletter): ce l'ha il suo piano,
  `Estensione Progetto WEB/Documenti/2026-07-09-Piano_Test_Estensione_Web.md`.
- **Il comportamento su PROD**: qui si collauda in locale. Su PROD si esegue solo la sequenza
  del go-live e le tre verifiche di §0.
