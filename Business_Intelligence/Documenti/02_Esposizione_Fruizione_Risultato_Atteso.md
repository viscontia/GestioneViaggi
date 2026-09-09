# Business Intelligence — Esposizione, fruizione e risultato atteso

**Versione:** 0.1 · **Data:** 8 settembre 2026  
**Stato:** guida funzionale; decisioni concordate e proposte di report da validare.  
**Destinatari:** responsabile del progetto, referenti aziendali, progettisti UI e sviluppatori.

## 1. Finalità

La BI deve aiutare l'azienda a decidere **quali viaggi programmare, quando proporli, chi ritorna, da dove arrivano i viaggiatori e quale margine rimane**. Deve offrire report guidati curati, senza chiedere all'utente di costruire query o conoscere il database.

Questa guida definisce il significato dei dati visualizzati. Vedi anche [architettura](01_Architettura_Tecnologica.md) e [integrazioni DB](03_Modifiche_Integrazioni_DB.md). Le formule definitive saranno implementate nel DB e condivise con le risposte alle domande libere.

## 2. Decisioni di dominio concordate

### 2.1 Viaggio e partenza

Il **viaggio** è il prodotto/itinerario a catalogo. La **partenza** è una sua edizione datata. Il confronto deve consentire sia la lettura aggregata del viaggio sia l'approfondimento delle singole partenze.

Una partenza trascorsa ma non effettuata è **«Programmata ma non effettuata»**: non è un errore da nascondere o correggere automaticamente. Le motivazioni possono essere diverse e oggi non sono registrate: nessuna spiegazione causale deve essere inventata.

| Stato operativo | Lettura BI |
|---|---|
| Programmata futura | Inizio successivo alla data di osservazione; nessun esito negativo anticipato |
| In corso / esito non ancora valutabile | Periodo iniziato ma non terminato; esclusa dal denominatore del tasso finale |
| Effettuata | Flag di effettuazione positivo; per i report di esito definitivo la data finale deve essere trascorsa |
| Programmata ma non effettuata | Data finale trascorsa e flag non positivo |

Nel DB esaminato il flag positivo è `Y`, non `S`. La classificazione temporale deve usare un'unica funzione condivisa. Un flag positivo su una partenza futura è un'incoerenza da segnalare, non un viaggio già realizzato. Data di riferimento e fuso orario aziendale devono essere espliciti; fino alla fine della giornata finale non attribuire automaticamente un esito negativo.

### 2.2 Mezzi e persone

**La capienza misura mezzi/equipaggi**: dieci auto, moto, biciclette, quad, cavalli o altri mezzi ammessi. I passeggeri non consumano ulteriori unità della capienza del mezzo che li ospita.

**Il numero delle persone ha valore statistico autonomo.** Quattro mezzi e venti persone possono rappresentare un viaggio di successo anche economicamente. Non attribuire un giudizio complessivo dalla sola occupazione dei mezzi.

Mostrare separatamente:

- Mezzi/equipaggi partecipanti.
- Clienti viaggiatori: piloti e passeggeri, ciascuno una volta per partenza.
- Guide/personale e totale persone presenti, con classificazione da confermare sui tipi partecipante.
- Persone per mezzo: specificare che numeratore e denominatore hanno lo stesso perimetro; con zero mezzi il rapporto è non calcolabile.

Nel periodo, una persona che compie tre viaggi genera **tre partecipazioni e un viaggiatore unico**. Non sommare i distinti mensili per ottenere il totale annuale dei viaggiatori unici.

### 2.3 Commerciale, economico e finanziario

- **Viaggi/Clienti:** valorizzazione commerciale stimata delle partecipazioni.
- **Contabilità/Finanza:** fatturato, costi, bilancio economico del viaggio, incassi, pagamenti e residui.
- Una stima da listini e iscrizioni non è un ricavo fatturato, un incasso o un margine effettivo.
- **I costi di partenze non effettuate restano nel bilancio della partenza, del viaggio e del periodo**, insieme a eventuali ricavi e rettifiche.
- La presenza di un documento e del pagamento collegato non costituisce due ricavi o due costi.

## 3. Struttura della dashboard

Due tab: **Viaggi/Clienti** e **Contabilità/Finanza**, entrambi accessibili a tutti gli utenti dell'azienda autenticata. Non introdurre nuovi flag per separarne l'accesso.

La fascia superiore mostra azienda, periodo, base temporale, confronto, filtri attivi, istante di aggiornamento e bottone **Aggiorna**. L'azienda non è un filtro libero per gli utenti aziendali.

Ogni report segue la progressione **indicatori → andamento/confronto → dettaglio**. I filtri applicati cliccando un grafico sono visibili e rimovibili. Il ritorno al livello superiore conserva periodo e selezioni.

## 4. Report Viaggi/Clienti

### V1 — Quali viaggi funzionano e quando programmarli

**Domanda:** quali itinerari e stagioni hanno prodotto partenze realizzate e partecipazione significativa?

Indicatori:

- Partenze programmate, effettuate e programmate ma non effettuate.
- Tasso di effettuazione = partenze effettuate / partenze con esito valutabile.
- Persone e mezzi totali e medi per partenza effettuata.
- Occupazione dei mezzi rispetto alla capienza, quando disponibile e storicamente attendibile.
- Valorizzazione commerciale stimata, con copertura e regole dichiarate.

Rappresentazioni proposte: andamento mensile, barre per viaggio/tipologia/destinazione e **matrice viaggio o destinazione × mese**. La matrice può mostrare tasso di effettuazione, mezzi medi o persone medie. Ogni cella espone anche la numerosità delle osservazioni.

Esempio: «Albania a maggio» deve distinguere un viaggio mai programmato, un solo tentativo non effettuato e cinque tentativi non effettuati. **Mai programmato non significa fallito.** Il report può suggerire quali combinazioni approfondire, non attribuire cause o garantire il successo futuro.

Drill-down: periodo → viaggio/destinazione → partenza → partecipanti autorizzati. Le partenze future mostrano iscritti attuali, non viaggiatori che hanno già viaggiato.

### V2 — Chi ritorna e con quale frequenza

**Domanda:** il cliente torna? Quanti viaggi compie e a quale distanza?

Per ritorno e frequenza si considerano **partecipazioni a viaggi effettuati**, con esclusione delle guide/personale dal perimetro clienti. La classificazione effettiva dei ruoli è un punto di verifica prima dello sviluppo.

| Metrica | Definizione proposta |
|---|---|
| Viaggiatori unici | Clienti distinti dell'azienda con almeno una partecipazione qualificante nel periodo |
| Prima esperienza conosciuta | Prima partenza effettuata osservata nello storico aziendale |
| Viaggiatori di ritorno | Attivi nel periodo con almeno una partenza effettuata precedente all'inizio del periodo |
| Viaggi medi per viaggiatore attivo | Partecipazioni qualificanti nel periodo / viaggiatori unici del periodo |
| Distribuzione annuale | Quanti viaggiatori fanno 1, 2, 3, 4 o più viaggi nell'anno |
| Intervallo tra viaggi | Mediana del tempo tra partenze effettuate consecutive; regola sui bordi del periodo da fissare |
| Ritorno per coorte | Quota della coorte di prima esperienza che torna negli anni successivi osservabili |

La definizione di ritorno proposta distingue chi era già cliente all'inizio del periodo da chi fa il primo e il secondo viaggio nello stesso periodo. Quest'ultimo è visibile nella distribuzione delle frequenze: **non cambiare tacitamente definizione** tra report e chat.

Le coorti recenti non hanno ancora la stessa durata di osservazione di quelle vecchie. Celle non osservabili restano tali; non diventano mancati ritorni. Con uno storico parziale parlare di «prima esperienza conosciuta», non di acquisizione certa.

Visualizzazioni: distribuzione delle frequenze, matrice delle coorti e andamento nuovi/ritorno. I distinti restano aziendali: nessun riconoscimento trasversale della persona tra silos.

### V3 — Provenienza geografica

**Domanda:** da quali territori arriva la domanda, e quali generano ritorno?

- Italia: regione → provincia → comune, secondo le informazioni effettivamente disponibili.
- Estero: nazione di residenza, usando una relazione attendibile e non deduzioni da cittadinanza o prefisso telefonico.
- Scelta tra viaggiatori unici e partecipazioni, con distinti ricalcolati al livello selezionato.
- Confronto tra prime esperienze conosciute e ritorni.

Mappa affiancata a graduatoria a barre e tabella. Dati mancanti o non mappabili in una voce esplicita. L'indirizzo anagrafico attuale non prova dove il cliente risiedesse al momento di un viaggio storico: dichiarare la base geografica finché non esiste una storicizzazione.

### V4 — Partenze future

Partenze in programma, persone iscritte, mezzi occupati, capienza e stima commerciale corrente. Evidenziare separatamente le iscrizioni delle guide/personale.

La curva «a quanti giorni dalla partenza arrivano le iscrizioni» è possibile solo con date d'iscrizione attendibili e perimetro dichiarato. Il confronto «quanti iscritti avevamo alla stessa data l'anno scorso» richiede uno storico completo degli stati o snapshot: non è equivalente a filtrare la data di creazione delle sole iscrizioni rimaste oggi.

## 5. Report Contabilità/Finanza

### E1 — Bilancio economico di viaggi e partenze

Riutilizzare e validare le strutture costi e le funzioni di bilancio già esistenti; non costruire una contabilità parallela.

- Ricavi documentati e rettifiche.
- Costi attribuiti e composizione per causale/categoria disponibile.
- Margine in valore assoluto e percentuale.
- Confronto fra edizioni dello stesso viaggio, periodi e destinazioni.
- Costi non attribuiti a una partenza, visibili separatamente e riconciliabili.

Due letture complementari:

1. **Esecuzione:** come rendono le partenze effettuate.
2. **Programmazione:** quanto rende l'intera programmazione con esito definito, incluse le partenze non effettuate e i relativi costi.

| Indicatore | Definizione |
|---|---|
| Margine per partenza | Ricavi meno costi attribuiti, secondo il contratto contabile validato |
| Margine medio per partenza | Somma margini / numero partenze del perimetro esplicitato |
| Margine percentuale complessivo | Somma margini / somma ricavi; non media semplice delle percentuali |

Con ricavi nulli/zero, la percentuale è non calcolabile; con ricavi negativi occorre una rappresentazione esplicita delle rettifiche. La media delle partenze effettuate non può essere presentata come risultato di tutta la programmazione. Le partenze senza dati contabili non entrano silenziosamente come margine zero: indicare la copertura.

Il termine «margine» non implica utile netto aziendale se mancano costi generali, allocazioni o altre componenti. La base netta/lorda e i trattamenti fiscali devono seguire la logica esistente validata, non formule UI generalizzate.

### E2 — Incassi, pagamenti e scadenze

- Flussi effettivamente registrati, per data finanziaria.
- Crediti e debiti residui con pagamenti parziali e rettifiche.
- Scaduto e prossime scadenze, per controparte e partenza.
- Collegamento dal documento ai regolamenti e viceversa.

Non chiamare «liquidità disponibile» il saldo dei soli flussi osservati: servono saldi iniziali, conti e copertura completa. Le proiezioni basate sulle scadenze sono impegni registrati, non previsioni certe di incasso.

### Area non ancora alimentata

L'8 settembre 2026 l'azienda 2 non aveva movimenti contabili in produzione. Mostrare **«Area non ancora alimentata»**, non una dashboard di zeri. I movimenti di test locali non costituiscono evidenza economica. Quando l'alimentazione parte, indicare la data iniziale di copertura; un anno precedente non alimentato non è un anno con ricavi zero.

## 6. Tempo e confronti

| Base temporale | Uso |
|---|---|
| Data della partenza | Programmazione, stagionalità e partecipazioni |
| Data d'iscrizione | Domanda/prenotazioni, con limiti dello storico |
| Data documento | Andamento dei documenti economici |
| Data pagamento/incasso | Flussi finanziari |
| Data di osservazione | Stato attuale, scaduto, fotografie delle prenotazioni |

Il bilancio per partenza e l'andamento documentale del periodo sono due letture diverse: un costo registrato dopo il viaggio deve restare collegato a quel viaggio senza alterare la sua data documento. Non applicare lo stesso filtro a entrambi gli assi senza dichiararlo.

Confronti proposti: periodo precedente di pari durata, stesso periodo dell'anno precedente, da inizio anno alla stessa data, due intervalli personalizzati. Definire nel contratto DB bordi inclusivi/esclusivi, fuso orario, trattamento del 29 febbraio e periodi incompleti.

Per ogni confronto mostrare valori assoluti, scostamento assoluto e percentuale solo quando significativa. Con base precedente zero o assente, indicare il caso invece di generare percentuali artificiali. Confrontare stagioni omogenee e indicare la numerosità; nessuna promessa di previsione affidabile da pochi casi.

## 7. Grafica, accessibilità e interazioni

Proposta: fondo chiaro, testo scuro, blu come serie principale, palette secondaria coerente, font leggibile con cifre tabulari. Valori e assi non devono perdere leggibilità per effetti decorativi.

- Indicatori con unità, definizione breve, copertura e confronto.
- Grafici sufficientemente ampi; evitare di concentrare tutti i report nella prima schermata.
- Serie precedente distinguibile anche senza colore, per esempio tratteggiata.
- Tooltip precisi e tabella alternativa al grafico.
- Navigazione da tastiera, focus visibile e percorso di ritorno dal dettaglio.
- Filtri attivi sempre visibili, ripristino esplicito, aggiornamento che conserva le selezioni.
- Niente colori di successo/insuccesso per un solo indicatore ambiguo: leggere insieme effettuazione, persone, mezzi e redditività.

Le esportazioni non sono ancora un requisito confermato. Se aggiunte, devono mantenere perimetro aziendale, definizioni, filtri e istante di lettura.

## 8. Domande del momento

La casella libera usa lo stesso catalogo dei report. Esempi:

- «Quali viaggi hanno avuto più persone per partenza rispetto all'anno scorso?»
- «Chi torna fa soprattutto uno o due viaggi all'anno?»
- «In quali mesi le partenze per l'Albania sono state effettuate più spesso?»
- «Qual è il margine medio, includendo le partenze non effettuate?»
- «Da quali province arrivano i viaggiatori di ritorno?»

La risposta include valore, tabella/grafico quando utile, periodo, filtri, definizione e copertura. Domande ambigue richiedono chiarimento; dati insufficienti o metriche non supportate producono una spiegazione esplicita. «Perché non ha funzionato?» non ha una risposta causale nei dati attuali.

## 9. Risultato atteso e collaudo funzionale

La dashboard è accettabile quando l'utente può:

1. Confrontare due periodi omogenei e capire quali viaggi sono stati realizzati, con quante persone e mezzi.
2. Distinguere mancata programmazione, mancata effettuazione e assenza di dati.
3. Leggere quattro mezzi/venti persone come due misure complementari.
4. Riconoscere un viaggiatore unico con tre partecipazioni senza conteggi duplicati.
5. Analizzare provenienza e ritorno senza attraversare il silo aziendale.
6. Ritrovare nel bilancio i costi di una partenza non effettuata.
7. Riconciliare ricavi, costi e margini con il bilancio esistente per lo stesso perimetro.
8. Aggiornare conservando il contesto, distinguendo risultato zero, dato mancante ed errore.
9. Ottenere da una domanda libera lo stesso risultato del report con uguali parametri.

## 10. Punti da definire prima delle metriche definitive

Classificazione guide/personale e mezzi; prezzi/sconti/supplementi e loro storicità; definizione dei ritorni e dell'intervallo medio/mediano; copertura geografica estera; capienza storica per partenza; completezza contabile; trattamento dei costi generali; obiettivi e soglie di eventuali giudizi di successo. Nessuno di questi punti giustifica l'invenzione di dati mancanti.
