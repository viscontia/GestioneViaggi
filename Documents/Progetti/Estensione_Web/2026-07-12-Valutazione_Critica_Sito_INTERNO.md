# Valutazione critica + decisioni aperte — Nuovo Sito Web SFT

> **USO INTERNO (Adriano + AI).** Non condividere col cliente. Accompagna la "Proposta Funzionale Nuovo Sito Web SFT" (documento client-facing). Data: 2026-07-12.
> Base: `Analisi_Preliminare_Sito_Web_SFT_v2.md` (visione, decisioni prese) + note del cliente sui siti di riferimento + analisi diretta dei competitor (WebFetch/WebSearch, luglio 2026) + capacità **reali** del CMS (Blocchi 5–13, già implementati e verificati sul DB).

---

## 1. Giudizio d'insieme

La visione (v2) è **solida e coerente**: CMS come motore unico, per-edizione, 5 lingue, SEO moderna, newsletter, recensioni/Stripe come opzioni per-azienda. Le decisioni chiave sono già prese col cliente. **Il grosso rischio non è la direzione ma le aspettative su alcune feature "vetrina"** che il cliente ha in testa guardando i competitor, e alcuni **gap del CMS** che vanno colmati prima che il sito possa mostrarle. Sotto, i punti che meritano attenzione prima di quotare.

## 2. Punti critici (con raccomandazione)

**a) "Mappa interattiva per selezionare la nazione" e "video hero che scorre" — attribuiti a nomads4x4, ma quel sito NON li ha.**
Verificato (WebFetch, lug 2026): nomads4x4 usa un **menu gerarchico** (Europa/Asia/…→paesi), non una mappa cliccabile, e non ha un video hero. Il cliente ricorda una cosa diversa dall'implementazione reale.
→ *Raccomandazione:* è comunque una **buona idea**; possiamo farla meglio di loro. Ma va detto chiaramente che (1) la **mappa interattiva** è un componente frontend con effort dedicato (JS/geo, hotspot per regione) da quotare a parte LA QUOTAZIONE E' AFFARE MIO, NON PREOCCUPARTENE. LA IDEA E' BUONA ED ENTRA A FARE PARTE DEL PROGETTO; (2) il **video hero** richiede almeno **1 video di qualità** — il cliente ha detto di non avere molti video. Chi lo produce? In alternativa, hero fotografico cinematografico (stile Nomadic Road) come fallback.IL CLIENTE SI ATTREZZERA' NEL MERITO.

**b) "Incluso / Escluso" (modello IMTBike) — NON è un campo strutturato nel CMS.**
Oggi il contenuto ha solo campi rich-text generici (`info_pernottamento_html`, `info_pasti_html`, `info_equipaggiamento_html`, `altre_info_html`). Non esiste una struttura "cosa è incluso / cosa è escluso".
→ *Raccomandazione:* per replicare la "scheda millimetrica" servono **due campi/liste dedicate** (incluso[], escluso[]) nel CMS (`web_tour_contenuti` o tabella figlia) + UI + traduzione. Piccola aggiunta, ma **da fare** se la vogliamo sul sito. In alternativa (rapida): convenzione redazionale dentro `altre_info_html` — meno pulita, non filtrabile/schematizzabile. NO VA INTEGRATA NEL CMS. PROSSIMO PASSO IMMEDIATO

**c) Recensioni — oggi c'è solo il TOGGLE, nessuna tabella né integrazione.**
`web_aziende_funzioni` ha il flag `recensioni` (on/off per azienda), ma **non esiste** una tabella recensioni né un'integrazione. Il cliente le vuole (deciso).
→ *Raccomandazione:* decidere la **fonte**: (1) **Google/TripAdvisor** (embed/API — social proof forte, meno lavoro CMS, ma vincoli di API/branding); (2) **gestione interna** (nuova tabella `web_recensioni` + moderazione + raccolta post-viaggio via email + privacy/consenso). IMTBike sbaglia mettendole in fondo: noi le posizioniamo **vicino alla CTA** nella scheda tour. Effort e privacy da valutare. DECISO: FONTE GOOGLE-TRIP ADVISOR (IL CLIENTE HA 5 SU 5)

**d) "Posti rimasti / disponibilità in tempo reale" (modello Ardventures/IMTBike) — derivabile ma non pulito.**
`ana_date_viaggi` ha valori calcolati `tot_clienti` e `tot_mezzi`, ma **non** un campo "capienza/posti totali" della data. "Posti rimasti" = capienza − iscritti: la capienza non è un dato pulito.
→ *Raccomandazione:* definire la capienza (max mezzi × posti, o campo esplicito su `ana_date_viaggi`) e un calcolo per i badge ("Ultimi posti", "Sold-out"). Piccola aggiunta dati + logica nello strato pubblico. Senza, i badge di disponibilità restano approssimativi. HO PARLATO CON IL CLIENTE E HA ACCETTATO LA MIA PROPOSTA TECNICA, CHE TI SPIEGO: IN ANA_VIAGGI AGGIUNGIAMO DUE CAMPI. IL PRIMO (VIAGGIO_CAPIENZA_MAX) PERMETTE DI INSERIRE UN NUMERO CHE RAPPRESENTA IL MASSIMO DI POSTI LIBERI. IL SECONDO CAMPO (VIAGGIO_CAPIENZA_ALERT) SEMPRE NUMERICO RAPPRESENTA IL "QUANDO" FARE SCATTARE LA SCRIITA SUL WEB "RIMANGONO SOLO 3 POSTI LIBERI" DOVE IL 3 E' PROPRIO QUESTO CAMPO. NATURALMENTE IL SW DOVRA' GESTIRE AUTOMATICAMENTE ALL'AGGIUNGERE O DIMINUIRE DELLE PRENOTAZIONI IN MOV_CLIENTI_VIAGGI QUALE NUMERO SCRIVERE SULLA PAGINA WEB (3,2,1, FINITO). IMMAGINO SIA NECESSARIO UN TRIGGER: LAVORIAMO SEMPRE IN OTTICA DB-FIRST.

**e) "Tour giornalieri / Weekend" (nuovo requisito, non nel v2).**
Il cliente vuole una sezione dedicata di esperienze 2–3 gg per il **mercato USA** (volo diretto Olbia). Non è modellato.
→ *Raccomandazione:* trattarlo come **tipo/categoria** (via `ana_tipo_viaggi` + una categoria web dedicata o un flag) così il sito può avere un filtro/menu "Tour giornalieri". Implicazioni marketing: **EN prioritario**, prezzi/formati chiari per l'utente USA, possibili landing dedicate ("Sardinia day tours from Olbia"). Da confermare col cliente se è un tipo viaggio nuovo in anagrafica. NON E' DETTO CHE I VIAGGI BREVI SIANO SOLO PER CLIENTI STRANIERI... E' SOLO UNA IPOTESI. POSSIAMO PERO' AGGIUNGERE UN FLAG SU ANA_TIPO_VIAGGI PER IDENTIFICARLI COME TALI E QUI SONO D'ACCORDO. QUESTO CI PERMETTERA' DI AVERE UNA CATEGORIA WEB DEDICATA, MA ATTENZIONE: SE ESISTONO CATEGORIE DI QUESTO TIPO ALLORA POTRA' COMPARIRE LA RELATIVA SEZIONE NEL SITO WEB, ALTRIMENTI NO !

**f) Frontend non deciso (Blazor SSR vs Next.js/Nuxt).**
Vincolo non negoziabile: **SEO → server-side rendering o pagine statiche**. L'editing è deciso (dentro MAUI); il frontend pubblico è aperto.
→ *Raccomandazione:* decidere in fase di preventivo. Next.js/Nuxt = ecosistema SEO/performance maturo + Cloudflare; Blazor SSR = un solo stack .NET. Non promettere prima della scelta. IL FRONT-END ERA STATO DECISO: TROVI TUTTO NEL DOCUMENTO /Users/adrianovisconti/Documents/Sviluppo\ Software/MAUI/GestioneViaggi/Estensione\ Progetto\ WEB/Documenti/Allegato\ 2\ -\ Analisi\ Tecnica\ Dettagliata.pdf

**g) DB di produzione (Supabase vs Hetzner co-locato).**
La latenza sito↔DB dipende dalla co-locazione. Le iscrizioni girano su Hetzner; il DB in memoria di progetto risulta Supabase.
→ *Raccomandazione:* confermare in fase tecnica; incide su performance e costi. TUTTO CONFERMATO: RIMANE SUPABASE E LE ISCRIZIONI SU HETZNER.

**h) Pagamenti Stripe + fatturazione automatica — scope grande (Fase 4).**
Le **regole per-azienda** sono già predisposte a DB (`web_pagamenti_config`/regole), ma la **logica di incasso, promemoria/solleciti schedulati, e fatturazione automatica** NON esiste. È un progetto a sé.
→ *Raccomandazione:* nel doc cliente presentarlo come **opzionale, fase successiva**; non dare tempi. Grande valore ma grande effort. NEL DOCUMENTO VA INDICATO COME FASE SUCCESSIVA, NON FARE MENZIONE DI TEMPI O DIFFICOLTA'

**i) Contenuto foto/video — il sito è foto-centrico ma dipende dal materiale del cliente.**
La galleria WebP e la mappa OSM ci sono nel CMS, ma la **qualità/quantità delle foto per tour** e l'eventuale video hero dipendono dal cliente.
→ *Raccomandazione:* concordare un **set fotografico curato** per i tour di punta e almeno 1 video hero; la vetrina "premium" vive o muore sul materiale visivo. NE HO PARLATO RIPETUTAMENTE CON IL CLIENTE, MA BISOGNA "MARTELLARE" SEMPRE SU QUESTO ARGOMENTO, A MIO AVVISO MOLTO PIU' CHE DETERMINANTE.

## 3. Mappatura funzionalità sito → capacità CMS reali

| Funzionalità sito | Stato CMS | Note |
|---|---|---|
| Catalogo/lista tour (foto, prezzo "da", durata, difficoltà, categoria, date) | ✅ Pronto | `fn_web_tour_pubblicati` per-edizione espone tutti questi campi |
| Scheda tour: descrizione, itinerario giorno/passi (testo+foto+didascalia), galleria, mappa OSM | ✅ Pronto | Blocchi 5/6/7/9 |
| Prezzo "da" per edizione | ✅ Pronto | `fn_web_prezzo_da_data` |
| Multilingua 5 lingue (persistite, hreflang-ready) | ✅ Pronto | Blocco 10, `web_traduzioni` |
| Difficoltà, categoria sportiva | ✅ Pronto | `ana_viaggi.viaggio_difficolta`, `web_tipi_viaggio_descrizioni` |
| Newsletter (iscrizione dal sito, invio) | ✅ Pronto | Blocco 11 + RLS anon insert |
| Stato pubblicato (solo pubblicati sul sito) | ✅ Pronto | RLS anon gated |
| **Incluso/Escluso strutturato** | ❌ Manca | serve campo/tabella dedicata |
| **Recensioni** (dati) | ⚠️ Solo flag | tabella/integrazione da fare |
| **Posti rimasti / capienza** | ⚠️ Parziale | manca "capienza"; badge da definire |
| **Tour giornalieri/weekend** (categoria/filtro) | ⚠️ Da modellare | tipo/categoria dedicata |
| Mappa interattiva selezione nazione | ❌ Frontend | componente sito, non CMS |
| Video hero | ❌ Contenuto | serve 1 video + player home |
| Pagamenti Stripe + reminder + fattura auto | ⚠️ Solo predisposto | logica Fase 4 |
| Badge dinamici (sold-out/ultimi posti/novità) | ⚠️ Dipende da (d) | novità=data creazione; sold-out=capienza |
| PDF programma tour | ✅ Fattibile | QuestPDF già in uso nel gestionale |
| Blog/diario | ⚠️ Predisposto | non 1° rilascio |

## 4. Decisioni aperte da chiudere (checklist)

- [ ] Video hero: sì/no? chi produce il video? (fallback hero fotografico) SI ARRIVERA'
- [ ] Mappa interattiva nazione: dentro il 1° rilascio o fase 2? (effort dedicato) PRIMO RILASCIO
- [ ] Incluso/Escluso: campi CMS dedicati (consigliato) o convenzione redazionale? CAMPI CMS DEDICATI PER ANA_VIAGGIO, NON PER ANA_DATE_VIAGGIO
- [ ] Recensioni: Google/TripAdvisor vs interne? (fonte + privacy) GOOGLE+TRIPADVISOR
- [ ] Capienza/posti: definire il dato per i badge disponibilità VEDI NOTE SOPRA
- [ ] Tour giornalieri/weekend: nuovo tipo viaggio in anagrafica? landing EN dedicate? VEDI NOTE SOPRA
- [ ] Frontend: Blazor SSR vs Next/Nuxt (in preventivo, vincolo SEO) VEDI NOTE SOPRA
- [ ] DB prod: Supabase vs Hetzner co-locato VEDI NOTE SOPRA
- [ ] Pagamenti/fatturazione: confermare come fase successiva (no tempi ora) SI
- [ ] Set fotografico curato per i tour di punta ARRIVERA' IL CLIENTE CI STA LAVORANDO

## 5. Note effort/priorità (indicative — il preventivo è fase successiva)

- **Basso / alto valore (fare):** mappatura campi CMS→sito (già pronti), incluso/escluso (2 campi), capienza+badge, categoria "tour giornalieri". Sono aggiunte piccole che sbloccano feature molto visibili.
- **Medio:** mappa interattiva nazione, recensioni (a seconda della fonte), PDF programma.
- **Alto / fase successiva:** pagamenti Stripe + reminder schedulati + fatturazione automatica; blog.
- **Dipendente dal cliente:** materiale foto/video.

**Regola per il doc cliente:** presentare tutto ciò che il CMS **già alimenta** come "pronto"; presentare (b)(c)(d)(e) come parte del sito (senza allarmare, sono aggiunte naturali); tenere (h) pagamenti come opzionale/fase successiva. SONO D'ACCORDO, MA ELIMINA TUTTO QUELLO CHE RIGUARDA COSTI ATTUALI, COSTI FUTURI, ECC. QUESTA PARTE LA GESTISCO IO PRIVATAMENTE.
