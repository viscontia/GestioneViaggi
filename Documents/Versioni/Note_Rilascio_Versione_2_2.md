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

### 2.6 — La guida della contabilità prometteva una cosa che il programma non fa

Nella finestra *Guida alle Registrazioni Contabili* si leggeva che sul ciclo passivo il sistema
«scorpora» l'IVA dall'importo lordo. **Non è così**: nelle righe di dettaglio l'IVA è sempre
calcolata **sopra** l'imponibile, in entrambi i cicli.

⛔️ Non era un dettaglio: chi seguiva quell'indicazione scriveva il **totale** della fattura
nell'imponibile e si ritrovava l'IVA addebitata due volte.

Testo corretto, e aggiunto un avviso esplicito su cosa scrivere nelle righe.

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

ℹ️ Il **640** è stato applicato subito perché **non dipende dal nuovo eseguibile**: il programma già
installato da Antonio quella funzione la chiamava già, e non la trovava.

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
