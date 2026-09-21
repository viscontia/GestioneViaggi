# Note di Rilascio — Versione 2.2

> ### 📦 Pronta da compilare — 2026-09-20
> I numeri di versione sono stati portati a **2.2** nei quattro punti del codice e nell'intestazione
> dei **cinque** manuali; i PDF sono rigenerati. Resta la compilazione dell'installer e la consegna.
> Versione precedente: **2.1** del 2026-09-14 (consegnata ad Antonio).

---

## In una riga

Tre difetti veri, tutti in produzione da prima di questa versione: le stampe dei bilanci che non
partivano, il margine del forfettario più alto del vero, e un movimento contabile che non si poteva
collegare a un viaggio. Più il **calendario delle partenze** nella dashboard di chi lavora e il
manuale della contabilità, che prima non esisteva.

---

## Sezione 1 — Novità

### ⭐️ 1.1 — Il calendario delle partenze nella dashboard

Nella dashboard compare **«Calendario Partenze»**: le partenze disegnate sulla loro estensione
temporale, con il dettaglio al passaggio del mouse e il clic che porta dentro la scheda del viaggio,
sulla linguetta delle date.

⛔️ **Non è un componente nuovo: era montato solo nella dashboard del SuperAdmin.** Cioè esisteva per
chi sviluppa e non per chi lavora — ed è il motivo per cui era stato chiesto come funzione mancante.

Oltre a montarlo dove serviva, tre aggiunte:

| | |
|---|---|
| **Si apre sulla prossima partenza** | Prima apriva sul mese corrente. A novembre, con la prossima partenza a marzo, mostrava un mese vuoto: e quel vuoto non diceva «non c'è niente in programma», diceva «non c'è niente *adesso*» |
| **Mese e anno da due tendine** | Si sceglie il punto in cui posizionarsi. Niente intervalli predefiniti; le frecce avanti/indietro restano |
| **Il numero dei mezzi** | Accanto ai partecipanti, non al loro posto: su un tour offroad le persone si ridistribuiscono fra i mezzi, i mezzi no. Stesso conteggio del bilancio viaggi, per non avere due definizioni di «mezzo» |

ℹ️ Esempio dai dati veri: una partenza di Capodanno con **6 partecipanti e 4 mezzi** — è la
differenza che rende utile il secondo numero.

---

### ⭐️ 1.2 — Nei movimenti, il viaggio si trova in due mosse

Sopra la tendina **Viaggio** della scheda contabile ci sono tre pulsanti: **TUTTI I VIAGGI**,
**GIÀ EFFETTUATI**, **DA EFFETTUARE**, ognuno con il proprio conteggio.

Il motivo è pratico: una fattura attiva si emette quasi sempre sul viaggio **appena concluso**, e
l'anagrafica cresce di anno in anno (in produzione oggi sono 23 viaggi, 17 con partenze già fatte).
Scorrere un elenco alfabetico per trovare quello di due settimane fa non è il modo di lavorare di
chi fattura.

Cambia anche **l'ordine**, non solo il contenuto: *GIÀ EFFETTUATI* mette in cima la partenza più
recente, *DA EFFETTUARE* la più vicina — quella su cui si incassano le caparre.

ℹ️ Un viaggio che si ripete compare in entrambi gli elenchi, ed è corretto: ha partenze concluse e
partenze future. I pulsanti leggono il **calendario**, non la spunta «effettuato», così un viaggio
che nessuno ha spuntato non sparisce da quelli da fatturare.

ℹ️ Si parte sempre da *TUTTI I VIAGGI*, e il viaggio già scelto resta visibile anche cambiando
filtro: nessuna scelta sparisce sotto gli occhi.

---

### ⭐️ 1.3 — Le modalità di pagamento: una tabella, e la scadenza che si calcola da sola

Mancava un pezzo di contabilità. Fino a ieri i giorni di scadenza li decideva la **causale**,
uguali per tutti: «fattura fornitore = 30 giorni». Ma i giorni non sono una proprietà del tipo
di documento, sono un **accordo con quella controparte**. Un fornitore paga a 30 giorni data
fattura, un altro a 60 fine mese, l'agenzia vuole la rimessa diretta. Finora andava riscritto a
mano ogni volta — e a mano si sbaglia.

**Cosa c'è di nuovo, in tre punti.**

1. **Una tabella nuova**: *Tabelle Contabili → Modalità di Pagamento*. Nasce **già piena**, con
   quindici modalità: RD, CONT, CARTA, ASS, ANTIC, 30DF, 60DF, 90DF, 30FM, 60FM, 90FM, RIBA30,
   RIBA60FM, MAV, SDD. Si aggiungono e si modificano come qualsiasi altra tabella.
2. **Ogni controparte ha la sua**, nella sua scheda: si sceglie una volta e basta. In elenco
   compare una colonna *Pagamento* col codice, per vedere a colpo d'occhio chi ce l'ha e chi no.
3. **Nei movimenti la proposta arriva da sola** appena si sceglie l'interlocutore, e **calcola
   la scadenza**. Resta modificabile: l'accordo abituale non impedisce l'eccezione.

**Il codice mnemonico.** Per i termini non esiste uno standard di legge, esiste una convenzione
commerciale italiana consolidata — quella che si legge sulle fatture e si usa a voce: `30DF` =
30 giorni data fattura, `60FM` = 60 giorni fine mese, `RD` = rimessa diretta. È quella che
abbiamo adottato.

⚠️ **Per la fattura elettronica invece lo standard c'è, ed è obbligatorio.** Ogni modalità porta
con sé i due codici che il Sistema di Interscambio pretende: `MP01`…`MP23` per **come** si paga
(MP05 bonifico, MP12 RIBA, MP08 carta, MP19 SEPA…) e `TP01`/`TP02`/`TP03` per **quando** (a rate,
in una volta sola, anticipo). Oggi non servono a niente; il giorno in cui si genererà l'XML non
andranno indovinati, sono già accanto al termine che li riguarda.

ℹ️ **«Fine mese» è la cosa che si sbaglia più spesso**, e vale la pena dirla: i giorni non
partono dalla data della fattura ma dall'ultimo giorno del mese in cui cade. Una fattura del
**3 marzo** a «60 FM» scade il **30 maggio**, non il 2 maggio — quasi un mese di differenza, ed
è il motivo per cui si litiga sulle scadenze. Nella scheda della modalità c'è un'anteprima che
lo mostra prima di salvare.

ℹ️ **Niente rate multiple** («30/60/90»): un movimento ha una scadenza sola, e un campo che il
programma poi ignora sarebbe peggio della sua assenza. Se serviranno, si affrontano insieme alle
scadenze multiple.

ℹ️ La modalità viene salvata **anche sul movimento**, non solo sulla controparte: serve a sapere
cosa era stato pattuito allora. Se domani si rinegozia con quel fornitore, le fatture già
registrate non cambiano condizioni da sole.

---

## Sezione 2 — Correzioni

### ⛔️ 2.1 — Le stampe dei bilanci non funzionavano affatto

**Sintomo:** *Stampe Contabili → Stampa Bilancio Viaggio* e *Stampa Bilancio Annuale Viaggi* non
producevano il PDF.

**Causa:** nel database erano rimaste **tre versioni superate** delle funzioni del bilancio, non
richiamate da nessuna parte del programma ma con parametri opzionali. La loro sola presenza rendeva
**ambigua** la chiamata interna, e il database la rifiutava:

```
ERROR: function fn_get_bilancio_viaggio(integer,integer,integer,date,date) is not unique
```

**Da quando:** da prima della 2.1 — il difetto non è stato introdotto da questa versione, è stato
**trovato** in questa.

ℹ️ È lo stesso inciampo già ripulito altrove dallo script 524: `CREATE OR REPLACE` non sostituisce
una funzione se cambia il numero dei parametri, e la vecchia firma resta lì a rendere ambigua ogni
chiamata che non li elenchi tutti.

**Correzione:** le tre firme morte sono state eliminate (`SqlScripts/638`).

⚠️ **Da verificare al rilascio**: provare una stampa bilancio prima e dopo aver applicato lo script.
Se prima dà errore, era rotta anche in produzione.

### 2.2 — Il margine di un forfettario era più alto del vero

**Sintomo:** nessuno. È il tipo di difetto peggiore — un numero plausibile e sbagliato.

**Causa:** il bilancio sommava ricavi **e costi** sempre al netto dell'IVA. Corretto per chi l'IVA
sugli acquisti la recupera; **sbagliato per un forfettario**, che non la recupera: quell'IVA è
denaro uscito, e non comparendo fra i costi gonfiava il margine di tutto il suo importo.

**Correzione:** le funzioni del bilancio espongono ora `importo_effettivo_eur` — il netto, tranne
sui **costi** di un'azienda che non detrae l'IVA, dove è il **totale IVA compresa**. I ricavi non
cambiano: un forfettario non addebita IVA in fattura, quindi netto e lordo coincidono. La stampa usa
il nuovo valore sia nei totali sia nelle righe, così righe e totale tornano sempre.

ℹ️ Il parametro era previsto fin dall'inizio (`ana_regimi_fiscali.is_iva_detraibile`): mancava chi
lo leggesse.

**Impatto sui numeri già visti:** nessuno in produzione. ⭐️ Al 2026-09-17 l'azienda SFT **non aveva
ancora registrato un solo movimento contabile**: nessun bilancio è mai stato prodotto con il calcolo
vecchio.

### ⛔️ 2.3 — In «Nuova Transazione» non si poteva collegare il movimento a un viaggio

**Sintomo:** nella scheda di un movimento contabile la tendina **Viaggio** non si apre. Resta vuota,
senza messaggi, mentre causale, controparte e valuta si compilano normalmente.

**Causa:** il dialog chiede al database tutti i dati di apertura in una chiamata sola, e quella
funzione — `fn_get_transazione_init_data` — **non è mai esistita**: lo script che doveva crearla era
stato scritto prima di alcune rinomine di colonne, quindi la funzione si creava e falliva alla prima
chiamata. Non è un difetto introdotto ora: era **già annotato** nella Checklist Go-Live del
2026-09-07 come «la form funziona male», e rimandato insieme al resto della contabilità.

⚠️ **Perché era così difficile da riconoscere:** il programma raccoglie l'errore, lo scrive nel log
e va avanti con una lista vuota. Il campo Viaggio, a differenza degli altri, in quel caso rinuncia a
cercarsi i dati da solo — quindi si vedeva **un solo campo morto in mezzo a una scheda
apparentemente sana**.

**Conseguenza vera, oltre al fastidio:** senza quel collegamento un costo non entra nel **Bilancio
Viaggio**, e il margine di quella partenza risulta migliore del reale — in silenzio.

**Correzione:** funzione riscritta allineata allo schema (`SqlScripts/640`), provata sia in
inserimento sia in modifica. Lo script vecchio è stato eliminato, perché uno script che crea una
funzione rotta è peggio di nessuno script.

### 2.4 — Nel dettaglio righe la lente di ricerca finiva sopra l'aliquota

Applicando **«Applica Calcolo Regime»**, nella colonna *IVA (%)* la scritta «Aliquota IVA» veniva
troncata in «Alq…» e si sovrapponeva alla lente di ricerca.

La label lì dentro era superflua — l'intestazione della colonna dice già «IVA (%)» — e in 130 pixel
non ci stava. Tolta la label e allargata la colonna.

Sistemate anche le **frecce su/giù** dei campi importo, che dalle quattro cifre in su finivano sopra
il numero: su un importo in euro non servono a nessuno — nessuno registra mille euro a colpi di
+1 — e sono state tolte sia dall'imponibile di riga sia dall'importo in testata.

### ⛔️ 2.5 — Le tendine della scheda si aprivano piene di righe **senza testo**

**Sintomo:** premendo la lente dell'aliquota IVA nel dettaglio righe si apriva un elenco con il
numero giusto di voci, **tutte vuote**.

**Causa:** i dati che il database manda alla scheda usano i nomi delle colonne (`iva_descrizione`,
`viaggio_descrizione_breve`), mentre il programma li cercava con i propri (`IvaDescrizione`,
`ViaggioDescrizioneBreve`) senza saperli convertire: gli oggetti venivano creati ma **vuoti**. Non
una lista vuota — una lista di elementi vuoti, che è diverso e più difficile da riconoscere.

⚠️ **Era nascosto dal difetto precedente** (§2.3): finché quella lettura non funzionava affatto,
ogni tendina si caricava per conto proprio e nessuno se ne accorgeva. Rimessa in funzione la lettura
unica, il problema di conversione è venuto a galla — il che è il motivo per cui le correzioni vanno
provate, non solo compilate.

**Correzione:** conversione automatica attivata lato programma, e alias del database riportati tutti
allo stesso stile (`SqlScripts/641`), perché la conversione funziona solo se **tutte** le chiavi
sono scritte allo stesso modo.

⚠️ **Una coda, trovata subito dopo** (`SqlScripts/642`): due elenchi su cinque — **controparti** e
**viaggi** — restavano agganciati male. Le loro classi non hanno una chiave con un nome proprio, ma
un generico `Id`, mentre le colonne si chiamano `controparte_id` e `viaggio_id`: il testo si vedeva,
ma ogni voce arrivava senza identificativo, e la controparte già scelta spariva dall'elenco. Il caso
dei **viaggi** non era ancora stato notato — la tendina sembrava sana — ed è stato corretto insieme.

ℹ️ Tre giri sullo stesso punto in un giorno. La lezione, annotata: quando una lettura unica torna in
servizio dopo essere stata ferma, **vanno verificate tutte le liste che porta**, non quella che ha
dato il sintomo.

### 2.6 — Un elenco vuoto non diceva di esserlo

Cercando un **cliente** su una fattura di vendita, la tendina mostrava una sola voce — *«--- TUTTE LE
CONTROPARTI ---»* — e sembrava che il caricamento fosse fallito. In realtà non c'era **nessuna
controparte marcata come cliente**, e quella voce serve alle stampe, non a una scheda dove devi
sceglierne una.

Due correzioni:

- la voce **«tutte le controparti»** ora compare **solo dove si filtra** — stampe, scadenziario,
  estrazione SDI — e non nelle schede di registrazione;
- ogni tendina che si apre senza risultati **lo dice**, e dice anche dove si rimedia: *«Nessun
  cliente in anagrafica controparti. Aggiungilo, o spunta “è cliente” su una controparte
  esistente.»*

ℹ️ Il messaggio è scritto **una volta sola** nel componente comune: i venticinque elenchi che ne
dipendono l'hanno preso tutti, e quelli contabili (controparti, viaggi, aliquote IVA, causali,
valute) dicono in più dove si risolve.

### 2.7 — L'aliquota IVA: il codice non si vedeva, e una volta scelta nemmeno lei

Nel dettaglio righe l'elenco delle aliquote mostrava **solo la descrizione**: per scegliere *N2.2*
— quella del regime forfettario — bisognava già sapere che per esteso si chiama «Regime Forfettario
art. 1 c. 54-89». Il **codice**, che è il modo in cui un'aliquota si cerca davvero, non compariva.

E una volta scelta, nella colonna non si leggeva: fra la crocetta e la lente restava lo spazio di
un **quadratino grigio**.

Tre correzioni che vanno insieme:

| | |
|---|---|
| **Nell'elenco** | Il codice viene per primo, in evidenza, seguito da descrizione e percentuale |
| **Nel campo** | Testo compatto — `N2.2 (0,00%)` — invece della descrizione estesa |
| **La scheda** | Allargata: dentro c'è una griglia di sette colonne che in larghezza media si comprimeva |

ℹ️ Elenco e campo ora possono dire cose diverse: si cerca con tutto, si legge poco. Prima erano
costretti a essere lo stesso testo, e vinceva sempre quello sbagliato per uno dei due usi.

⚠️ **E l'aliquota scelta ora si legge nella colonna**, come pastiglia — `22 · 22,00%` — sia mentre
si sceglie sia dopo. Il calcolo era sempre stato giusto (1.000 + 22% = 1.220), ma la colonna restava
muta: si vedeva l'imposta e non si sapeva quale aliquota l'avesse prodotta, che su un documento
fiscale è proprio il dato da controllare. Se manca, la colonna dice *«da scegliere»* invece di
restare bianca.

### 2.8 — La guida della contabilità prometteva una cosa che il programma non fa

Nella finestra *Guida alle Registrazioni Contabili* si leggeva che sul ciclo passivo il sistema
«scorpora» l'IVA dall'importo lordo. **Non è così**: nelle righe di dettaglio l'IVA è sempre
calcolata **sopra** l'imponibile, in entrambi i cicli.

⛔️ Non era un dettaglio: chi seguiva quell'indicazione scriveva il **totale** della fattura
nell'imponibile e si ritrovava l'IVA addebitata due volte.

Testo corretto, e aggiunto un avviso esplicito su cosa scrivere nelle righe.

---

### ⛔️ 2.9 — Si perdeva il lavoro senza che nessuno chiedesse niente

Tre modi diversi di buttare via una scheda compilata a metà, tutti senza una domanda:

1. **Un clic fuori dalla finestra.** Il comportamento predefinito di una finestra di
   MudBlazor è chiudersi se si clicca sullo sfondo. Un clic a vuoto — per spostare il
   mouse, per togliere il fuoco da un campo — e la scheda spariva con tutto dentro.
2. **Il tasto Esc.** Stessa cosa, con un tasto che si preme per istinto quando si vuole
   chiudere una tendina.
3. **La rotella del mouse.** Il più insidioso: una rotellata riportava alla dashboard.
   Non era un difetto del programma ma del motore della finestra, che legge lo scroll
   che sfonda il bordo della pagina — la rotella inclinabile, due dita sul trackpad —
   come il gesto «indietro» del browser. E «indietro», qui, vuol dire cambiare pagina.

**Come è stato chiuso.** Non correggendo una schermata alla volta — erano oltre cento i
punti in cui si apre una finestra — ma cambiando la regola generale una volta sola: da
oggi **nessuna finestra si chiude per sbaglio**, né cliccando fuori né con Esc. Si esce
dal pulsante *Annulla*, e nella scheda dei movimenti contabili quel pulsante chiede
conferma quando c'è davvero qualcosa da perdere.

Dove la chiusura rapida ha senso e non c'è lavoro da perdere — conferme di
cancellazione, anteprime, guide, parametri di stampa — Esc continua a funzionare.

La rotella è chiusa da due lati insieme: nel foglio di stile (`overscroll-behavior`,
che vale su ogni piattaforma) e nelle impostazioni della finestra su Windows
(`IsSwipeNavigationEnabled`). Nella stessa occasione sono state tolte le scorciatoie da
browser che non servono in un gestionale e possono solo fare danni: **F5** e **Ctrl+R**
ricaricavano l'applicazione da zero, **Alt+Freccia** faceva lo stesso danno della rotella.

---

### ⛔️ 2.10 — La tendina dei viaggi si apriva bianca

Dopo le correzioni 2.3 e 2.5 la tendina **Viaggio** si apriva, ma su un riquadro vuoto: una
riga per ogni viaggio in anagrafica, tutte **senza testo**. Lo stesso aspetto che aveva l'IVA
prima del punto 2.5, e la stessa famiglia di cause.

I viaggi sono l'unico caso in cui i nomi usati nella tabella e quelli usati nel programma non
coincidono: la colonna si chiama `viaggio_descrizione_breve`, il programma cerca
`descrizione_breve`. Ogni viaggio arrivava quindi completo di tutto tranne il suo nome.

ℹ️ Perché si vedeva solo qui: tutte le altre schermate leggono i viaggi per una strada diversa,
che i nomi veri li conosce. La scheda dei movimenti è l'unica che passa dalla lettura unica
introdotta al punto 2.3.

Corretto **dal lato del database** (script `643`), costruendo la lista campo per campo con i
nomi che il programma si aspetta. Due miglioramenti arrivati con la correzione:

* sotto al nome del viaggio ora compare anche la **nazione**, che prima non arrivava mai;
* **non viaggia più la mappa del viaggio**. Veniva spedita insieme al resto — un'immagine
  intera per ogni viaggio, a ogni apertura della scheda — e non la usava nessuno.

---

### ⛔️ 2.11 — In produzione nessuna stampa contabile poteva funzionare

Non è un difetto nato oggi: è un'assenza rimasta dal go-live, trovata facendo un
controllo che non era mai stato fatto — prendere tutti i nomi di funzione che il
programma cita nel codice e chiedere al database di produzione quali non esistono.

Ne mancavano **cinque**, tutte della stessa famiglia: la stampa dei **movimenti**,
dello **scadenzario**, del **registro IVA**, del **bilancio viaggio** e della **fattura
attiva**. Il programma le chiama, non le trova, e la stampa non parte.

ℹ️ Perché nessuno se n'era accorto: per stampare servono movimenti contabili, e in
produzione non ce n'erano ancora. Sarebbe uscito alla prima stampa vera — cioè davanti
al cliente.

Tutte e cinque sono state **ricreate in produzione** prendendo la definizione
dall'ambiente di sviluppo, dove sono in servizio da sempre, e provate una per una.

⚠️ Insieme è stato applicato anche lo **script 638**, in anticipo sul rilascio: senza,
la stampa del bilancio sarebbe rimasta ambigua fra tre versioni della stessa funzione.

---

### 2.12 — Quindici funzioni avevano più di una firma, e due erano pericolose

Stessa radice del punto 2.1: quando una funzione viene ricreata con un parametro in
più, il database **non sostituisce** la vecchia, ne tiene due. Finché il programma passa
tutti i parametri non succede niente; il giorno in cui ne omette uno, il database non sa
più quale scegliere e la chiamata fallisce. È esattamente ciò che aveva bloccato le
stampe dei bilanci.

Censite tutte: erano **quindici**. Due meritano una riga a parte:

* **`reset_password_with_token`** aveva due versioni: una che cifra la password, l'altra
  che scriveva nel campo **quello che riceveva**. Se una chiamata fosse finita sulla
  seconda, la password sarebbe stata salvata **in chiaro** e l'accesso non avrebbe più
  funzionato. Non è mai successo solo grazie a un dettaglio di come il programma scrive
  la chiamata.
* **`sp_app_delete_role`** ne aveva due indistinguibili fra loro.

Tenuta per ognuna solo la versione realmente in uso — cercata nel gestionale, nel sito e
dentro le altre funzioni, non scelta a occhio.

✅ Resta una **guardia**: `SELECT * FROM fn_check_firme_duplicate();` elenca le funzioni
con più di una firma. Da lanciare prima di ogni rilascio; deve rispondere zero righe.

---

### ⛔️ 2.13 — Le stampe con un filtro sulle date non partivano

L'elenco delle **fatture attive** non compariva mai. Non era la pagina: la ricerca
falliva prima di cominciare, e falliva **sempre**, perché la pagina imposta da sola
l'intervallo di date appena si sceglie l'anno.

**La causa, in una riga:** il programma mandava le date come *timestamp* (data **e**
ora), mentre le funzioni del database aspettano una *data*. Non sono la stessa cosa e il
database non converte da solo: rispondeva «questa funzione non esiste», e la stampa si
fermava lì.

⚠️ **Non era solo la fattura attiva.** Lo stesso difetto era in altre tre stampe —
**scadenzario**, **bilancio viaggio** e **movimenti contabili** — e si manifestava alla
stessa condizione: filtrare per data, cioè quasi sempre. Corrette tutte e quattro nello
stesso giro.

ℹ️ In produzione non se n'era accorto nessuno perché non c'erano ancora movimenti
contabili da stampare (§2.11): le stampe non arrivavano nemmeno a provarci.

---

### 2.14 — L'elenco delle fatture attive restava vuoto anche dopo la correzione

Due cose ancora, sulla stessa schermata:

* **La pagina non cercava da sola.** Si apriva con i filtri già pronti sull'anno in corso,
  ma la griglia restava vuota finché non si premeva *Cerca* — e una griglia vuota appena
  aperta si legge come «non c'è niente da stampare», non come «devi premere un pulsante».
  Ora l'elenco si popola all'apertura, e di nuovo quando si sceglie un'altra azienda.
* **Un filtro lasciato in bianco filtrava lo stesso.** La tendina *Stato*, se svuotata
  dopo essere stata usata, non mandava «nessun filtro» ma una **stringa vuota**: il
  database cercava allora le fatture con stato uguale a `''`, che non esiste, e
  rispondeva zero righe.

⚠️ La seconda l'ha corretta il database (script `652`) e non la schermata: *vuoto e
assente sono la stessa cosa* è una regola che il progetto applica già altrove, e lasciarla
al chiamante significa che basta una tendina che si comporta diversamente perché il filtro
torni a mordere.

---

## Sezione 3 — Documentazione

### ⭐️ 3.1 — Il manuale della contabilità

`Documents/Manuali_Utente/Manuale_Contabilita.md` — **quinto manuale utente**, 15 capitoli:
registrazioni e righe di dettaglio, causali, regime fiscale e calcolo automatico, date e controlli,
valute estere, protocollo IVA, incassi e pagamenti, collegamento ai viaggi, le sei stampe contabili,
fattura elettronica per lo SDI, tabelle contabili.

Prima non esisteva niente sulla contabilità: era l'area più delicata del programma e la meno
spiegata.

### 3.2 — Aggiornati

| Documento | Cosa cambia |
|---|---|
| `Funzioni_DB.md` | Le due funzioni del bilancio con la colonna nuova; tolte dall'inventario le firme eliminate |
| Checklist Go-Live PROD | Nuovo §2.4-bis: lo script 638 e l'ordine in cui va applicato |
| `Prossime_Funzioni.md` | Punto 13 chiuso; punto 12 (PDF del viaggio) con la decisione sul prezzo |
| `COME_SI_GENERA_L_INSTALLER.md` | Tre inciampi della compilazione 2.1: git assente nella VM, apici sui percorsi, `Get-Arch` da definire. E la regola di cancellare i setup vecchi, col confronto dei pesi che dimostra perché |
| §2.8.4 Checklist, piano storico, memoria | ⚠️ **Correzione importante**: descrivevano come lavoro aperto la centralizzazione dei controlli su `ana_clienti`, che era invece **già fatta su entrambi i lati**. La svista ha fatto proporre come prioritario un lavoro chiuso: i documenti ora riportano lo stato verificato sul codice |

---

## Sezione 4 — Database

| Script | Cosa fa |
|---|---|
| `638_Bilancio_Viaggi_IvaNonDetraibile.sql` | Elimina tre firme superate delle funzioni del bilancio (**senza, le stampe non funzionano**) e aggiunge `importo_effettivo_eur` alle due superstiti |
| `639_Calendario_Mezzi_E_MeseIniziale.sql` | Aggiunge `tot_mezzi` a `fn_get_calendar_data` e crea `fn_get_calendar_mese_iniziale` |
| `640_FnGetTransazioneInitData_Corretta.sql` | Crea `fn_get_transazione_init_data`, che **non è mai esistita**: senza, in «Nuova Transazione» la tendina Viaggio resta vuota. ✅ **Già applicato in PROD il 2026-09-20** (§5) |
| `641_FnGetTransazioneInitData_AliasSnakeCase.sql` | Alias del JSON tutti in snake_case: senza, le tendine si popolano di elementi senza testo. ✅ **Già applicato in PROD il 2026-09-20** (§5) |
| `642_FnGetTransazioneInitData_ChiaviId.sql` | Alias `id` per controparti e viaggi, le cui classi ereditano `Id` da BaseEntity. ✅ **Già applicato in PROD il 2026-09-20** (§5) |
| `643_FnGetTransazioneInitData_Viaggi.sql` | I viaggi con le chiavi che il programma cerca (`descrizione_breve`, non `viaggio_descrizione_breve`): senza, la tendina Viaggio è bianca. Toglie anche la mappa dal JSON. ✅ **Già applicato in PROD il 2026-09-20** (§5) |
| `644_TransazioneInitData_ViaggiPartenze.sql` | Aggiunge `ultima_partenza` e `prossima_partenza` a ogni viaggio: è su queste che poggiano i tre pulsanti del §1.2. ✅ **Già applicato in PROD il 2026-09-20** (§5) |
| `645_ModalitaPagamento_Tabella.sql` | Crea `ana_modalita_pagamento` e le due colonne di collegamento su controparti e movimenti. ✅ **Già applicato in PROD il 2026-09-20** (§5) |
| `646_ModalitaPagamento_Funzioni_E_Dati.sql` | Funzioni CRUD + le 15 modalità di partenza per ogni azienda (idempotente). ✅ **Già applicato in PROD il 2026-09-20** (§5) |
| `647_ModalitaPagamento_Controparti_E_InitData.sql` | Ricrea `fn_ana_controparti_get_all` e `_get_by_id` con la modalità e il suo codice. ✅ **Già applicato in PROD il 2026-09-20** (§5) |
| `648_TransazioneInitData_ModalitaPagamento.sql` | Le modalità attive nell'apertura della scheda movimenti. ✅ **Già applicato in PROD il 2026-09-20** (§5) |
| `649_FirmeDuplicate_Pulizia.sql` | Elimina le firme morte di 13 funzioni e crea la guardia `fn_check_firme_duplicate()`. ✅ **Già applicato in PROD il 2026-09-20** (§5) |
| `650_PROD_Stampe_Mancanti.sql` | Ricrea le 5 funzioni di stampa contabile che in PROD non esistevano. ✅ **Già applicato in PROD il 2026-09-20** (§5) |
| `651_Web_ClienteProfiloPubblico.sql` | Il sito risponde con verdetti invece che con i dati personali del cliente. ✅ **Già applicato in PROD il 2026-09-21** (§5) |
| `652_FattureAttive_FiltriVuoti.sql` | Un filtro vuoto non filtra più: l'elenco fatture attive tornava vuoto. ✅ **Già applicato in PROD il 2026-09-21** (§5) |

⚠️ **Ordine di rilascio**: gli script **prima**, l'applicativo **poi**. Valgono per entrambi: la
stampa del bilancio legge `importo_effettivo_eur` e il calendario legge `tot_mezzi` — colonne che
senza gli script non esistono, e il programma andrebbe in errore invece di ripiegare.

ℹ️ Nessuna migrazione di dati: sono solo funzioni.

---

## Sezione 5 — ✅ Già applicato in PRODUZIONE (non serve rifarlo)

Elenco tenuto aggiornato man mano, per non arrivare al rilascio senza sapere cosa è già in piedi.

| Quando | Cosa | Effetto |
|---|---|---|
| 2026-09-14 | Creato il bucket Storage **`tour-media`** (pubblico) | Senza, il caricamento di foto e mappe rispondeva *«Upload immagine fallito (400)»* |
| 2026-09-14 | **Chiavi Storage separate** fra sviluppo e produzione | Revocarne una non blocca più l'altra |
| 2026-09-14 | **Chiave Claude** configurata sull'azienda 2 (da Antonio) | Traduzioni e testi SEO funzionanti |
| **2026-09-20** | **`SqlScripts/640`** — creata `fn_get_transazione_init_data` | ⭐️ La tendina **Viaggio** nei movimenti contabili ora si apre: verificato in PROD, 23 viaggi, 12 causali, 34 valute |
| **2026-09-20** | **`SqlScripts/641`** — alias del JSON in snake_case | Le tendine della scheda mostrano il testo delle voci, non righe vuote |
| **2026-09-20** | **`SqlScripts/642`** — alias `id` per controparti e viaggi | La controparte selezionata non sparisce più dall'elenco |
| **2026-09-20** | **`SqlScripts/643`** — i viaggi con le chiavi della classe | La tendina **Viaggio** mostra i nomi dei viaggi e la nazione: verificato in PROD, 23 viaggi con descrizione piena |
| **2026-09-20** | **`SqlScripts/644`** — le date di partenza su ogni viaggio | Prepara i tre pulsanti §1.2: verificato in PROD, 23 viaggi di cui 17 già effettuati e 12 da effettuare |
| **2026-09-20** | **`SqlScripts/645`–`648`** — modalità di pagamento | Verificato in PROD: 15 modalità per SFT, presenti nell'apertura della scheda movimenti. ⚠️ La tabella si **vede** solo con l'eseguibile 2.2 |
| **2026-09-20** | **`SqlScripts/649`** — firme duplicate | 15 funzioni ripulite, fra cui la password in chiaro; `fn_check_firme_duplicate()` risponde zero righe |
| **2026-09-20** | ⭐️ **`SqlScripts/650`** — le 5 stampe contabili mancanti | ⛔️ In PROD non esistevano: nessuna stampa contabile funzionava. Ricreate e provate tutte |
| **2026-09-20** | **`SqlScripts/638`** — bilanci (anticipato) | Serviva al 650: senza, la stampa del bilancio resta ambigua fra tre firme |

ℹ️ Il **640** e i tre che lo correggono (**641**, **642**, **643**) sono stati applicati subito
perché **non dipendono dal nuovo eseguibile**: il programma già installato da Antonio quella
funzione la chiamava già, e non la trovava. Il **644** aggiunge solo due campi in più al JSON,
che la versione installata ignora: applicarlo in anticipo non le cambia nulla.

⛔️ **Resta da applicare solo il `639`** (calendario), che va **insieme** all'eseguibile nuovo:
aggiunge `tot_mezzi` e crea `fn_get_calendar_mese_iniziale`, cose che solo la 2.2 sa leggere.

ℹ️ Il **638** era in questa lista fino al 2026-09-20: è stato anticipato perché serviva alla
stampa del bilancio (§2.11). Non rompe la 2.1 installata — aggiunge una colonna che quella
versione semplicemente non legge.

---

## Sezione 6 — Cosa NON è cambiato, e vale la pena dirlo

- Il **sito pubblico e il modulo di iscrizione** (Flask) non sono toccati da questa versione. ⭐️ Sono
  in uso dai clienti veri: le iscrizioni arrivano da lì.
- Il **pulsante «Scrivili con l'AI»** per i testi SEO è della **2.1**, non di questa.
- La **chiave dello Storage dentro il binario** resta il debito aperto più rilevante
  (`Prossime_Funzioni.md`, punto 11).

---

## Sezione 7 — Al momento del rilascio

### 0. I due controlli preliminari — **prima di tutto il resto**

Si lanciano su **PROD** e durano un minuto. Nascono da due guasti veri: le stampe dei
bilanci bloccate da firme doppie (§2.1) e le cinque stampe contabili che in produzione
non esistevano (§2.11). Vanno rifatti a ogni rilascio, non una volta sola.

**a) Nessuna funzione deve avere più di una firma**

```sql
SELECT * FROM fn_check_firme_duplicate();
```

⛔️ Deve rispondere **zero righe**. Se ne compare una, è una versione vecchia rimasta
indietro: prima o poi farà fallire una chiamata con *«function ... is not unique»*.
Trovare quale firma il programma usa davvero, e togliere le altre.

**b) Ogni funzione che il codice chiama deve esistere in PROD**

Dalla cartella del progetto:

```bash
grep -rhoE "\b(fn|sp)_[a-z0-9_]+\b" --include="*.cs" --include="*.razor" \
     Services/ Repositories/ Statistics/ Components/ Helpers/ | sort -u
```

I nomi che ne escono vanno confrontati con quelli presenti in PROD (`pg_proc`, schema
`public`): il procedimento completo è in `Documents/Architettura/Funzioni_DB.md` §0.

⛔️ Ogni nome mancante è una funzione che il programma chiama e non trova: la schermata
che la usa **non funziona**, e spesso in silenzio. ℹ️ Qualche riga sarà un falso allarme
(nomi che compaiono solo dentro un commento, o composti a pezzi): si controllano a mano,
sono pochi.

⚠️ **Uno script che sta in `SqlScripts/` non è uno script applicato.** È questa la
distrazione da cui nascono entrambi i controlli.

---

1. ✅ **Fatto il 2026-09-20** — numero di versione a **2.2** in `Versione.txt`, nel `#define` di Inno
   Setup, in `ApplicationDisplayVersion` (build 38 → 39) e nell'intestazione dei cinque manuali;
   PDF rigenerati e verificati titolo per titolo.
2. Applicare su PROD **solo `SqlScripts/639`** — **prima** di consegnare l'eseguibile. ✅ Tutti gli altri (**638**, **640**–**650**) sono già applicati (§5): non rifarli.
3. Compilare seguendo `Scripts/windows/COME_SI_GENERA_L_INSTALLER.md`: **win10-x64**, sorgente
   `C:\GestioneViaggi-build`, e cancellare i setup vecchi dopo la consegna.
4. Provare, in «Nuova Transazione»:
   - la tendina **Viaggio** si apre, mostra i nomi e la nazione, e il movimento si collega;
   - i tre pulsanti **TUTTI / GIÀ EFFETTUATI / DA EFFETTUARE** filtrano e riordinano (§1.2);
   - scegliendo l'interlocutore arriva la sua **modalità di pagamento** e la scadenza si
     calcola da sola (§1.3);
   - la finestra **non si chiude** cliccando fuori, con Esc o con la rotella (§2.9).
5. Verificare sulla VM, nell'ordine:
   - la **stampa del bilancio** deve produrre il PDF (è la correzione principale);
   - la dashboard di un utente **non SuperAdmin** deve mostrare il **Calendario Partenze**, aperto
     sul mese della prossima partenza, con i mezzi nel dettaglio al passaggio del mouse.
   - ⭐️ **le altre quattro stampe contabili**: movimenti, scadenzario, registro IVA e fattura
     attiva. In produzione non hanno **mai** funzionato fino al 2026-09-20 (§2.11), quindi
     questo è il loro primo collaudo vero;
   - **Tabelle Contabili → Modalità di Pagamento**: l'elenco deve contenere quindici voci.
