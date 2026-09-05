# Il sito consegna i dati personali a chiunque conosca un'email

**Analisi del 2026-09-05.** Documento operativo: serve a modificare il sito prima del
go-live. Non è una proposta — la direzione è stata decisa, qui c'è come si fa.

---

## 1. Cosa espone oggi, misurato

Una sola richiesta, **senza alcuna autenticazione**, conoscendo soltanto l'indirizzo email
di un cliente:

```
GET /api/cliente/dati-per-email?email=<email di un cliente>
```

risponde con **24 campi, 12 dei quali personali**:

```
codice_fiscale             RRGFLV64P05A794K
indirizzo_residenza        VIA PIEMONTE, 40      comune_residenza  RANICA
telefono                   3491589069            pref_tel_int      +39
data_nascita               1964-09-05            comune_nascita    BERGAMO
tipo_doc  CI               numero_documento      CA97157NB
documento_rilasciato_da    COMUNE DI RANICA
documento_rilasciato_data  2022-09-04            documento_scadenza  2032-09-05
```

⚠️ Non è un elenco anagrafico: **codice fiscale, indirizzo e numero del documento con ente
e scadenza** sono esattamente ciò che serve per registrare una persona in albergo o per
spendere la sua identità altrove.

### Gli endpoint coinvolti

| Endpoint | Cosa restituisce | Chi lo chiama |
|---|---|---|
| `/api/cliente/dati?email=` | 24 campi, 12 personali | `Step2Content.jsx` — precompila la scheda del pilota |
| `/api/cliente/dati-per-email?email=` | 24 campi, 12 personali | `Step3Content.jsx` — apre la scheda del passeggero |
| `/api/session/cliente_esistente?email=` | 2 campi, nessuno personale | ok |
| `/api/cliente/verifica-registrazione-viaggio` | 1 campo | ok |
| `/api/debug/session` | l'intera sessione | ⚠️ **endpoint di debug raggiungibile in produzione**: con una sessione attiva restituisce tutto ciò che contiene. Va tolto o chiuso |

⚠️ **Nessuno dei due endpoint principali ha un limite di tentativi.** Chi possiede una
lista di indirizzi — quella del club, una qualunque — li può interrogare tutti.

### Da quanto

**Circa due anni**, per parola dell'utente: il sito è in produzione da allora. Questa non
è un'esposizione che nascerà al go-live; è aperta adesso. Vale la pena guardare i log del
server per capire se qualcuno l'ha usata: è la domanda che il titolare del trattamento si
fa prima che se la faccia qualcun altro.

---

## 2. Perché è successo: l'email è nata come chiave

Il sito identifica le persone dall'email fin dal primo passo, e la usa per due cose
diverse che non sono mai state separate:

1. **capire se sei già cliente**, per non crearti una scheda doppia;
2. **precompilare il modulo**, per non farti riscrivere tutto.

La prima è legittima e non richiede di mostrare niente. La seconda manda l'intera scheda
al browser. Finché le due cose passano dallo stesso endpoint, sapere un indirizzo email
equivale ad avere la scheda.

⚠️ Va detto per chiarezza: **l'email non ha mai identificato nessuno.** Chiunque può
digitare qualunque indirizzo e nessuno lo verifica. Chi identifica davvero è il
**documento**, obbligatorio per tutti dallo script 563. Rendere l'email meno potente non
toglie una verifica: toglie un privilegio che non era mai stato guadagnato.

---

## 3. I tre verbi, che oggi sono uno solo

| Azione | Chi la compie | Cosa serve |
|---|---|---|
| **Inserire** dati | il pilota, anche per la moglie e per il figlio | **niente** — è così che funzionano i viaggi |
| **Vedere** dati già in archivio | l'interessato | **prova d'identità** |
| **Modificare** dati già in archivio | l'interessato | **prova d'identità** |

Tutta l'analisi che segue discende da questa tabella. Il difetto di oggi è che il sito
tratta i tre casi come uno.

---

## 4. Il disegno: verdetti invece di dati

**Per completare un'iscrizione il browser non ha bisogno dei dati personali: ne ha bisogno
il server, che li possiede già.**

Il pezzo che lo rende possibile esiste ed è già collaudato: `fn_documento_esito_per_partenza`
(script 582) risponde *«questo documento basta per questa partenza»* — un verdetto, non un
dato.

| Oggi il browser riceve | Deve ricevere |
|---|---|
| `numero_documento`, `documento_scadenza_data` | «il tuo documento è valido per questo viaggio» / «è scaduto, va aggiornato» |
| `indirizzo_residenza`, `comune_residenza` | niente |
| `codice_fiscale` | niente |
| `telefono`, `pref_tel_int` | niente |
| `data_nascita`, `comune_nascita` | niente |
| `cognome`, `nome`, `titolo` | ✅ restano: servono per il saluto e per la conferma visiva |

Chi si iscrive vede **«Ciao Flavio, ti abbiamo riconosciuto»** e prosegue. Non vede la
propria scheda — e quindi non la vede nemmeno chi ha digitato la sua email per curiosità.

⚠️ **La conferma dell'identità (nome e cognome) non è un problema** ed è stata
esplicitamente accettata: sapere che una persona è cliente di SFT non è un dato da
proteggere. Il valore da difendere è il **contenuto della scheda**.

---

## 5. L'OTP: vedere e modificare i propri dati

### Il flusso

1. La persona è stata riconosciuta e prosegue l'iscrizione. Sotto il saluto compare:
   *«Vuoi controllare o correggere i tuoi dati? Ti mandiamo un codice.»*
2. **Preme il bottone** — mai in automatico digitando l'email, o l'endpoint diventa un modo
   per riempire la casella di chiunque.
3. Il codice arriva alla **casella già in archivio**. Validità **5 minuti**, **uso singolo**,
   massimo **3 tentativi**.
4. Codice giusto → la scheda compare e si può correggere. Codice sbagliato o scaduto → si
   prosegue l'iscrizione senza vedere nulla: **l'OTP non è un cancello sull'iscrizione, è
   la scorciatoia per non riscrivere tutto.**

⚠️ Chi non fa l'OTP **non resta fuori**: ridigita i propri dati e l'iscrizione va a buon
fine lo stesso, perché il riconoscimento per anagrafica (difetto 91) la aggancia alla sua
scheda senza doppioni. È la differenza fra una misura che la gente subisce e una che
sceglie.

### Chi non ha un'email in archivio

Su PROD (azienda 2) sono **7 clienti su 27** fra quelli con la scheda incompleta. A loro il
codice non si può mandare: non c'è la casella.

Il sito quindi **chiede l'email**, la aggancia alla scheda con
`fn_ana_clienti_aggancia_email` (script 593, scrive solo dove il campo è vuoto) e manda lì
il codice.

⚠️ **Ma su quelle schede l'OTP non prova nulla**, e questa è la cucitura da non perdere di
vista: il codice va all'indirizzo che *chi sta chiedendo* ha appena digitato, quindi
dimostra soltanto che sa leggere la propria posta. È una proprietà dell'OTP in sé — verifica
il possesso di una casella, non l'identità di una persona. Se la casella la sceglie il
richiedente nello stesso momento, la verifica gira a vuoto.

**Due regole, e servono entrambe:**

1. **Bonifica una tantum** — Antonio completa le 7 schede dal gestionale (§2.12 della
   checklist go-live, l'elenco gli è già stato mandato). Da quel momento il sito tratta
   solo schede che un'email ce l'hanno.
2. **Regola permanente** — su una scheda **senza** email in archivio, il codice sblocca il
   **completare** (riempire i campi vuoti) ma **non il vedere** ciò che c'è già. Perché
   domani si presenterà qualcun altro in quella condizione, e la regola deve reggere senza
   dipendere da una bonifica fatta una volta.

### Completare non è modificare

Lo dice già lo script 594: *«riempire un campo vuoto non conta come modifica: quella è una
scheda che si completa, non un'identità che si riscrive»*. Vale anche qui — ed è ciò che
permette ai 27 con la scheda incompleta di iscriversi.

⚠️ Quando il sito riempie un campo vuoto su una scheda esistente, **manda un avviso al
cliente** («abbiamo aggiornato la tua scheda: numero documento»). È lo stesso meccanismo
autocorrettivo della conferma di iscrizione: se non è stato lui, se ne accorge subito.

---

## 6. Cosa cambiare, file per file

### Server

| Dove | Cosa |
|---|---|
| `app.py` — `/api/cliente/dati` e `/api/cliente/dati-per-email` | Smettono di restituire i 12 campi personali. Rispondono: `esiste`, `cognome`, `nome`, `titolo`, `cliente_id`, e i **verdetti** (documento valido per la partenza sì/no, quali campi obbligatori mancano — i **nomi**, non i valori) |
| `app.py` — nuovi endpoint | `/api/cliente/otp/richiedi` (POST, con limite di frequenza) e `/api/cliente/otp/verifica` (POST). Dopo verifica riuscita, la sessione porta un segno che abilita `/api/cliente/scheda` — l'unico endpoint che restituisce i dati completi |
| `app.py` — `/api/debug/session` | **Va tolto**, o chiuso dietro una variabile d'ambiente assente in produzione |
| `Classi_Tabelle_DB/cliente.py` | Un metodo per la scheda completa (solo dopo OTP) e uno per il profilo ridotto |
| Limite di frequenza | Sugli endpoint che accettano un'email: senza, restano enumerabili |

### Database

| Cosa | Perché |
|---|---|
| Tabella dei codici (`web_otp_codici`: email, codice **cifrato**, scadenza, tentativi, usato) | Il codice non si tiene in chiaro, come per i segreti SMTP (script 475) |
| `fn_otp_genera` / `fn_otp_verifica` | La regola dei 5 minuti, dei 3 tentativi e dell'uso singolo sta **a database**, non nel Python: è la stessa ragione per cui ci sono tutte le altre |
| Pulizia dei codici scaduti | Una riga per ogni richiesta, e non servono più dopo cinque minuti |

### Interfaccia

| Dove | Cosa |
|---|---|
| `Step2Content.jsx` | Non precompila più dai dati ricevuti. Mostra il saluto, i verdetti, e il bottone «controlla i tuoi dati» |
| `Step3Content.jsx` | La modale del passeggero si apre in inserimento, non in modifica: il pilota **inserisce**, non **vede** |
| Nuovo componente | La finestrella del codice: richiesta, inserimento, esito |

---

## 7. Cosa NON cambia (per contenere i test)

- Il **percorso di iscrizione** resta identico nei passi e nell'ordine.
- Il riconoscimento del cliente esistente resta, e resta la sua utilità: niente doppioni.
- Le regole di validazione, i controlli sui documenti e il consenso **non si toccano**: sono
  già a database e non passano dai dati mandati al browser.
- Il gestionale MAUI **non è coinvolto**: legge dal database, non dagli endpoint del sito.

---

## 8. Impatto sui test

⚠️ Serve un altro giro, e l'utente lo ha già messo in conto. Ma non su tutto:

| Gruppo del piano Flask | Da rifare? |
|---|---|
| A — titolo e sesso | no |
| B — consenso email | no |
| C — i controlli condivisi | **sì**, parzialmente: cambiano i dati che il modulo riceve |
| D — iscrizione al viaggio | **sì**, interamente: è il percorso toccato |
| E — la posta | no, salvo il nuovo invio del codice |
| F — i due software concordano | **sì**, parzialmente |
| G — consenso durante l'iscrizione | no |
| **Nuovo gruppo H — protezione dei dati** | **sì**: che gli endpoint non restituiscano più i campi personali, che l'OTP scada davvero, che tre tentativi sbagliati chiudano, che il codice non si riusi, che senza OTP l'iscrizione funzioni lo stesso |

---

## 9. Ordine di lavoro

1. **Chiudere il rubinetto** — gli endpoint smettono di restituire i campi personali, il
   modulo lavora sui verdetti. ⚠️ Da solo blocca i 27 con la scheda incompleta: va quindi
   fatto insieme al punto 3.
2. **Togliere `/api/debug/session`** — indipendente, immediato.
3. **L'OTP** — database, endpoint, interfaccia.
4. **Il completamento dei campi vuoti** senza OTP, con avviso via email al cliente.
5. **La bonifica delle 7 schede** da parte di Antonio (in parallelo, non blocca).
6. **Il limite di frequenza** sugli endpoint che accettano un'email.
7. **Il nuovo gruppo H** del piano di test, più i gruppi C, D e F da rifare.

---

## 10. La frase da ricordare

Il sito non è stato scritto male: è stato scritto quando **l'email sembrava una chiave**.
Lo era per comodità — evitare a chi torna di riscrivere tutto — e nessuno ha notato che la
stessa comodità, vista da fuori, è un archivio aperto. ⚠️ È lo stesso ceppo dei difetti
trovati oggi: **una regola che vale per tutti scritta in un posto solo va bene; un
privilegio che vale per tutti no.**
