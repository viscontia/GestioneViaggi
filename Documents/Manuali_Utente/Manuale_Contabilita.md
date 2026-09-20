# Manuale — La contabilità

**A chi è rivolto**: chi registra fatture, incassi e pagamenti, e chi produce le stampe fiscali. Nessuna conoscenza tecnica richiesta.

> ### 📌 Riferito a **Gestione Viaggi 2.2** · manuale aggiornato il **20 settembre 2026**
>
> ⚠️ **Controlla che il numero corrisponda** a quello che leggi in basso nella barra di stato del
> programma. Se non corrisponde, questo manuale può descrivere schermate diverse da quelle che
> hai davanti: chiedi la versione aggiornata prima di seguirlo.


---

## Perché questo manuale

La contabilità del gestionale non è un blocco note dove si annotano importi: è il posto da cui
escono il **registro IVA**, il **bilancio di un viaggio** e i **file per l'Agenzia delle Entrate**.
Per poterli produrre, il programma pretende che le registrazioni siano fatte in un certo modo — e
quando rifiuta qualcosa, lo fa per una ragione.

Questo manuale spiega **prima il perché, poi i tasti**. Chi conosce il perché sbaglia meno, e
soprattutto capisce i messaggi di rifiuto invece di cercare un modo per aggirarli.

⚠️ **La regola da cui dipende tutto:** è la **causale** che decide il comportamento del programma —
se è un costo o un ricavo, se serve la scadenza, se la registrazione entra nel registro IVA. Non è
un'etichetta: è un interruttore.

---

## Indice

1. [Com'è fatta una registrazione](#1-comè-fatta-una-registrazione)
2. [La causale decide quasi tutto](#2-la-causale-decide-quasi-tutto)
3. [Il regime fiscale e il calcolo automatico delle righe](#3-il-regime-fiscale-e-il-calcolo-automatico-delle-righe)
4. [Registrare un movimento, campo per campo](#4-registrare-un-movimento-campo-per-campo)
5. [Le righe di dettaglio e i totali](#5-le-righe-di-dettaglio-e-i-totali)
6. [Le date e i controlli che non si aggirano](#6-le-date-e-i-controlli-che-non-si-aggirano)
7. [Le modalità di pagamento](#7-le-modalità-di-pagamento)
8. [Le valute diverse dall'euro](#8-le-valute-diverse-dalleuro)
9. [Il protocollo IVA, e perché poi non si cancella più](#9-il-protocollo-iva-e-perché-poi-non-si-cancella-più)
10. [Incassi e pagamenti: «Paga Ora»](#10-incassi-e-pagamenti-paga-ora)
11. [Collegare un movimento a un viaggio](#11-collegare-un-movimento-a-un-viaggio)
12. [Trovare quello che cerchi nell'elenco](#12-trovare-quello-che-cerchi-nellelenco)
13. [Le stampe contabili](#13-le-stampe-contabili)
14. [La fattura elettronica per lo SDI](#14-la-fattura-elettronica-per-lo-sdi)
15. [Le tabelle contabili](#15-le-tabelle-contabili)
16. [Riepilogo in una pagina](#16-riepilogo-in-una-pagina)

---

## 1. Com'è fatta una registrazione

Ogni movimento contabile ha **due piani**, e confonderli è l'errore di partenza più comune:

| | Cos'è | Cosa contiene |
|---|---|---|
| **Testata** | Il documento nel suo insieme | Data, causale, controparte, importo, valuta, numero e data del documento, scadenza, stato |
| **Righe di dettaglio** | Di cosa è fatto quell'importo | Una o più righe, ognuna con descrizione, tipo, imponibile e aliquota IVA |

**Perché non basta un importo solo.** Una fattura da 1.042 € non è «1.042 €»: è una prestazione,
più eventualmente una rivalsa previdenziale, più un bollo — ognuna con la sua aliquota IVA. Il
registro IVA e la fattura elettronica hanno bisogno di quella scomposizione, non del totale. Se le
righe mancano o non quadrano, il documento non si può produrre.

ℹ️ Dentro la scheda di registrazione, in alto, c'è un pulsante **«Guida»** che riassume queste
stesse regole a video.

---

## 2. La causale decide quasi tutto

La **causale contabile** è il secondo campo che compili, ed è quello che cambia il comportamento di
tutti gli altri. Ogni causale porta con sé quattro informazioni:

| Informazione | Cosa determina |
|---|---|
| **Ciclo** (Attivo / Passivo) | ⭐️ Se è un **ricavo** o un **costo**. Cambia l'etichetta del campo controparte in *Cliente* o *Fornitore*, e il movimento diventa ENTRATA o USCITA |
| **Genera IVA** | Se la registrazione entra nel **registro IVA** e riceve un protocollo (capitolo 9) |
| **Richiede scadenza** | Se la **data di scadenza diventa obbligatoria**. Tipico delle fatture, inutile per un incasso immediato |
| **Tipo documento SDI** | Il codice (TD01, TD04…) che serve alla **fattura elettronica** |

Nell'elenco dei movimenti la causale è una pastiglia colorata: **verde** per i ricavi, **rossa** per
i costi. È il modo più rapido di vedere se hai sbagliato causale.

⛔️ **Cambiare causale a registrazione già fatta non è indolore**: cambia il ciclo, e con esso il
significato contabile del movimento. Se hai sbagliato, verifica dopo il cambio che controparte,
scadenza e righe abbiano ancora senso.

ℹ️ Le causali si creano e si modificano in **Tabelle → Tabelle Contabili → Causali** (capitolo 15).
Sono per azienda: ognuna ha le sue.

---

## 3. Il regime fiscale e il calcolo automatico delle righe

Ogni azienda ha un **regime fiscale** — Ordinario, Forfettario o Semplificato — impostato nella sua
anagrafica. Non è un'informazione decorativa: determina le aliquote IVA predefinite, se esiste una
cassa previdenziale e se scatta l'imposta di bollo.

### ⭐️ «Applica Calcolo Regime»

Per le aziende il cui regime lo prevede, sopra le righe di dettaglio compare il pulsante **«Applica
Calcolo Regime»**. Scrivi l'importo della prestazione, lo premi, e il programma **genera le righe
al posto tuo**, nell'ordine giusto.

**Esempio — regime forfettario, prestazione da 1.000,00 €:**

| # | Riga | Importo | Perché |
|---|---|---|---|
| 1 | PRESTAZIONE | 1.000,00 | L'importo che hai scritto |
| 2 | RIVALSA INPS 4% | 40,00 | Il 4% previsto dal regime |
| 3 | IMPOSTA DI BOLLO | 2,00 | Perché 1.000 + 40 supera la soglia di 77,47 |

✅ **Fa il conto che sbaglieresti tu.** La soglia del bollo si calcola sulla prestazione **più** la
cassa previdenziale, non sulla sola prestazione: è il dettaglio che si dimentica.

ℹ️ **Se il pulsante non c'è**, il regime dell'azienda non prevede un calcolo automatico — è il caso
del regime ordinario. Le righe si compilano a mano, ed è normale.

⚠️ I parametri (percentuali, soglie, codici IVA) **non sono scritti nel programma**: stanno in una
tabella che l'amministratore può correggere se la legge cambia, senza che serva una nuova versione
del gestionale. Se un valore ti sembra sbagliato, è una configurazione da rivedere, non un difetto
da subire.

---

## 4. Registrare un movimento, campo per campo

**Contabilità → Movimenti Contabili → «Nuova Transazione»**

| Campo | Note |
|---|---|
| **Data Transazione** ⭐️ | Obbligatoria. È la data contabile del movimento |
| **Causale Contabile** ⭐️ | Obbligatoria, e da scegliere **per prima**: cambia il resto della scheda (capitolo 2) |
| **Cliente / Fornitore** ⭐️ | L'etichetta cambia da sola secondo il ciclo della causale |
| **Descrizione** ⭐️ | Obbligatoria. È quella che leggerai nell'elenco fra sei mesi: «FATTURA» non serve a niente |
| **Importo** e **Valuta** ⭐️ | Obbligatori. Sulle valute diverse dall'euro vedi il capitolo 8 |
| **Dettaglio Righe** | Il cuore della registrazione — capitolo 5 |
| **Stato Pagamento** | Da Pagare, Pagato, Parzialmente Pagato, Annullato |
| **N. Documento** e **Data Documento** | ⚠️ **o entrambi, o nessuno dei due** |
| **Note** | Libere |
| **Modalità di Pagamento** | Arriva dall'interlocutore e calcola la scadenza; modificabile — capitolo 7 |
| **Data Scadenza** | Obbligatoria se la causale lo richiede: l'etichetta mostra l'asterisco |
| **Data Pagamento** | Da valorizzare quando il movimento è saldato |
| **Viaggio** e **Data Viaggio** | ⚠️ **o entrambi, o nessuno dei due** — capitolo 11 |

✅ **I campi di testo diventano maiuscoli da soli**: non è il tasto BLOC MAIUSC rimasto acceso, è il
programma che uniforma ciò che finirà nelle stampe.

---

## 5. Le righe di dettaglio e i totali

Sotto la testata c'è la tabella **Dettaglio Righe**. Si aggiungono con **«Aggiungi Riga»**, o tutte
insieme con «Applica Calcolo Regime» (capitolo 3).

Ogni riga ha un **tipo**, e i tipi non sono sinonimi:

| Tipo | Quando si usa |
|---|---|
| **Prestazione** | L'importo principale: il servizio venduto o la fornitura ricevuta |
| **Cassa Prev.** | La rivalsa previdenziale (es. INPS 4%), calcolata sull'imponibile della prestazione |
| **Bollo** | L'imposta di bollo, quando il totale supera la soglia di legge |
| **Spese Art.15** | Spese anticipate **in nome e per conto** del cliente: restano fuori dalla base imponibile IVA |

### ⚠️ L'imponibile che scrivi è sempre il **netto**

Su ogni riga scrivi l'**imponibile**; il programma calcola l'IVA come *imponibile × aliquota* e la
somma per ottenere il lordo. Vale **sempre**, sia sulle fatture che ricevi sia su quelle che emetti:
non esiste una modalità in cui scrivi il totale e il programma toglie l'IVA da dentro.

⛔️ **Quindi, su una fattura di acquisto, non scrivere il totale della fattura nella riga**: scrivi
l'imponibile che leggi sul documento. Altrimenti ti ritrovi l'IVA addebitata due volte.

✅ In fondo alla tabella il programma mostra **IMPONIBILE**, **IVA** e **TOTALE** calcolati dalle
righe: è il confronto da fare con il documento cartaceo prima di salvare.

ℹ️ **Se ballano pochi centesimi** rispetto al documento, correggi a mano l'imponibile di una riga
finché i totali coincidono. È l'uso previsto: gli arrotondamenti di chi ha emesso la fattura non
sono necessariamente i tuoi.

---

## 6. Le date e i controlli che non si aggirano

Le date di una registrazione devono raccontare una storia possibile. Il programma verifica che lo
facciano, e i controlli sono di due specie.

### I controlli che **bloccano**

| Regola | Perché |
|---|---|
| Numero documento e data documento: **o entrambi o nessuno** | Mezzo riferimento non serve a nessuno |
| Scadenza **≥** data documento | Non si scade prima di esistere |
| Pagamento **≥** data documento | Non si paga una fattura non ancora emessa |
| Pagamento **≥** scadenza | Il pagamento anticipato si registra con la sua data reale, non retrodatando la scadenza |
| Anno compreso fra **2000 e 2100** | È un pavimento di plausibilità |
| Scadenza obbligatoria se la causale la richiede | Senza, il movimento non comparirebbe nello scadenziario |

⛔️ **Il controllo sull'anno non è pignoleria.** In produzione è stata trovata una registrazione del
20/02/2022 con data pagamento **20/02/2202**: una cifra fuori posto, che tutti gli altri controlli
avevano superato indenne, perché fra loro erano coerenti.

### I controlli che **chiedono conferma**

Una data dentro l'intervallo ammesso ma **insolita** non viene vietata: il programma chiede se sei
sicuro. Succede per date oltre cinque anni nel futuro e per date che vanno indietro **più di un
anno**.

ℹ️ **Perché proprio un anno**: a gennaio si chiude legittimamente l'esercizio precedente, e
registrare fatture di dicembre è lavoro ordinario. Sui viaggi la tolleranza è diversa — lì una data
passata è quasi sempre un errore.

---

## 7. Le modalità di pagamento

I giorni di pagamento non sono una proprietà del tipo di documento: sono un **accordo con quella
controparte**. Due fatture identiche possono scadere a 30 e a 60 giorni, e finora andava scritto a
mano ogni volta.

### Come funziona, in tre passaggi

1. **La tabella** — *Tabelle Contabili → Modalità di Pagamento*. Nasce già piena di quindici voci;
   si aggiungono e si modificano come qualsiasi altra tabella.
2. **La controparte** — nella sua scheda c'è *Modalità di pagamento abituale*: si sceglie una volta.
   Nell'elenco delle controparti la colonna *Pagamento* mostra il codice, così si vede subito chi ce
   l'ha e chi no.
3. **Il movimento** — appena scegli l'interlocutore, la sua modalità compare da sola e **calcola la
   data di scadenza**. Puoi cambiarla: l'accordo abituale non impedisce l'eccezione.

### Le quindici modalità già pronte

| Codice | Significato |
|---|---|
| `RD` | Rimessa diretta (bonifico a vista) |
| `CONT` | Contanti alla consegna |
| `CARTA` | Carta di credito o bancomat |
| `ASS` | Assegno bancario |
| `ANTIC` | Anticipo / caparra alla prenotazione |
| `30DF` `60DF` `90DF` | Bonifico a 30, 60, 90 giorni **data fattura** |
| `30FM` `60FM` `90FM` | Bonifico a 30, 60, 90 giorni **fine mese** |
| `RIBA30` `RIBA60FM` | Ricevuta bancaria |
| `MAV` | Pagamento con MAV a 30 giorni |
| `SDD` | Addebito diretto SEPA |

ℹ️ I codici seguono la convenzione commerciale italiana, quella che si legge sulle fatture: `DF` =
data fattura, `FM` = fine mese. Non è uno standard di legge, è come si parla fra chi fattura.

### ⚠️ «Data fattura» e «fine mese» non sono la stessa cosa

È la differenza che fa litigare sulle scadenze, e vale la pena averla chiara:

| Fattura del | Con `60DF` scade il | Con `60FM` scade il |
|---|---|---|
| 3 marzo | 2 maggio | **30 maggio** |

Con **fine mese** i giorni non partono dalla data della fattura ma dall'**ultimo giorno del mese in
cui cade**. Quasi un mese di differenza.

✅ Quando crei o modifichi una modalità, sotto ai campi c'è un'**anteprima**: ti dice quando
scadrebbe una fattura di oggi con quei termini. Guardala prima di salvare.

### Quando la scadenza viene ricalcolata

| Situazione | Cosa succede alla data di scadenza |
|---|---|
| Scegli l'interlocutore e il campo scadenza è **vuoto** | Viene calcolata |
| Scegli l'interlocutore e la scadenza **c'è già** | Non viene toccata (te lo dice sotto il campo) |
| Scegli tu una modalità dalla tendina | Viene **sempre** ricalcolata: l'hai chiesto tu |
| Cambi la data del documento | Segue la nuova data |

ℹ️ Sotto alla tendina compare sempre una riga che spiega cosa è successo e da dove arriva la
proposta. Se una controparte non ha una modalità abituale, te lo dice — così non sembra un
caricamento fallito.

### Per la fattura elettronica

Ogni modalità porta con sé anche i due codici che il **Sistema di Interscambio** pretende:

* **ModalitaPagamento** — da `MP01` a `MP23`: come si paga (MP01 contanti, MP05 bonifico,
  MP08 carta, MP12 RIBA, MP19 SEPA Direct Debit…);
* **CondizioniPagamento** — `TP01` a rate, `TP02` pagamento completo, `TP03` anticipo.

Sono già impostati su tutte e quindici le modalità di partenza: non c'è niente da fare, se non
compilarli quando aggiungi una modalità tua.

### Cosa non fa

⛔️ **Niente rate multiple** («30/60/90 giorni»). Un movimento ha una sola data di scadenza, e un
campo che il programma poi ignora sarebbe peggio che non averlo. Se servirà, si farà insieme alle
scadenze multiple.

ℹ️ La modalità resta scritta **anche sul movimento**, non solo sulla controparte. Serve a sapere
cosa era stato pattuito allora: se domani rinegozi con quel fornitore, le fatture già registrate
non cambiano condizioni da sole.

---

## 8. Le valute diverse dall'euro

Se la valuta della transazione **non è l'euro**, il programma cambia comportamento:

- ⛔️ **L'IVA non viene calcolata**: l'intero importo è considerato costo. Le righe restano, ma con
  IVA a zero e lordo uguale all'imponibile.
- ✅ Il **controvalore in euro** viene calcolato con il tasso di cambio della **data del documento**,
  e il programma va a cercarlo da solo.
- ℹ️ Riaprendo la registrazione, un riquadro mostra il controvalore ottenuto e da quale importo.

⚠️ **Se il tasso non è recuperabile** (nessuna connessione, o data per cui il tasso non esiste), il
salvataggio **riesce lo stesso** ma compare un avviso. Non ignorarlo: senza tasso, quel movimento
peserà zero nei bilanci in euro. I tassi si consultano e si correggono in **Tabelle → Tabelle
Contabili → Storico Tassi**.

⛔️ Una transazione in valuta estera **non riceve il protocollo IVA** e non entra nel registro IVA
(capitolo 9). È voluto: il registro IVA italiano è in euro.

---

## 9. Il protocollo IVA, e perché poi non si cancella più

Quando salvi, il programma assegna in automatico un **numero di protocollo IVA** — ma solo se
ricorrono **tutte e tre** queste condizioni:

1. la **causale genera IVA**;
2. la valuta è l'**euro**;
3. lo stato **non** è *Annullato*.

La numerazione è **progressiva per azienda, per anno e per ciclo**: le fatture di vendita e quelle
di acquisto hanno due serie separate, e ogni anno riparte da 1. L'anno si prende dalla **data del
documento**.

> ### ⛔️ Una registrazione con protocollo **non si elimina**
>
> Provandoci, il programma rifiuta e dice perché. Non è un capriccio: quel numero è già stato usato
> nel registro IVA, e cancellarlo lascerebbe un **buco nella numerazione** — che in una verifica è
> esattamente la cosa che non si può spiegare.
>
> ✅ **Cosa fare invece**: apri la registrazione e portala allo stato **Annullato**. Il numero resta
> occupato, il movimento non conta più, e la sequenza regge.

ℹ️ Le registrazioni **senza** protocollo — quelle che non generano IVA, quelle in valuta estera —
si eliminano normalmente.

---

## 10. Incassi e pagamenti: «Paga Ora»

Nell'elenco, sulle righe in stato *Da Pagare* o *Parzialmente Pagato*, compare l'icona 💳 **Paga
Ora**. Apre una finestrella dove indichi **importo**, **data** ed eventuali **note**.

**Cosa succede davvero:** il programma **crea una seconda registrazione** — un pagamento o un
incasso, secondo il ciclo — collegata a quella di partenza, e ne aggiorna lo stato.

✅ **Perché non si limita a cambiare lo stato:** il pagamento è un fatto contabile per conto suo, con
una data che quasi mai coincide con quella della fattura. Tenerli separati è ciò che permette allo
scadenziario di dire cosa è aperto **a una certa data**.

- ⚠️ L'importo **non può superare il residuo**: il programma lo rifiuta.
- Pagando meno del dovuto, lo stato diventa **Parzialmente Pagato** e la riga resta nell'elenco dei
  da pagare, per la parte restante.

### Gli stati, e i colori

| Stato | Colore | Significato |
|---|---|---|
| **Da Pagare** | arancio | Aperto |
| **Parzialmente Pagato** | blu | Incassato o pagato in parte |
| **Pagato** | verde | Chiuso |
| **Annullato** | rosso | Registrazione annullata, resta per storia |

---

## 11. Collegare un movimento a un viaggio

In fondo alla scheda ci sono **Viaggio** e **Data Viaggio**. Sono facoltativi, ma ⚠️ **o li compili
entrambi o nessuno dei due**: il programma rifiuta il salvataggio a metà, perché un costo attribuito
a un viaggio senza sapere a quale **partenza** non è attribuibile a niente.

✅ **Vale la pena farlo**, ed è il motivo per cui la funzione esiste: solo i movimenti collegati
finiscono nel **Bilancio del viaggio** (capitolo 13), che è il documento che dice se una partenza ha
guadagnato o perso. Un costo non collegato scompare dal conto di quella partenza — e il margine che
leggi risulta migliore del vero.

ℹ️ Il collegamento si può aggiungere anche dopo, riaprendo la registrazione.

### Trovare il viaggio giusto senza scorrere tutta l'anagrafica

Sopra la tendina **Viaggio** ci sono tre pulsanti, con fra parentesi quanti viaggi contiene
ciascuno:

| Pulsante | Cosa mostra | Con quale ordine |
|---|---|---|
| **TUTTI I VIAGGI** | tutta l'anagrafica | alfabetico |
| **GIÀ EFFETTUATI** | i viaggi con almeno una partenza conclusa | **dal più recente**: in cima quello appena chiuso |
| **DA EFFETTUARE** | i viaggi con una partenza in corso o futura | **dalla più vicina**: in cima la prossima |

✅ Serve soprattutto in **fatturazione attiva**: una fattura si emette quasi sempre sul viaggio
appena concluso, e con *GIÀ EFFETTUATI* te lo trovi in cima invece di cercarlo in mezzo agli altri.
Per le **caparre** vale il contrario: *DA EFFETTUARE* mette per prima la partenza più vicina.

ℹ️ Un viaggio che si ripete ogni anno compare in **entrambi** gli elenchi: ha partenze già fatte e
partenze ancora da fare, ed è giusto trovarlo sia di qua sia di là.

ℹ️ I tre pulsanti guardano il **calendario delle partenze**, non la spunta «effettuato»: un viaggio
che nessuno si è ricordato di spuntare resta comunque fra quelli da fatturare.

ℹ️ Il filtro non viene ricordato: ogni volta che apri una registrazione riparte da *TUTTI I VIAGGI*.
E il viaggio che hai già scelto resta sempre visibile, anche se cambi filtro.

---

## 12. Trovare quello che cerchi nell'elenco

La pagina **Movimenti Contabili** ha una fila di filtri che si combinano fra loro:

| Filtro | Note |
|---|---|
| **Viaggio** | Abilita il filtro sulla data viaggio |
| **Data Viaggio** | Disponibile solo dopo aver scelto un viaggio |
| **Causale** | Un tipo di documento alla volta |
| **Data Movimento** | Un giorno preciso |
| **Solo da Pagare** | ⭐️ La spunta che si usa più spesso: mostra solo ciò che è ancora aperto |
| **Reset** | Toglie tutti i filtri in un colpo |

Le icone su ogni riga: ✏️ modifica, 💳 paga (solo se aperto), 🖨 stampa fattura (solo sulle fatture
attive), 🗑 elimina.

---

## 13. Le stampe contabili

Stanno tutte sotto **Stampe Contabili**. Ognuna apre una finestrella di parametri e produce un PDF.

| Stampa | A cosa serve | Parametri principali |
|---|---|---|
| **Stampa Movimenti Contabili** | Il giornale dei movimenti, per controlli e quadrature | Ciclo, controparte, causale, stato, intervalli di data e di importo, numero documento, *solo scadute* |
| **Scadenziario** | ⭐️ Cosa è aperto e quando scade — lo strumento per sapere chi pagare e chi sollecitare | Intervallo di scadenza, controparte, con o senza viaggio |
| **Bilancio Viaggio** | Il conto economico di **una partenza**: ricavi, costi, margine | Viaggio e data viaggio (obbligatori), valuta del report, intervallo date documento |
| **Bilancio Annuale Viaggi** | Lo stesso, ma per **tutte** le partenze di un anno | Anno, valuta del report |
| **Registro IVA** | Il registro da consegnare, in ordine di protocollo | Periodo, credito IVA del periodo precedente |
| **Stampa Fatture Attive** | Le fatture emesse, in PDF e in XML | Anno, date, cliente, importi, stato, numero |

⚠️ **Il bilancio di un viaggio vale quanto i collegamenti che hai fatto** (capitolo 11). Se un costo
non è agganciato alla partenza, lì non c'è — e il margine sembra più alto di quello che è.

> ### ℹ️ Come vengono contati i costi, secondo il regime
>
> Il bilancio somma i ricavi al netto dell'IVA — ed è giusto, perché l'IVA incassata non è un
> ricavo. Sui **costi** invece dipende dal regime fiscale dell'azienda:
>
> - **regime ordinario**: si conta l'**imponibile**, perché l'IVA sugli acquisti si recupera e
>   quindi non è un costo;
> - **regime forfettario**: si conta il **totale IVA compresa**, perché quell'IVA **non si recupera**
>   ed è denaro uscito a tutti gli effetti.
>
> ✅ **Non devi fare niente**: il programma legge il regime dell'azienda e applica la regola giusta.
> Gli importi che leggi nelle righe del report sono già quelli usati per il margine, quindi le righe
> e il totale tornano sempre.

ℹ️ Il **Registro IVA** chiede il credito del periodo precedente perché il programma non lo può
dedurre da sé: la contabilità comincia da un certo punto in poi, e prima di quel punto c'è un saldo
che conosce solo chi tiene i conti.

ℹ️ I PDF finiscono nella cartella **Download** e si aprono da soli.

---

## 14. La fattura elettronica per lo SDI

Le fatture emesse si trasformano in **file XML per l'Agenzia delle Entrate**. Due strade:

- **Stampe Contabili → Stampa Fatture Attive** — una fattura alla volta: PDF, oppure XML
- **Estrazione Dati → Estrazione Dati per SDI** — ⭐️ **«Esporta Tutti XML SDI»**, l'intero periodo
  filtrato in un colpo

I file si chiamano `IT<partita IVA>_<progressivo>.xml` e finiscono nella cartella **Download**.

### ⛔️ Il controllo prima dell'export, e come leggerlo

Prima di generare, il programma verifica che ci sia tutto quello che lo SDI pretende. Se manca
qualcosa **non genera un file monco**: mostra l'elenco puntato di cosa manca e dove.

I casi più frequenti:

| Il messaggio dice | Dove si risolve |
|---|---|
| Il cliente non ha né Partita IVA né Codice Fiscale | Anagrafica del cliente |
| Il cliente non ha né Codice Destinatario SDI né PEC | Anagrafica del cliente |
| Indirizzo, CAP o Comune mancanti | Anagrafica del cliente, o dell'azienda per la sede legale |
| L'aliquota a 0% non ha la **Natura** compilata | Tabelle Contabili → Aliquote IVA |
| Tipo documento SDI non configurato per questa causale | Tabelle Contabili → Causali |
| Codice Regime Fiscale SDI non configurato | Anagrafica azienda — serve l'amministratore |

✅ **Leggi l'elenco e correggi l'anagrafica**, poi riprova: non c'è niente da forzare. Un XML
incompleto verrebbe scartato dallo SDI, e lo scarto arriva giorni dopo.

---

## 15. Le tabelle contabili

**Tabelle → Tabelle Contabili**. Si toccano di rado, ma quando una stampa o un export si lamenta, la
risposta è quasi sempre qui.

| Tabella | Cosa contiene |
|---|---|
| **Tipi Controparti** | Le categorie di clienti e fornitori |
| **Valute** | Le valute usate; l'euro è quella di base |
| **Storico Tassi** | I tassi di cambio raccolti, per data. Qui si verifica un controvalore che non torna |
| **Causali** | ⭐️ Il cuore: ciclo, IVA, scadenza, tipo documento SDI (capitolo 2) |
| **Aliquote IVA** | Codici, percentuali e **Natura** per le aliquote a zero — quella che lo SDI pretende |
| **Modalità di Pagamento** | ⭐️ Termini e modalità: codice, giorni, fine mese, codici SDI (capitolo 7) |
| **Regimi Fiscali** | 🔒 Solo amministratore: i parametri di calcolo di ogni regime (capitolo 3) |

---

## 16. Riepilogo in una pagina

| Se devi… | Fai così |
|---|---|
| Far calcolare la scadenza da sola | Metti la modalità di pagamento nella scheda dell'interlocutore — capitolo 7 |
| Registrare una fattura ricevuta | Causale del ciclo passivo, poi righe con l'**imponibile** letto sul documento |
| Far quadrare i centesimi col cartaceo | Correggi a mano l'imponibile di una riga |
| Generare le righe di un forfettario | **Applica Calcolo Regime**, dopo aver scritto l'importo |
| Cancellare una registrazione con protocollo | Non si può: portala ad **Annullato** (cap. 9) |
| Sapere cosa devi incassare | **Scadenziario**, oppure la spunta *Solo da Pagare* nell'elenco |
| Registrare un pagamento | Icona 💳 **Paga Ora** sulla riga: crea il movimento collegato |
| Capire se un viaggio ha guadagnato | **Bilancio Viaggio** — ma solo se i costi sono collegati alla partenza |
| Mandare una fattura allo SDI | **Estrazione Dati per SDI**, e correggi l'anagrafica se il controllo si lamenta |
| Capire perché un controvalore è a zero | Manca il tasso di cambio per quella data (cap. 8) |

### Le tre cose da non fare

1. ⛔️ **Non** scrivere il totale della fattura nell'imponibile di una riga: lì va il **netto**, l'IVA la aggiunge il programma.
2. ⛔️ **Non** cercare il modo di cancellare una registrazione protocollata: si annulla, non si cancella.
3. ⛔️ **Non** lasciare i costi di un viaggio senza il collegamento alla partenza: il bilancio di quel viaggio dirà il falso, e nessun messaggio te lo segnalerà.

---

*📌 Gestione Viaggi **2.2** — manuale aggiornato il 20 settembre 2026.*
*Se aggiorni questo manuale, aggiorna anche il numero di versione qui e in testa: serve a sapere
a quale versione del programma le istruzioni si riferiscono davvero.*
