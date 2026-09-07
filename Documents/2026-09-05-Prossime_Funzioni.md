# Prossime funzioni — cose decise ma non ancora fatte

Raccoglie le idee emerse **durante** il piano di test e messe da parte di proposito, per
non allargare il lavoro mentre si collauda. Ognuna dice **perché** è nata: fra sei mesi
la motivazione è l'unica cosa che non si ricostruisce da sola.

Nulla di qui è pianificato. Si decide quando, una alla volta, dopo il go-live.

---

## 1. Conferma al cliente quando lo si cancella o gli si cambia camera

**Deciso il 2026-09-05.** Nata guardando il difetto 80: ci si è accorti che il sistema
manda posta ai clienti in un caso solo — l'iscrizione — e in nessun altro.

### Il problema

Quando un cliente viene tolto da un viaggio, o cambia camera, **quasi sempre è lui ad
averlo chiesto**. Ma non riceve nessuna conferma che sia stato fatto: la richiesta è
arrivata per telefono o messaggio, l'operatore la esegue nel gestionale, e lì finisce.
Perché il cliente lo sappia, qualcuno in segreteria deve richiamarlo o scrivergli
apposta.

Sono due costi insieme: **lavoro manuale ripetitivo** per la segreteria, e **clienti
disallineati** ogni volta che quel lavoro manuale salta. Chi ha chiesto di cambiare
camera e non riceve nulla, o richiama per sapere se è stato fatto, o si presenta alla
partenza convinto di una sistemazione diversa.

### Cosa dovrebbe fare

Al verificarsi di una di queste condizioni nel gestionale:

- **cancellazione di un partecipante** da un viaggio (pilota o passeggero);
- **cambio di camera** — l'assegnazione sta in `mov_clienti_alloggi`, che tiene fino a
  sei clienti per sistemazione (`cliente_id1_fk` … `cliente_id6_fk`);

il gestionale **chiede all'operatore se mandare una mail di conferma** alle persone
coinvolte, e la manda.

⚠️ **Si chiede, non si manda e basta.** È il punto che rende la funzione accettabile:
l'operatore che risponde NO ha già avvisato il cliente in altro modo — l'ha appena
sentito al telefono, gli ha risposto su WhatsApp — e una seconda conferma automatica
sarebbe rumore. La macchina toglie il lavoro ripetitivo, non la decisione.

### Le regole, decise il 2026-09-05

| Caso | Regola |
|---|---|
| **Si cancella un passeggero** | Si scrive **a lui se ha un indirizzo**; altrimenti **al suo pilota**. |
| **Si cancella un pilota che ha passeggeri** | I passeggeri **si cancellano tutti**, e **si avvisano tutti quelli che hanno un indirizzo**. Senza pilota non hanno un mezzo: restare iscritti non avrebbe senso. |
| **Si cambia camera** | Sono coinvolti **tutti gli occupanti di quella camera**, e nessun altro. |
| **In che lingua** | Nella **lingua del cliente** (`ana_clienti.cliente_lingua`, già popolata dal Blocco 10 e da `SqlScripts/465`). |
| **Che traccia resta** | **Copia alla segreteria** di ogni mail inviata. Nessuna tabella nuova: la casella della segreteria diventa il registro, ed è il posto dove chi risponde al telefono guarda comunque. |

### La cancellazione è già stata corretta (2026-09-05)

I due difetti che questa funzione avrebbe attraversato — passeggeri lasciati indietro,
letto non liberato — sono stati corretti subito con `SqlScripts/586`, per non rimettere
le mani sulla stessa cancellazione due volte. Vedi i **difetti 81 e 82** nelle note di
rilascio.

Resta quindi da fare **solo la mail**: la cancellazione ora sa già *chi* esce dal viaggio
(`fn_mov_clienti_viaggi_cancellazione_effetti` restituisce nome, ruolo, motivo e
indirizzo di ognuno), che è esattamente l'elenco dei destinatari. Chi la realizzerà
troverà il lavoro di raccolta già fatto.

### Prerequisito tecnico, e non è piccolo

Il testo delle mail deve stare **dove stanno già gli altri**, non nel codice C#: le mail
del sito sono modelli, e queste devono esserlo allo stesso modo, altrimenti nascono due
posti in cui si scrive ai clienti e divergono (vedi *Centralizzare e uniformare*).

⚠️ **Prima ancora**: il gestionale invia posta tramite `Services/Email/SmtpEmailSender.cs`
— oggi lo usa solo `NewsletterSenderService` — e **non ha nessuna rete di sicurezza per
l'ambiente locale**. È esattamente il difetto 80, dall'altro lato: sul sito è stato
chiuso il 2026-09-05 con `MAIL_DIROTTA_A`, nel gestionale no. Lì è pure più grave, perché
il mittente è un motore di newsletter: un invio di prova non raggiunge una persona, ne
raggiunge centinaia. **Questa funzione fa diventare l'invio di posta dal gestionale una
cosa quotidiana**, quindi la protezione va messa prima di realizzarla — e comunque va
messa, anche se la funzione non si farà mai.

---

## 2. Area riservata dei clienti — **fuori progetto**

**Segnalata il 2026-09-04** provando D4: «un giorno mi piacerebbe che i Clienti potessero
avere una propria area riservata… Bello ma futuribile». L'utente ha poi precisato:
*«puoi metterla nelle cose future, ma assolutamente fuori progetto»*.

Resta scritta qui solo perché non vada persa. **Non è un lavoro previsto**, non entra in
nessuna stima e non condiziona nessuna scelta di adesso.

---

## 0-bis. 🔴 IL SITO CONSEGNA I DATI PERSONALI A CHIUNQUE — **da fare prima del go-live**

**Deciso il 2026-09-05.** Analisi operativa completa in
`Estensione Progetto WEB/Documenti/2026-09-05-Analisi_Protezione_Dati_Personali_Sito.md`.

Una richiesta senza autenticazione, conoscendo **solo l'email** di un cliente, restituisce
codice fiscale, indirizzo, telefono, data e comune di nascita, **numero del documento con
ente e scadenza**. ⚠️ Non nascerà al go-live: è così **da circa due anni**, in produzione.

### La decisione

| | |
|---|---|
| **Rubinetto** | Gli endpoint smettono di mandare i campi personali al browser. Il modulo lavora su **verdetti** («il tuo documento è valido per questo viaggio») invece che su dati — la funzione esiste già, è `fn_documento_esito_per_partenza` |
| **Saluto sì, scheda no** | Nome e cognome restano: sapere che una persona è cliente di SFT non è un dato da proteggere. Il contenuto della scheda sì |
| **OTP** | Codice via email per **vedere e modificare** i propri dati: 5 minuti, uso singolo, 3 tentativi, richiesto premendo un bottone |
| **Non è un cancello** | Chi non fa l'OTP ridigita i suoi dati e si iscrive lo stesso: il riconoscimento per anagrafica lo aggancia alla sua scheda senza doppioni |
| **Chi non ha email** | Gliela si chiede e si aggancia alla scheda (`fn_ana_clienti_aggancia_email`). ⚠️ Ma su quelle schede l'OTP **non prova nulla** — il codice va all'indirizzo che il richiedente ha appena digitato: sblocca il **completare**, non il **vedere** |
| **Completare ≠ modificare** | Riempire un campo vuoto non richiede OTP (è già la regola dello script 594), ma manda un **avviso al cliente**: se non è stato lui se ne accorge |

### Perché tutto insieme e non in due tempi

Il rubinetto da solo bloccherebbe i **27 clienti con la scheda incompleta**: senza vedere
cosa manca non possono completarla, e senza completarla non si iscrivono. E l'OTP da solo
non basta, perché **7 di quei 27 non hanno un'email** a cui mandare il codice. Le tre parti
— rubinetto, OTP, completamento — si reggono a vicenda.

⚠️ **Comporta un altro giro di test**, messo in conto dall'utente: da rifare i gruppi C, D
e F del piano Flask, più un gruppo **H** nuovo sulla protezione dei dati.

---

## 0. Chi non ha l'email non poteva iscriversi sul sito — **RISOLTO il 2026-09-05**

Fatto con `SqlScripts/593` (difetto 91): il sito riconosce la persona, le aggancia l'email
che sta fornendo e prosegue sulla sua scheda. ⚠️ Resta da sanare a mano **GENDUSO
FRANCESCA**, che senza data di nascita nessuna regola può riconoscere (checklist
§3.0-quater-bis).

Quello che segue è il testo com'era quando è stato trovato.


**Trovato dall'utente il 2026-09-05, test F7.** Il sito identifica le persone
**dall'email**: è la prima cosa che chiede, ed è la chiave con cui ritrova la scheda
(`fn_wizard_verifica_cliente`). Nel gestionale invece l'email **non è obbligatoria** — e
non deve esserlo, perché la passeggera che non lascia il proprio indirizzo sta esercitando
una scelta legittima.

Le due regole non coincidono, e la conseguenza è che **un cliente già in anagrafica senza
email non si può iscrivere dal sito**.

### Cosa succede davvero, misurato su PROD (azienda 2)

Su 206 clienti, **8 non hanno email**. Non finiscono tutti allo stesso modo:

| | quanti | esito |
|---|---|---|
| Riconosciuti e **bloccati** | **7** | `ERRORE / STESSA_ANAGRAFICA` — non possono iscriversi |
| ⚠️ **Non riconosciuti → doppione** | **1** | GENDUSO FRANCESCA (id 3023): **non ha la data di nascita**, e senza quella la regola non scatta |

Le sette bloccate sono CAMBIAGIO PIERANGELA, COLOMBO ROBERTA, DENARI MARIA ADELAIDE,
DONATI BARBARA, MAIORCA MARIA, MELIS GIORGIA, MEZZALAMA BIANCA. ⚠️ Sono **tutte donne**,
il che conferma da dove vengono: passeggere iscritte da altri, senza un indirizzo proprio.

**Il disastro temuto — la scheda doppia — è quasi sempre già evitato**, e da lavoro fatto
in questo stesso ciclo: `fn_ana_clienti_verifica_duplicato` riconosce la stessa persona da
cognome, nome, data di nascita e comune di nascita, e risponde ERRORE. Ma «non si crea un
doppione» qui significa «non si iscrive nessuno»: la persona resta fuori, e in un caso su
otto il doppione si crea lo stesso perché i dati non bastano a riconoscerla.

### La direzione, da decidere

La regola che manca è la stessa già decisa per la pagina pubblica della newsletter — *«chi
si iscrive da quel link ed è già cliente: aggiornare la sua scheda»*. Applicata qui: quando
il sito riconosce la stessa anagrafica e **quella scheda non ha email**, invece di rifiutare
dovrebbe **attaccare l'email alla scheda esistente** e proseguire con quel cliente.

⚠️ È una decisione di prodotto, non tecnica: significa accettare che cognome, nome, data e
comune di nascita bastino a dire «questa è la stessa persona» e a legarle un indirizzo
email. Va decisa prima di scriverla.

⚠️ Resta comunque da sanare a mano il caso GENDUSO FRANCESCA: senza data di nascita nessuna
regola automatica può riconoscerla.

---

## 0-bis. Il sito pretende l'email anche dal passeggero, il database no

**Esito del test F7, 2026-09-05.** Il gestionale permette di creare un cliente senza
email; il sito la pretende **sempre**, per il pilota e per ogni passeggero
(`Step3Content.jsx`: «Il campo email è obbligatorio»).

⚠️ Il punto non è che i due software divergano: è che **il sito è più severo della
regola**. La regola canonica sta in `fn_mov_clienti_viaggi_valida` e dice un'altra cosa —
l'email serve **a chi guida**, perché è a lui che vanno convocazione, variazioni di
programma e istruzioni. Al passeggero no: *«un passeggero che non lascia il proprio numero
non sta nascondendo un dato, sta esercitando una scelta legittima»* (script 563).

### Cosa costa oggi

Su PROD (azienda 2), dei **88 passeggeri** mai iscritti a un viaggio, **12 non hanno un
indirizzo email** — il 14%. Sono le mogli, le compagne, i figli: le stesse persone di cui
si è detto parlando del consenso, *«nove volte su dieci è la moglie del pilota»*.

Oggi il pilota che vuole iscrivere online la propria compagna senza casella ha due strade,
entrambe cattive:

1. **Inventarle un indirizzo**, o riusare il proprio. ⚠️ È la peggiore: sporca
   l'anagrafica con un recapito falso, e crea una scheda che il sito ritroverà con
   l'email sbagliata la prossima volta.
2. **Rinunciare a iscriverla online** e scrivere in segreteria — che è quello che il sito
   stesso suggerisce oggi in fondo alla pagina dei passeggeri. Cioè: la funzione esiste ma
   per il 14% dei casi si torna al telefono.

### La direzione

Rendere l'email del passeggero **facoltativa**, allineando il sito alla regola che il
database già applica. ⚠️ Ha una conseguenza da pensare prima: senza email quel passeggero
non è più ritrovabile dal sito alla prossima iscrizione, e va riconosciuto per nome e data
di nascita — lo stesso meccanismo del difetto 91, con le stesse cautele (nessuna conferma
accettata, identità non modificabile).

Da decidere prima del go-live.

---

## 1-bis. ⚠️ Lo step 5 chiede la camera nell'ordine sbagliato — **da analizzare in PIANIFICAZIONE**

**Segnalato dall'utente il 2026-09-05**, subito dopo il gruppo G: *«così come è oggi mi
sembra complicato per l'utente e foriero di errori»*.

### Come funziona adesso

Per un'iscrizione con **1 o 2 persone** (Modalità A) il sito mostra una fila di card di
tipi camera **per ciascun partecipante**. Una coppia deve quindi scegliere «CAMERA
MATRIMONIALE» **due volte** — una per il pilota e una per il passeggero. Solo *dopo*, e
solo se le due scelte coincidono e la camera ha almeno due posti, compare la domanda:
**«dormite nella stessa camera?»**

Con **3 o più persone** (Modalità B) l'interazione cambia del tutto: un mini-wizard che
compone una camera alla volta. Due modi diversi di fare la stessa cosa, a seconda di
quanti si è.

### Il problema

⚠️ **La domanda arriva alla fine, quando invece è quella che dovrebbe guidare tutto.**
«Dormite nella stessa camera?» è la prima cosa che una coppia sa di sé, e se la si
chiedesse subito indirizzerebbe la scelta invece di doverla convalidare a posteriori.
Così com'è, si chiede alla persona di esprimere due volte una scelta che è una sola, e poi
le si chiede se intendeva davvero quello che ha appena fatto.

**Una precisazione sul rischio, verificata nel codice** (`handleModeAConfirm`): rispondendo
**no** non si ottengono due matrimoniali. Il sito rifiuta con un messaggio — «Non puoi
assegnare una camera da più posti a una sola persona» — e fa ricominciare. Quindi
l'assegnazione sbagliata *non* viene registrata, ed è già qualcosa. ⚠️ Ma il costo resta:
la persona ha compiuto tre scelte, ne ha sbagliata una che non sapeva di poter sbagliare, e
deve rifare tutto. Il difetto è di percorso, non di dato.

### Cosa dovrà considerare l'analisi

Va fatta **entrando in modalità di pianificazione**, com'è stato chiesto, prima del
passaggio in produzione. I casi da coprire, tutti reali per un'iscrizione fino a quattro
persone:

| Caso | Cosa deve poter esprimere |
|---|---|
| Una persona sola | Singola, o doppia uso singola (con supplemento) |
| Coppia che dorme insieme | Una camera per due — matrimoniale o due letti |
| Due persone che dormono separate | Due camere da una persona ciascuna |
| Tre persone | Una tripla, oppure una doppia + una singola |
| Quattro persone | Due doppie, doppia + due singole, quadrupla… |
| Genitore con minore | Chi sta con chi non è deducibile dai dati |

⚠️ Da tenere presente in ogni ipotesi:

- **Il costo cambia**: le camere con `supplemento = 'Y'` costano di più, quindi un errore
  di assegnazione non è solo un fastidio — si traduce in un preventivo sbagliato.
- **La capienza è un vincolo del database**: `ana_tipo_alloggio.tipo_alloggio_numero_occupanti`,
  e le assegnazioni stanno in `mov_clienti_alloggi` (sei posti per riga).
- **Le due modalità andrebbero riconciliate**: se una via funziona per quattro persone,
  probabilmente funziona anche per due, e si toglie di mezzo un secondo percorso da
  mantenere e da collaudare.
- **La domanda giusta viene prima**: prima *chi sta con chi*, poi *in che tipo di camera*.
  È l'ordine in cui la gente pensa alla propria sistemazione.

---

## 2-bis. L'indirizzo del sito SFT è scritto dentro il codice

**Annotato il 2026-09-05** durante il test G4. Il bottone **Esci** dell'ultima modale del
sito di iscrizione porta a `https://www.sardegnafuoritraccia.it/it`, scritto a mano dentro
`static/js/components/SimpleSummaryModal.jsx`.

È il sito **attuale**. Quando andrà online quello nuovo, chi si è appena iscritto verrebbe
mandato sul vecchio — e nessuno se ne accorgerebbe, perché la pagina esiste ed è di SFT.

⚠️ Non è solo un indirizzo da cambiare: **non dovrebbe stare nel codice**. L'indirizzo
della segreteria e i parametri SMTP arrivano già dalla configurazione dell'azienda; questo
no, ed è per azienda tanto quanto gli altri. Va spostato lì, così il giorno del cambio si
aggiorna un dato invece di ricompilare il sito.

---

## 3. Pagina pubblica di iscrizione alla newsletter (Fase 3)

**Decisa il 2026-09-04.** Serve un indirizzo condivisibile — su WhatsApp, sui social, in
firma alle mail — che porti a una pagina dove chiunque può iscriversi alla newsletter
senza iscriversi a un viaggio.

Regole già fissate: chi si iscrive da lì **ed è già cliente** non crea un doppione, si
aggiorna la sua scheda; **niente doppia conferma via email** (decisione esplicita
dell'utente). Va realizzata insieme al sito nuovo, non prima: è una pagina pubblica, e
oggi il sito pubblico non c'è ancora.

---

## 4. Import degli iscritti raccolti dal vecchio sito

**Da ricordare al go-live.** Antonio ha già raccolto indirizzi con il vecchio sito, che
non sono nel gestionale. Vanno portati dentro **al momento del go-live**, altrimenti la
prima newsletter parte a un pubblico più piccolo di quello reale.

⚠️ Sono contatti che hanno acconsentito **altrove**: al momento dell'import va registrato
da dove viene il consenso (`consenso_marketing_fonte` esiste apposta), non trattato come
se l'avessero dato qui.

---

## 5-bis. Il gestionale accettava QUALUNQUE certificato TLS — **RISOLTO il 2026-09-05**

`Services/Email/SmtpEmailSender.cs` faceva `(s, c, h, e) => true`: qualunque certificato
andava bene. Un intermediario con un certificato inventato sarebbe stato accettato, e con
lui **utenza e password della casella**. ⚠️ Era l'esatto contrario della vulnerabilità
chiusa aggiornando MailKit (difetto 84).

**La diagnosi è cambiata due volte, e solo la terza era giusta.** Vale la pena scriverlo,
perché le prime due sembravano ragionevoli:

1. *«Il certificato del server è valido, ma .NET non conosce la radice `ISRG Root YR`.»*
   Plausibile — OpenSSL validava, .NET no. **Sbagliato.**
2. *«Serve fissare la radice per impronta.»* Conseguenza della prima. Sarebbe stata una
   soluzione fragile, da aggiornare a ogni rinnovo. **Sbagliata anche questa.**
3. **Quella vera**, ottenuta stampando la catena che .NET costruisce davvero:

```
elementi della catena costruita da .NET: 4
  CN=sardegnafuoritraccia.it
      ⚠️ RevocationStatusUnknown: An incomplete certificate revocation check occurred.
  CN=YR1, O=Let's Encrypt
  CN=Root YR, O=ISRG
  CN=ISRG Root X1, O=Internet Security Research Group
```

.NET la catena la costruisce **per intero**, fino a `ISRG Root X1` che macOS conosce
benissimo. L'unico rilievo è che **non riesce a completare il controllo di revoca** — cosa
comune da quando Let's Encrypt ha dismesso OCSP. Il certificato è valido, la catena è
attendibile: mancava solo un'informazione accessoria.

⚠️ La lezione: ho dedotto due volte una diagnosi da un sintomo («.NET rifiuta») invece di
chiedere al programma *perché* rifiutava. La risposta era a una `Console.WriteLine` di
distanza.

### La cura

Nuovo `Services/Email/CertificatoServerPosta.cs`: si valida tutto e si tollera **solo**
l'impossibilità di verificare la revoca. Nome che non corrisponde, certificato scaduto,
catena che non arriva a una radice attendibile, firma non valida — tutto il resto è
rifiutato. E quando si accetta per la revoca, **lo si scrive nel registro**: se un giorno
quel messaggio cambia, si vede.

Provato contro server veri e ostili:

| Server | Esito | Perché |
|---|---|---|
| `mail.sardegnafuoritraccia.it` | ✅ accettato | `RevocationStatusUnknown` |
| `smtp.gmail.com` | ✅ accettato | certificato valido per sé |
| `expired.badssl.com` | ⛔️ rifiutato | `NotTimeValid` |
| `self-signed.badssl.com` | ⛔️ rifiutato | catena non attendibile |
| `wrong.host.badssl.com` | ⛔️ rifiutato | nome che non corrisponde |

---
## 5. Debiti tecnici già individuati

| Cosa | Perché aspetta |
|---|---|
| **Passaggio a MudBlazor 9** | Risolverebbe alla radice i difetti #9090 e #11217 della libreria, aggirati a mano nei campi data (vedi `Documents/Digitazione_Date.md`). È un cambio di versione maggiore: **dopo** il go-live, mai durante un collaudo. |
| **Componente condiviso `CampoData`** | I campi data ripetono in 33 punti picker + convertitore + classe CSS + `TextUpdateSuppression`. Incapsularli in un componente solo è quanto chiede `ComponentiShared.md`, e farebbe sparire la soppressione di MUD0002 dal `.csproj` (vedi `Documents/Digitazione_Date.md`). Rimandato: tocca 33 punti di chiamata, non durante un collaudo. |
| **Rilettura dal database aprendo una modifica** | Fatte le cinque che contano — viaggi, partenze, movimenti contabili, clienti, controparti (difetti 93 e 94). Restano le **tabelle di appoggio**, che l'utente ha deciso di lasciare come sono: cambiano una volta l'anno e il problema è teorico. Sulle altre si modifica la fotografia presa al caricamento dell'elenco, col rischio di salvare dati vecchi sopra a quelli nuovi (difetto 93). Da valutare caso per caso: su una tabella di appoggio che cambia una volta l'anno è teorico, su anagrafiche e movimenti no. |
| **Ristrutturazione di `Step2Content.jsx`** | Il file è cresciuto troppo e concentra troppe responsabilità. Rimandato di proposito a fine test: rifarlo mentre lo si sta collaudando vanifica il collaudo. |
| **Analisi iscrizioni e assegnazione camere** | Controlli probabilmente doppi e divergenti fra MAUI e Flask, come lo erano per `ana_clienti`. Stesso metodo: misurare su PROD prima di scrivere. Vedi `Documents/2026-08-20-Analisi_Validazioni_e_CRUD_AnaClienti.md`. |

---

## 6. Clienti iscritti ai viaggi di un'altra azienda — **RISOLTO il 2026-09-05**

Era il residuo dell'importazione da Oracle. Scelta la strada di creare le anagrafiche
mancanti nell'azienda del viaggio (`SqlScripts/587-588-589`), e aggiunta la guardia che
impedisce di rifarlo. Vedi il **difetto 83** nelle note di rilascio.

⚠️ **Resta aperto, ma è un'altra cosa**: l'azienda 6 in produzione non ha ragione di
esistere (parole dell'utente, 2026-09-05). Va affrontato separatamente — qui si è solo
fatto in modo che il confine fra le due aziende sia reale finché ce ne sono due.

---

## Unicità dell'anagrafica: un confronto su più campi, obbligatorio

**Deciso il 2026-09-07** da Adriano, dopo aver misurato i doppioni veri di PROD: «anche lì
dobbiamo avere una protezione e l'unica è un confronto su più campi anagrafici. Obbligatorio.»
Vale **su entrambi i lati**: gestionale e sito. Da completare come analisi e poi realizzare —
altrimenti il database continua a sporcarsi.

### Perché non basta l'email

Erano state considerate, e scartate sui dati veri:

| Rimedio | Avrebbe fermato MAIORCA? | Avrebbe fermato TACCA? |
|---|---|---|
| `cliente_email` UNIQUE | ⛔️ no — la riga doppia **non aveva email** | ⛔️ no — due indirizzi diversi (`.sa` / `.ta`) |
| OTP di verifica dell'indirizzo | ⛔️ no — creata dalla segreteria, non dal sito | ⛔️ no — entrambi gli indirizzi sono suoi |
| **Identità: cognome + nome + data di nascita** | ✅ sì | ✅ sì |

⚠️ **Nessuno dei due doppioni di produzione sarebbe stato impedito da email obbligatoria +
unica + OTP. Entrambi lo sarebbero stati dal confronto anagrafico.**

E l'email obbligatoria ha un costo che si ritorce: i 7 clienti della segreteria che hanno
viaggiato senza indirizzo, e le tre coppie che ne condividono uno, sarebbero **costretti a
inventarne uno** — cioè proprio le email finte che si vogliono evitare.

### Il dato che orienta il lavoro

Clienti di azienda 2 per origine: **163 creati dalla segreteria** nel gestionale, **32 dal
sito**, 8 non registrati, 2 da Adriano. L'80% non passa dal sito: ⚠️ **una protezione che viva
solo nel sito lascia scoperta la strada da cui arrivano quattro clienti su cinque.** Deve stare
a database.

### Cosa c'è già, e cosa manca

La regola **esiste**, in `fn_ana_clienti_verifica_duplicato`: codice fiscale se c'è, altrimenti
cognome + nome + data di nascita + comune di nascita, col commento «l'omonimia esiste, ma non
alla stessa data e nello stesso comune di nascita». Manca il **vincolo** che la renda
inaggirabile: oggi è una funzione che si può non chiamare.

⚠️ Da decidere in analisi: la funzione usa anche il **comune di nascita**, ma su due delle tre
coppie di PROD i coniugi sono nati nello stesso comune — quindi come vincolo va valutato se
includerlo (più permissivo) o fermarsi a cognome + nome + data di nascita (più severo).
Attenzione ai clienti **senza data di nascita**, che un vincolo non copre.

**Stato di PROD al 2026-09-07:** dopo la cancellazione della MAIORCA doppia resta **1 gruppo in
violazione** (TACCA ALESSANDRO, 4377 e 4381 — la 4377 non ha iscrizioni). Sistemato quello, il
vincolo si può creare.

### L'OTP resta, ma per un'altra ragione

Non serve contro i doppioni. Serve a garantire che l'indirizzo esista e sia raggiungibile:
protegge la conferma d'iscrizione, blocca le iscrizioni fasulle, e ⚠️ **rafforza il consenso** —
un consenso raccolto a un indirizzo mai verificato è debole proprio dove conta.
⚠️ Da progettare con una via d'uscita: aggiunge un passaggio nel momento in cui la persona sta
decidendo di iscriversi, e lega l'iscrizione al funzionamento della posta.
