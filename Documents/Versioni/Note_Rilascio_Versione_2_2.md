# Note di Rilascio — Versione 2.2

> 🚧 **In preparazione.** Il documento si compila man mano, e i numeri di versione nel programma
> **non sono ancora stati portati a 2.2**: si fa al momento di compilare, per non avere in giro
> manuali che dichiarano una versione che non esiste.
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

### 2.4 — La guida della contabilità prometteva una cosa che il programma non fa

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
| `640_FnGetTransazioneInitData_Corretta.sql` | Crea `fn_get_transazione_init_data`, che **non è mai esistita**: senza, in «Nuova Transazione» la tendina Viaggio resta vuota. ⭐️ Applicabile subito, anche prima dell'applicativo |

⚠️ **Ordine di rilascio**: gli script **prima**, l'applicativo **poi**. Valgono per entrambi: la
stampa del bilancio legge `importo_effettivo_eur` e il calendario legge `tot_mezzi` — colonne che
senza gli script non esistono, e il programma andrebbe in errore invece di ripiegare.

ℹ️ Nessuna migrazione di dati: sono solo funzioni.

---

## Sezione 5 — Cosa NON è cambiato, e vale la pena dirlo

- Il **sito pubblico e il modulo di iscrizione** (Flask) non sono toccati da questa versione. ⭐️ Sono
  in uso dai clienti veri: le iscrizioni arrivano da lì.
- Il **pulsante «Scrivili con l'AI»** per i testi SEO è della **2.1**, non di questa.
- La **chiave dello Storage dentro il binario** resta il debito aperto più rilevante
  (`Prossime_Funzioni.md`, punto 11).

---

## Sezione 6 — Al momento del rilascio

1. Portare a **2.2** i quattro punti in cui vive il numero di versione: `Versione.txt`, il `#define`
   di Inno Setup, `ApplicationDisplayVersion` (+ build), l'intestazione dei **cinque** manuali.
2. Applicare `SqlScripts/638` su PROD — **prima** di consegnare l'eseguibile.
3. Compilare seguendo `Scripts/windows/COME_SI_GENERA_L_INSTALLER.md`: **win10-x64**, sorgente
   `C:\GestioneViaggi-build`, e cancellare i setup vecchi dopo la consegna.
4. Applicare anche `SqlScripts/639` — stesso vincolo d'ordine.
5. Verificare sulla VM, nell'ordine:
   - la **stampa del bilancio** deve produrre il PDF (è la correzione principale);
   - la dashboard di un utente **non SuperAdmin** deve mostrare il **Calendario Partenze**, aperto
     sul mese della prossima partenza, con i mezzi nel dettaglio al passaggio del mouse.
