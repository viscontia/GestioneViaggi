# Piano di collaudo — `ana_clienti`: un controllo, un posto solo

> **USO INTERNO.** Sequenza eseguibile per collaudare il lavoro del 2026-08-20 (fasi 0-5 del piano
> `docs/plans/2026-08-20-ana-clienti-un-controllo-un-posto-solo.md`).
> Stessa forma del runbook newsletter: **da dove parti · cosa fai · cosa deve succedere**.
>
> ⛔️ **Tutto in LOCALE.** PROD ha le funzioni ma non lo schema che presuppongono (mancano `538`-`542`):
> le chiamate là fallirebbero. Vedi la nota sullo stato di PROD nella Checklist Go-Live.

---

## A — Prerequisiti

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| A1 | `docker ps` | Il container `postgres_db` è in piedi |
| A2 | `dotnet build -f net9.0-maccatalyst` | Build verde |
| A3 | Avvia il gestionale e accedi come utente dell'**azienda 2** | La pagina Clienti si apre |
| A4 | Nel progetto del sito: `./start-iscrizione-local.sh` | Wizard raggiungibile, **puntato al DB locale** |
| A5 | Verifica i dati di riferimento | `SIG.` = titolo 6, `SIG.RA` = 8, ORISTANO = comune 70582, tipo partecipante 4 = *pilota mezzo proprio*, 6 = *passeggero* |

> I casi qui sotto usano nomi che iniziano per `ZZ` per ritrovarli e cancellarli in fondo.

---

## B — Anagrafica cliente: i controlli scesi nel database

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| B1 | Clienti → Nuovo | Compila un cliente valido e salva | Si salva. Il **sesso** non è digitabile: lo mostra derivato dal titolo |
| B2 | Nuovo cliente | Email `pippo@` (senza dominio) | **Errore** sul campo, mentre scrivi: *«L'indirizzo email non è scritto in modo valido»* |
| B3 | Nuovo cliente | Cognome `A` (un carattere) | **Rifiutato**: *«Il cognome deve avere almeno 2 caratteri»* |
| B4 | Nuovo cliente | IBAN `XX123` | **Rifiutato** con la ragione (15-34 caratteri, due lettere iniziali) |
| B5 | Nuovo cliente | Telefono valorizzato, **prefisso vuoto** | ⚠️ **Chiede conferma**, non blocca: *«C'è un numero di telefono ma manca il prefisso internazionale»*. Confermando, si salva |
| B6 | Nuovo cliente | Documento: rilascio **domani** | **Rifiutato**: la data di rilascio è nel futuro |
| B7 | Nuovo cliente | Documento con scadenza **passata** | **Avviso** (non blocca): *«Il documento risulta scaduto il …»* |
| B8 | Nuovo cliente | Data di nascita **domani** | **Rifiutato** |

---

## C — Il codice fiscale

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| C1 | Nuovo cliente | Cognome `ZZTOLU`, nome `ANTONIO`, M, nato il **24/08/1977** a **ORISTANO**, CF `TLONTN77M24G113N` | Nessuna segnalazione sul codice fiscale: **corrisponde** |
| C2 | Stesso caso | Cambia la data di nascita in **24/07/1977** | ⚠️ **Chiede conferma**: il codice non corrisponde e dice quale risulterebbe |
| C3 | Nuovo cliente | Metti `ANTONIO` nel **cognome** e `ZZTOLU` nel **nome**, stesso CF | ⚠️ **Chiede conferma** dicendo *«Nome e cognome sembrano invertiti: il codice fiscale corrisponde leggendo «ZZTOLU» come cognome…»* |
| C4 | Stesso caso | **Conferma** | Si salva. È il caso raro del codice emesso invertito, che deve restare registrabile |
| C5 | Nuovo cliente | CF `TLONTN77M24G113A` (ultimo carattere alterato) | **Rifiutato**: non supera il controllo dell'ultimo carattere |
| C6 | Nuovo cliente | CF `ABC` | **Rifiutato**: forma non valida |
| C7 | Cliente **nato all'estero** (comune senza codice catastale) | Inserisci un CF formalmente valido | Passa: il confronto con l'anagrafica **non è possibile** e non è colpa di chi compila |

---

## D — Duplicati e omonimi

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| D1 | Nuovo cliente | Usa il CF di **TOLU ANTONIO** (`TLONTN77M24G113N`) su un'altra anagrafica | **Rifiutato**, e dice **chi** ce l'ha già |
| D2 | Nuovo cliente | Stessi cognome, nome, **data e comune di nascita** di un cliente esistente, senza CF | **Rifiutato**: esiste già un cliente con gli stessi dati anagrafici |
| D3 | Nuovo cliente | Solo **cognome e nome** uguali a un esistente (data diversa) | **Avviso**, non blocco: gli omonimi esistono davvero |
| D4 | ⭐ **Il caso che prima era cieco** | Come D3, ma **senza codice fiscale e senza data di nascita** | **Avviso lo stesso.** Il vecchio controllo qui non vedeva nulla: girava solo sulle schede complete |
| D5 | Nuovo cliente | Email già usata da un altro cliente | **Avviso**, non blocco — condividere la casella è prassi legittima. ⚠️ Prima diceva *«impossibile proseguire»* |
| D6 | **Modifica** di un cliente esistente | Salva senza cambiare nulla | **Nessuna segnalazione**: non deve accusare se stesso |
| D7 | Utente di un'**altra azienda** | Cerca di creare un cliente con il CF di un cliente dell'azienda 2 | **Nessun blocco**: i silos restano silos |

---

## E — Consenso e lingua

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| E1 | Nuovo cliente | Spunta il consenso e salva | A DB: `consenso_marketing` vero, **`consenso_marketing_data` valorizzata** e una fonte |
| E2 | Cliente con consenso | Riapri, cambia **solo il telefono**, salva | Consenso, data e fonte **invariati**. È la trappola da verificare: un aggiornamento non deve azzerarli |
| E3 | Cliente con consenso | Togli la spunta e salva | Consenso spento, ma **data e fonte restano**: servono a dimostrare che un tempo c'era |
| E4 | Cliente senza consenso | Accendilo | **Nuova** data e nuova fonte |
| E5 | Qualsiasi cliente | Cambia la lingua e salva, poi riapri | Il valore è quello scelto. ⚠️ Non passa più da una chiamata separata dopo il salvataggio |

---

## F — Iscrizione al viaggio

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| F1 | Partecipanti di una partenza | Iscrivi come **pilota** un cliente **senza email** | **Rifiutato**, e il messaggio dice **chi** è |
| F2 | Stesso caso | Metti l'email a quel cliente, poi riprova | Si iscrive |
| F3 | Stessa partenza | Iscrivi lo **stesso cliente due volte** | **Rifiutato**: già iscritto a questo viaggio in questa data |
| F4 | Partecipanti | Iscrivi un pilota **senza marca, modello e targa** | **Rifiutato**: *«Per il ruolo «PILOTA MEZZO PROPRIO» i dati del mezzo sono obbligatori: manca la marca, il modello e la targa»* |
| F5 | Stesso caso | Compila marca e modello, lascia la targa | Il messaggio nomina **solo la targa** |
| F6 | Partecipanti | Iscrivi un **passeggero** senza mezzo e senza email | Passa: per lui non sono obbligatori |

---

## G — Il sito di iscrizione

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| G1 | Wizard, passo 2 | Guarda sotto l'email | C'è la spunta **«Desidero ricevere comunicazioni…»**, **non pre-selezionata** e distinta dall'accettazione delle condizioni |
| G2 | Wizard | Completa un'iscrizione **spuntando** il consenso | A DB il nuovo cliente ha consenso vero, data e **fonte `SITO_ISCRIZIONE`** |
| G3 | Wizard | Completa un'iscrizione **senza** spuntarlo | Consenso falso. Nessuna data, nessuna fonte |
| G4 | Wizard, campo CF | Inserisci un CF con l'ultimo carattere errato | Il sito lo rifiuta — ora è il database a dirlo |
| G5 | Wizard | CF valido ma **non corrispondente** all'anagrafica digitata | Segnalato, con il codice che risulterebbe |
| G6 | Wizard | Iscriviti a un viaggio **a cui sei già iscritto** | **Rifiutato**. ⚠️ Prima il sito non lo controllava affatto |
| G7 | Wizard | Completa un'iscrizione normale, dall'inizio alla fine | Funziona: cliente creato, prenotazione inserita, email di conferma |

---

## H — La prova che conta: i due software concordano

> È il collaudo del perché di tutto il lavoro. Ogni riga si esegue **due volte**, una dal gestionale e
> una dal sito, e le due risposte devono essere la stessa.

| # | Il dato sbagliato | Atteso da **entrambi** |
|---|---|---|
| H1 | Email malformata | Rifiutata |
| H2 | Codice fiscale con carattere di controllo errato | Rifiutato |
| H3 | Codice fiscale già di un altro cliente | Rifiutato, con l'indicazione di chi ce l'ha |
| H4 | Nome e cognome invertiti (CF coerente) | Segnalato come invertiti, con proposta |
| H5 | Iscrizione doppia allo stesso viaggio | Rifiutata |
| H6 | Pilota senza email | Rifiutato |

---

## I — Non regressione

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| I1 | Apri **dieci clienti storici** a caso e salvali senza modifiche | Si salvano. Se qualcuno si rifiuta, guarda il messaggio: probabile dato storico incoerente, non un difetto |
| I2 | Griglia clienti: ricerca, ordinamento, paginazione | Invariati |
| I3 | Export Excel dei clienti | La colonna **Titolo** è valorizzata |
| I4 | Stampa una **rooming list** e una **scheda viaggio** | Invariate |
| I5 | Invia una **newsletter di prova** | I destinatari e i loro telefoni sono quelli di prima (il prefisso ha ancora lo spazio: `+39 333…`) |
| I6 | Elimina un cliente **con viaggi** | Rifiutato come prima (lo bloccano i trigger) |

---

## Pulizia finale

```sql
-- I clienti di prova creati durante il collaudo
SELECT cliente_id, cliente_cognome, cliente_nome FROM ana_clienti WHERE cliente_cognome LIKE 'ZZ%';
-- e le loro eventuali iscrizioni, prima di cancellarli
```

---

## Cosa NON è coperto da questo piano

- **PROD.** Nulla di questo si prova là: manca lo schema (`538`-`542`).
- **La consegna coordinata** (fase 6): script → sito → eseguibile, in quest'ordine.
- **Le letture** di `ClienteRepository`, non ancora convertite: restano SQL inline e funzionano come prima.
- **Il consenso per i passeggeri** del wizard (passo 3): oggi la spunta è solo per chi compila. La
  decisione del 2026-08-20 era «uno per ciascun partecipante» — resta da fare.
