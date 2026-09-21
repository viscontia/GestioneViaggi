# Cosa c'è di nuovo nella versione 2.2

**Per Antonio — 21 settembre 2026**
Versione precedente: 2.1 del 14 settembre.

Questa versione porta **tre cose nuove** e sistema una serie di difetti, quasi tutti nella parte
contabile. Non devi fare niente di particolare: installa e trovi tutto al suo posto.

---

## Le tre cose nuove

### 1. Il calendario delle partenze, nella pagina iniziale

Aprendo il programma trovi il **calendario dei viaggi** con le partenze del mese.

Si apre **sul mese della prossima partenza**, non sul mese corrente: a novembre, con il primo
viaggio a marzo, non ti ritrovi davanti una pagina vuota. Passando il mouse su una partenza vedi
quanti partecipanti ci sono e **quanti mezzi** — che per un tour offroad è il numero che conta
davvero, perché le persone si ridistribuiscono ma i mezzi no.

### 2. Trovare il viaggio giusto in due mosse, nei movimenti contabili

Sopra la casella **Viaggio** della scheda movimenti ci sono tre pulsanti, con fra parentesi quanti
viaggi contiene ciascuno:

| | Cosa mostra | In che ordine |
|---|---|---|
| **TUTTI I VIAGGI** | tutta l'anagrafica | alfabetico |
| **GIÀ EFFETTUATI** | quelli con almeno una partenza conclusa | **dal più recente** |
| **DA EFFETTUARE** | quelli con una partenza in arrivo | **dalla più vicina** |

Serve soprattutto quando **fatturi**: una fattura si emette quasi sempre sul viaggio appena
concluso, e con *GIÀ EFFETTUATI* te lo trovi in cima invece di cercarlo in mezzo agli altri. Per le
**caparre** vale il contrario: *DA EFFETTUARE* mette per prima la partenza più vicina.

Un viaggio che si ripete ogni anno compare in **tutti e due** gli elenchi: ha partenze già fatte e
partenze ancora da fare.

### 3. Le modalità di pagamento

Questa è la novità più utile per la contabilità, ed è in tre pezzi.

**a) Una tabella nuova** — *Tabelle → Tabelle Contabili → Modalità di Pagamento*. La trovi **già
piena**, con quindici modalità: rimessa diretta, contanti, carta, assegno, caparra, bonifico a 30 /
60 / 90 giorni (data fattura o fine mese), ricevuta bancaria, MAV, addebito SEPA. Puoi aggiungerne
e modificarle come qualsiasi altra tabella.

**b) Ogni cliente o fornitore ha la sua** — nella sua scheda c'è *Modalità di pagamento abituale*:
la scegli **una volta sola**. Nell'elenco delle controparti una colonna ti mostra il codice, così
vedi a colpo d'occhio chi ce l'ha e chi no.

**c) Nei movimenti arriva da sola** — appena scegli l'interlocutore, la sua modalità compare e
**calcola la data di scadenza**. Puoi sempre cambiarla: l'accordo abituale non ti impedisce
l'eccezione.

> ⚠️ **«Data fattura» e «fine mese» non sono la stessa cosa**, ed è l'errore che fa litigare sulle
> scadenze. Con *fine mese* i giorni non partono dalla data della fattura ma dall'**ultimo giorno
> del mese** in cui cade:
>
> | Fattura del | Con `60DF` scade il | Con `60FM` scade il |
> |---|---|---|
> | 3 marzo | 2 maggio | **30 maggio** |
>
> Quando crei o modifichi una modalità, sotto ai campi c'è un'**anteprima** che ti dice quando
> scadrebbe una fattura di oggi con quei termini. Guardala prima di salvare.

ℹ️ Ogni modalità porta con sé anche i codici che servono alla **fattura elettronica** (MP05 per il
bonifico, MP12 per la ricevuta bancaria, e così via). Sono già impostati su tutte e quindici: non
devi fare niente, ma quando arriverà il momento dell'XML saranno già al loro posto.

---

## Quello che prima non funzionava

### Le stampe

⛔️ **Le stampe dei bilanci non partivano affatto.** Un difetto nel database le bloccava sul
nascere. Corretto.

⛔️ **Le altre stampe contabili** — movimenti, scadenzario, registro IVA, fattura attiva — si
fermavano **appena mettevi un filtro sulle date**, cioè quasi sempre. Corretto.

**L'elenco delle fatture da stampare** non compariva: la pagina aspettava che premessi *Cerca*, e
in più un filtro lasciato in bianco filtrava lo stesso. Ora l'elenco si apre già pieno.

### La scheda dei movimenti contabili

Era la parte più fragile e ci abbiamo lavorato parecchio:

* **la scheda non si chiude più per sbaglio.** Prima bastava un clic fuori dalla finestra, il tasto
  Esc o — la peggiore — **una rotellata del mouse**, e tutto quello che avevi scritto spariva senza
  una domanda. Ora si esce dal pulsante *Annulla*, che ti chiede conferma se c'è qualcosa da
  perdere. Vale per **tutte** le finestre del programma, non solo per questa;
* **la casella del viaggio si apriva vuota**, o piena di righe senza testo. Ora mostra i viaggi con
  il nome e la nazione;
* **l'aliquota IVA scelta non si vedeva** in colonna: restava un quadratino grigio. Ora si legge il
  codice, prima e dopo averla scelta, e nella ricerca trovi anche i codici tipo `N2.2`;
* la lente di ricerca finiva **sopra** la colonna IVA, e le freccette coprivano gli importi a
  quattro cifre. Sistemate tutte e due.

### I conti

⚠️ **Il margine dei viaggi era più alto del vero**, per chi è in regime forfettario. Il programma
calcolava il margine sull'imponibile anche sui costi, ma chi non detrae l'IVA **la paga davvero**:
quella parte è un costo a tutti gli effetti. Ora il margine tiene conto del regime dell'azienda.

ℹ️ La guida alle registrazioni contabili prometteva una cosa che il programma non fa (lo
«scorporo» dell'IVA dal totale). Testo corretto: nelle righe di dettaglio si scrive sempre
l'**imponibile**, mai il totale.

---

## Il manuale della contabilità

Insieme a questa versione trovi un manuale nuovo: **Manuale_Contabilita.pdf**.

Spiega come è fatta una registrazione, come la causale decide quasi tutto, il calcolo automatico
delle righe, le modalità di pagamento (capitolo 7), il protocollo IVA, le stampe e la fattura
elettronica. Se c'è una sola cosa da leggere di questa consegna, è quella.

---

## In una riga

Il calendario in prima pagina, i viaggi che si filtrano fra fatti e da fare, le modalità di
pagamento che calcolano le scadenze — e la contabilità che finalmente stampa.
