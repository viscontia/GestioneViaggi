# Business Intelligence — Modifiche e integrazioni previste al DB

**Versione:** 0.1 · **Data:** 8 settembre 2026  
**Stato:** piano DB-first, nessuna migrazione BI eseguita. Nomi logici e contratti da definire, non API già disponibili.  
**Destinatari:** responsabile del progetto, sviluppatori backend e database.

## 1. Principi e perimetro

Le regole di [overview.md](../../Documents/overview.md) sono vincolanti. Tutti i calcoli e le aggregazioni analitiche vivono in funzioni PostgreSQL. Nessun SQL di dominio inline nel frontend o nel backend C#; nessuna seconda implementazione delle formule nella chat AI.

Questa guida accompagna [architettura tecnologica](01_Architettura_Tecnologica.md) e [guida funzionale](02_Esposizione_Fruizione_Risultato_Atteso.md).

Le query esplorative dell'8 settembre sono state eseguite in transazioni `READ ONLY`, con timeout e senza invocare funzioni applicative di scrittura. **Non sono state apportate modifiche al DB.**

Riferimenti: [Funzioni_DB.md](../../Documents/Funzioni_DB.md), [Gestione_check.md](../../Documents/Gestione_check.md), [Implementazione_Contabile.md](../../Documents/Implementazione_Contabile.md), [checklist go-live](../../Estensione%20Progetto%20WEB/Documenti/2026-07-10-Checklist_Go_Live_PROD.md).

## 2. Baseline osservata e go-live

Lo schema Docker è il riferimento di destinazione; Supabase contiene i dati reali. Il go-live di allineamento era previsto per il 9 settembre 2026: verificarne l'esecuzione prima di assumere disponibili colonne e funzioni locali.

### Dati dell'azienda 2 osservati in Supabase l'8 settembre

| Misura | Valore | Perimetro |
|---|---:|---|
| Anagrafiche | 203 | `ana_clienti.azienda_fk = 2`, prima della bonifica |
| Viaggi | 20 | Catalogo azienda 2 |
| Partenze | 24 | Edizioni datate azienda 2 |
| Partecipazioni | 235 | Iscrizioni alle partenze azienda 2, incluse guide e riferimenti da bonificare |
| Partenze future | 5 | Data inizio successiva alla data di osservazione |
| Movimenti contabili | 0 | `mov_transazioni` dell'azienda 2 |

Per anno della partenza: 2024 = 1 partenza/22 partecipazioni; 2025 = 7/83; 2026 = 16/130. **Non è una serie di consuntivi omogenei:** il 2024 è parziale e il 2026 include il futuro.

Otto partenze con data finale trascorsa e flag diverso da `Y` rappresentano, secondo il requisito confermato, **programmate ma non effettuate**. Non trattarle come errori.

### Bonifica dei silos già prevista

Le 26 iscrizioni a partenze dell'azienda 2 riferite a 25 clienti dell'azienda 6 sono un residuo noto dell'importazione. Gli script [587](../../SqlScripts/587_Silos_Rimappare_I_Clienti_Fuori_Azienda.sql), [588](../../SqlScripts/588_Silos_Creare_Le_Anagrafiche_Mancanti.sql) e [589](../../SqlScripts/589_Silos_Il_Confine_Viene_Imposto.sql) prevedono rimappaggio, creazione delle anagrafiche mancanti e guardia contro nuovi attraversamenti.

Non duplicare questa bonifica nel progetto BI. Dopo il go-live verificare il referto dei silos e riconciliare i conteggi. Non fissare oggi il numero finale di clienti come dato acquisito.

Lo script 588 registra le nuove schede con `created_by = 'migrazione_silos'` e data corrente: **questa data non è acquisizione commerciale**. Le prime esperienze devono derivare dallo storico delle partecipazioni qualificate, non dalla creazione tecnica della scheda.

## 3. Fonti e granularità

| Fonte | Granularità e utilizzo | Attenzione |
|---|---|---|
| `ana_clienti` | Una scheda cliente per azienda | Identità e demografia correnti, non automaticamente storiche |
| `ana_viaggi` | Un viaggio a catalogo | Destinazione, tipologia; capienza locale sul viaggio |
| `ana_date_viaggi` | Una partenza | Date, flag effettuazione e listini della partenza |
| `mov_clienti_viaggi` | Una partecipazione cliente–partenza | PK viaggio/partenza/cliente; ruolo, mezzo, pilota collegato e sconto |
| `mov_clienti_alloggi` | Un'assegnazione alloggio con più occupanti | Non unirla direttamente ai fatti senza controllare le moltiplicazioni |
| `ana_business_events` | Un evento applicativo | Copertura parziale, non dimostrata sufficiente a ricostruire tutti gli stati |
| `mov_transazioni` | Un documento o movimento secondo causale | Economico e finanziario convivono: distinguerli |
| `mov_transazioni_righe` | Una riga del documento | Non sommare di nuovo la testata dopo una join alle righe |
| `ana_tipi_causali` | Una causale configurata | Ciclo, segno, documento, concorso al fatturato |
| `ana_controparti` | Una controparte aziendale | Può essere cliente e/o fornitore |
| `web_pagamenti_transazioni` — locale | Una richiesta/transazione di pagamento web | Collegamento `mov_transazione_fk`, importi in centesimi, stato e valuta |

Le entità analitiche sono separabili logicamente, senza imporre da subito un warehouse: **cliente, partenza, partecipazione, documento, regolamento**. Le dimensioni comuni sono azienda, calendario, viaggio, destinazione, tipologia, ruolo, geografia, controparte, causale e valuta.

Aggregare ogni fatto alla propria granularità prima di combinarlo con altri. Il risultato deve riconciliarsi con la sorgente anche quando un documento ha più righe o una partenza più camere.

## 4. Catalogo delle funzioni analitiche da progettare

I seguenti sono **gruppi funzionali proposti**, non nomi di funzioni già create. Le firme e la numerazione degli script si stabiliscono dopo il censimento definitivo post go-live.

| Gruppo | Responsabilità |
|---|---|
| Stato partenza | Classificazione univoca di futuro, in corso, effettuato e non effettuato |
| Indicatori viaggi | Conteggi di partenze, persone, mezzi e medie con perimetro esplicito |
| Stagionalità | Viaggio/destinazione × periodo, tasso di effettuazione e numerosità |
| Ritorno e frequenza | Distinti, prima esperienza conosciuta, frequenze e coorti |
| Geografia | Aggregazioni gerarchiche e quota non mappabile |
| Valorizzazione commerciale | Stima da tariffe, ruoli, sconti e supplementi validati |
| Bilancio economico BI | Riutilizzo/estensione del bilancio esistente e confronto tra partenze |
| Flussi e residui | Documenti e regolamenti senza duplicazioni, scaduto e copertura |
| Dettagli | Drill-down paginato, con gli stessi filtri e l'autorizzazione del riepilogo |
| Copertura e qualità | Disponibilità dei dati, limiti storici, informazioni mancanti |

### Contratto comune

Ogni famiglia deve dichiarare: granularità, azienda autorizzata, periodo, base temporale, data di osservazione, inclusioni/esclusioni, classificazione dei ruoli, valuta e politica di conversione, unità, denominatore, comportamento con dati assenti e versione semantica.

L'output deve consentire al backend di esporre istante di lettura, periodo effettivo, copertura e numerosità. Dettagli paginati con ordinamento stabile; aggregati privi di PII non necessarie. I limiti di dettaglio e di esecuzione sono applicati server-side.

Nessuna azienda `NULL` con significato «tutte» nelle API aziendali BI. Le funzioni esistenti che supportano tale convenzione non vanno esposte direttamente al browser.

## 5. Integrazioni di dominio necessarie

### 5.1 Conteggio mezzi ed equipaggi

La funzione `fn_web_mezzi_occupati_data` nello script 479 conta i tipi partecipante 4/5. Non soddisfa da sola il requisito generale concordato per moto, biciclette, quad, cavalli e altri mezzi.

Prevedere un criterio DB centralizzato: censire i tipi partecipante e stabilire come identificare il responsabile di ciascun mezzo/equipaggio, includendo i piloti moto ed escludendo i passeggeri dal conteggio mezzi. Non assumere che `tipo_partecipante_pilota = true` sia sufficiente: nei dati esaminati anche GUIDA è marcata come pilota. Confermare se i mezzi dello staff consumano capienza commerciale oppure vanno solo nel totale operativo.

Non deduplicare soltanto per targa: può mancare, e alcuni mezzi non la possiedono. Usare le relazioni del dominio, chiarendo i casi del mezzo guida e delle iscrizioni senza pilota collegato. Valutare se una classificazione configurata dei ruoli basta o se occorra un'identità di equipaggio: scegliere dopo il censimento, evitando una nuova entità non necessaria.

Il cambiamento delle funzioni pubbliche dei posti rimasti potrebbe influire sul sito: non modificarle implicitamente per la BI. Proporre un'eventuale convergenza separata e collaudare entrambi i consumatori.

### 5.2 Capienza storica

In locale `viaggio_capienza_max` e `viaggio_capienza_alert` sono sul viaggio, non sulla partenza. Una loro modifica può cambiare retroattivamente l'occupazione calcolata delle vecchie edizioni.

Per confronti storici affidabili, valutare una capienza della singola partenza o una storicizzazione del valore. **Nessun riempimento retroattivo con la capienza corrente presentato come fatto storico.** Finché non disponibile, mostrare non calcolabile o un valore ricostruito esplicitamente etichettato.

### 5.3 Stima commerciale e prezzi

Le partenze possiedono tariffe per categorie e le partecipazioni uno sconto totale. Verificare la corrispondenza per tutti i ruoli, inclusi moto, bambini, guide, noleggio e passeggeri del mezzo guida; censire supplementi e logica già usata dal gestionale.

Se il prezzo cambia dopo l'iscrizione, il listino corrente non prova il valore pattuito. Distinguere stima ai prezzi correnti da valore storicizzato. L'eventuale memorizzazione della quota concordata è un'integrazione da valutare, non un dato oggi garantito.

### 5.4 Date, ritorni e geografia

Riutilizzare la classificazione condivisa delle partenze rispettando la decisione «trascorsa non effettuata = programmata ma non effettuata». Non basare i viaggi effettuati sulla sola data.

Prima esperienza e ritorni si calcolano su partecipazioni effettuate, dopo bonifica degli identificativi. Le importazioni e le cancellazioni limitano lo storico: definire una copertura osservabile, non una falsa data di inizio attività.

Verificare il percorso comune → provincia → regione e la codifica delle residenze estere. Non inferire il paese da prefisso telefonico, nazionalità o nome. Senza storia degli indirizzi, etichettare la geografia come residenza attuale.

### 5.5 Evoluzione delle prenotazioni e snapshot

La situazione corrente non consente di ricostruire esattamente la domanda passata: le iscrizioni cancellate non compaiono più. Gli eventi osservati hanno copertura parziale dal marzo 2026 e non sono stati validati come registro completo riproducibile.

Per confronti «alla stessa distanza dalla partenza» proporre snapshot giornalieri per azienda/partenza: data di osservazione, persone per ruolo, mezzi, capienza e stima commerciale con la versione della regola. Definire idempotenza, fuso orario, completezza del caricamento e conservazione. Uno snapshot mancante non vale zero.

Si tratta di **scritture analitiche programmate future**, da autorizzare e implementare separatamente: le interrogazioni della dashboard rimangono in sola lettura. Nessun backfill inventato; ricostruzioni da eventi solo se la copertura è dimostrata e dichiarata.

Gli snapshot non risolvono da soli la storia economica: se in futuro servirà «quale margine vedevamo alla data X», occorrerà valutare una storia dei documenti o fotografie economiche coerenti.

## 6. Riutilizzo della contabilità esistente

Sono già presenti le famiglie `fn_get_bilancio_viaggio`, `fn_get_bilancio_annuale_viaggi`, `fn_get_fatturato_annuale`, `fn_get_fatturato_periodo`, `fn_get_fatturato_mensile_trend`, `fn_get_scadenzario_stampa` e la vista `vw_scadenzario`.

Prima di riusarle verificare firme, filtri aziendali, date, causali, segni, valute e moltiplicazioni. Osservazioni puntuali dell'8 settembre:

- La definizione di `fn_get_fatturato_periodo` letta sia in locale sia in produzione somma imponibile EUR/importo EUR legacy con il segno della causale, esclude `ANNULLATO` e usa data documento con fallback alla data transazione.
- In tale definizione il parametro `p_valuta_target_id` **non è utilizzato**. Non presentare il risultato come convertito soltanto perché è stato passato quel parametro.
- La vista `vw_scadenzario` letta in produzione usa ancora `transazione_importo_eur_old`; la sua adeguatezza dopo l'allineamento va verificata, non assunta.

Questi sono rilievi per la validazione, non autorizzazioni a modificare ora le funzioni.

Regole da garantire:

1. Costi di partenze non effettuate inclusi nel loro bilancio e nel risultato complessivo.
2. Documenti, note di credito, incassi/pagamenti e relativi stati trattati secondo la causale, evitando doppio conteggio.
3. Testate e righe riconciliate: non aggregare entrambe come fatti indipendenti.
4. Pagamenti web collegati a `mov_transazioni` non sommati nuovamente; normalizzare centesimi/unità e valuta.
5. Margine per partenza distinto da conto documentale del periodo. Costi senza partenza espliciti; nessuna allocazione arbitraria.
6. Copertura economica dichiarata: zero movimenti azienda 2 non dimostra margine zero.
7. Verificare se tutti i costi sono stati registrati: valutare un indicatore di chiusura/completamento del bilancio per partenza solo se il processo aziendale può alimentarlo.

Nessuna stima di liquidità assoluta senza saldi iniziali e perimetro conti completo. Nessuna formula fiscale nuova dedotta dal solo nome di un campo: usare la logica contabile di dominio validata.

## 7. Sicurezza DB e identità

Progettare ruolo di lettura BI, grant e policy coerenti con il backend autenticato. Le funzioni devono derivare o verificare il tenant rispetto all'identità attendibile; il semplice parametro passato dal chiamante non è sufficiente.

RLS non deve essere aggirata da proprietari, viste o funzioni privilegiate. Se una funzione `SECURITY DEFINER` è indispensabile, limitare privilegi del proprietario, `search_path`, chiamanti e perimetro; motivare e testare l'eccezione. Evitare esposizione accidentale tramite schema pubblico/Data API.

Gestione di sessioni, aperture monouso e audit potrà richiedere nuove strutture o un provider esterno: la scelta dipende dall'architettura d'identità. Non usare tabelle dei reset password come surrogato. Separare privilegi di identità e lettura BI.

Con pooling transazionale il contesto aziendale deve valere per l'intera transazione corretta, essere impostato dal backend attendibile e non sopravvivere impropriamente alla richiesta. Testare richieste consecutive e concorrenti di aziende diverse.

## 8. Piano delle migrazioni

| Passo | Attività | Verifica |
|---|---|---|
| 1 | Censimento post go-live di schema, funzioni, grant e dati | Versione e referto silos verificati; baseline aggiornata |
| 2 | Contratti delle metriche e classificazione ruoli/mezzi | Esempi approvati e attesi riproducibili |
| 3 | Funzioni analitiche e isolamento | Risultati riconciliati, test di accesso negato tra aziende |
| 4 | Integrazioni strettamente necessarie per capienza/prezzi | Comportamento storico dichiarato; nessun dato inventato |
| 5 | Funzioni economiche validate e copertura | Fatture, pagamenti parziali, rettifiche e partenze non effettuate |
| 6 | Snapshot, se confermati | Idempotenza, lacune visibili, data iniziale certa |
| 7 | Indici/aggregazioni solo se motivati | Piani di esecuzione e tempi sotto carico concordato |

Gli script eseguibili futuri restano in `SqlScripts/`, numerati secondo l'ultimo numero realmente disponibile, senza prenotare ora numeri o duplicare quelli del go-live. Deploy locale tramite `./deploy_sql.sh`; aggiornare sempre la parte curata di `Documents/Funzioni_DB.md`. Non modificare manualmente l'appendice auto-generata. Il deploy in produzione segue la procedura e le approvazioni del progetto, non il wrapper Docker.

Per ogni nuovo vincolo o relazione applicare le quattro domande di `Gestione_check.md`: cosa succede cancellando il riferito, modificandolo, quali altri riferimenti esistono e come il messaggio guida l'operatore. Migrazioni additive dove possibile; nessuna rimozione di funzioni usate da MAUI o dal sito senza censimento dei consumatori e piano di compatibilità.

## 9. Casi minimi di collaudo

- Quattro mezzi e venti clienti: quattro unità di capienza e venti partecipazioni.
- Moto e mezzi non automobilistici inclusi; passeggeri non duplicano il mezzo; staff esplicito.
- Cliente con tre partenze: tre partecipazioni e un distinto nel periodo.
- Partenza trascorsa non effettuata: entra nel tasso di non effettuazione; gli iscritti non diventano viaggiatori effettivi.
- Partenza futura o in corso: esclusa dal denominatore degli esiti definitivi.
- Mese senza programmazione distinto da tentativo non effettuato.
- Scheda creata da bonifica: non appare come acquisizione commerciale al go-live.
- Costi senza ricavi di una partenza non effettuata: margine negativo conservato, percentuale non calcolabile.
- Fattura a più righe e pagamenti parziali: ricavo/costo e flusso finanziario conteggiati una sola volta.
- Pagamento web collegato al movimento: nessun doppio incasso.
- Cambio capienza/listino: nessuna riscrittura silenziosa di indicatori storici dichiarati come effettivi.
- Assenza dati contabili, errore DB e importo zero distinguibili.
- Azienda diversa nei parametri o negli ID: accesso rifiutato; nessun dato nella cache, nel dettaglio o nella chat.
- Periodi incompleti, anno bisestile e base precedente zero: confronto esplicito e corretto.

## 10. Manutenzione della guida

Quando una proposta viene approvata, documentare decisione e data. Quando viene implementata, riportare script e funzioni effettivi e le verifiche svolte; aggiornare le altre due guide se cambia il significato esposto all'utente. Non promuovere automaticamente la baseline pre go-live a baseline definitiva.
