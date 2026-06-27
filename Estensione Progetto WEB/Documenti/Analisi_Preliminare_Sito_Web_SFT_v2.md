# Analisi Preliminare — Nuovo Sito Web + Gestionale come Motore Unico
## Sardegna Fuori Traccia (SFT)

**Versione:** 2.1 — Documento Preliminare (recepisce le risposte di Adriano del 19/6)
**Data:** 19 Giugno 2026
**Stato:** Bozza per revisione interna (Adriano) → poi versione da presentare al cliente
**Natura del documento:** funzionale, non tecnico. I dettagli tecnici sono confinati nell'Appendice A.
**Posizione:** `Estensione Progetto WEB/Documenti/` (cartella che raccoglie tutti i documenti del progetto).

> **Nota di lettura.** Questa v2.0 nasce dall'analisi diretta di: (a) database PostgreSQL reale del gestionale, (b) sito web live `sardegnafuoritraccia.it` con audit SEO verificato sul codice, (c) screenshot del backend Drupal attuale, (d) progetto dell'app di iscrizione, (e) benchmark dei competitor. Dove la v1.0 conteneva ipotesi, qui ci sono **dati verificati**. I punti in cui ho corretto o ridimensionato la v1.0 sono segnalati con **⟲ Revisione**.

---

## 0. SINTESI PER IL DECISORE (Executive Summary)

**L'idea centrale è valida e la confermo:** trasformare il gestionale in **motore unico** che alimenta anche il sito web, eliminando il doppio inserimento dati e il backend Drupal separato. Un solo database, un solo punto di lavoro per l'operatore.

**Tre fatti emersi dall'analisi che rafforzano il progetto:**

1. **Il sito attuale è su tecnologia a fine vita.** Gira su **Drupal 7 + PHP 5.6**, entrambi **fuori supporto** (Drupal 7 dal gennaio 2025, PHP 5.6 dal 2018). Non è solo una questione estetica: è un **rischio di sicurezza e di continuità**. Questo da solo giustifica il rifacimento, a prescindere dal restyling.

2. **Il gestionale ha già i mattoni tecnici per fare tutto in casa.** È un'app **MAUI Blazor Hybrid** e contiene già: editor rich-text (Blazored.TextEditor), elaborazione immagini (ImageSharp), motore grafico per disegnare mappe (SkiaSharp), generatore PDF (QuestPDF). **La tua scelta di tenere tutto nel gestionale è quindi tecnicamente fondata e a costo-componenti zero** (la v1.0 ipotizzava erroneamente l'acquisto di Telerik/Syncfusion: non serve).

3. **Il database è già una base solida ma incompleta.** Contiene viaggi, date, prezzi, clienti, iscrizioni, multi-azienda. Mancano i contenuti "editoriali" del sito (itinerario giorno-per-giorno, gallerie, SEO), la newsletter e il multilingua. Sono aggiunte, non riscritture.

**Le decisioni strategiche già prese (con Adriano):**
- ✅ **Tutto dentro il gestionale MAUI** (un solo punto per l'operatore; niente seconda interfaccia). *L'operatore lavora già solo da PC con schermo grande; in crescita, delegherà a personale di segreteria.*
- ✅ **Mappa del percorso = base OpenStreetMap**, area individuata automaticamente dalle coordinate del GPX, con tracciato semplificato (no GPX scaricabile) — vedi §9.
- ✅ **Multilingua: tutte e 5 le lingue subito** (IT, FR, EN, DE, ES).
- ✅ **Newsletter a TUTTE le email del sistema** (clienti + iscritti) per l'azienda abilitata, deduplicate. Consenso già acquisito → si procede; da ora consenso e disiscrizione tracciati.
- ✅ **Servizio email professionale (ESP) = opzione, non obbligo**: scelta dell'azienda, con il relativo costo evidenziato; configurazione per-azienda nel DB.
- ✅ **Blog: non nel primo rilascio, ma con predisposizione tecnica** (architettura pronta ad accoglierlo).
- ✅ **Hosting: si valuta di restare su Hetzner** (già usato per le iscrizioni) con Cloudflare davanti — vedi §4.3.

**Cosa NON cambia:** l'app di iscrizione online resta **esattamente com'è** e continua a essere richiamata dal nuovo sito.

**Confermato da SFT:** vuole sia le **recensioni** sia i **pagamenti online con Stripe**. Poiché lavoriamo in **multi-azienda**, queste e le altre funzioni opzionali sono **attivabili/disattivabili per singola azienda** (ogni azienda può avere scelte diverse). Prevista anche una **sezione FAQ**.

---

## 1. CONTESTO E OBIETTIVI

### 1.1 I tre sistemi attuali
| Sistema | Tecnologia | Ruolo oggi |
|---|---|---|
| **Sito web** | Drupal 7 / PHP 5.6 (EOL) | Vetrina + backend autonomo per i tour + newsletter |
| **Gestionale** | .NET MAUI Blazor Hybrid + PostgreSQL | Anagrafiche, viaggi, date, prezzi, iscrizioni, alloggi, contabilità, multi-azienda |
| **App iscrizioni** | Python/Flask + React, stesso PostgreSQL | Iscrizione online clienti ai viaggi, già integrata |

Oggi i contenuti dei tour vengono inseriti **due volte** (una nel gestionale per la parte operativa, una in Drupal per la vetrina) e le due liste di contatti (clienti del gestionale e iscritti newsletter su Drupal) vivono **separate**.

### 1.2 Obiettivi del progetto
1. **Centralizzare**: il gestionale diventa l'unica fonte; il sito legge da lì.
2. **Autonomia dell'operatore**: aggiorna i viaggi e pubblica le pagine senza competenze tecniche.
3. **Multilingua automatico**: IT (sorgente) → FR, EN, DE, ES, con traduzione AI.
4. **Anagrafiche unificate**: clienti + iscritti newsletter in un unico sistema, deduplicato e a norma GDPR.
5. **Preservare l'app di iscrizione**: nessuna modifica al flusso esistente.
6. **Sito moderno e ben posizionato**: mobile-first, veloce, SEO corretta, allineato ai migliori del settore.

---

## 2. ANALISI DEL SITO ATTUALE (verificata sul codice live)

### 2.1 Struttura
- **Menu:** Home · Fuoristrada · Quad · Estero · Moto · Foto · Video · Contatti · Strumenti
- **Pagine tour** con itinerario giorno-per-giorno molto ricco (es. *Barbagia Wild Tour*): foto principale, galleria, sport, periodo, durata, difficoltà, luoghi, descrizione, tappe giornaliere con testo+foto+didascalia, info pernottamento/pasti/equipaggiamento/altre info.
- **Lingue:** Italiano e Francese.
- **CMS:** Drupal 7 con editor CKEditor; struttura a "nodi" con traduzione per-nodo.

### 2.2 Audit SEO — cosa c'è e cosa manca (dati reali)

| Elemento | Stato | Dettaglio verificato |
|---|---|---|
| Stack | 🔴 Critico | **Drupal 7 + PHP 5.6.40**, entrambi end-of-life |
| `<title>` home | ✅ Buono | "Escursioni e Tour Fuoristrada Offroad 4x4 Quad MTB Enduro in Sardegna" |
| `<title>` pagina tour | 🟡 Debole | "Tour: BARBAGIA WILD TOUR" — manca località/keyword (es. "4x4 Sardegna") |
| Meta description | ✅ Presente | Ben scritta su home; sulla pagina tour è il testo introduttivo grezzo |
| **hreflang** (multilingua SEO) | 🔴 Assente | Nessun tag hreflang: IT e FR **non** sono collegati per i motori di ricerca |
| **Dati strutturati (Schema.org / JSON-LD)** | 🔴 Assente | **Zero** markup su home e su pagina tour → niente rich snippet (TouristTrip, Offer, AggregateRating) su Google |
| Open Graph (condivisione social) | 🟡 Parziale | Presenti og:title/description/url/site_name, **manca og:image** e le Twitter Card |
| Viewport mobile | 🔴 Problema | `user-scalable=0`: **blocca lo zoom** (barriera di accessibilità, penalizzato) |
| Immagini | 🔴 Da ottimizzare | Solo JPG/PNG, **niente WebP/AVIF**, **niente lazy-loading** → pagine pesanti |
| Sitemap / robots | 🟡 Base | robots.txt di default Drupal (Crawl-delay 10); sitemap non servita in modo pulito sul path standard |
| Blog / contenuti SEO | 🔴 Assente | Nessuna sezione editoriale per traffico organico a coda lunga |
| Social proof (recensioni) | 🔴 Assente sul sito | Nessuna recensione/rating integrata nelle pagine |

**In sintesi:** i fondamentali base ci sono (title, description, URL parlanti), ma **mancano tutti gli elementi SEO moderni** che fanno la differenza per un tour operator: dati strutturati, multilingua corretto, performance immagini, social proof. Il nuovo sito parte quindi con un grande margine di miglioramento "facile".

**⟲ Revisione v1.0:** la v1.0 elencava queste mancanze come "probabili". Sono **confermate e verificate sul codice**. In più è emerso il punto più importante che la v1.0 non citava: lo **stack a fine vita**.

---

## 3. BENCHMARK COMPETITOR E BEST PRACTICE

### 3.1 Concorrenza diretta (Sardegna / Italia)
Operatori che competono sullo stesso terreno: **Off Road Sud Sardinia**, **Live Out – Sardegna 4x4**, **4x4 Viaggi Avventura**, **Escursì**, **Excursionatura**, **Oroseia Adventure Tours**. Offrono escursioni 4x4/quad guidate con taglio simile. *Implicazione:* SFT deve distinguersi su **qualità della vetrina, contenuti (itinerari narrati), prova sociale e posizionamento SEO multilingua** — esattamente le aree in cui oggi il sito è più debole.

### 3.2 Riferimenti internazionali (best-in-class)
Operatori e piattaforme di riferimento worldwide per 4x4/overland/moto-avventura: **Overcross** (4x4 + moto worldwide, multilingua — analizzato in dettaglio), **RIDE Adventures**, **Active 4x4 Adventures** ("all meals included"), **Overland Expo**, **Edelweiss Bike Travel**, **Much Better Adventures** / **TourRadar** (pattern di conversione).

**Pattern verificati su Overcross (comparabile a SFT):** sito **multilingua** (3 lingue, switch via path URL `/en/ /de/ ...`); **filtri** per tipo tour, continente/paese, durata, data, prezzo; **card tour** con foto, prezzo "from", titolo con località, intervallo date, **rating a stelle (es. 4.4/5)**, durata, tag categoria; **rating/recensioni** ben visibili; link social; sezione **MAP**; CTA "Check Availability".

### 3.3 Best practice da adottare (prioritizzate)

| # | Best practice | Area | Impatto/Sforzo |
|---|---|---|---|
| 1 | Pagina-tour con **itinerario giorno-per-giorno** ricco (testo+foto), già punto di forza di SFT | Contenuto | Alto / Basso* |
| 2 | **Card tour** con foto, prezzo "a partire da", durata, difficoltà, badge ("Ultimi posti", "Novità") | UX | Alto / Medio |
| 3 | **Filtri** per mezzo, destinazione, difficoltà, durata, prezzo, **data/disponibilità** | UX | Alto / Medio |
| 4 | **Mobile-first** + immagini ottimizzate (WebP, lazy-load) | Performance | Alto / Medio |
| 5 | **Dati strutturati Schema.org** (TouristTrip/Trip + Offer + AggregateRating + BreadcrumbList) | SEO | Alto / Basso |
| 6 | **Multilingua con hreflang** corretto (5 lingue) | SEO | Alto / Medio |
| 7 | **Prova sociale**: recensioni Google/TripAdvisor, foto reali partecipanti | Conversione | Alto / Medio |
| 8 | **CTA "Iscriviti" sempre raggiungibile** (sticky) → punta all'app esistente | Conversione | Alto / Basso |
| 9 | **WhatsApp/contatto rapido** | Conversione | Medio / Basso |
| 10 | **Mappa del percorso** su OpenStreetMap (vedi §9) | Contenuto | Medio / Medio |
| 11 | **Calendario partenze** con prossime date e disponibilità | UX | Medio / Medio |
| 12 | **Prezzo "a partire da"** calcolato automaticamente dal minimo delle date | UX | Medio / Basso |
| 13 | **Download PDF programma** (generabile con QuestPDF già in uso) | Contenuto | Medio / Basso |
| 14 | **Blog/diario di viaggio** per SEO a coda lunga | SEO | Medio / Medio |
| 15 | **Landing per destinazione** ("Tour 4x4 Barbagia", "Quad Ogliastra") | SEO | Medio / Medio |

\* *Basso perché i contenuti esistono già e vengono solo strutturati nel DB.*

---

## 4. LA VISIONE: IL GESTIONALE COME MOTORE UNICO

### 4.1 Architettura (decisione presa: tutto nel gestionale)

```
┌──────────────────────────────┐
│   GESTIONALE MAUI (desktop)  │  ← l'operatore gestisce TUTTO qui:
│   Blazor Hybrid + MudBlazor  │    viaggi, date, prezzi, contenuti web,
│                              │    itinerario, gallerie, SEO, newsletter
└───────────────┬──────────────┘
                │ scrive
                ▼
┌──────────────────────────────┐
│   DATABASE POSTGRESQL        │  ← FONTE UNICA DI VERITÀ
│   (dati operativi + web)     │    (oggi Docker in test, Supabase in prod)
└───────┬───────────────┬──────┘
        │ legge (API)   │ legge/scrive (già oggi)
        ▼               ▼
┌──────────────────┐  ┌──────────────────────┐
│  NUOVO SITO WEB  │  │  APP ISCRIZIONI      │
│  mobile-first,   │  │  (Flask/React)       │
│  multilingua,SEO │  │  RESTA COM'È         │
└───────┬──────────┘  └──────────────────────┘
        │ bottone "Iscriviti"
        └──────────────────────► app iscrizioni
```

**Come il sito legge i dati:** tra database e sito si frappone una **piccola API di sola lettura** (un "passacarte" sicuro) che espone i tour **pubblicati**. Il sito non accede mai direttamente al DB operativo: legge solo ciò che l'operatore ha marcato come "pubblicato". Questo protegge i dati gestionali/contabili e permette al sito di essere veloce (le pagine pubblicate possono essere pre-generate/cache).

**⟲ Revisione v1.0:** la v1.0 lasciava aperta la scelta del frontend (Blazor vs Next.js vs Nuxt). Resta da decidere in fase di preventivo, ma il vincolo chiave è uno solo: **deve essere ottimo per la SEO** (rendering lato server o pagine statiche). L'editing invece è **deciso: dentro MAUI**.

### 4.2 Il flusso dell'operatore (come lavorerà)
1. Crea/modifica il **viaggio** (dati operativi: giorni, notti, km, tipo, trattamento, pernottamento — già oggi).
2. Compila la **nuova scheda "Contenuti Web"**: sottotitolo, descrizione, difficoltà, luoghi, **itinerario giorno-per-giorno con foto**, info pernottamento/pasti/equipaggiamento, galleria, campi SEO.
3. Carica il **GPX** → il sistema individua automaticamente l'area dalle coordinate del GPX e genera la **mappa su base OpenStreetMap** con il percorso (vedi §9).
4. Preme **"Traduci"** → l'AI produce le 4 lingue; l'operatore può revisionarle.
5. Preme **"Pubblica"** → il tour diventa visibile sul sito (la pagina web si genera dai dati).
6. Per un nuovo tour simile: **"Clona"** (come già nel backend Drupal odierno) e modifica.

### 4.3 Hosting e infrastruttura (valutazione: Hetzner)
L'app di iscrizione è già ospitata su **Hetzner**. **Valutazione: conviene restarci anche per il nuovo sito.**
- **Pro:** ottimo rapporto costo/prestazioni (VPS da ~5–15 €/mese), **data center in UE** (coerente col GDPR), già conosciuto, possibilità di **co-locare** sito + app + DB riducendo le latenze, nessun lock-in.
- **Da affiancare:** **Cloudflare** davanti al sito (CDN globale, cache, certificati SSL, ottimizzazione immagini) → performance e SEO migliori a costo minimo.
- **Compromesso:** è un server **auto-gestito** (a differenza di piattaforme "managed" tipo Vercel). L'onere si riduce con strumenti come **Coolify** (deploy automatici tipo-Vercel su Hetzner).
- **Da confermare in fase tecnica:** dove risiede il **database di produzione** (in memoria di progetto risulta Supabase; le iscrizioni girano su Hetzner) — la co-locazione DB/sito incide sulla latenza.

---

## 5. COSA MANCA NEL DATABASE E COSA AGGIUNGERE

Il confronto è tra i **campi reali del backend Drupal** (dagli screenshot) e la **struttura reale del DB** (verificata). Qui in forma funzionale; i nomi tecnici delle tabelle sono in **Appendice A**.

### 5.1 Già presente nel gestionale (riusabile)
Nome viaggio, descrizione, giorni/notti/km, tipo viaggio, tipo trattamento, tipo pernottamento, tipo avvicinamento, nazione, **date + tutti i prezzi** (pilota, passeggero, passeggero auto-guida, 3 fasce bambini), stato effettuazione, multi-azienda, **link al sito attuale** e **una mappa immagine** già caricabile.

### 5.2 Da aggiungere (i veri gap)

**A) Contenuti editoriali del tour** (oggi solo su Drupal):
sottotitolo, descrizione promozionale (rich text), **difficoltà**, **durata testuale** ("5gg/4nn in campeggio"), **principali luoghi visitati**, info pernottamento/pasti/equipaggiamento/altre info (rich text), campi **SEO** (slug, meta title, meta description), **stato pubblicazione** (bozza/pubblicato/archiviato), ordine di visualizzazione.

**B) Itinerario giorno-per-giorno** — *il gap più importante.*
Struttura **annidata e ordinabile**, esattamente come nel backend Drupal:
**Giornata** (titolo, es. "1ª TAPPA – COSTA DEL SINIS E MONTE ARCI") → **N Passaggi**, ciascuno con testo rich, immagine e didascalia. Sia le giornate sia i passaggi devono essere **riordinabili (drag&drop)**.

**C) Galleria immagini del tour** — foto principale + galleria, ognuna con **alt text** e **titolo** (servono per SEO/accessibilità), ordinabili.

**D) Categoria "Sport" del sito.**
**⟲ Revisione v1.0:** la v1.0 proponeva un campo a testo libero. **Sconsigliato.** Nel DB esistono **7 tipi viaggio tecnici** (4X4, 4X4 SUV, Enduro bicilindrici, Enduro monocilindrici, Moto stradale, Auto stradali, Quad) mentre il sito usa **4 "Sport"** (Fuoristrada, Quad, Moto Enduro, Moto Stradale). La soluzione corretta è una **mappatura** dei tipi tecnici verso le categorie-web (più un'etichetta visualizzata), non un campo libero che si disallineerebbe.

**E) Mappa GPX** — file GPX di origine + immagine su base OpenStreetMap generata (vedi §9).

**F) Newsletter** — iscritti + storico invii (vedi §8).

**G) Traduzioni multilingua** — i testi nelle 4 lingue aggiuntive (vedi §7).

---

## 6. NUOVE FUNZIONALITÀ NEL GESTIONALE

Tutte realizzabili con componenti **già presenti** (a costo-licenza zero):

| Funzione | Componente già nel progetto |
|---|---|
| Editor rich-text (descrizioni, passaggi) | **Blazored.TextEditor** (Quill) |
| Upload + ridimensionamento foto gallery | **SixLabors.ImageSharp** |
| Calcolo bounding box / disegno percorso su mappa (opz. B di §9) | **SkiaSharp** |
| PDF programma tour | **QuestPDF** (già in uso) |
| UI (tabelle, drag&drop, form) | **MudBlazor 8.15** |

**Nuova scheda "Contenuti Web" nel viaggio**, con: editor descrizioni, **gestione itinerario giorno-per-giorno con drag&drop**, galleria con alt/titolo, campi SEO, pulsanti **Traduci / Anteprima / Pubblica**, e **Clona** esteso ai contenuti web.

**Nuova sezione "Newsletter"**: elenco iscritti (filtri per lingua/fonte/stato), composizione, scelta destinatari, anteprima multilingua, invio deduplicato, storico.

**⟲ Revisione v1.0 (rischio "editor complesso in MAUI"):** **annullato.** Trattandosi di Blazor Hybrid, gli editor web girano nativamente dentro l'app; Blazored.TextEditor è già incluso.

---

## 7. MULTILINGUA AUTOMATICO (IT → FR, EN, DE, ES)

**Flusso:** l'operatore scrive **solo in italiano** → preme **"Traduci"** → un servizio AI traduce tutti i testi del tour → le traduzioni si salvano nel DB con un flag "tradotto automaticamente / revisionato" → l'operatore può correggere → se modifica l'italiano, il sistema segnala le traduzioni come **"da aggiornare"**.

**Tecnologia consigliata:** **API Claude (Anthropic)** per qualità su testi turistici/promozionali e coerenza del tono; alternativa **DeepL**. Costo nell'ordine di **centesimi per tour**.

**Da tradurre:** titoli, sottotitolo, descrizioni, itinerario (tutti i passaggi), info pernottamento/pasti/equipaggiamento/altre info, meta SEO, testi statici del sito.
**Da NON tradurre:** nomi di luoghi (Barbagia, Supramonte…), prezzi, date, dati tecnici (km).

**Salvataggio vs SEO:** le traduzioni vanno **memorizzate** (non tradotte "al volo"): solo così le pagine in ogni lingua sono indicizzabili da Google con hreflang corretto.

**⟲ Revisione v1.0:** confermo l'impianto. Aggiungo il vincolo SEO (traduzioni persistite) e noto che il modello Drupal odierno (traduzione per-nodo) va sostituito da **traduzione per-campo** nel nostro DB, più flessibile.

---

## 8. NEWSLETTER + UNIFICAZIONE ANAGRAFICHE

### 8.1 La situazione reale (verificata)
- **740 clienti** nel gestionale, di cui **443 con email**.
- `ana_clienti` **non ha alcun campo di consenso marketing/GDPR**.
- L'email **non è univoca né deduplicata** nel DB.
- Gli iscritti newsletter vivono **solo su Drupal**.

### 8.2 Proposta (recepita la decisione di Adriano)
**Regola d'oro dei destinatari:** la newsletter viene inviata a **TUTTE le email presenti nel sistema per l'azienda su cui l'utente è abilitato** — cioè l'**unione deduplicata** di:
- **clienti** del gestionale con email valida (per quell'azienda), e
- **iscritti newsletter** (da sito o importati), che possono *non* essere clienti.

Il **collegamento al cliente non limita l'invio**: serve solo a riconoscere i doppioni (chi è cliente *e* iscritto) ed evitare invii multipli. La deduplicazione è per **email normalizzata**.

Nuova tabella **iscritti newsletter** con: email, nome/cognome opzionali, **lingua preferita**, data iscrizione, **consenso (data + fonte)**, **stato (attivo/disiscritto)**, **fonte** (sito/gestionale/import), token di disiscrizione, ed eventuale collegamento al cliente. Serve soprattutto per chi si iscrive **solo dal sito** e per tracciare consensi/disiscrizioni.

**Regole operative:**
1. **Import iniziale** della lista email da Drupal.
2. **Matching** per email normalizzata verso `ana_clienti` (per riconoscere i doppioni).
3. All'invio: **unione + deduplica** di clienti + iscritti, **esclusi i disiscritti** (lista di soppressione).
4. Un iscritto **non diventa automaticamente cliente** (lo diventa solo partecipando a un viaggio).

### 8.3 GDPR — situazione e regole (recepita la decisione di Adriano)
- **Consenso già acquisito** per i contatti esistenti → **si può procedere** con l'invio. *(Buona prassi: conservare evidenza di quando/come è stato raccolto.)*
- **D'ora in avanti** il consenso va **tracciato** (data + fonte) per ogni nuovo contatto, e va sempre garantita la **disiscrizione** (link in ogni email + pagina di cancellazione). Chi si disiscrive entra nella lista di soppressione e non riceve più, anche se cliente.
- Per coerenza si aggiunge il tracciamento del consenso **anche lato clienti** (campi su `ana_clienti`), così la fonte del consenso è sempre registrata.

### 8.4 Infrastruttura di invio — opzione, non obbligo (recepita la decisione di Adriano)
Due modalità, **scelta dell'azienda**:
- **A) SMTP proprio** (es. casella `segreteria@`, già modellata nel DB in `ana_aziende_smtp`): **nessun costo aggiuntivo**, ma con liste grandi rischia problemi di **deliverability** (spam/blacklist) e traccia poco bounce/aperture.
- **B) Servizio email professionale / ESP** (Brevo, Mailchimp, MailerLite, Amazon SES): **migliore recapito**, gestione automatica di bounce/disiscrizioni/statistiche, ma con un **costo aggiuntivo per il Tour Operator** (in genere proporzionale al volume di invii).

**Raccomandazione:** per le newsletter di massa l'opzione B è preferibile, ma resta **una scelta, non un obbligo**. La configurazione è **per-azienda** nel DB (si estende `ana_aziende_smtp`, che gestisce già `rate_limit_per_hour` e failover): ogni azienda decide se usare il proprio SMTP o un ESP. Il **costo va evidenziato** al cliente.

---

## 9. MAPPA DEL PERCORSO (base OpenStreetMap + percorso da GPX) — decisione presa

**Obiettivo:** mostrare *dove* si svolge il viaggio su una **mappa reale**, senza regalare la traccia GPS scaricabile.

**Soluzione scelta (recepita la decisione di Adriano) — base OpenStreetMap:**
1. Dal file **GPX** il sistema calcola automaticamente il **riquadro geografico** (bounding box dalle coordinate min/max) con un margine: così la porzione di mappa **contiene e centra** sempre il percorso (risolve il problema del "GPX non centrato" che avevi sollevato).
2. Su quella porzione di **mappa OpenStreetMap** viene disegnato il **percorso**.
3. Per non regalare la traccia esatta: la linea è **semplificata/decimata** e il **GPX non è mai scaricabile** dal sito.

**Due vie tecniche (da scegliere in fase di preventivo):**
- **A) API "static map" già pronta** (Geoapify *free tier*, MapTiler, Mapbox, Stadia Maps): si passano bounding box + linea del percorso e si riceve l'immagine pronta. Più **semplice e veloce**; il free tier è ampiamente sufficiente per i volumi attuali (67 viaggi).
- **B) Rendering interno** con **SkiaSharp** (già nel progetto) sopra le tile OpenStreetMap: **più controllo** sullo stile, ma occorre un fornitore di tile conforme alla *usage policy* OSM.

**Licenza:** i dati OpenStreetMap sono **ODbL** → obbligatoria l'attribuzione **"© OpenStreetMap contributors"** sulla mappa. Costo: nullo o minimo (free tier).

**Nota da confermare:** mostrando il percorso su mappa reale, anche se semplificato, l'indicazione è più precisa di un disegno astratto. Va deciso con il Tour Operator **quanto** semplificare la linea (più fedele = più utile al cliente; più vaga = più protettiva della traccia).

**⟲ Nota — "AI che disegna la mappa":** scartata. Gli image-generator AI **non** garantiscono fedeltà geografica né una traccia plausibile. *(Opzione premium futura: mappe illustrate a mano da un grafico — più belle ma con costo per tour.)*

---

## 10. APP DI ISCRIZIONE — DA PRESERVARE

L'app `iscrizioni.sardegnafuoritraccia.it` (Flask + React) scrive già su `ana_clienti`, `mov_clienti_viaggi`, `mov_clienti_alloggi`, è **multi-azienda** (token azienda nell'URL) e invia conferme. **Resta invariata.** Il nuovo sito continuerà ad avere il bottone **"Iscriviti"** per ogni tour, con il link **generato automaticamente** dal gestionale (azienda + viaggio sono già nel DB).
*Da verificare in fase tecnica:* dove è memorizzato il token azienda dell'URL di iscrizione (es. `2-976f2734`), per generarlo correttamente dal gestionale.

---

## 11. NUOVO SITO WEB — PAGINE E FUNZIONALITÀ

**Pagine:** Home (hero video/foto + tour in evidenza + filtri + prossime partenze) · Liste per categoria (Fuoristrada/Quad/Moto/Estero) · **Dettaglio tour** (itinerario giorno-per-giorno, galleria, mappa OSM, prezzi, CTA iscrizione) · Calendario partenze · Chi siamo · Galleria/Video · **FAQ** (globali + eventuali FAQ specifiche per tour) · Contatti (form + WhatsApp + social) · Newsletter · Privacy/Cookie · *(predisposto, non nel primo rilascio)* **Blog/Diario**.

**Funzionalità chiave:** filtri tour; prezzo "a partire da" automatico; badge dinamici (Ultimi posti/Novità/Sold-out) calcolati dal gestionale; **mappa OpenStreetMap** con percorso; PDF programma; condivisione social; cookie consent GDPR; **mobile-first**; **Schema.org** + **hreflang 5 lingue**; immagini WebP + lazy-load.

**Funzioni opzionali — confermate da SFT, attivabili/disattivabili per azienda:**
- **Recensioni**: **SFT le vuole.** Integrazione Google/TripAdvisor oppure gestione interna (fonte configurabile). Essendo multi-azienda, per ogni azienda è un **toggle on/off**.
- **Pagamenti online con Stripe** (acconti **e saldi** prima della partenza): **SFT li vuole.** ⚠️ **Le regole di pagamento possono variare da azienda ad azienda** (acconto sì/no, percentuale, quando si versano acconto e saldo, oppure pagamento in **soluzione unica** e quando): gestite con una **tabella di regole per-azienda**. In più il sistema invia **promemoria** di scadenza al cliente e **solleciti** se il pagamento è scaduto (con tono adeguato), sempre con **copia nascosta (CCN) al tour operator** su un indirizzo aziendale a scelta — dettaglio in Appendice A.2. **Attivabile/disattivabile per azienda.** **🔗 Plus contabile:** ogni incasso **alimenta automaticamente la contabilità** già presente nel gestionale — cliente, viaggio **e contabilità generale** — ed **emette in automatico la fattura** (acconto e saldo) inviandone subito una **copia PDF** al cliente (la fattura elettronica segue il consueto flusso di legge). *Dettaglio tecnico: playbook Passi 4.4–4.5.*
- **Blog/Diario**: solo **predisposizione tecnica**, non nel primo rilascio.

---

## 12. ROADMAP A FASI (alto livello — l'effort/preventivo è una fase successiva)

| Fase | Contenuto | Esito |
|---|---|---|
| **1. Database & API** | Nuove tabelle (contenuti web, itinerario, gallerie, newsletter, traduzioni, mappa); funzioni DB; API di sola lettura per il sito | Fondamenta dati |
| **2. Gestionale** | Scheda "Contenuti Web", itinerario drag&drop, gallerie, SEO, traduzione AI, mappa GPX, sezione Newsletter | L'operatore lavora da un solo posto |
| **3. Sito web** | Frontend moderno SEO-first, multilingua, integrazione API, newsletter, link iscrizione | Vetrina nuova |
| **4. Migrazione & Go-live** | Import contenuti/immagini da Drupal, import + matching newsletter, redirect SEO dal vecchio al nuovo | Spegnimento Drupal 7 |

*Nota: le fasi 2 e 3 sono in buona parte parallelizzabili una volta pronta la fase 1.*

---

## 13. DECISIONI PRESE E PUNTI ANCORA APERTI

**✅ Decisioni prese (aggiornate al 19/6):**
1. Editing e newsletter **dentro il gestionale MAUI** (un solo punto).
2. Mappa = **base OpenStreetMap**, area auto-individuata dal GPX, tracciato semplificato (no GPX scaricabile).
3. **Tutte e 5 le lingue subito.**
4. Newsletter a **tutte le email del sistema** per l'azienda abilitata; **consenso già dato → si procede**; tracciamento consenso + disiscrizione d'ora in poi.
5. **ESP opzionale** (costo evidenziato), configurazione **per-azienda** nel DB.
6. **Blog**: predisposizione tecnica sì, realizzazione **non** nel primo rilascio.
7. **Hosting**: si valuta di restare su **Hetzner + Cloudflare** (DB di produzione da confermare).
8. **Recensioni: SFT ha detto sì** → integrate nel sito (fonte Google/TripAdvisor o interne, configurabile).
9. **Pagamenti online Stripe: SFT ha detto sì** → con regole di pagamento e promemoria/solleciti **per-azienda** (§11 + Appendice A.2).
10. **Funzioni opzionali = toggle per-azienda**: essendo multi-azienda, recensioni, pagamenti, blog, ESP, ecc. si **attivano/disattivano per singola azienda** tramite una configurazione dedicata (Appendice A.2). Le scelte di SFT non vincolano le altre aziende.

**📥 Da reperire (Adriano):**
- **Export della lista email da Drupal** (l'accesso è ottenibile su richiesta).

---

## 14. PROSSIMI PASSI
1. Tua revisione di questo documento (direzione corretta?).
2. Chiusura dei punti aperti di §13.
3. Affinamento e versione presentabile al cliente.
4. **Stima dettagliata dell'effort → preventivo** (fase successiva, come da promemoria).

---

## APPENDICE A — Dettaglio tecnico (per Adriano / sviluppo)

### A.1 Database reale — stato verificato
- **Volumi:** 2 aziende · 67 viaggi · 146 date-viaggio · 740 clienti (443 con email).
- **Tabelle chiave:** `ana_viaggi`, `ana_date_viaggi`, `ana_clienti`, `mov_clienti_viaggi`, `mov_clienti_alloggi`, `ana_aziende`.
- **`ana_viaggi`** ha già: `viaggio_link` (URL web attuale), `viaggio_mappa` (bytea) + mimetype/filename, `azienda_id`, FK a tipo viaggio/trattamento/pernottamento/avvicinamento/nazione.
- **`ana_date_viaggi`** ha già tutti i costi e `data_viaggio_effettuato_sino` (Y/N/P).
- **Tassonomie:** `ana_tipo_viaggi` (7 valori tecnici), `ana_tipo_trattamento` (6), `ana_tipo_pernottamento` (4), `ana_tipo_avvicinamento` (4).
- **`ana_clienti`**: ha `cliente_email` (indicizzata, **non univoca**); **nessun campo consenso/marketing**; unico scoped su (azienda, cognome, nome, nascita, CF).
- **`ana_aziende`**: ha `sito_web` e `sito_web_iscrizione`.
- **`ana_aziende_smtp`** (già esistente): configurazione email **per-azienda** completa — host/porta/credenziali cifrate (`password_enc` jsonb), `from_name/from_email/reply_to`, `rate_limit_per_hour`, failover, test di connessione. È la base su cui innestare l'opzione ESP.
- **`ana_aziende_email`** (già esistente): elenco indirizzi di contatto per reparto/azienda.
- **Multi-tenant**: `azienda_id` su tutte le tabelle di dominio + policy RLS `superadmin_bypass_all`.

### A.2 Nuove tabelle proposte (bozza, in stile DB-First)
> Tutte multi-azienda (`azienda_id`) e con audit `created/updated`. Tutto l'accesso via **funzioni PL/pgSQL** (zero SQL inline nei servizi), come da architettura del progetto. Documentare in `Documents/Funzioni_DB.md` dopo l'implementazione.

1. **`web_tour_contenuti`** (1:1 con `ana_viaggi`): sottotitolo, descrizione_html, difficolta, durata_testo, luoghi_visitati, info_pernottamento_html, info_pasti_html, info_equipaggiamento_html, altre_info_html, slug, meta_title, meta_description, stato_pubblicazione (enum bozza/pubblicato/archiviato), ordine, web_categoria_sport.
2. **`web_tour_itinerario`** (N per tour): giorno_numero, titolo_giornata, ordine.
3. **`web_tour_itinerario_passaggi`** (N per giornata): testo_html, immagine/url, didascalia, ordine.
4. **`web_tour_immagini`** (N per tour): tipo (principale/galleria), immagine/url, alt_text, titolo, ordine.
5. **`web_tour_mappa`** (1:1 con tour): gpx (bytea), **bbox calcolato** (min/max lat/lon), immagine_render (bytea o URL), provider (osm/geoapify/…), parametri_render (semplificazione, zoom, margine), data_generazione.
6. **`web_traduzioni`** (per-campo): entità+campo+lingua+testo_tradotto, tradotto_auto (bool), revisionato (bool), obsoleto (bool), data.
7. **`web_categorie_sport`** + mappatura da `ana_tipo_viaggi` (no testo libero).
8. **`web_newsletter_iscritti`**: email_normalizzata (univoca per azienda), nome, cognome, lingua, consenso (data + fonte), stato (attivo/disiscritto), fonte, token_disiscrizione, cliente_fk (nullable → `ana_clienti`). *Nota: l'invio usa una **vista/unione** clienti+iscritti deduplicata, non il semplice elenco di questa tabella.*
9. **`web_newsletter_invii`** (+ righe destinatari/stato consegna): oggetto, corpo_html (per lingua), data_invio, numero_destinatari, stato; bounce/aperture se via ESP.
10. **`web_newsletter_soppressioni`**: email disiscritte / bounce permanenti → escluse da ogni invio.
11. **Config invio per-azienda**: estendere **`ana_aziende_smtp`** (già esistente) per supportare anche il tipo **ESP** (provider, api_key cifrata, dominio mittente), oppure tabella dedicata `ana_aziende_esp`. Scelta SMTP-vs-ESP per-azienda.
12. *(consigliato)* aggiungere a `ana_clienti`: `consenso_marketing` (bool) + `consenso_marketing_data` + fonte.
13. *(futuro, sola predisposizione)* `web_blog_articoli` — per il blog/diario, fuori dal primo rilascio.
14. *(futuro, sola predisposizione)* **Pagamenti — regole per-azienda** `web_pagamenti_regole` (per `azienda_id`): ogni azienda può avere politiche diverse, quindi la tabella definisce —
    - **modalità**: *soluzione unica* **oppure** *acconto + saldo*;
    - **acconto**: previsto sì/no, **percentuale** (o importo fisso), **scadenza** = *alla prenotazione* **oppure** *entro N giorni dalla prenotazione*;
    - **saldo**: **scadenza** = *entro N giorni prima della partenza* (in alternativa: alla prenotazione / entro N giorni dalla prenotazione);
    - **soluzione unica**: **scadenza** analoga (*alla prenotazione* / *N giorni prima della partenza*);
    - valuta, attivo, note.
    Queste regole vengono lette dall'integrazione **Stripe** e dall'**app di iscrizione** per calcolare importi e date di scadenza. Lo spazio dati va predisposto fin da subito, anche se l'incasso online si attiva dopo. *(Estendibile con override per singolo viaggio/data.)*
    - **Promemoria e solleciti di pagamento** (stessa logica per-azienda):
      - **promemoria pre-scadenza**: attivo sì/no, *quando* (es. N giorni prima della scadenza e/o il giorno stesso);
      - **sollecito post-scadenza** (pagamento scaduto): attivo sì/no, *quando* (es. dal giorno dopo, +N giorni), con **tono diverso/più deciso**;
      - **destinatario**: il **cliente finale** (nella sua lingua);
      - **CCN al tour operator**: sì/no + **scelta dell'indirizzo aziendale** a cui mandare la copia nascosta (tra quelli di `ana_aziende_email`);
      - **testi/template** distinti per i due casi (promemoria / scaduto), multilingua.

      *Nota tecnica: se servono più promemoria per la stessa scadenza, conviene una tabella figlia `web_pagamenti_reminder_regole` (1:N). L'invio richiede un **processo schedulato** (job giornaliero) che controlla le scadenze e spedisce le email tramite l'SMTP/ESP dell'azienda (§8.4).*
15. *(futuro, sola predisposizione)* `web_pagamenti_transazioni` (Stripe): traccia gli incassi e lo stato (acconto / saldo / totale pagato), con riferimento a iscrizione / cliente / data viaggio.
16. *(futuro)* `web_pagamenti_reminder_log`: traccia i promemoria/solleciti inviati (destinatario, data, scadenza di riferimento, esito) per non inviarli due volte e per storico.
17. **Configurazione funzioni per-azienda** `web_aziende_funzioni` (per `azienda_fk`): **toggle on/off** delle funzioni opzionali, con eventuali parametri (jsonb). Esempi: `recensioni` (attiva + fonte: google/tripadvisor/interne), `pagamenti_online` (attiva → regole in `web_pagamenti_regole`), `blog`, `newsletter_esp`. Il sito **mostra/nasconde** le sezioni in base a questi flag e il gestionale espone gli switch per ogni azienda. *(Per SFT: recensioni = ON, pagamenti online = ON.)*

### A.3 Stack verificato del gestionale
.NET MAUI Blazor Hybrid · **MudBlazor 8.15.0** · **Blazored.TextEditor 1.1.0** (Quill) · **SixLabors.ImageSharp 3.1.12** · **SkiaSharp 2.88.8** · QuestPDF · PostgreSQL 17.5 (Docker test / Supabase prod).

### A.4 Sito attuale — evidenze SEO raccolte
Header HTTP: `x-generator: Drupal 7`, `x-powered-by: PHP/5.6.40`, `content-language: it`, canonical presente. Home: title keyword-rich OK, meta description OK, OG parziale (manca og:image), **0 JSON-LD**, **0 hreflang**, viewport `user-scalable=0`, immagini jpg/png senza lazy-load. Pagina tour: title generico "Tour: …", **0 dati strutturati**.
