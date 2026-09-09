# Consuntivo del lavoro svolto — 27 giugno / 8 settembre 2026

**A cosa serve questo documento.** Fissare per capitoli e punti che cosa è stato fatto, con due
destinatari: chi lavora al progetto (per ritrovare le decisioni fra sei mesi) e Antonio SFT (per
sapere che cosa ha ricevuto).

⚠️ **Il perimetro iniziale era uno solo**: preparare il gestionale a fare da backend per il nuovo
sito pubblico. Quel perimetro è la **Parte I** di questo documento, ed è **meno di un terzo** del
lavoro. Tutto il resto — Parte II — è nato dai collaudi: ogni prova su una funzione nuova ha
scoperchiato qualcosa di preesistente, e si è deciso volta per volta di sistemarlo invece di
annotarlo e rimandarlo.

## I numeri

| | |
|---|---|
| Periodo | 27 giugno → 8 settembre 2026 (11 settimane) |
| Commit (gestionale) | **602** — di cui **166** correzioni |
| Commit (sito di iscrizione) | 37 |
| File toccati | 580 |
| Righe aggiunte | ~159.000 |
| Script SQL scritti | **226** nel periodo, numerati fino al `636` |
| Script da applicare al go-live | **228** (dal `406` in poi), in sequenza |
| Funzioni di database | 610 (erano 699: ne sono state eliminate 84 che non chiamava più nessuno) |
| Versione | 1.35 → **2.0** (gestionale) · 3.x → **4.0** (sito di iscrizione) |

---

# PARTE I — Il perimetro iniziale: il backend per il nuovo sito

Il gestionale diventa **l'unico motore di contenuti** del sito pubblico: nessun CMS separato, i
testi si scrivono dove già si lavora, e il sito legge.

## 1. Le schede dei tour

1. **Una scheda per edizione**, cioè per singola partenza (viaggio + data), non per viaggio: due
   partenze dello stesso itinerario possono raccontarsi diversamente.
2. **Anteprima** di come apparirà sul sito, comprese le prossime partenze in programma, e
   **anteprima in lingua** quando le traduzioni sono complete e approvate.
3. **Tre stati** — bozza, pubblicato, archiviato — con il controllo di pubblicabilità **al
   salvataggio**, che riporta a bozza e dice cosa manca.
4. **Clonazione** da un'altra partenza, comprese le traduzioni già approvate; ⚠️ con la gestione
   del caso in cui le due partenze abbiano **durata diversa**.
5. **Ordine sul sito**, indirizzo web (slug) e sua unicità.

## 2. Itinerario, immagini, mappe

6. **Itinerario giorno per giorno** con riordino; ogni giornata mostra la **data reale**, derivata
   dalla partenza, che si aggiorna da sola se la giornata viene spostata.
7. **Galleria immagini** con conversione automatica in WebP, archiviazione su Supabase Storage,
   copertina, riordino e protezione delle foto usate nell'itinerario.
8. **Mappe da traccia GPX** — una dell'intero viaggio e una per giornata, con descrizione
   tradotta, blocco dei file duplicati e ⚠️ tracciato **volutamente generalizzato**, perché la
   mappa mostri il percorso senza renderlo replicabile.

## 3. Multilingua

9. **Traduzioni assistite (Claude)** in EN/DE/FR/ES: traduce solo ciò che manca o è diventato
   obsoleto, mai ciò che è già stato revisionato.
10. **Revisione con editor visuale** (mai HTML a vista) e **approvazione in blocco** dopo un
    controllo a campione, con il vincolo che il campione copra **ogni lingua**.
11. ⛔️ **Gating**: non si pubblica finché le traduzioni non sono revisionate. Una traduzione
    automatica non letta da nessuno è testo che finisce sul sito sotto il nome dell'azienda.
12. **Registro dei consumi** con soglia di spesa facoltativa e avviso al 90%.

## 4. Newsletter

13. **Motore di invio multilingua**: ogni destinatario riceve nella propria lingua, presa
    dall'anagrafica.
14. **Lingua del cliente** in anagrafica, mai vuota: se non specificata viene derivata dalla
    nazione di residenza e memorizzata, così chi invia non deve ragionare.
15. **Pagina di iscrizione e disiscrizione**, con soppressioni per azienda.

## 5. Configurazione e catalogo

16. **Funzioni web per azienda**: quali parti del sito sono attive, con il gating dei comandi
    corrispondenti.
17. **Tipi di viaggio globali** con descrizioni web e traduzioni — ⚠️ **l'unica cosa condivisa fra
    le aziende**: tutto il resto resta separato.
18. **Incluso / Escluso** a livello viaggio, condiviso fra le edizioni e tradotto con la scheda.
19. **Capienza e posti rimasti** per partenza.
20. **Cifratura dei segreti** (`pgcrypto` + master key d'ambiente): chiavi salvate cifrate e
    rilette in chiaro solo dall'applicazione.

---

# PARTE II — Fuori dal perimetro: ciò che i collaudi hanno scoperchiato

> Il criterio applicato, ogni volta: **una regola scritta in due posti diverge sempre.** Quasi
> tutto quello che segue è la stessa cosa vista da angoli diversi — due copie della stessa
> regola, una nel gestionale e una nel sito, che nel tempo avevano preso strade diverse.

## 6. Sistemazioni e camere — il capitolo più grande

Rifatto **da cima a fondo** fra il 5 e il 7 settembre. Prima esistevano nove strade diverse per
scrivere una camera, e **quattro su cinque non controllavano niente**.

21. ⛔️ **Da nove funzioni di scrittura a una.** Il gestionale ne usava tre, il sito una quarta, le
    altre erano rimaste indietro senza chiamanti.
22. ⛔️ **Capienza rigorosa**: una camera da due deve avere esattamente due occupanti. Non era mai
    stato imposto. La regola sta nel **trigger**, quindi vale per il gestionale, per il sito e per
    una correzione fatta a mano.
23. **Il genere della sistemazione** (camera d'albergo / tenda / nessuna): tabella nuova e legame
    con le tipologie di pernottamento. ⚠️ Prima, su un viaggio in campo tendato, il programma
    offriva le camere d'albergo — e il sito pure, per poi far fallire l'iscrizione alla fine.
24. **Spostare una persona di camera** è diventato possibile: prima si finiva in un vicolo cieco,
    perché le camere valide sono per definizione piene e non c'era modo di aggiungersi.
25. ⛔️ **Lo spostamento è una sola operazione atomica.** Prima erano due chiamate, e fra l'una e
    l'altra ci sta tutto ciò che non dipende dal codice: la rete, il pool che chiude, l'app che va
    giù (ed è successo). Si restava con una persona in due camere o una camera vuota mai
    eliminata — ⚠️ **nessuna delle due dà errore**: sono dati che sembrano buoni e si scoprono in
    albergo.
26. **Chi resta senza camera non è più un buco silenzioso**: il programma chiede *«partecipa
    ancora al viaggio?»* e non lascia rimandare la risposta.
27. **La sistemazione di chi resta la sceglie chi lavora**, non il programma: due amici possono
    volere letti separati, e da dentro il software non si sa.
28. **L'assegnazione della camera nasce spenta** all'iscrizione: iscrivere e sistemare tornano due
    lavori distinti, com'erano su Oracle. ⚠️ È la correzione più importante per l'uso quotidiano —
    vedi il manuale.
29. **Linguetta «Partecipanti senza camere»**, che compare solo se c'è qualcuno da sistemare e
    sparisce quando il lavoro è finito.
30. **Sistemazioni che non si propongono da sole** (camere attrezzate per disabili): restano in
    elenco, ma il programma non le assegna a chi capita.
31. **Il tipo predefinito lo decide il database**, non il C#, perché serve anche al sito; e la
    capienza si ferma a sei, quante sono le colonne che la tabella può contenere.
32. **Le righe storiche sotto capienza non si toccano** — deciso, non rimandato: sono tutte su
    viaggi già conclusi e riscriverle significherebbe riscrivere cosa è stato prenotato e pagato.

## 7. Anagrafica cliente

33. ⛔️ **I campi obbligatori sui tab non visitati non bloccavano il salvataggio.** Si poteva
    salvare una scheda incompleta senza che nulla protestasse.
34. **17 controlli scesi nel database** come vincoli veri (email, cognome, nome, sesso, telefono,
    IBAN, indirizzo, coerenza delle date del documento…), così valgono anche per il sito e per
    un'importazione.
35. **Codice fiscale**: coerenza completa con l'anagrafica (nome, cognome, sesso, data e comune di
    nascita) — ⚠️ prima esisteva una funzione di controllo che **dentro aveva scritto `TODO:
    implementare`**: non inerte, ingannevole.
36. **Il codice fiscale è obbligatorio per chi guida e risiede in Italia**, non per tutti: serve
    per la fattura, che è intestata al pilota. ⚠️ Ai passeggeri non si chiede — iscrivere una
    famiglia non deve richiederlo a ciascuno.
37. ⛔️ **Chi guida dev'essere maggiorenne**, con l'età calcolata **alla partenza** e non
    all'iscrizione.
38. **Gli avvisi si vedono mentre si compila**, non solo al salvataggio.
39. **La scheda si compila senza mai prendere il mouse.**
40. **Tipo documento**: una tabella sola al posto di due elenchi divergenti.
41. **Prefissi telefonici**: da testo libero a tabella.
42. **Unicità dell'anagrafica** (8 settembre): ⚠️ **un vincolo c'era già e non proteggeva** — in un
    indice unico il valore vuoto non collide con niente, e 324 clienti su 777 non hanno il codice
    fiscale: per loro quel vincolo non esisteva. Sostituito con uno che funziona.

## 8. Iscrizioni al viaggio

43. **Tre regole sulle partenze che nessuno aveva mai scritto**, e che ora valgono ovunque.
44. **«Partenza chiusa» era definita due volte, e diversamente.** Una partenza cominciata ieri non
    è «conclusa» ma non è nemmeno «iscrivibile»: il sito mostrava partenze che il database poi
    rifiutava.
45. **Il documento si controlla al secondo passo**, non alla fine dopo aver compilato tutto.
46. **Cancellare un partecipante si porta dietro ciò che dipendeva da lui** (i passeggeri di un
    pilota), e lo dice **prima**, elencandoli.
47. **La spunta «effettuato» si spegne** invece di far scoprire il rifiuto dopo.

## 9. Documenti d'identità

48. **Il documento dev'essere valido alla fine del viaggio**, non oggi.
49. ⚠️ **Distinzione fra Italia ed estero**: all'estero un documento scaduto è un **errore** — senza
    non si parte; in Italia è un **avviso** — si parte, ma l'albergo può rifiutare la
    registrazione, perché i documenti di **ogni** occupante si presentano per legge.
50. **Avviso prima delle stampe di partenza**, lista colorata e nota nei PDF, compresa
    l'indicazione di **chi non si può avvisare** perché manca l'indirizzo.

## 10. Il sito di iscrizione (Flask)

51. ⛔️ **Il passo 5 riscritto da capo.** Prima conteneva **cinque regole sulle camere**, tutte
    duplicate dal gestionale e nessuna delle quali guardava il genere del viaggio. Ora la domanda
    è quella giusta — **«come volete dormire»**, non «che stanza volete» — e le regole stanno tutte
    nel database.
52. **Consenso all'invio di email**: chiesto una volta sola a chi non ha mai risposto, e ⚠️ **il
    "no" viene registrato**, perché è ciò che evita di richiederlo.
53. **La regola dell'email è una sola** e sta nel database: prima il sito aveva la sua, più
    permissiva.
54. **Il ripristino dei dati fra un passo e l'altro** (mezzo, passeggeri) non si perde più.
55. ⛔️ **La posta è fail-closed**: se la configurazione di dirottamento è ambigua il sito **si
    ferma** invece di spedire a destinatari veri.
56. **Una chiamata riuscita non prova che il database sia vivo**: diagnostica corretta.

## 11. Unificazione — la stessa regola in un posto solo

57. **84 funzioni eliminate** perché non le chiamava più nessuno (699 → 610), con le definizioni
    conservate in un file, per poterle rileggere se un domani servissero.
58. **Verificato che non esiste più un caso** di due funzioni diverse che fanno lo stesso lavoro
    dai due lati: le tre tabelle che entrambi i software scrivono usano la stessa funzione.
59. **Due trigger di audit scrivevano la stessa colonna**, e chi vincesse dipendeva dall'ordine
    alfabetico dei nomi: «chi ha scritto questa riga» rispondeva sempre «postgres».
60. **Un trigger proteggeva una colonna che non esiste più**: ⚠️ non inerte, **ingannevole** —
    leggendolo si concludeva che il legame utente-ruolo fosse scoperto, mentre era protetto da
    sempre.
61. **La creazione di funzioni dal codice C# è stata tolta**: una definizione che vive
    nell'applicazione non è nel database, e chi legge il database non la trova.
62. **Via il ponteggio dell'ESP** (provider di posta esterno), piano abbandonato a luglio: ⛔️
    teneva una colonna per una **chiave API cifrata** in un sistema che quel segreto non usa.

## 12. Multi-tenancy — i silos

63. ⛔️ **Clienti iscritti ai viaggi di un'altra azienda**: residuo dell'importazione da Oracle. Le
    anagrafiche mancanti sono state create nell'azienda giusta e ⚠️ **il confine è ora imposto**,
    non solo rispettato per convenzione.
64. **Il filtro azienda non è più costruito concatenando SQL**: è un parametro.
65. **Il consenso si chiede e si registra solo sui clienti della propria azienda.**

## 13. Sicurezza, privacy, dipendenze

66. ⛔️ **Il sito espone i dati personali**: con la sola email si ottenevano codice fiscale,
    indirizzo e documento. Aperto da due anni. **Analizzato e da chiudere prima del go-live** —
    vedi Parte III.
67. **Nessuna segnalazione di duplicato nomina più nessuno**: il messaggio non dice più di chi sia
    il codice fiscale già usato.
68. **MailKit 4.9.0 → 4.17.0**, chiude una CVE.
69. **Cifratura dei segreti** con master key d'ambiente (vedi punto 20), con la master key **fuori
    dal pacchetto dell'applicazione**.

## 14. Difetti preesistenti trovati durante i collaudi

Nessuno di questi era nel perimetro. Tutti erano lì da prima.

70. ⛔️ **Una partenza già avvenuta era cancellabile senza alcuna domanda.** L'unica protezione era
    accidentale — di norma quelle partenze hanno prenotazioni — quindi non valeva quando i
    partecipanti non c'erano mai stati. Spariva storico aziendale in modo irreversibile.
71. ⛔️ **Anno digitato errato: `262` invece di `2026`, salvato senza un avviso.** Nessun controllo
    guardava l'anno: quelli esistenti erano tutti *relativi*, e un refuso sull'anno sposta
    entrambe le date insieme. ⚠️ **Su PROD era già successo**: una transazione aveva data pagamento
    `20/02/2202`. Dato corretto.
72. ⛔️ **Il formato delle date seguiva la lingua del PC.** Su una macchina in inglese, `01/12/2026`
    veniva riletto come 12 gennaio: **giorno e mese scambiati, in silenzio**. Non si era mai
    manifestato perché la macchina di sviluppo è in italiano — ⚠️ è il tipo di guasto che compare
    solo dal cliente. Trovati e allineati **16 campi data** in tutta l'applicazione.
73. ⛔️ **Cinque stampe erano rotte**: gli script non erano mai stati applicati.
74. **La ricerca nelle liste non cercava, filtrava** quello che era già stato caricato: in ufficio
    si è in più d'uno, e i dati cambiano sotto. Ora interroga il database, in tutte le liste allo
    stesso modo.
75. **La ricerca clienti restituiva sedici campi in meno**, e la scheda arrivava mutilata.
76. **Il titolo dei partecipanti restava «Caricamento…»** a elenco caricato.
77. **Le date perdevano cifre mentre si digitava.**
78. **I campi collegati si azzeravano** anche quando il valore non era cambiato.
79. **Il messaggio scritto per chi legge veniva buttato via** e sostituito con uno generico.

## 15. Qualità del dato in produzione

Misurato su PROD in sola lettura, e corretto solo dove autorizzato.

80. **Tre doppioni anagrafici veri**, trovati e risolti: MAIORCA MARIA, TACCA ALESSANDRO,
    COLOMBO ROBERTA. ⚠️ L'ultimo non era una cancellazione: entrambe le schede avevano iscrizioni,
    e le due erano **iscritte alla stessa partenza** — con la conseguenza che il pilota risultava
    in **due camere matrimoniali sulla stessa notte**. Una rooming list stampata in quel momento
    avrebbe chiesto all'albergo una camera in più.
81. ✅ **Oggi PROD non ha più doppioni riconoscibili** su cognome + nome + data di nascita.
82. **Ricognizione su tutte le 108 colonne data/ora** dello schema, alla ricerca di anni
    implausibili.
83. ⚠️ **Restano due clienti senza data di nascita** (GENDUSO, FORNO): fuori dalla portata sia del
    vincolo sia del riconoscimento automatico. Si recuperano solo chiedendo.

## 16. Documentazione, collaudo, strumenti

84. **Piano di test del gestionale**: eseguito integralmente, tutti i gruppi chiusi.
85. **Piano di test delle sistemazioni** e **piano di test del sito di iscrizione** (nove gruppi):
    scritti ed eseguiti.
86. **Checklist di go-live**: 228 script in sequenza, con il *perché* di ciascuno, più le voci ad
    attenzione manuale.
87. **Due manuali utente nuovi** — sistemazioni e iscrizioni, contenuti web — e il manuale del sito
    riallineato dopo un anno.
88. **Grafo di conoscenza del progetto** (`graphify`), con ricostruzione automatica a ogni commit.
89. **Note di rilascio 2.0**, documento vivo.

---

# PARTE III — Che cosa resta prima del go-live

⛔️ **Bloccanti**

90. **Chiudere l'esposizione dei dati personali sul sito** (punto 66). Analizzato, non ancora
    chiuso.
91. **Applicare i 228 script a PROD**, nella sequenza della checklist.
92. **Impostare la master key dei segreti** in produzione e re-inserire i segreti.
93. **Togliere il dirottamento della posta** dall'ambiente di produzione: se resta, nessun cliente
    riceve niente.
94. **Ruolo anonimo e RLS**, bucket Storage, allineamento della lingua sui clienti reali.

⚠️ **Da fare, non bloccanti**

95. **Gli screenshot dei due manuali** (dieci in tutto).
96. **Pulizia ricorrente dei token scaduti**: oggi non li rimuove nessuno.
97. **Riverificare i campi data su Windows**, possibilmente con la lingua di sistema in inglese
    (punto 72).

**Rimandato consapevolmente**

98. SQL ancora scritto dentro il codice del gestionale in alcuni punti (elencati).
99. Verifica dell'indirizzo email con codice usa-e-getta (OTP): utile, ma **non** contro i
    doppioni — nessuno dei tre casi reali sarebbe stato fermato.
100. Le anomalie sui dati storici che il cliente ha deciso di lasciare come sono.
