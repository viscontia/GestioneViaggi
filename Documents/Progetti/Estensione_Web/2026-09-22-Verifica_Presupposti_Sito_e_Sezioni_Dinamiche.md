# Il sito è pronto a partire? — verifica dei presupposti e disegno delle sezioni dinamiche

> **USO INTERNO.** Data: 2026-09-22. Apre la fase del **sito pubblico vero e proprio**.
> Fa seguito a `2026-07-13-Analisi_Lavori_Rimanenti_Sito_INTERNO.md` (§A e §B) e alla
> `2026-07-13-Proposta_Funzionale_Sito_Web_SFT.md` accettata da Adriano e da Antonio.
> Tutte le misure sono prese su **PRODUZIONE** (azienda 2, SFT) il 2026-09-22.

---

## In una riga

L'impianto tecnico c'è quasi tutto — **manca il contenuto che lo accende**: la tabella delle
sezioni del sito è **vuota**, nessuna scheda è **pubblicata**, e nessuna tipologia di viaggio
sa ancora **in quale pagina del sito finire**.

---

## 1. Cosa dicono i documenti accettati, in sintesi

Il sito è una **vetrina fotografica** alimentata dal gestionale come fonte unica: si scrive il
tour una volta, si pubblica con un clic, il sito legge in tempo reale solo ciò che è pubblicato.
Cinque lingue (IT · EN · DE · FR · ES) con traduzione assistita. L'app di iscrizione resta
com'è: ogni tour ha il bottone «Iscriviti» che ci porta.

**Pagine previste**: Home (video + «Trova il tuo tour» + evidenza + prossime partenze + mappa
interattiva delle zone) · Catalogo con filtri · **Scheda tour per edizione** · Tour giornalieri
· Chi siamo · Galleria/Video · FAQ · Contatti · Newsletter · Privacy.

**Stack deciso**: Next.js App Router, SEO-first, ISR con rigenerazione su richiesta, lettura
server-side via `@supabase/ssr`, esposizione dei soli contenuti pubblicati tramite RLS `anon`.

⚠️ **Il presupposto che regge tutto**: il gestionale si connette come superuser e **scavalca le
RLS** — l'isolamento fra aziende vive nelle funzioni PL/pgSQL. Le RLS sono il confine di
sicurezza **solo** per la lettura pubblica del sito. Chi scriverà il sito deve saperlo: ogni
lettura pubblica passa dallo strato `fn_web_*`, mai dalle tabelle.

---

## 2. Verifica sul database di produzione

### 2.1 Quello che c'è, e funziona

| | |
|---|---|
| Schede contenuto web | **8** |
| Giornate di itinerario | **64** |
| Immagini dei tour | **19** |
| Mappe generate da GPX | **7** |
| Traduzioni | **404** (101 × EN, DE, FR, ES) |
| Viaggi con incluso/escluso | 7 |
| Viaggi con difficoltà | 7 |

Lo **strato pubblico è già ricco**: `fn_web_tour_pubblicati` restituisce già titolo, slug,
difficoltà, durata, **prezzo "da"**, immagine, **incluso/escluso**, **posti rimasti** con il
relativo stato, **is_tour_breve**, meta title e description. I §A.1, A.2 e A.3 dell'analisi di
luglio sono quindi **implementati a database**.

✅ E filtra già `data_viaggio_data_inizio > CURRENT_DATE`: **da domani in avanti**, esattamente
il criterio chiesto al punto 3. Non va reinventato, va riusato.

### 2.2 ⛔️ I buchi — campi previsti e mai valorizzati

| # | Cosa | Stato in PROD | Conseguenza sul sito |
|---|---|---|---|
| 1 | `web_tipi_viaggio_descrizioni` | **0 righe** | **Nessuna sezione del sito esiste.** È la tabella che dà nome e indirizzo alle pagine per tipologia |
| 2 | `ana_tipo_viaggi.descrizione_web_fk` | **NULL su 7 tipi su 7** | Nessun viaggio sa in quale pagina finire |
| 3 | `web_tour_contenuti.stato_pubblicazione` | **8 su 8 in bozza**, 0 pubblicate | Il sito sarebbe **vuoto**: `fn_web_tour_pubblicati` non restituisce nulla |
| 4 | `web_aziende_funzioni` | **nessuna riga** per SFT | Tutte le funzioni web risultano spente (newsletter, recensioni, mappe…) |
| 5 | `web_indirizzi` | **0 righe** | Niente social né contatti nel piè di pagina |
| 6 | `ana_viaggi.viaggio_capienza_alert` | **0 su 23** (capienza_max: 6 su 23) | Mai «Rimangono solo N posti»: senza soglia il badge non scatta |
| 7 | `ana_tipo_viaggi.tipo_viaggio_breve` | **false su 7 su 7** | La sezione «Tour giornalieri» non comparirà mai |

ℹ️ I punti 1 e 2 sono **uno solo**: `descrizione_web_fk` non poteva essere valorizzato perché
non c'è nulla a cui puntare. Prima si creano le sezioni, poi si collegano i tipi.

### 2.3 ⚠️ Un buco strutturale: le sezioni non sono traducibili

Le entità tradotte oggi sono `ana_viaggi`, `web_tour_contenuti`, `web_tour_itinerario`,
`web_tour_itinerario_passaggi`, `web_tour_mappa`. **`web_tipi_viaggio_descrizioni` non c'è.**

Su un sito in cinque lingue le voci di menu resterebbero in italiano: *«Viaggi in 4x4»* anche
nella versione tedesca. È il primo testo che un visitatore straniero legge.

⚠️ **E c'è una tensione di modello da sciogliere**: `web_tipi_viaggio_descrizioni` è **globale**
(nessun `azienda_id`, è una delle due sole tabelle condivise fra aziende), mentre
`web_traduzioni` è **per azienda**. Tradurre un'entità globale in una tabella per-azienda
significa che due aziende tradurrebbero due volte la stessa riga, con esiti diversi. Le strade
sono due — **decisione da prendere**:

* **(a) traduzione globale**: si ammette `azienda_id` nullo in `web_traduzioni` per le entità
  condivise. «Enduro» si traduce una volta per tutti. Semplice, ma introduce un secondo
  significato nella colonna;
* **(b) traduzione per azienda**: ogni azienda traduce le sezioni che usa. Nessuna modifica di
  modello, ma lo stesso lavoro rifatto — e per ora l'azienda è **una sola**.

ℹ️ Propendo per **(b)** adesso e **(a)** se e quando arriverà la seconda azienda: oggi (b) non
costa nulla e non tocca il modello.

### 2.4 Cosa comparirebbe oggi, pubblicando tutto

| Tipologia (gergo gestionale) | Sezione sito | Viaggi | Schede web | Partenze da domani | Prima partenza |
|---|---|---|---|---|---|
| VIAGGIO 4X4 CON RIDUTTORE | ⛔️ nessuna | 19 | **8** | 10 | 18/10/2026 |
| VIAGGIO ENDURO BICILINDRICI | ⛔️ nessuna | 2 | 0 | 1 | 22/10/2026 |
| VIAGGIO ENDURO MONOCILINDRICI | ⛔️ nessuna | 2 | 0 | 1 | 29/10/2026 |

⚠️ **Tutte e otto le schede web stanno su una sola tipologia.** Anche risolvendo i punti 1-2-3,
il sito nascerebbe con **una sezione sola**: *4x4*. Le due tipologie enduro hanno partenze
future ma **nessun contenuto web**, quindi resterebbero invisibili — correttamente, secondo la
regola del punto 3.

ℹ️ Non è un difetto, è una **dipendenza dal cliente**: servono le schede dei tour enduro. Va
nell'elenco §D dell'analisi di luglio, accanto a foto e video.

---

## 3. Le sezioni dinamiche per tipologia (richiesta del 2026-09-22)

### 3.1 La richiesta

Ogni tipologia di viaggio ha la sua **pagina dedicata** sul sito. La pagina compare **da sola**
quando esistono viaggi di quella tipologia con partenze **da domani in avanti**, e sparisce da
sola quando non ce ne sono più. La sezione «viaggi in e-bike» oggi non esiste: comparirà il
giorno in cui ci sarà un e-bike in calendario, senza che nessuno tocchi il sito.

### 3.2 Il meccanismo, che in gran parte c'è già

```
ana_viaggi.viaggio_tipo_viaggio_fk
      ↓
ana_tipo_viaggi  ──descrizione_web_fk──▶  web_tipi_viaggio_descrizioni
 (gergo interno)                            (nome + slug + ordine = la PAGINA del sito)
```

⭐️ **Il valore di questo doppio passaggio: il gergo interno non è il gergo del sito.** In
gestionale «VIAGGIO ENDURO BICILINDRICI» e «VIAGGIO ENDURO MONOCILINDRICI» sono due cose
diverse, perché cambiano mezzo e difficoltà. Per chi visita il sito sono **una sezione sola,
"Enduro"**: la distinzione fra bicilindrici e monocilindrici non gli dice niente, mentre la
differenza fra un enduro e un 4x4 sì. La mappatura **N:1** serve esattamente a questo, ed è
già supportata dal modello.

### 3.3 Cosa manca: una funzione sola

Serve **una** funzione nello strato pubblico — chiamiamola `fn_web_sezioni_tipologia(azienda, lingua)` —
che risponda: *quali sezioni vanno mostrate adesso, con che nome, a che indirizzo, e quanti
tour contengono.*

⚠️ **Deve poggiare su `fn_web_tour_pubblicati`, non ricalcolare il criterio.** Se riscrivesse
per conto suo «pubblicato e con partenza futura», il giorno in cui quel criterio cambia il menu
mostrerebbe sezioni che il catalogo non ha — o le nasconderebbe pur avendo tour dentro. È la
regola del progetto: **una regola, un posto solo.**

**La condizione di comparsa è «almeno un tour PUBBLICATO con partenza da domani»**, non «almeno
un viaggio in anagrafica». ⛔️ Con la sola anagrafica la sezione comparirebbe **vuota**: un
visitatore clicca «Enduro» e trova una pagina senza tour — peggio che non avere la voce.

### 3.4 Conseguenze per il sito (Next.js)

* Il **menu** si costruisce da quella funzione, non da un elenco scritto a mano nel codice.
* Le pagine sono **una rotta dinamica** `/tour/[sezione]`, generata dagli slug che la funzione
  restituisce: una sezione nuova non richiede di scrivere una pagina nuova.
* Una sezione che si svuota **sparisce dal menu** e il suo indirizzo deve rispondere
  **410 Gone** o rimandare al catalogo — ⚠️ non un 404 muto, che Google interpreta come errore
  del sito invece che come pagina ritirata di proposito.
* La rigenerazione segue la stessa strada già decisa per i posti rimasti: quando cambia lo stato
  di pubblicazione o una data, si rigenerano **il menu e le sezioni toccate**.

### 3.5 Le due domande da chiudere prima di scrivere il codice

1. **Una sezione senza foto va mostrata?** Un tour pubblicato ma senza immagini finisce in una
   griglia di card grigie. Propongo: la sezione compare, ma il tour senza immagine principale
   non è pubblicabile — il controllo esiste già in scrittura (`StatoPartenzaRules`).
2. **Ordine delle sezioni**: `web_tipi_viaggio_descrizioni.ordine` esiste già. Va deciso se il
   menu segue quell'ordine fisso o il numero di tour disponibili. ℹ️ Consiglio l'ordine fisso:
   un menu che si riordina da solo disorienta chi torna.

---

## 4. Cosa fare, in ordine

### Prima di tutto — il contenuto (nessuna riga di codice)

1. **Creare le sezioni** in *Tabelle → Descrizioni Web*: nome, slug, ordine. Per SFT oggi ne
   bastano due o tre (4x4, Enduro, e in prospettiva E-bike).
2. **Collegare le tipologie** alle sezioni nella pagina Tipologie Viaggio (la mappatura N:1).
3. **Marcare i tour brevi** con `tipo_viaggio_breve`, se esistono.
4. **Pubblicare le schede**: oggi sono 8 su 8 in bozza.
5. **Accendere le funzioni web** per SFT (`web_aziende_funzioni`) e compilare `web_indirizzi`
   con social e contatti.
6. **Impostare `viaggio_capienza_alert`** sui viaggi che hanno già la capienza massima.

### Poi — le aggiunte a database

7. `fn_web_sezioni_tipologia` (§3.3).
8. Traduzione delle descrizioni web (§2.3), dopo aver sciolto il nodo globale/per-azienda.

### Infine — il sito

9. Fase §B dell'analisi di luglio, con il menu e le rotte costruiti sulla funzione del punto 7.

⚠️ **I punti 1-6 non sono lavoro di sviluppo: sono lavoro di redazione.** Senza, il sito più
bello del mondo nasce vuoto. Vanno fatti da Antonio (o da Adriano con lui) **prima** che abbia
senso mettere mano al frontend.
