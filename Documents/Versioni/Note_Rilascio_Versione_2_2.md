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

ℹ️ Il **640** e i tre che lo correggono (**641**, **642**, **643**) sono stati applicati subito
perché **non dipendono dal nuovo eseguibile**: il programma già installato da Antonio quella
funzione la chiamava già, e non la trovava. Il **644** aggiunge solo due campi in più al JSON,
che la versione installata ignora: applicarlo in anticipo non le cambia nulla.

⛔️ Gli altri due script — **638** e **639** — **non** sono stati applicati: vanno **insieme**
all'eseguibile nuovo, perché aggiungono colonne che solo la versione 2.2 sa leggere. Applicarli
prima non romperebbe nulla, ma applicarli **dopo** l'eseguibile sì.

---

## Sezione 6 — Cosa NON è cambiato, e vale la pena dirlo

- Il **sito pubblico e il modulo di iscrizione** (Flask) non sono toccati da questa versione. ⭐️ Sono
  in uso dai clienti veri: le iscrizioni arrivano da lì.
- Il **pulsante «Scrivili con l'AI»** per i testi SEO è della **2.1**, non di questa.
- La **chiave dello Storage dentro il binario** resta il debito aperto più rilevante
  (`Prossime_Funzioni.md`, punto 11).

---

## Sezione 7 — Al momento del rilascio

1. ✅ **Fatto il 2026-09-20** — numero di versione a **2.2** in `Versione.txt`, nel `#define` di Inno
   Setup, in `ApplicationDisplayVersion` (build 38 → 39) e nell'intestazione dei cinque manuali;
   PDF rigenerati e verificati titolo per titolo.
2. Applicare su PROD `SqlScripts/638` e `639` — **prima** di consegnare l'eseguibile. ✅ Il **640** è già stato applicato il 2026-09-20 (§5): non rifarlo.
3. Compilare seguendo `Scripts/windows/COME_SI_GENERA_L_INSTALLER.md`: **win10-x64**, sorgente
   `C:\GestioneViaggi-build`, e cancellare i setup vecchi dopo la consegna.
4. Provare, in «Nuova Transazione», che la tendina **Viaggio** si apra e che un movimento si possa collegare a un viaggio.
5. Verificare sulla VM, nell'ordine:
   - la **stampa del bilancio** deve produrre il PDF (è la correzione principale);
   - la dashboard di un utente **non SuperAdmin** deve mostrare il **Calendario Partenze**, aperto
     sul mese della prossima partenza, con i mezzi nel dettaglio al passaggio del mouse.
