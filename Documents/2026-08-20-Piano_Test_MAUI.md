# Piano di test — Gestionale MAUI (`ana_clienti` centralizzato)

**Data:** 2026-08-20
**Ambiente:** DB locale Docker (`gestione_viaggi`), script `538`–`562` applicati
**Chi lo esegue:** Adriano (richiede l'app in esecuzione: non è automatizzabile da CLI)

---

## Perché questo piano esiste separato

Copre **solo il gestionale**. Il sito di iscrizione ha il suo piano
(`2026-08-20-Piano_Test_Flask.md`), e la prova incrociata fra i due è in fondo a quello.

**Non è qui ciò che è già stato verificato a livello di database o di API**: il calcolo del
codice fiscale, gli esiti di `fn_ana_clienti_valida`, l'avviso nome/sesso come funzione,
la lettura della configurazione SMTP. Quelli sono stati eseguiti e sono passati. Qui resta
ciò che si può vedere **solo aprendo l'applicazione**.

> **Prima di iniziare** — l'app va lanciata con la variabile `GV_SECRET_KEY` impostata, altrimenti
> i segreti restano illeggibili e alcune funzioni web risultano spente. Non è un difetto.

---

## A — Le letture, ora nel database

Con gli script `558`–`560` **`ClienteRepository.cs` non contiene più una sola SELECT**. Le funzioni
esistevano dal marzo 2026 e nessuno le chiamava: sono state completate e collegate.

È il gruppo con il rischio più alto di tutto il lavoro, per un motivo preciso: **un campo che
sparisce da una form non dà errore**. Non c'è, e se ne accorge solo chi guarda. Il modo giusto di
fare questi test è **confrontare**, non ispezionare: apri una scheda che conosci e verifica che ci
sia tutto quello che c'era ieri.

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| A1 | Apri l'**elenco clienti** | Ci sono tutti. Comune di nascita e di residenza **con la provincia**, non vuoti |
| A2 | Nell'elenco guarda le colonne **viaggi fatti / da fare** | Valorizzate come prima |
| A3 | Filtra l'elenco **per anno** | Il filtro funziona e riduce le righe |
| A4 | **Cerca** per cognome, poi per email, poi per codice fiscale | Trova in tutti e tre i casi; i comuni sono valorizzati anche nei risultati |
| A5 | Apri un cliente **con foto e documento** | Si vedono entrambi. È il caso più a rischio: viaggiano in base64 e **solo** nel dettaglio |
| A6 | Apri un cliente e controlla **titolo, lingua e consenso** | Il titolo è quello giusto nella tendina (non vuoto) |
| A7 | Apri un cliente, **salva senza modificare**, riaprilo | Titolo, lingua e consenso **invariati**. Se il titolo tornasse vuoto o il consenso si spegnesse, la lettura non porta la chiave |
| A8 | Da un cliente apri le **statistiche viaggi** | Si apre. Prima della correzione andava in eccezione: leggeva colonne che la vecchia funzione non restituiva |
| A9 | Prova a **cancellare** un cliente con iscrizioni, poi uno con alloggio assegnato | Rifiutato in entrambi i casi |
| A10 | Cancella un cliente **senza** iscrizioni né alloggi (uno `ZZ` di prova) | Si cancella |
| A11 | Accedi come utente di **un'altra azienda** e cerca un cliente della prima | Non lo trova |

> **Da guardare una volta sola.** La ricerca per email ora ordina per `cliente_id` e restituisce la
> scheda più vecchia. Prima non ordinava affatto: con le tre coppie che condividono la casella,
> quale delle due tornasse era arbitrario e poteva cambiare fra due esecuzioni identiche.

---

## B — L'avviso nome/sesso, che ora vive nel database

La regola stava solo in C#. Ora sta in `fn_nome_sesso_avviso` e nella tabella
`ana_nomi_maschili_in_a`, ed è **la stessa che vede il sito**. Il validatore C# è stato eliminato:
non c'erano più due copie da tenere allineate, c'era una copia in più.

Cambia anche **quando** compare: prima a ogni tasto, ora quando si sceglie il titolo e quando si
lascia il campo Nome. È un giro al database, e il momento utile è quando il nome è finito.

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| B1 | Nuovo cliente: titolo **SIG.**, nome **FRANCESCA**, esci dal campo | Compare l'avviso giallo «sembra un nome femminile…» |
| B2 | Cambia il titolo in **SIG.RA** | L'avviso **sparisce** subito |
| B3 | Titolo **SIG.**, nome **ANDREA** | **Nessun** avviso (è in lista) |
| B4 | Titolo **SIG.**, nome **GIANLUCA** | Nessun avviso |
| B5 | Titolo **SIG.**, nome **GIUSEPPE MARIA** | Nessun avviso (MARIA come secondo nome è maschile) |
| B6 | Titolo **SIG.**, nome **MARIA** da solo | Avviso presente |
| B7 | Titolo **SIG.RA**, nome **MARCO** | Avviso «sembra un nome maschile…» |
| B8 | Con l'avviso a video, **salva** | Il salvataggio **riesce**: è un avviso, non un divieto |
| B9 | Non scegliere alcun titolo e scrivi un nome | Nessun avviso: senza titolo non c'è un sesso da contraddire |

---

## C — Salvataggio e validazione

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| C1 | Nuovo cliente con **email scritta male** | Rifiutato, messaggio in italiano leggibile — **non** un errore del database con dentro la riga |
| C2 | Nuovo cliente con **cognome di un carattere** | Rifiutato: «Il cognome deve avere almeno 2 caratteri.» |
| C3 | Nuovo cliente con il **codice fiscale di una persona già presente** | Bloccato, con l'indicazione di chi è |
| C4 | Nuovo cliente con **cognome e nome invertiti** rispetto al codice fiscale | Chiede conferma proponendo lo scambio |
| C5 | Cliente con **documento scaduto** | Avviso, **non** blocco |
| C6 | Telefono compilato ma **prefisso internazionale vuoto** | Chiede conferma |
| C7 | Cliente **senza email** | Passa (l'obbligo dipende dal ruolo: vedi il gruppo D) |
| C8 | Data di nascita o di rilascio **nel futuro** | Rifiutato |

---

## C-bis — Consenso e lingua: le trappole

Il consenso non è un flag qualunque: le tre colonne (`consenso_marketing`, `_data`, `_fonte`)
esistono per **dimostrare** che è stato dato. Un aggiornamento che le azzera non perde una
preferenza, perde una prova — e non è recuperabile con un backfill.

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| Cb1 | Nuovo cliente | Spunta il consenso e salva | A DB: consenso vero, **data valorizzata** e una fonte |
| Cb2 | Cliente **con** consenso | Riapri, cambia **solo il telefono**, salva | Consenso, data e fonte **invariati**. È la trappola vera: un aggiornamento qualsiasi non deve toccarli |
| Cb3 | Cliente con consenso | Togli la spunta e salva | Consenso spento, ma **data e fonte restano**: servono a dimostrare che un tempo c'era |
| Cb4 | Cliente **senza** consenso | Accendilo | **Nuova** data e nuova fonte |
| Cb5 | Qualsiasi cliente | Cambia la **lingua**, salva, riapri | Il valore è quello scelto. Non passa più da una chiamata separata dopo il salvataggio: è dentro il CRUD |

---

## D — Iscrizione al viaggio

Fino al 2026-08-21 il gestionale chiamava ancora la vecchia `sp_mov_clienti_viaggi_create`, che
**non controllava nulla**: le regole degli script `551` e `553` le applicava soltanto il sito. Cioè
lo strumento usato tutti i giorni era quello scoperto. Ora entrambe le form di iscrizione
(`QuickAddParticipantDialog` e il tab Partecipanti) passano da `fn_mov_clienti_viaggi_insert`.

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| D1 | Iscrivi come **pilota** una persona senza email | Si apre il popup **«Manca l'email»** con il nome della persona |
| D2 | Nel popup lascia il campo vuoto o premi **Annulla iscrizione** | L'iscrizione **non** avviene; nessuna riga a database |
| D3 | Nel popup scrivi un'email **malformata** | Il pulsante «Salva e prosegui» resta disabilitato |
| D4 | Nel popup scrivi un'email valida e conferma | L'email finisce **in anagrafica** (riaprendo la scheda cliente c'è), e l'iscrizione prosegue |
| D5 | Riapri il popup: il fuoco parte dal campo email? | Sì |
| D6 | Iscrivi la stessa persona senza email come **accompagnatore** | Consentito, nessun popup |
| D7 | Ruolo che richiede i **dati del mezzo**, lasciali vuoti | Rifiutato, e il messaggio dice **quali** mancano (marca, modello, targa) |
| D7b | Stesso caso, ma compila **marca e modello** e lascia solo la targa | Il messaggio nomina **solo la targa**: dice cosa manca, non ripete l'elenco intero |
| D8 | Iscrivi due volte la stessa persona allo stesso viaggio e data | Rifiutato |
| D9 | Ripeti D1 e D7 dal **tab Partecipanti** del viaggio, non dall'inserimento rapido | Stesso comportamento: le due form condividono lo stesso codice |
| D10 | **Modifica** un partecipante esistente cambiandogli ruolo in pilota, se non ha email | Stesso popup |

> Il popup non è una scorciatoia per aggirare il controllo: l'email inserita passa dal salvataggio
> normale dell'anagrafica, quindi dagli stessi controlli di sempre. Se fosse duplicata o
> incoerente, il salvataggio lo direbbe e l'iscrizione non proseguirebbe.

---

## E — Non regressione

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| E1 | Apri **dieci clienti storici** a caso e salvali senza modifiche | Si salvano. Se qualcuno si rifiuta, guarda il messaggio: probabile dato storico incoerente, non un difetto |
| E2 | **Export Excel** dei clienti | La colonna **Titolo** è valorizzata |
| E3 | Stampa una **rooming list** e una **scheda viaggio** | Invariate |
| E4 | Invia una **newsletter di prova** | Destinatari e telefoni come prima |
| E5 | Percorri le tabelle **Titoli persone**: elenco, inserimento, modifica, cancellazione | Funzionano. Cancellare un titolo **in uso** è impedito |
| E6 | Tabulazione e focus nelle form toccate (cliente, newsletter) | Il focus parte dal primo campo, il TAB segue l'ordine |

---

## Pulizia finale

```sql
SELECT cliente_id, cliente_cognome, cliente_nome FROM ana_clienti WHERE cliente_cognome LIKE 'ZZ%';
-- e le eventuali iscrizioni collegate, prima di cancellarli
```

---

## Cosa questo piano NON copre

- **PROD.** Nulla si prova là: mancano gli script `538`–`542` e `556`.
- **Il sito di iscrizione** — ha il suo piano, e con esso la prova incrociata.
- **La consegna coordinata** (script → sito → eseguibile, in quest'ordine).
- **I test xUnit**: in questo progetto non girano da CLI (`NU1201`). La verifica è build + prova nell'app.
