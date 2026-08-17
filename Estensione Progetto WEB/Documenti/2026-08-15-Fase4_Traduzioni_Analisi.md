# Fase 4 — Traduzione della newsletter · analisi

*Analisi preliminare. **4.1 e 4.2 realizzati** (script 531); 4.3–4.5 da fare.*

---

## 1. Dov'è il problema, esattamente

Il vecchio motore — quello che spediva un corpo HTML unico — **traduceva**:
`SendCampaignAsync` chiamava Claude su *oggetto* e *corpo* per ogni lingua presente fra i
destinatari, e chi non aveva traduzione riceveva l'italiano.

Il motore a blocchi che l'ha sostituito **non traduce affatto**. In
`SendCampaignBlocchiAsync` la lingua è scritta a mano:

```csharp
Lingua = "IT", StatoConsegna = sent ? "inviato" : "errore"
```

Non è una svista: era dichiarato, ma va sanato. Oggi il cliente tedesco con
`cliente_lingua = 'DE'` riceve la newsletter **in italiano**, e nel registro dei destinatari
risulta pure che l'ha ricevuta in italiano. Il dato è coerente; il risultato no.

Le lingue in gioco sono cinque: **IT** (originale) più **EN, DE, ES, FR**, le stesse già usate dai
contenuti web.

---

## 2. Due strade, e perché una sola regge

| | **A — tradurre l'HTML finito** | **B — tradurre campo per campo** |
|---|---|---|
| Come | si compone la mail in italiano, si passa tutto l'HTML a Claude per ogni lingua | si traducono i singoli campi dei blocchi, si compone la mail già nella lingua giusta |
| Costo | **a ogni invio**, e per ogni lingua | **una volta per newsletter**, riusabile |
| Revisione | impossibile: nessuno rilegge un HTML tradotto | il testo tradotto si legge e si corregge, campo per campo |
| Rischio | Claude riscrive anche ciò che non è testo: attributi `style`, URL, `<img>`, indirizzi di disiscrizione | nessuno: il markup lo genera il nostro renderer, sempre uguale |
| Coerenza | ogni invio può tradurre diversamente | la traduzione è un dato, non un effetto |

È la strada **A** quella che il vecchio motore usava, ed è anche il motivo per cui il passaggio ai
blocchi l'ha semplicemente persa: non era un pezzo riutilizzabile, era una chiamata dentro l'invio.

La strada **B** è quella già in uso per i contenuti web, con la sua tabella, i suoi stati e la sua
pagina di revisione. **Propongo B**, e il resto di questa analisi la assume.

---

## 3. Il cuore della questione: non tutto il testo è la stessa cosa

Su un blocco ci sono venti campi. Dividerli in «testo» e «non testo» non basta — la domanda giusta
è **da dove viene** quel testo, perché è questo a decidere se tradurlo, riusarlo o rigenerarlo.

### Categoria 1 — Scritto dall'utente per questa newsletter → **si traduce**

| Campo | Su quali blocchi | Nota |
|---|---|---|
| `titolo` | testata, riquadro informativo | ma **non** sul riquadro tour: vedi §4 |
| `sottotitolo` | testata, riquadro informativo | ma **non** sul riquadro tour: vedi §4 |
| `corpo_html` | testo, riquadro informativo | HTML, come le descrizioni dei tour: già gestito |
| `link_etichetta` | pulsanti, immagini, riquadri | «Prenota ora», «Scopri il tour» |
| `immagine_alt` | immagine, testata, riquadri | lo legge chi non scarica le immagini, e i lettori di schermo |

Più l'**oggetto** della newsletter, che non sta sui blocchi ma su `web_newsletter_invii` ed è la
prima riga che il destinatario legge.

### Categoria 2 — Viene da un'entità che ha già le sue traduzioni → **si riusa, non si ritraduce**

È il caso del **riquadro tour**, ed è la scoperta che cambia di più il progetto. Vedi §4.

### Categoria 3 — Generato o fisso → **si rigenera nella lingua, non si traduce**

Qui sta il punto che hai sollevato, e non riguarda solo le date.

| Cosa | Perché non si traduce |
|---|---|
| **Periodo del tour** — «Dal 2 al 7 maggio 2026» | È **generato** da `fn_mese_italiano` a partire da due date. Tradurlo a mano lo **congela**: cambiando la partenza, il testo italiano si aggiorna e quello tedesco resta indietro, in silenzio. Va **rigenerato** per lingua, con i nomi dei mesi di quella lingua |
| **Frase di disiscrizione** del piè di pagina | Oggi è scritta in italiano dentro il renderer, e va **a tutti**. Non è testo dell'utente: è testo del programma, e per giunta obbligatorio per legge. Va localizzato nel codice, non messo in tabella |
| **Etichette di riserva** — «Vai alla pagina del Tour», «Scopri di più» | Le mette il programma quando l'utente non scrive nulla. Se l'utente *scrive* un'etichetta, quella è categoria 1 e si traduce; se non scrive niente, il valore di riserva dev'essere già nella lingua giusta |
| **Dati aziendali** del piè di pagina — ragione sociale, indirizzo, telefono, sito | Sono dati, non prosa. «Via Roma 1» resta «Via Roma 1» in ogni lingua |
| **Nomi dei social** | «Facebook» è «Facebook» |

> La distinzione che conta: **tradurre** è per ciò che una persona ha scritto; **localizzare** è per
> ciò che il programma produce. Mettere in tabella un testo generato significa fotografare un
> valore che cambierà, e non accorgersene.

### Categoria 4 — Non è testo → **non entra nemmeno nella discussione**

`layout`, `layout_pulsante`, `colonne`, `colore_titolo`, `colore_sottotitolo`, `social`,
`icona_url`, `immagine_url`, `immagine_storage_path`, `data_viaggio_id_fk`, `indirizzo_id_fk`,
`ordine`, `tipo`.

**Con un'eccezione che merita una decisione, non un'assunzione: `link_url`.** Vedi §5.

---

## 4. Il riquadro tour: tradurre due volte lo stesso testo sarebbe un errore

Il riquadro tour non contiene testo scritto per la newsletter: contiene **una copia** di ciò che sta
nella scheda web del tour — titolo, periodo, descrizione, immagine di copertina. E la scheda web
`web_tour_contenuti` **è già tradotta in tutte e quattro le lingue**: nel database locale ci sono
già `descrizione_html`, `durata_testo`, `info_pasti_html`, `info_equipaggiamento_html`,
`altre_info_html` in EN, DE, ES, FR.

Tradurre di nuovo quei campi come testo del blocco significherebbe:

- pagare due volte la stessa traduzione;
- ottenere due testi **diversi** per lo stesso tour, uno sul sito e uno nella mail;
- doverli revisionare due volte, e vederli divergere alla prima correzione.

**Proposta:** per il blocco tour la traduzione si **risolve dal tour**, non si archivia sul blocco.
Al momento di comporre la mail in tedesco, il riquadro legge la scheda web di quella partenza in
tedesco. Se l'utente ha modificato a mano i testi del riquadro — cosa che il programma consente,
ed è giusto — allora quei campi tornano categoria 1 e si traducono come tutti gli altri.

Serve quindi sapere, per ogni campo del blocco tour, **se è ancora quello del tour o se è stato
riscritto**. È un dato che oggi non abbiamo.

---

## 5. Il collegamento cambia lingua — **deciso: URL separati**

*Deciso il 15/08/2026.* Il sito avrà **indirizzi distinti per lingua**. È più lavoro sul sito, ma
evita due cose che non si recuperano dopo:

- dalla mail, un destinatario tedesco atterrerebbe su una pagina che non sa di doverlo accogliere in
  tedesco: l'informazione che abbiamo noi — `cliente_lingua`, certa — si perderebbe proprio nel
  passaggio;
- senza indirizzi distinti **Google indicizza una sola versione**, e le traduzioni dei tour
  resterebbero utili a chi le legge ma invisibili a chi cerca in tedesco o in francese. Con un sito
  che nasce anche per farsi trovare all'estero, è la ricaduta che pesa di più.

**Conseguenza sul progetto: `link_url` esce dalla categoria 4 ed entra nella 3.** Non è più un dato
fisso da conservare, è un indirizzo da **comporre** con la lingua del destinatario. Il testo del
pulsante e la pagina a cui porta viaggiano insieme.

Da chiudere quando si arriverà al 4.3, non adesso:

- **la forma dell'indirizzo** (`/de/tour/slug`? `/tour/slug` per l'italiano e `/de/...` per le
  altre?) — va concordata con chi costruisce il sito, perché deve corrisponderle esattamente;
- **dove si compone**: oggi il collegamento lo costruisce il database
  (`fn_web_newsletter_dati_tour`, script 514) e viene **salvato** sul blocco. Con gli indirizzi per
  lingua va composto al momento della resa, non salvato — altrimenti si conserva la versione
  italiana e la si traduce ogni volta;
- **le newsletter già inviate non si toccano**: conservano l'indirizzo con cui sono partite, come
  ogni altro dato congelato.

## 6. Ciclo di vita: le tre cose che si rompono da sole

La tabella `web_traduzioni` ha già gli stati che servono — `tradotto_auto`, `revisionato`,
`obsoleto` — e le funzioni per marcare obsoleto. Vanno però agganciati ai tre momenti in cui una
traduzione smette di valere:

**a) L'utente modifica un blocco.** Le traduzioni di *quel campo* diventano obsolete. Esiste già
`fn_web_traduzioni_marca_obsolete`: va chiamata dall'aggiornamento del blocco, altrimenti si spedisce
un testo tedesco che non corrisponde più all'italiano — e nessuno se ne accorge, perché in italiano
è giusto.

**b) Si clona una newsletter o si crea da un modello.** La clonazione genera **id di blocco nuovi**,
e le traduzioni sono indirizzate per id: la copia nasce **senza**. Due strade, entrambe difendibili:
copiare anche le traduzioni (la copia è pronta, ma se poi si cambia il testo italiano restano
disallineate — vedi punto a), oppure lasciarle fuori e ritradurre. Per i **modelli** propendo per
copiarle: un modello «Auguri di Natale» ha lo stesso testo ogni anno.

**c) Si spedisce.** Una newsletter inviata è la prova documentale di cosa è stato mandato. Oggi
`web_newsletter_invii.corpo_html` conserva **un solo** corpo, e il registro dei destinatari
(`web_newsletter_invii_destinatari`) tiene la lingua ma **non** il testo. Con l'invio multilingua
quella colonna non basta più: o si archivia il corpo **per lingua**, o dopo l'invio non si è più in
grado di dire cosa ha ricevuto il destinatario tedesco. È lo stesso principio per cui congeliamo
già gli indirizzi della rubrica al momento dell'invio.

---

## 7. Costo, e perché la granularità conta

`ClaudeTranslationClient.TranslateAsync` traduce **una stringa per chiamata**. La newsletter che hai
composto ha 16 blocchi; contando titoli, sottotitoli, corpi ed etichette si arriva a una trentina di
stringhe. Per quattro lingue sono **~120 chiamate per newsletter**.

Il consumo è già tracciato (`WebAiConsumoService`, con soglia di spesa) e la traduzione per campo si
paga **una volta sola** invece che a ogni invio — quindi rispetto a oggi si risparmia comunque. Ma
120 chiamate per una newsletter è granularità sbagliata: conviene **raggruppare per lingua** (tutti i
campi in un colpo, con un formato che tenga separati i pezzi) e scendere a 4 chiamate. Da verificare
sulla qualità: un titolo tradotto conoscendo il resto della newsletter è probabilmente *migliore*,
non peggiore.

---

## 8. Cosa vedrà l'utente

Perché sia usabile e non un obbligo, serve poco ma preciso:

- nella composizione, un **indicatore per lingua**: tradotta / da revisionare / obsoleta / mancante;
- **«Traduci le lingue mancanti»**, come già esiste per i contenuti web;
- l'**anteprima in una lingua a scelta**, non solo in italiano;
- prima di spedire, un **avviso non bloccante**: «N destinatari riceveranno l'italiano perché la
  loro lingua non è tradotta». Non bloccante di proposito: spedire in italiano a un tedesco è
  peggio del silenzio, ma bloccare l'invio per una traduzione mancante è peggio ancora.

---

## 9. Come lo spezzerei

| # | Contenuto | Perché in quest'ordine |
|---|---|---|
| **4.1** ✅ | Localizzazione dei testi **del programma**: piè di pagina, disiscrizione, etichette di riserva, nomi dei mesi | Nessun database, nessuna IA. Da solo elimina l'italiano dalle parti fisse della mail spedita a stranieri |
| **4.2** ✅ | Traduzione per campo dei blocchi (categoria 1) + risoluzione al rendering + fallback IT | Il cuore |
| **4.3** | Riquadro tour: riuso delle traduzioni del tour, e rilevamento dei campi riscritti a mano | Dipende dal 4.2 ma è separabile |
| **4.4** | Ciclo di vita: obsolescenza alla modifica, clonazione, **archivio per lingua** all'invio | Va fatto prima di spedire davvero in multilingua |
| **4.5** | Interfaccia: stato per lingua, «traduci mancanti», anteprima per lingua, avviso pre-invio | Ultimo: prima si stabilizza il modello |

**Il 4.1 è indipendente da tutto e si può fare subito.**

---

## 10. Cosa non farei

- **Non tradurrei i nomi propri.** «ICHNUSA TOUR» non diventa niente in tedesco. Ma «MARE MONTI
  RELAX IN 4X4» sì: la differenza non la sa il programma, quindi il titolo del tour va **proposto**
  tradotto e lasciato correggibile, mai imposto.
- **Non tradurrei automaticamente all'invio.** La traduzione è un'azione dell'utente, con un costo e
  una revisione. Tradurre al momento dello «Invia a tutti» significa spendere senza che nessuno
  rilegga, e scoprire un errore quando è partito.
- **Non metterei le date in tabella**, per il motivo del §3.
- **Non introdurrei una sesta lingua** finché le cinque non funzionano.

---

## 11. Le domande da chiudere prima di iniziare

1. ~~Gli URL del sito avranno la lingua?~~ **Chiuso il 15/08/2026: sì, indirizzi separati.** Resta
   da concordare la *forma* dell'indirizzo con chi costruisce il sito (§5).
2. **Clonando un modello, le traduzioni si copiano?** (§6b) — io direi sì per i modelli.
3. **Si archivia il corpo per lingua all'invio?** (§6c) — io direi sì: è la stessa logica per cui
   una newsletter inviata non si modifica.
4. **Il titolo del riquadro tour si traduce o si riusa dal tour?** (§4) — dipende se l'utente l'ha
   riscritto, e quel dato oggi non lo abbiamo.
