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

### Domande aperte (da sciogliere quando si farà, non prima)

| Nodo | Perché non è ovvio |
|---|---|
| **A chi si scrive quando si cancella un passeggero** | Il passeggero spesso **non ha un indirizzo suo** — nove volte su dieci è la compagna del pilota, e in anagrafica la mail manca. Il riferimento naturale è il pilota (`mov_clienti_viaggi.cliente_pilota_id_fk`). Probabile regola: si scrive a chi ha un indirizzo, e per il passeggero senza indirizzo si scrive al suo pilota. |
| **Cancellare un pilota che ha passeggeri** | Se il pilota salta, i suoi passeggeri restano senza mezzo. Vanno avvisati? Vanno cancellati? È una regola di prodotto, non una scelta tecnica: la risposta è di Antonio. |
| **Cambio camera: chi è «coinvolto»** | Di sicuro chi si sposta. Ma anche gli altri occupanti della camera che lascia e di quella in cui entra? Cambiare compagno di stanza è un'informazione che li riguarda — avvisarli tutti può però diventare invadente. |
| **In quale lingua** | `ana_clienti.cliente_lingua` esiste già (Blocco 10, backfill con `SqlScripts/465`). La conferma deve seguirla, come fa la newsletter: scrivere in italiano a un cliente straniero è peggio che non scrivere. |
| **Che traccia resta** | Se l'invio non viene registrato, la segreteria non sa se è partito e richiama lo stesso — cioè la funzione non elimina il lavoro che voleva eliminare. Serve una registrazione di *quando* e *a chi*, leggibile dal gestionale. |

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

## 5. Debiti tecnici già individuati

| Cosa | Perché aspetta |
|---|---|
| **Passaggio a MudBlazor 9** | Risolverebbe alla radice i difetti #9090 e #11217 della libreria, aggirati a mano nei campi data (vedi `Documents/Digitazione_Date.md`). È un cambio di versione maggiore: **dopo** il go-live, mai durante un collaudo. |
| **Ristrutturazione di `Step2Content.jsx`** | Il file è cresciuto troppo e concentra troppe responsabilità. Rimandato di proposito a fine test: rifarlo mentre lo si sta collaudando vanifica il collaudo. |
| **Analisi iscrizioni e assegnazione camere** | Controlli probabilmente doppi e divergenti fra MAUI e Flask, come lo erano per `ana_clienti`. Stesso metodo: misurare su PROD prima di scrivere. Vedi `Documents/2026-08-20-Analisi_Validazioni_e_CRUD_AnaClienti.md`. |
