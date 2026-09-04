# Analisi lavori rimanenti — Nuovo Sito Web SFT

> **USO INTERNO (Adriano + AI).** Fa seguito a `2026-07-12-Valutazione_Critica_Sito_INTERNO.md`, di cui recepisce le **decisioni prese da Adriano** (risposte in maiuscolo nel doc). Data: 2026-07-13.
> Questo documento traccia **cosa resta da fare** ora che i punti aperti sono chiusi. Ordine: prima le aggiunte al CMS (gestionale), poi il sito.

## Decisioni recepite (sintesi)
- **Infra confermata**: DB su **Supabase**, iscrizioni su **Hetzner**, Cloudflare davanti.
- **Frontend deciso** (Allegato 2 — Analisi Tecnica Dettagliata): **Next.js (App Router, React), SEO-first**, ISR (pagine tour statiche + rigenerazione in background) + **revalidation on-demand**, lettura server-side con `@supabase/ssr`, espone **solo i contenuti pubblicati** via **RLS anon**. Fasi 0→4.
- **Incluso/Escluso**: campi **dedicati su `ana_viaggi`** (livello viaggio, non per data). Prossimo passo immediato.
- **Capienza / posti rimasti**: due campi su `ana_viaggi` + **trigger** DB-first (dettaglio sotto). Prossimo passo immediato. ** Nota Adriano: il trigger deve scattare appena raggiunto il limite di capienza, ma deve scattare (sotto questo limite) ogni volta che arriva una nuova prenotazione, gestendo quindi di conseguenza una ripubblicazione della pagina web in automatico per avere immediatezza lato cliente che i posti rimasti non sono più (ad esempio) 3, ma sono diventati 2, poi uno, poi va anche gestito il caso 0 posti disponibili, con la scritta SOLD OUT
- **Tour brevi/giornalieri**: **flag su `ana_tipo_viaggi`** → categoria web dedicata → sezione sito **condizionale** (compare solo se esistono tour di quel tipo). Non solo per stranieri.
- **Recensioni**: fonte **Google + TripAdvisor** (il cliente ha 5/5). Integrazione lato sito, vicino alla CTA.
- **Mappa interattiva nazioni**: **nel 1° rilascio**.
- **Video hero**: sì (materiale del cliente in arrivo). **Set fotografico**: il cliente ci sta lavorando.
- **Pagamenti Stripe + fatturazione**: **fase successiva** (regole per-azienda già predisposte a DB).

---

## A. Aggiunte al CMS (gestionale) — prossimi passi immediati, DB-first

### A.1 Incluso / Escluso (su `ana_viaggi`)
Attributo del **viaggio** (uguale per tutte le edizioni), come la difficoltà — letto live dal sito.
- **DB**: aggiungere a `ana_viaggi` **due campi HTML** — `viaggio_incluso` e `viaggio_escluso` (l'operatore scrive elenchi puntati). **Deciso (Adriano): niente tabella figlia strutturata, bastano i due campi.**
- **CRUD**: estendere `sp_ana_viaggi_create/update` + `fn_ana_viaggi_get_by_id/get_all` (come già fatto per `viaggio_difficolta`, script 467).
- **C#**: `AnaViaggi` model + `AnaViaggiService` (bind/map) + editor nel dialog viaggio (2 editor Quill).
- **Traduzioni**: aggiungere i due campi al set tradotto (Blocco 10 orchestrator + `web_traduzioni`).
- **Strato pubblico**: esporre i due campi in `fn_web_tour_pubblicati` (o via join `ana_viaggi`) per la scheda tour.

### A.2 Capienza e "posti rimasti" (su `ana_viaggi` + trigger)
Proposta tecnica **approvata dal cliente**.
- **DB — `ana_viaggi`**: `viaggio_capienza_max` INTEGER (posti totali) + `viaggio_capienza_alert` INTEGER (soglia: sotto questo numero il sito scrive "Rimangono solo N posti", dove N è il residuo reale).
- **Calcolo posti rimasti** (per **edizione/data**, perché gli iscritti sono per data): `posti_rimasti(data) = viaggio_capienza_max − occupati(data)`, dove `occupati(data)` = iscritti in `mov_clienti_viaggi` per quella `data_viaggio` (verificare la chiave data in `mov_clienti_viaggi`).
- **Trigger DB-first**: su `mov_clienti_viaggi` (INSERT/UPDATE/DELETE) → ricalcola e mantiene un **campo cache** su `ana_date_viaggi` (es. `data_viaggio_posti_rimasti` o `_occupati`), così il sito legge veloce senza contare al volo. Ricalcolo idempotente (SET = max − count). *(Alternativa senza trigger: calcolo live in `fn_web_tour_pubblicati`; ma la scelta condivisa è il trigger → cache mantenuta.)*
- **Logica badge (strato pubblico / sito)**: `rimasti > alert` → nessuna scritta (o "Disponibile"); `0 < rimasti ≤ alert` → **"Rimangono solo N posti"**; `rimasti = 0` → **"SOLD OUT"**.
- **Aggiornamento IMMEDIATO sul sito (richiesta Adriano)**: il trigger scatta **ad ogni variazione** di prenotazione (non solo al raggiungimento della soglia) e, oltre a ricalcolare il residuo, **innesca la ripubblicazione automatica della pagina tour** (revalidation on-demand di Next.js) così il visitatore vede subito il numero aggiornato in tempo reale (3 → 2 → 1) e, a **0 posti, "SOLD OUT"**. Meccanismo: il trigger (o una funzione chiamata da esso) segnala al sito quale pagina/edizione rigenerare (webhook/endpoint di revalidation). *(Da definire in fase tecnica il canale di notifica trigger→sito; il concetto è approvato.)*
- **Esposizione**: aggiungere `posti_rimasti` (e/o il badge) all'output di `fn_web_tour_pubblicati` per-edizione.
- **UI gestionale**: i due campi capienza nel dialog viaggio (accanto a difficoltà/km).

### A.3 Tour brevi / giornalieri (flag su `ana_tipo_viaggi`)
- **DB**: aggiungere a `ana_tipo_viaggi` un flag (es. `tipo_viaggio_breve` BOOLEAN, default false) per marcare i tipi "esperienza breve 1–3 gg". *(Non è legato al mercato estero: è solo una categorizzazione.)*
- **Categoria web dedicata**: i tour con tipo marcato confluiscono in una **categoria web "Tour giornalieri"** (via la mappatura tipo→descrizione web già esistente, Blocco 8).
- **Sito — sezione condizionale**: la voce di menu / sezione "Tour giornalieri" **compare solo se** esistono tour pubblicati di quel tipo per l'azienda; altrimenti **non appare**. (Lato strato pubblico: una funzione che dice se esistono tour "brevi" pubblicati.)
- **UI gestionale**: checkbox sul tipo viaggio (pagina Tipologie Viaggio).

### A.4 Recensioni — Google + TripAdvisor
- **Fonte decisa**: **Google + TripAdvisor** (nessuna tabella recensioni interna, nessuna moderazione lato nostro).
- **CMS/config**: il flag `web_aziende_funzioni.recensioni` (già esistente) governa on/off; aggiungere in `parametri` (jsonb) l'identificativo/URL della scheda Google (Place ID) e TripAdvisor per-azienda.
- **Sito**: widget/embed (o API) delle recensioni **nella scheda tour, accanto alla CTA** (correggendo l'errore di IMTBike che le mette in fondo). Rating aggregato a stelle + qualche recensione.
- *Nota:* verificare vincoli/branding delle API/widget Google e TripAdvisor in fase tecnica.

---

### A.5 Pagina pubblica di iscrizione alla newsletter (con link condivisibile)
*(Deciso il 2026-09-04.)*

- **Il caso reale**: molte persone scrivono ad Antonio per email o WhatsApp per chiedere
  informazioni su un viaggio. Sono contatti caldi — hanno alzato la mano da soli — e oggi
  finiscono nel nulla: nessuno chiede loro il consenso, e la conversazione si chiude lì.
- **Cosa serve**: una pagina pubblica, con un **indirizzo stabile e corto**, che permetta
  l'iscrizione alla newsletter. Antonio incolla quel link a mano in fondo alla risposta —
  «se ti va di restare aggiornato, iscriviti qui» — e chi vuole si iscrive da sé.
- **Perché funziona meglio di una spunta**: chi arriva da quel link si sta iscrivendo di
  **propria iniziativa**. È la forma di consenso più solida che esista, e non richiede ad
  Antonio nient'altro che incollare un indirizzo.
- **Vincolo tecnico, non negoziabile**: la pagina **non scrive nel database per conto suo**.
  Passa dalle stesse funzioni che usano il gestionale e il sito di iscrizione
  (`fn_consenso_registra_risposta` e le `fn_web_newsletter_*`), con una **fonte propria**
  (es. `pagina_iscrizione`) per sapere sempre da dove viene ogni consenso. Se la si scrive
  da zero si ricrea la divergenza che tutto questo lavoro sta chiudendo.
- **Da decidere in fase realizzativa**: se chi si iscrive da lì e **risulta già cliente** debba
  aggiornare `ana_clienti.consenso_marketing` invece di creare un iscritto separato. Va deciso,
  altrimenti la stessa persona finisce in due elenchi e riceve tutto due volte.
- **Doppia conferma (double opt-in)**: da valutare. Rende il consenso inattaccabile ma perde
  per strada chi non apre la mail di conferma. È una scelta di merito, non tecnica.

---

## B. Sito web pubblico (Fase 3) — Next.js SEO-first
- **Stack**: Next.js (App Router, React), ISR + revalidation on-demand, `@supabase/ssr`, Cloudflare. Legge lo **strato pubblico** (`fn_web_tour_pubblicati` + funzioni web_* + le aggiunte §A) via RLS anon.
- **Pagine**: Home (hero video/foto + Tour Finder + evidenza + prossime partenze + **mappa interattiva nazioni**), Catalogo (griglia + filtri), **Scheda tour per-edizione** (foto+prezzo da, colpo d'occhio, galleria, itinerario, mappa OSM, **incluso/escluso**, **recensioni Google/TripAdvisor**, **posti rimasti**, "Iscriviti" sticky), **Tour giornalieri** (condizionale), Chi siamo, Galleria/Video, FAQ, Contatti (form+WhatsApp+social), Newsletter, Privacy.
- **Trovabilità**: 5 lingue con **hreflang**, **Schema.org** (TouristTrip/Offer/AggregateRating/BreadcrumbList), immagini WebP + lazy-load, mobile-first.
- **Integrazioni**: bottone "Iscriviti" → **app iscrizioni esistente** (invariata); PDF programma (QuestPDF nel gestionale); condivisione social; cookie consent GDPR.
- **Mappa interattiva nazioni** (1° rilascio): componente frontend con hotspot per zona/destinazione → filtra il catalogo.

## C. Fasi successive
- **Pagamenti online Stripe + promemoria/solleciti + fatturazione automatica** (Fase 4): regole **per-azienda** già predisposte a DB (`web_pagamenti_config`/regole); logica di incasso, job schedulato reminder, fattura auto da implementare. *(Nel doc cliente: solo "fase successiva", senza tempi né difficoltà.)*
- **Blog / diario** (predisposto tecnicamente).

## D. Dipendenze dal cliente (da sollecitare — determinanti)
- **Materiale fotografico curato** per i tour di punta e **almeno 1 video hero** di qualità: la vetrina "premium" vive o muore su questo → **martellare** costantemente. *(Il cliente ci sta lavorando.)*
- **Schede Google/TripAdvisor** (Place ID / URL) per collegare le recensioni.

## E. Ordine consigliato
1. **CMS §A** (incluso/escluso · capienza+trigger · flag tipo breve · config recensioni) — piccole aggiunte ad alto impatto, sbloccano feature molto visibili sul sito.
2. **Sito §B** (Next.js) sullo strato pubblico ormai completo.
3. **Fase 4** (pagamenti) e **blog** come fasi successive.

*(Le stime/effort e i costi sono gestiti privatamente da Adriano e non compaiono nei documenti.)*
