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

## 5-bis. ⚠️ Il gestionale accetta QUALUNQUE certificato TLS dal server di posta

**Trovato il 2026-09-05** verificando l'aggiornamento di MailKit.
`Services/Email/SmtpEmailSender.cs` (righe 75 e 157) fa:

```csharp
client.ServerCertificateValidationCallback = (s, c, h, e) => true;
```

Cioè: qualunque certificato va bene. Un intermediario che si mettesse in mezzo con un
certificato inventato verrebbe accettato, e con lui **utenza e password della casella**.

⚠️ È l'esatto contrario della vulnerabilità appena chiusa aggiornando MailKit
(CVE-2026-41319, un attacco dell'uomo in mezzo su STARTTLS): finché la validazione è
disattivata, la correzione della libreria protegge molto meno.

**Perché quel callback c'è, però, ha una ragione vera.** Misurato lo stesso giorno: il
certificato del server *è* valido — OpenSSL lo verifica con `Verify return code: 0 (ok)`,
catena completa fino a `ISRG Root YR` — ma **.NET su questa macchina non conosce ancora
quella radice** e riporta `RemoteCertificateChainErrors`. Togliendo il callback e basta,
l'invio smette di funzionare: provato.

Quindi non è una riga da cancellare. Va sostituita con una validazione che accetti *quella*
catena e nient'altro (radice fissata per impronta), oppure aspettando che la radice entri
nell'archivio di sistema. ⚠️ **Non durante il piano di test**: si rischia di spegnere la
posta, e la posta è appena stata collaudata (gruppo E).

---

## 5. Debiti tecnici già individuati

| Cosa | Perché aspetta |
|---|---|
| **Passaggio a MudBlazor 9** | Risolverebbe alla radice i difetti #9090 e #11217 della libreria, aggirati a mano nei campi data (vedi `Documents/Digitazione_Date.md`). È un cambio di versione maggiore: **dopo** il go-live, mai durante un collaudo. |
| **Componente condiviso `CampoData`** | I campi data ripetono in 33 punti picker + convertitore + classe CSS + `TextUpdateSuppression`. Incapsularli in un componente solo è quanto chiede `ComponentiShared.md`, e farebbe sparire la soppressione di MUD0002 dal `.csproj` (vedi `Documents/Digitazione_Date.md`). Rimandato: tocca 33 punti di chiamata, non durante un collaudo. |
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
