# Analisi Preliminare - Nuovo Sito Web Sardegna Fuori Traccia

**Versione:** 1.0 - Documento Preliminare
**Data:** 19 Giugno 2026
**Stato:** Bozza per revisione interna

---

## 1. CONTESTO E OBIETTIVO DEL PROGETTO

### Situazione Attuale
Sardegna Fuori Traccia (SFT) dispone attualmente di:
- Un **sito web** (sardegnafuoritraccia.it) basato su Drupal, con una sezione di backend che permette al tour operator di gestire in autonomia i contenuti dei viaggi (tour)
- Un **software gestionale** (applicazione desktop MAUI) che gestisce anagrafica clienti, viaggi, date, iscrizioni, alloggi, fatturazione e contabilità, con database PostgreSQL
- Un'**app web di iscrizione** (iscrizioni.sardegnafuoritraccia.it) già integrata con il gestionale, che consente ai clienti di iscriversi ai viaggi direttamente dal sito

### Obiettivo
Rifare il sito web di SFT con un approccio moderno, mantenendo e potenziando tutte le funzionalità attuali, con questi obiettivi chiave:

1. **Centralizzare la gestione** - Il gestionale diventa il "motore unico": un solo database alimenta sia il gestionale che il sito web
2. **Mantenere l'autonomia dell'operatore** - Il tour operator deve poter aggiornare il sito senza competenze tecniche, come fa oggi
3. **Traduzione automatica multilingua** - I contenuti devono essere automaticamente tradotti in 5 lingue (IT, FR, EN, DE, ES)
4. **Unificare le anagrafiche** - Clienti del gestionale e iscritti alla newsletter confluiscono in un unico sistema
5. **Preservare l'app di iscrizione** - L'attuale sistema di iscrizione online deve continuare a funzionare
6. **Migliorare SEO e immagine** - Il nuovo sito deve seguire le best practice dei migliori tour operator offroad

---

## 2. ANALISI DEL SITO WEB ATTUALE

### 2.1 Struttura del Sito
Dall'analisi delle schermate e della struttura visibile, il sito attuale presenta:

**Menu di navigazione principale:**
- Home | Fuoristrada | Quad | Estero | Moto | Foto | Video | Contatti | Strumenti

**Pagine principali:**
- Homepage con elenco tour (tabella con foto, titolo, sport, data inizio, difficoltà, durata)
- Pagine dettaglio tour con itinerario giorno per giorno
- Galleria foto e video
- Pagina contatti
- Sezione "Strumenti" (probabilmente con link alla newsletter e altre utility)

**Lingue disponibili:** Italiano e Francese (bandierine nel header)

**CMS:** Drupal (riconoscibile dalla struttura del backend, dall'uso di CKEditor, dalla gestione dei nodi/contenuti)

### 2.2 Analisi SEO - Stato Attuale e Criticità

**Elementi presumibilmente presenti:**
- URL parlanti in italiano (es. `/it/tour/fuoristrada/barbagia-wild-tour`)
- Struttura breadcrumb (Home > Tour Name)
- Testi alt sulle immagini della galleria

**Criticità e mancanze probabili:**
- **Schema.org/Structured Data** - Assente o incompleto. Per i tour servirebbero markup `TouristTrip`, `Event`, `Offer` per apparire nei rich snippet di Google
- **Meta description personalizzate** - Probabilmente auto-generate da Drupal
- **Sitemap XML** - Da verificare se presente e aggiornata
- **Performance/Core Web Vitals** - Drupal tende ad essere pesante; serve ottimizzazione
- **Contenuti duplicati multilingua** - Con solo IT e FR, manca `hreflang` per le 5 lingue target
- **Blog/contenuti SEO** - Manca una sezione blog/diario di viaggio che genererebbe traffico organico
- **Google Business Profile** - Da verificare integrazione
- **Open Graph / Social Meta** - Probabilmente basici o assenti

### 2.3 Backend Attuale - Gestione Tour (da screenshot)
Il tour operator compila questi campi per ogni tour:

| Campo | Tipo | Note |
|-------|------|------|
| Lingua | Select | IT/FR |
| Titolo Tour | Testo | Obbligatorio |
| Sottotitolo | Testo | Breve descrizione |
| Foto Principale | Upload immagine | Con alt text e titolo |
| Galleria Immagini | Upload multipli | Con alt text, titolo e ordinamento |
| Sport | Select | Fuoristrada, Moto Enduro, Moto Stradale, Quad |
| Servizio Associato | Select | Tipo di escursione |
| Periodo (Da/A) | Date | Data inizio e fine |
| Durata | Testo | Es. "5gg/4nn in campeggio" |
| Difficoltà | Select | Turistica, Media, Medio-Alta |
| Principali Luoghi Visitati | Testo | Elenco separato da virgole |
| Descrizione Tour | Rich text (CKEditor) | Descrizione promozionale |
| Itinerario Giorno per Giorno | Struttura ripetibile | Per ogni giornata: Titolo + Passaggi multipli |
| → Passaggio della Giornata | Rich text + Immagine | Testo + foto + didascalia per ogni tappa |
| Info Pernottamento | Rich text | Dettagli alloggio |
| Info Pasti | Rich text | Dettagli trattamento |
| Dotazioni ed Equipaggiamento | Rich text | Cosa portare/serve |
| Altre Informazioni | Rich text | Meteo, consigli, ecc. |

Funzionalità: **Visualizza / Modifica / Clona**

---

## 3. BEST PRACTICE DEI MIGLIORI SITI WEB DI TOUR OFFROAD

Dall'analisi dei siti di riferimento nel settore (Nomade Aventure, Terre d'Aventure, Morocco Overland, Iceland Rovers, G Adventures, Overland Expeditions, e altri specialisti offroad), emergono le seguenti best practice:

### 3.1 Design e UX
- **Hero section** con immagine/video full-screen e call-to-action chiara
- **Filtri rapidi** per destinazione, tipo mezzo, difficoltà, durata, fascia di prezzo
- **Vista calendario** dei prossimi tour con disponibilità visiva
- **Card tour** con foto accattivante, prezzo "a partire da", rating/recensioni, badge (es. "Ultimi posti", "Novità")
- **Design mobile-first** - la maggior parte del traffico è da smartphone
- **Velocità di caricamento** - immagini ottimizzate (WebP/AVIF), lazy loading

### 3.2 Contenuti Tour
- **Itinerario interattivo** con mappa del percorso (possibilmente con traccia GPX visualizzata)
- **Scheda tecnica** chiara: km totali, dislivelli, fondo stradale, tipo mezzo richiesto
- **Galleria fotografica** con lightbox e possibilità di zoom
- **Video trailer** del tour (anche solo 30-60 secondi)
- **Download** del programma in PDF
- **Sezione FAQ** specifica per ogni tour o globale
- **Recensioni dei partecipanti** con foto e nome

### 3.3 Conversione e Engagement
- **CTA "Iscriviti/Prenota" ben visibile** e sempre raggiungibile durante lo scroll
- **WhatsApp / Chat** per contatto rapido
- **Countdown** alla prossima data disponibile
- **Social proof** - feed Instagram, numero partecipanti, recensioni Google/TripAdvisor
- **Condivisione social** per ogni tour
- **Newsletter** con form ben posizionato e incentivo (es. sconto, anteprima date)

### 3.4 SEO e Visibilità
- **Schema.org markup** per ogni tour (`TouristTrip`, `Event`, `AggregateOffer`)
- **Blog/Diario di viaggio** con contenuti originali e foto (SEO a coda lunga)
- **Landing page per destinazione** (es. "Tour 4x4 Sardegna", "Offroad Barbagia")
- **Pagina comparativa** tra tour simili
- **Sitemap multilingua** con `hreflang` corretti
- **Google Business Profile** aggiornato con post e foto

---

## 4. ANALISI DEL DATABASE ATTUALE E GAP IDENTIFICATI

### 4.1 Cosa Esiste Già nel Database del Gestionale

Il database PostgreSQL contiene già una base solida:

**Tabella `ana_viaggi`** (Anagrafica Viaggi):
- Identificativo, Descrizione breve, Descrizione estesa, Giorni, Notti, Km, Note
- Tipo viaggio (FK → 4X4, SUV, Enduro, Moto Stradale, Quad)
- Tipo trattamento (FK → Mezza pensione, Pensione completa, Nessuno, ecc.)
- Tipo pernottamento (FK → Albergo, Campi tendati, Nessuno, ecc.)
- Tipo avvicinamento (FK → Veicolo, Traghetto, Aereo, Treno)
- Nazione di destinazione
- Link al sito web attuale
- Mappa (file binario)
- Azienda di appartenenza (multi-tenant)

**Tabella `ana_date_viaggi`** (Date e Prezzi):
- Data inizio e fine per ogni edizione del viaggio
- Costi per pilota, passeggero, passeggero auto-guida, bambini (3 fasce)
- Stato effettuazione (Y/N/P)
- Note specifiche per data

**Tabella `ana_clienti`** (Anagrafica Clienti):
- Dati completi: nome, cognome, sesso, data nascita, residenza, telefono, email
- Documenti: tipo, numero, scadenza, foto documento
- Codice fiscale, IBAN
- Intolleranze alimentari

**Tabelle di movimento** (`mov_clienti_viaggi`, `mov_clienti_alloggi`):
- Iscrizioni ai viaggi con tipo partecipante e mezzo
- Assegnazione alloggi

### 4.2 Gap Identificati - Cosa Manca nel Database

Confrontando i campi gestiti dal backend attuale del sito web con il database del gestionale, i gap sono significativi. Qui sotto l'elenco di ciò che andrebbe aggiunto:

#### A) Nuova Tabella: `web_tour_contenuti` (Contenuti Web del Tour)
Campi da aggiungere legati al singolo viaggio, dedicati alla pubblicazione web:

| Campo Mancante | Tipo | Descrizione |
|----------------|------|-------------|
| **Sottotitolo** | varchar(500) | Es. "Selvaggia Sardegna" - non presente in DB |
| **Descrizione promozionale** | text (HTML) | Rich text per il sito, diverso dalla descrizione_estesa del gestionale |
| **Sport/Categoria web** | varchar | "Fuoristrada", "Quad", "Moto Enduro" - diverso dal tipo_viaggi tecnico |
| **Servizio associato** | varchar | "Escursioni e Tour Fuoristrada 4x4 in Sardegna" |
| **Difficoltà** | varchar/enum | Turistica, Media, Medio-Alta, Alta |
| **Durata testuale** | varchar | "5gg/4nn in campeggio" - nel DB ci sono solo i numeri |
| **Principali luoghi visitati** | text | Lista testuale |
| **Info pernottamento** | text (HTML) | Rich text descrittivo (non solo il tipo) |
| **Info pasti** | text (HTML) | Rich text descrittivo |
| **Dotazioni/equipaggiamento** | text (HTML) | Cosa portare |
| **Altre informazioni** | text (HTML) | Meteo, consigli, ecc. |
| **URL slug** | varchar | Parte URL per SEO (es. "barbagia-wild-tour") |
| **Meta title** | varchar | Per SEO |
| **Meta description** | text | Per SEO |
| **Stato pubblicazione** | enum | Bozza / Pubblicato / Archiviato |
| **Ordine visualizzazione** | integer | Per ordinamento manuale nella lista |

#### B) Nuova Tabella: `web_tour_itinerario` (Itinerario Giorno per Giorno)
Completamente assente nel DB. Struttura necessaria:

| Campo | Tipo | Descrizione |
|-------|------|-------------|
| tour_contenuto_fk | FK | Riferimento al tour |
| giorno_numero | integer | Ordine del giorno (1, 2, 3...) |
| titolo_giornata | varchar | Es. "1 TAPPA - COSTA DEL SINIS E MONTE ARCI" |
| ordine | integer | Per riordinamento |

#### C) Nuova Tabella: `web_tour_itinerario_passaggi` (Passaggi della Giornata)
Ogni giornata può avere più passaggi:

| Campo | Tipo | Descrizione |
|-------|------|-------------|
| itinerario_fk | FK | Riferimento alla giornata |
| testo_passaggio | text (HTML) | Descrizione del passaggio |
| immagine | bytea o URL | Foto del passaggio |
| didascalia_immagine | varchar | Didascalia foto |
| ordine | integer | Per ordinamento |

#### D) Nuova Tabella: `web_tour_immagini` (Galleria Fotografica)
Gestione immagini per il sito web:

| Campo | Tipo | Descrizione |
|-------|------|-------------|
| tour_contenuto_fk | FK | Riferimento al tour |
| tipo_immagine | enum | 'principale' / 'galleria' |
| immagine | bytea o URL | Il file immagine |
| alt_text | varchar | Testo alternativo (SEO + accessibilità) |
| titolo | varchar | Titolo/tooltip |
| ordine | integer | Per ordinamento |

#### E) Nuova Tabella: `web_newsletter_iscritti` (Newsletter)
Completamente assente. Da creare:

| Campo | Tipo | Descrizione |
|-------|------|-------------|
| email | varchar | Email dell'iscritto |
| nome | varchar | Opzionale |
| cognome | varchar | Opzionale |
| lingua_preferita | varchar | IT/FR/EN/DE/ES |
| data_iscrizione | timestamp | Quando si è iscritto |
| consenso_privacy | boolean | GDPR |
| data_consenso | timestamp | Quando ha dato il consenso |
| attivo | boolean | Per disiscrizione |
| fonte | varchar | 'sito_web' / 'gestionale' / 'importato' |
| cliente_fk | integer, nullable | FK opzionale verso ana_clienti (se è anche cliente) |

#### F) Nuova Tabella: `web_newsletter_invii` (Storico Newsletter)
Per tracciare gli invii:

| Campo | Tipo | Descrizione |
|-------|------|-------------|
| oggetto | varchar | Oggetto dell'email |
| corpo | text (HTML) | Contenuto della newsletter |
| data_invio | timestamp | Quando è stata inviata |
| numero_destinatari | integer | Quanti hanno ricevuto |
| stato | enum | Bozza / Inviata |

#### G) Tabella `web_tour_traduzioni` (Contenuti Multilingua)
Per gestire le traduzioni di tutti i testi:

| Campo | Tipo | Descrizione |
|-------|------|-------------|
| contenuto_originale_fk | FK | Riferimento al contenuto originale |
| tipo_contenuto | varchar | 'tour_descrizione', 'itinerario_passaggio', ecc. |
| lingua | varchar(2) | EN, FR, DE, ES |
| testo_tradotto | text | Traduzione |
| tradotto_automaticamente | boolean | Se tradotto da AI |
| revisionato | boolean | Se revisionato da umano |
| data_traduzione | timestamp | Quando è stato tradotto |

### 4.3 Riepilogo Visivo dei Gap

```
GESTIONALE (oggi)              SITO WEB (oggi - Drupal)         GAP
─────────────────              ─────────────────────             ───
✅ Nome viaggio                ✅ Titolo Tour                    ≈ (mapping diretto)
❌ -                           ✅ Sottotitolo                    🔴 MANCA
✅ Descrizione estesa (testo)  ✅ Descrizione (HTML ricco)       🟡 DIVERSO FORMATO
❌ -                           ✅ Difficoltà                     🔴 MANCA
❌ -                           ✅ Durata testuale                🔴 MANCA
❌ -                           ✅ Luoghi visitati                🔴 MANCA
✅ Tipo viaggio (tecnico)      ✅ Sport/Categoria (web)          🟡 MAPPING NECESSARIO
✅ Tipo pernottamento (lookup) ✅ Info pernottamento (HTML)      🟡 SERVE ANCHE TESTO LIBERO
✅ Tipo trattamento (lookup)   ✅ Info pasti (HTML)              🟡 SERVE ANCHE TESTO LIBERO
❌ -                           ✅ Equipaggiamento (HTML)         🔴 MANCA
❌ -                           ✅ Altre informazioni (HTML)      🔴 MANCA
✅ Mappa (blob)                ✅ Foto principale                🟡 SCOPO DIVERSO
❌ -                           ✅ Galleria immagini               🔴 MANCA
❌ -                           ✅ Itinerario giorno per giorno   🔴 MANCA (gap maggiore)
✅ Date + Prezzi               ✅ Periodo + Costi                ✅ GIÀ PRESENTE
❌ -                           ✅ SEO (slug, meta, ecc.)         🔴 MANCA
❌ -                           ✅ Stato pubblicazione            🔴 MANCA
❌ -                           ✅ Newsletter                     🔴 MANCA INTERAMENTE
❌ -                           ✅ Multilingua                    🔴 MANCA INTERAMENTE
```

---

## 5. APP DI ISCRIZIONE - INTEGRAZIONE ESISTENTE

### Stato Attuale
L'app di iscrizione (iscrizioni.sardegnafuoritraccia.it) è:
- Sviluppata in **Python/Flask** con frontend **React** (SPA)
- Già connessa al **database PostgreSQL** del gestionale
- **Multi-azienda**: l'URL contiene l'identificativo azienda (es. `/2-TOKEN/`)
- Scrive direttamente su `ana_clienti`, `mov_clienti_viaggi`, `mov_clienti_alloggi`
- Invia email di conferma al cliente e riepilogo alla segreteria

### Cosa Preservare
- L'app resta **esattamente come è oggi**
- Il sito web nuovo continuerà ad avere il bottone "Iscriviti" che punta a questa app
- Nessuna modifica al flusso di iscrizione
- Il link dal sito al sistema di iscrizione può essere generato automaticamente dal gestionale, perché l'azienda_id e il viaggio sono già nel DB

### Possibile Evoluzione Futura (non in scope ora)
- Integrare il form di iscrizione direttamente nel nuovo sito come componente embedded
- Aggiungere pagamento online

---

## 6. STRATEGIA MULTILINGUA

### Requisito
Tutti i contenuti del sito devono essere disponibili in: **Italiano, Francese, Inglese, Tedesco, Spagnolo**

### Soluzione Proposta: Traduzione Automatica AI con Revisione

**Flusso operativo per l'utente:**
1. L'operatore scrive i contenuti del tour **solo in italiano** (come fa oggi)
2. Premendo un bottone "Traduci" nel gestionale, un servizio AI traduce automaticamente tutti i testi nelle 4 lingue aggiuntive
3. Le traduzioni vengono salvate nel database (tabella `web_tour_traduzioni`)
4. L'operatore **può** revisionare e correggere manualmente le traduzioni (opzionale)
5. Quando un testo italiano viene modificato, il sistema segnala che le traduzioni potrebbero essere obsolete

**Tecnologia per la traduzione:**
- **Opzione consigliata: API Claude/Anthropic** - Eccellente qualità per testi turistici e promozionali, comprende il contesto e mantiene il tono del brand
- Opzione alternativa: DeepL API - Buona qualità, costo prevedibile per parola
- Opzione economica: Google Translate API - Costo basso ma qualità inferiore per testi creativi

**Vantaggi dell'approccio AI rispetto a traduzioni manuali:**
- Costo bassissimo (centesimi per tour)
- Velocità immediata
- Coerenza terminologica tra tutti i tour
- L'operatore non deve più fare copia/incolla su strumenti esterni

**Elementi da tradurre:**
- Titolo e sottotitolo del tour
- Descrizione promozionale
- Itinerario giorno per giorno (tutti i passaggi)
- Info pernottamento, pasti, equipaggiamento, altre info
- Testi statici del sito (menu, footer, pulsanti, ecc.)
- Meta description per SEO multilingua

**Elementi che NON vanno tradotti:**
- Nomi propri di luoghi (Barbagia, Ogliastra, Monte Arci - restano in italiano)
- Prezzi e date
- Dati tecnici (km, quote, coordinate)

---

## 7. UNIFICAZIONE ANAGRAFICHE: CLIENTI + NEWSLETTER

### Problema Attuale
Oggi esistono due "mondi" separati:
1. **Clienti nel gestionale** - chi ha partecipato o si è iscritto a un viaggio (con tutti i dati anagrafici)
2. **Iscritti alla newsletter** - nel database Drupal del sito web (probabilmente solo email e poco altro)

Queste due liste hanno sicuramente sovrapposizioni: clienti che sono anche iscritti alla newsletter.

### Soluzione Proposta

**Nuova tabella `web_newsletter_iscritti`** nel database PostgreSQL del gestionale, con un campo opzionale `cliente_fk` che collega l'iscritto alla newsletter al cliente del gestionale.

**Flusso di unificazione:**
1. **Importazione iniziale**: le email della newsletter Drupal vengono importate nella nuova tabella
2. **Matching automatico**: per ogni email importata, il sistema cerca corrispondenze in `ana_clienti` (per email)
3. **Collegamento**: dove c'è match, si crea il link `cliente_fk`
4. **Deduplicazione**: se un cliente del gestionale è anche nella newsletter, la newsletter viene inviata una sola volta
5. **Flusso continuo**: quando un nuovo cliente si iscrive (via app iscrizione), l'email viene automaticamente aggiunta anche alla lista newsletter (con consenso)

**Regola fondamentale:** chi lascia solo l'email per la newsletter **non diventa automaticamente un cliente**. Diventa cliente solo quando partecipa a un viaggio. Ma il sistema sa che sono potenzialmente la stessa persona.

**Target newsletter:** al momento dell'invio, il sistema unisce:
- Iscritti alla newsletter (attivi, non disiscritti)
- Clienti del gestionale con email valida e consenso marketing

Eliminando automaticamente i duplicati.

---

## 8. ARCHITETTURA PROPOSTA - IL GESTIONALE COME MOTORE DEL SITO

### Concetto Chiave
Il gestionale non genera direttamente le pagine HTML. Invece:

```
┌─────────────────────┐
│   GESTIONALE MAUI   │ ← L'operatore gestisce tutto qui
│  (App Desktop .NET) │
└──────────┬──────────┘
           │ scrive su
           ▼
┌─────────────────────┐
│   DATABASE POSTGRES  │ ← Fonte unica di verità
│  (viaggi + web data) │
└──────────┬──────────┘
           │ letto da
           ▼
┌─────────────────────┐
│    SITO WEB NUOVO    │ ← Frontend moderno (SSR o SSG)
│   (Next.js / Nuxt)   │
└──────────┬──────────┘
           │ link a
           ▼
┌─────────────────────┐
│  APP ISCRIZIONE      │ ← Resta com'è (Flask/React)
│  (già funzionante)   │
└─────────────────────┘
```

### Flusso Operativo per il Tour Operator

1. **Crea/modifica un viaggio** nel gestionale (dati operativi: giorni, notti, costi, tipo)
2. **Aggiunge i contenuti web** tramite una nuova sezione del gestionale:
   - Sottotitolo, descrizione promozionale, difficoltà, luoghi
   - Itinerario giorno per giorno con foto
   - Info alloggio, pasti, equipaggiamento
   - Galleria fotografica
3. **Preme "Traduci"** → le traduzioni vengono generate automaticamente
4. **Preme "Pubblica sul sito"** → il contenuto diventa visibile sul sito web
5. Il sito web legge dal database e mostra le pagine aggiornate

### Tecnologia Sito Web
Il nuovo sito web sarà un'applicazione web moderna (separata dal gestionale) che legge i dati dal database PostgreSQL, possibilmente attraverso una API REST/GraphQL dedicata.

Opzioni tecnologiche da valutare:
- **Blazor Server/WASM** - stessa tecnologia .NET del gestionale (competenze condivise)
- **Next.js** - React SSR/SSG, ottimo per SEO, ecosistema ricchissimo
- **Nuxt.js** - Equivalente Vue.js

---

## 9. FUNZIONALITÀ DEL NUOVO SITO WEB

### 9.1 Pagine e Sezioni

| Pagina | Descrizione |
|--------|-------------|
| **Homepage** | Hero con video/foto, tour in evidenza, filtri rapidi, prossime partenze |
| **Lista Tour per categoria** | Fuoristrada, Quad, Moto, Estero - con filtri e ordinamento |
| **Dettaglio Tour** | Tutte le info, itinerario giorno per giorno, galleria, mappa, prezzi, CTA iscrizione |
| **Calendario Partenze** | Vista calendario con tutte le date disponibili |
| **Chi Siamo** | Storia, team, filosofia |
| **Galleria Foto** | Portfolio fotografico per tour/destinazione |
| **Video** | Raccolta video dei tour |
| **Blog/Diario** | Racconti di viaggio, consigli, SEO content |
| **Contatti** | Form, mappa, WhatsApp, social |
| **Newsletter** | Iscrizione con scelta lingua preferita |
| **FAQ** | Domande frequenti |
| **Privacy/Cookie Policy** | Obbligatorie GDPR |

### 9.2 Funzionalità Chiave

- **Filtri tour**: per tipo mezzo, destinazione, difficoltà, durata, fascia prezzo, disponibilità
- **Prossime partenze**: sezione in evidenza con countdown
- **Badge dinamici**: "Ultimi posti", "Novità", "Sold Out" (calcolati dal gestionale)
- **Prezzo "a partire da"**: mostrato automaticamente dal prezzo minimo in `ana_date_viaggi`
- **Mappa interattiva** del percorso con traccia GPX (se disponibile)
- **Download PDF** del programma (generabile automaticamente da QuestPDF, già usato nel gestionale)
- **Condivisione social** per ogni tour
- **Cookie consent** GDPR compliant
- **Responsive design** mobile-first

---

## 10. SEZIONE GESTIONALE - NUOVE FUNZIONALITÀ DA AGGIUNGERE

Nel gestionale MAUI saranno aggiunte queste nuove funzionalità:

### 10.1 Editor Contenuti Web del Tour
Una nuova tab/sezione nella scheda viaggio con:
- Editor rich text (WYSIWYG) per descrizione promozionale
- Gestione itinerario giorno per giorno (drag & drop per riordinare)
- Upload e gestione galleria immagini (con crop/ridimensionamento)
- Campi SEO (slug, meta title, meta description)
- Pulsante "Traduci" per generazione automatica traduzioni
- Pulsante "Pubblica" per rendere visibile sul sito
- Pulsante "Anteprima" per vedere come apparirà sul sito
- Funzionalità "Clona" per creare un nuovo tour da uno esistente (copia anche contenuti web)

### 10.2 Gestione Newsletter
Una nuova sezione del gestionale per:
- Visualizzare gli iscritti alla newsletter (con filtri per lingua, fonte, stato)
- Comporre newsletter con editor rich text
- Selezionare i destinatari (tutti, solo newsletter, solo clienti, per lingua)
- Anteprima multilingua della newsletter
- Invio con deduplicazione automatica
- Storico invii

### 10.3 Dashboard Sito Web
Un pannello nel gestionale che mostra:
- Tour pubblicati vs bozza
- Traduzioni mancanti o obsolete
- Iscritti newsletter (numero e trend)

---

## 11. PIANO DI MIGRAZIONE

### Fase 1 - Database e Backend (settimane 1-3)
1. Creare le nuove tabelle nel database PostgreSQL
2. Creare le funzioni DB per CRUD dei nuovi dati
3. Sviluppare le API REST per il sito web

### Fase 2 - Gestionale (settimane 3-6)
1. Aggiungere editor contenuti web nella scheda viaggio
2. Integrare upload e gestione immagini
3. Implementare traduzione automatica AI
4. Aggiungere gestione newsletter

### Fase 3 - Sito Web (settimane 5-10)
1. Sviluppare il nuovo sito web con design moderno
2. Integrare con API del database
3. Implementare multilingua
4. SEO optimization
5. Integrazione newsletter

### Fase 4 - Migrazione Dati e Go-Live (settimane 10-12)
1. Importare contenuti dal sito Drupal nelle nuove tabelle
2. Importare lista newsletter dal DB Drupal
3. Matching email newsletter ↔ clienti gestionale
4. Test completo
5. Go-live e redirect dal vecchio al nuovo sito

---

## 12. CONSIDERAZIONI FINALI

### Vantaggi dell'Approccio Proposto
- **Un solo punto di gestione**: l'operatore fa tutto dal gestionale, non deve più imparare due sistemi
- **Un solo database**: niente più dati duplicati o disallineati tra gestionale e sito
- **Multilingua automatico**: risparmio enorme di tempo e costi
- **Anagrafiche unificate**: visione completa dei clienti e potenziali clienti
- **Migliore SEO**: sito moderno, veloce, con markup strutturati
- **App iscrizione preservata**: nessuna interruzione del servizio esistente

### Rischi e Mitigazioni
| Rischio | Mitigazione |
|---------|-------------|
| Complessità dell'editor rich text in MAUI | Usare componenti collaudati (es. Syncfusion, Telerik) |
| Qualità traduzioni AI | Permettere revisione manuale, usare prompt specializzati per turismo |
| Migrazione contenuti da Drupal | Pianificare export strutturato con anticipo |
| Performance sito con molte immagini | CDN, ottimizzazione immagini automatica, lazy loading |

### Prossimi Passi
1. **Revisione di questo documento** insieme per validare l'approccio
2. **Presentazione al cliente** per approvazione funzionale
3. **Stima dettagliata dell'effort** per formulare il preventivo
4. **Scelta della tecnologia** per il frontend del sito web
5. **Definizione delle priorità** (cosa va live per primo)

---

*Documento generato come analisi preliminare. Da raffinare dopo discussione interna e con il cliente.*
