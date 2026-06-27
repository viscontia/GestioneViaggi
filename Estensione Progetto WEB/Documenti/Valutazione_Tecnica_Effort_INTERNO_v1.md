# Valutazione Tecnica dell'Effort — DOCUMENTO INTERNO
## Progetto SFT — Nuovo sito + gestionale come motore unico

> 🔒 **USO INTERNO (Adriano + AI). NON trasmettere al cliente.**
> **Versione:** 1.0 · **Data:** 20 Giugno 2026 · **Base:** `Analisi_Preliminare_Sito_Web_SFT_v2.md` (v2.1)
> Questa è la base ragionata per costruire il preventivo economico. Qui ci sono **ore**, non prezzi (il prezzo lo definiamo insieme dopo, §C).

---

## A. COME LEGGERE QUESTA STIMA

### A.1 Il modello di lavoro (4 ruoli)
Ogni attività è stimata su quattro colonne, secondo come lavoriamo davvero:

| Sigla | Chi | Cosa |
|---|---|---|
| **COD (AI)** | Io (Claude) | Scrittura del codice (DB, gestionale, sito, integrazioni) |
| **AN.F.** | Adriano | Analisi funzionale: requisiti, regole, scelte di campo/UX |
| **CONG.** | Io + Adriano | Lavoro congiunto: decisioni di design, integrazione, debug a quattro mani |
| **TEST** | Adriano | Test, collaudo e **verifica finale** (umana, non delegabile all'AI) |

### A.2 Assunzioni chiave (il cuore del "ragionato")
1. **Le ore "COD (AI)" sono già fortemente compresse** rispetto allo sviluppo tradizionale: indicativamente **1/3–1/4** di quanto impiegherebbe uno sviluppatore umano. Non sono ore di lavoro umano fatturabili a tariffa piena: corrispondono soprattutto a un **costo-strumento** (abbonamento/credito AI) + alla mia supervisione.
2. **Il collo di bottiglia reale è il tempo umano di Adriano** (AN.F. + CONG. + TEST). Lo sviluppo veloce **non accorcia** il collaudo: testare, verificare, validare contenuti e flussi resta a velocità umana. Questa è la voce che pesa davvero sul calendario e sul prezzo.
3. Le ore sono **effort**, non calendario. Diverse attività si sovrappongono (vedi §D timeline).
4. Stima a **granularità media**: in fase realizzativa ogni voce può oscillare ±20%. Per questo c'è un **buffer** (§B.7).

### A.3 Cosa è incluso / cosa NO
**Incluso:** DB + funzioni + API, modulo "Contenuti Web" nel gestionale, traduzione AI, newsletter, mappa OSM, nuovo sito 5 lingue SEO-first, recensioni, pagamenti Stripe + regole + promemoria, migrazione da Drupal, go-live.
**Escluso (a carico SFT o da quotare a parte):** produzione di **foto/testi/video** (li fornisce SFT), redazione legale di privacy/cookie policy, **canone di manutenzione** post-go-live (contratto separato), creazione contenuti del blog, onboarding documentale Stripe dell'azienda.

---

## B. STIMA PER ATTIVITÀ (ore)

### FASE 0 — Setup & Architettura
| # | Attività | COD (AI) | AN.F. | CONG. | TEST | Tot |
|---|---|--:|--:|--:|--:|--:|
| 0.1 | Ambienti dev/stage/prod, repo, Hetzner + Cloudflare + Coolify, domini/SSL | 6 | 0 | 2 | 4 | 12 |
| 0.2 | Conferma architettura: dove sta il DB prod, stack frontend, map provider, ESP | 0 | 3 | 4 | 0 | 7 |
| | **Subtotale F0** | **6** | **3** | **6** | **4** | **19** |

### FASE 1 — Database, Funzioni DB, API di lettura
| # | Attività | COD (AI) | AN.F. | CONG. | TEST | Tot |
|---|---|--:|--:|--:|--:|--:|
| 1.1 | Schema nuove tabelle (contenuti, itinerario, passaggi, immagini, mappa, traduzioni, categorie sport, newsletter, soppressioni, consensi, toggle funzioni + predisposizioni pagamenti/blog) | 14 | 4 | 3 | 6 | 27 |
| 1.2 | Funzioni PL/pgSQL CRUD (DB-first: molte funzioni, multi-azienda + RLS) | 20 | 2 | 3 | 12 | 37 |
| 1.3 | API di sola lettura per il sito (tour pubblicati, categorie, dettagli, immagini, mappe, traduzioni; cache) | 16 | 3 | 3 | 10 | 32 |
| 1.4 | Aggiornamento `Funzioni_DB.md` | 3 | 0 | 0 | 1 | 4 |
| | **Subtotale F1** | **53** | **9** | **9** | **29** | **100** |

### FASE 2 — Gestionale MAUI (editor web + newsletter + config)
| # | Attività | COD (AI) | AN.F. | CONG. | TEST | Tot |
|---|---|--:|--:|--:|--:|--:|
| 2.1 | Scheda "Contenuti Web" (campi editoriali, rich text, SEO, stato, anteprima, pubblica, clona esteso) | 18 | 4 | 4 | 10 | 36 |
| 2.2 | Itinerario giorno-per-giorno **annidato** con drag&drop (giornate → passaggi: testo+foto+didascalia) | 14 | 2 | 2 | 8 | 26 |
| 2.3 | Galleria immagini (upload multiplo, resize ImageSharp, alt/titolo, ordinamento) | 8 | 1 | 1 | 4 | 14 |
| 2.4 | Mappatura categoria "Sport" ↔ tipi viaggio tecnici | 4 | 1 | 0 | 2 | 7 |
| 2.5 | GPX → mappa OSM (parse, bbox/centratura, static-map API o SkiaSharp, semplificazione traccia) | 12 | 2 | 2 | 6 | 22 |
| 2.6 | Traduzione AI (Claude API): pulsante, salvataggio per-campo, flag auto/revisionato/obsoleto, UI revisione | 14 | 2 | 3 | 10 | 29 |
| 2.7 | Sezione Newsletter (iscritti+filtri, compose, unione+dedup, invio SMTP/ESP, soppressioni, storico) | 16 | 3 | 3 | 10 | 32 |
| 2.8 | Config per-azienda (toggle funzioni `web_aziende_funzioni` + scelta/credenziali ESP) | 8 | 2 | 2 | 4 | 16 |
| | **Subtotale F2** | **94** | **17** | **17** | **54** | **182** |

### FASE 3 — Nuovo sito web (frontend SEO-first, 5 lingue)
| # | Attività | COD (AI) | AN.F. | CONG. | TEST | Tot |
|---|---|--:|--:|--:|--:|--:|
| 3.1 | Setup frontend SSR/SSG, design system, i18n 5 lingue + hreflang, infra SEO (sitemap, Schema.org, meta/OG), integrazione API | 22 | 4 | 4 | 10 | 40 |
| 3.2 | Home (hero, tour in evidenza, prossime partenze, filtri rapidi) | 10 | 2 | 2 | 5 | 19 |
| 3.3 | Liste per categoria + filtri (mezzo/destinazione/difficoltà/durata/prezzo/data) + prezzo "da" + badge | 12 | 2 | 2 | 6 | 22 |
| 3.4 | Dettaglio tour (itinerario, gallery+lightbox, mappa OSM, scheda tecnica, prezzi/date, CTA Iscriviti, PDF, FAQ, share) | 16 | 3 | 3 | 8 | 30 |
| 3.5 | Pagine statiche (chi siamo, gallery/video, contatti+WhatsApp, newsletter signup+double opt-in, privacy/cookie, cookie consent) | 12 | 2 | 1 | 6 | 21 |
| 3.6 | Calendario partenze | 6 | 0 | 0 | 3 | 9 |
| 3.7 | Recensioni (Google/TripAdvisor o interne) — toggle per-azienda | 8 | 2 | 1 | 4 | 15 |
| 3.8 | Finalizzazione performance/SEO/accessibilità (WebP, lazy, Core Web Vitals, Lighthouse) | 8 | 0 | 0 | 6 | 14 |
| | **Subtotale F3** | **94** | **15** | **13** | **48** | **170** |

### FASE 4 — Pagamenti Stripe + promemoria/solleciti (per-azienda)
| # | Attività | COD (AI) | AN.F. | CONG. | TEST | Tot |
|---|---|--:|--:|--:|--:|--:|
| 4.1 | Integrazione Stripe (checkout, webhook, transazioni, modello multi-azienda) | 18 | 3 | 3 | 12 | 36 |
| 4.2 | Motore regole pagamento per-azienda (acconto/saldo/soluzione unica, scadenze) + UI config | 10 | 3 | 2 | 6 | 21 |
| 4.3 | Promemoria/solleciti (job schedulato, template multilingua, CCN operatore, anti-duplicati, log) | 12 | 2 | 2 | 8 | 24 |
| | **Subtotale F4** | **40** | **8** | **7** | **26** | **81** |

### FASE 5 — Migrazione dati & Go-live
| # | Attività | COD (AI) | AN.F. | CONG. | TEST | Tot |
|---|---|--:|--:|--:|--:|--:|
| 5.1 | Import contenuti + immagini da Drupal (67 tour: itinerari, gallerie) | 14 | 3 | 2 | 10 | 29 |
| 5.2 | Import newsletter + matching/dedup con clienti + consensi | 6 | 2 | 0 | 4 | 12 |
| 5.3 | Traduzione iniziale 67 tour × 4 lingue (batch AI) + **revisione umana** | 4 | 1 | 0 | 16 | 21 |
| 5.4 | Redirect SEO old→new (301), sitemap, hreflang, Search Console | 6 | 1 | 0 | 4 | 11 |
| 5.5 | Go-live (cutover DNS, smoke test, monitoring, spegnimento Drupal) | 3 | 0 | 2 | 4 | 9 |
| | **Subtotale F5** | **33** | **7** | **4** | **38** | **82** |

### TRASVERSALI
| # | Attività | COD (AI) | AN.F. | CONG. | TEST | Tot |
|---|---|--:|--:|--:|--:|--:|
| C.1 | Coordinamento / PM (sync periodici lungo tutto il progetto) | 0 | 0 | 20 | 0 | 20 |
| C.2 | Manuale utente nuove funzioni (per l'operatore) | 6 | 1 | 0 | 2 | 9 |
| | **Subtotale Trasversali** | **6** | **1** | **20** | **2** | **29** |

---

## B.7 TOTALI

| | COD (AI) | AN.F. (Adriano) | CONG. (io+Adriano) | TEST (Adriano) | **TOTALE** |
|---|--:|--:|--:|--:|--:|
| **Somma attività** | 326 | 60 | 76 | 201 | **663** |
| **Buffer +15%** (imprevisti, cicli di fix) | 49 | 9 | 11 | 30 | **100** |
| **TOTALE con buffer** | **375** | **69** | **87** | **231** | **≈ 763** |

**Le due grandezze che contano davvero:**
- **Tempo umano di Adriano** (AN.F. + CONG. + TEST) = **337 h** (≈ **388 h** con buffer). ← *questo è il vero costo/lavoro*
- **Sviluppo AI** (COD) = **326 h** (≈ **375 h** con buffer). ← *throughput, non lavoro umano a tariffa piena*

> 📌 Nota: **il TEST di Adriano (201 h, ~30% del totale) supera l'intera analisi funzionale + il coordinamento.** È la conferma concreta del tuo punto: l'AI accelera lo sviluppo, ma **non** la verifica umana.

---

## C. DA ORE A PREZZO — RAGIONAMENTO (placeholder, da decidere insieme)

Il punto delicato: **come prezzare un lavoro dove il codice lo produce l'AI?** Tre approcci, con esempio numerico *illustrativo* (sostituisci la tariffa con la tua).

> **Tariffa oraria di esempio: 50 €/h** — *placeholder, da definire tu.*

**1) Cost-plus sulle TUE ore umane (pavimento del prezzo).**
388 h (con buffer) × 50 € = **≈ 19.400 €** + costi vivi (vedi §C.1) + margine. È il minimo sotto cui non ha senso scendere: copre il tuo tempo reale.

**2) Benchmark "agenzia" (soffitto / valore di mercato).**
Se le 663 h fossero **tutte** lavoro umano (come farebbe un'agenzia): 663 × 50 € = **≈ 33.000 €** (senza buffer); con buffer **~38.000 €**. È quanto il cliente pagherebbe altrove per lo stesso risultato.

**3) Value-based "ragionato" (la via consigliata).**
Prezzo nella fascia **tra il pavimento e il soffitto**, perché:
- consegni il **valore** di un'agenzia (piattaforma su misura, multilingua, automazioni) → giustifica più del puro cost-plus;
- ma sei **molto più competitivo** grazie all'AI → vantaggio commerciale forte.
Fascia indicativa: **~24.000–28.000 €** *(con tariffa 50 €/h; riscalala con la tua)*. Resti sotto l'agenzia e **valorizzi** il guadagno di produttività invece di regalarlo.

### C.1 Costi vivi ricorrenti (a carico SFT — già nel doc cliente)
Hetzner ~10 €/mese · OpenStreetMap 0 € · Mailchimp 11,41 €/mese *(facoltativo)* · Stripe a consumo *(facoltativo)* · **API Claude per traduzioni**: pochi centesimi/tour (a consumo, trascurabile). Da NON confondere col prezzo di realizzazione.

### C.2 Suddivisione in milestone (per il preventivo e per il cliente)
- **M1 — Piattaforma + sito live (senza pagamenti):** Fasi 0,1,2,3,5 → effort ≈ **582 h** (con buffer ~669 h). Porta SFT online sul nuovo sito.
- **M2 — Pagamenti Stripe + promemoria:** Fase 4 → effort ≈ **81 h** (con buffer ~93 h). Attivabile subito dopo, anche come secondo SAL.
> Vantaggio: il cliente va **live prima** (M1) e i pagamenti diventano un secondo stato avanzamento, riducendo il "salto" iniziale del preventivo.

---

## D. TEMPI (calendario, non effort)

Il calendario è guidato dalla **tua disponibilità** (analisi + collaudo), non dallo sviluppo AI.
- **Effort umano Adriano ≈ 388 h.** A ~15 h/settimana (part-time, realistico avendo il gestionale da seguire) → **~6 mesi**; a ~25 h/settimana → **~3,5–4 mesi**.
- Lo sviluppo AI procede più veloce ma **deve attendere** i tuoi cicli di test e le tue conferme funzionali: è lì che si forma la coda.
- Fasi 2 (gestionale) e 3 (sito) **parallelizzabili** una volta pronta la Fase 1.

---

## E. RISCHI / VOCI DA TENERE D'OCCHIO (possono spostare le ore)
| Rischio | Impatto | Nota |
|---|---|---|
| **Modello multi-azienda di Stripe** (Connect vs chiavi separate per azienda) | Medio-Alto su F4 | Da decidere presto: cambia l'architettura pagamenti |
| **Formato export Drupal** (contenuti/itinerari/immagini) | Medio su F5.1 | Finché non vediamo l'export reale, l'import è stimato "al buio" |
| **Volume revisione traduzioni** (67×4) | Medio su F5.3/2.6 | Se ti fidi del primo giro AI con spot-check, le ore TEST scendono |
| **Scelta stack frontend** (Next/Nuxt vs Blazor SSR) | Medio su F3 | Incide su velocità di sviluppo e su tue competenze di verifica |
| **DB prod** (Supabase vs Hetzner) | Basso-Medio | Latenza API↔DB; co-locazione consigliata |

---

## F. PROSSIMO PASSO (domani)
1. Tu fissi la **tariffa oraria** reale → ricalcoliamo i 3 scenari di §C.
2. Decidiamo **M1+M2 separati** o preventivo unico.
3. Sciogliamo i due rischi "presto" (modello Stripe, stack frontend).
4. Da questa valutazione interna ricaviamo il **preventivo "pulito" per il cliente** (senza ore AI esposte, con prezzo a milestone).
