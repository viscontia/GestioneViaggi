# Piano di test — Generi di sistemazione e coerenza col viaggio

**Scritto il 2026-09-06**, dopo l'implementazione su MAUI. Copre il gestionale; la parte
sul sito arriverà quando il passo 5 sarà riscritto.

Riferimenti: `Estensione Progetto WEB/Documenti/2026-09-05-Analisi_Scelta_Camere_Step5.md`,
`SqlScripts/599`–`601`.

⚠️ **Segnala solo ciò che non funziona.** Dove serve un dato da cercare, chiedi.

### Stato

| Gruppo | Esito |
|---|---|
| **A** — La pagina dei Generi di Sistemazione | ✅ **superato** (2026-09-06) |
| **B** — Il genere sui tipi di sistemazione | ✅ **superato** (2026-09-06) |
| **C** — Le sistemazioni previste da un pernottamento | ✅ **superato** (2026-09-06), dopo gli script `607`→`609` e la correzione dei messaggi |
| **D** — Quel che si può assegnare dipende dal viaggio | ✅ **superato** (2026-09-06), dopo `610`, `611`, la tendina unica e la correzione del blocco |
| **E** — La validazione al salvataggio | ☐ da fare |
| **F** — Il suggerimento del tipo | ✅ **superato** (2026-09-06), dopo `610`–`615`, la tendina unica, lo spostamento atomico e la linguetta «senza camere» |
| **G** — Che le due strade dicano la stessa cosa | ✅ **superato** (2026-09-06), eseguito in locale su transazione annullata. ⚠️ G1e resta come atteso ma in contraddizione con la decisione sulla capienza — vedi la nota in fondo |

I difetti trovati durante A–C e corretti: la domanda di conferma al posto del rifiuto
(`609`), «NESSUNO» modificabile (`609`), le descrizioni minuscole (`603`), le guardie
incomplete sui generi (`606`), e ⚠️ **il messaggio del database sostituito da una frase
generica** (`DatabaseExceptionHelper`) — che riguardava tutte le guardie, non solo C12.

---

## Prima di cominciare

Il database locale deve avere gli script fino al **613** applicati.

⚠️ **Dal 2026-09-06 la tendina delle sistemazioni è UN componente solo**
(`TipoAlloggioSelect`), usato da tutte e tre le schede. Prima erano tre copie: se una prova
di D o E fallisce in una scheda sola, è un difetto del componente o di come quella scheda lo
usa — non più «una delle tre copie è rimasta indietro». Verifica:

```sql
SELECT count(*) FROM ana_alloggio_generi;                 -- atteso: 3
SELECT count(*) FROM ana_tipo_alloggio WHERE genere_fk IS NULL;  -- atteso: 0
SELECT count(*) FROM ana_tipo_pernottamento_generi;       -- atteso: 4
```

---

## A — La pagina dei Generi di Sistemazione

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| A1 | Menu → **Generi di Sistemazione** | La voce c'è, accanto a «Tipologie Alloggi». Si apre con tre righe: ALBERGO, TENDA, NESSUNA |
| A2 | **Nuovo** → descrizione «BUNGALOW», codice «BUNGALOW», ordine 3 | Si crea. ⚠️ Descrizione e codice diventano MAIUSCOLI da soli |
| A3 | Scrivi nel codice «CASA MOBILE» (con lo spazio) | Lo spazio diventa `_`: `CASA_MOBILE`. Il codice lo usa il programma, non può avere spazi |
| A4 | **Modifica** il bungalow appena creato | ⚠️ Il campo **codice è disabilitato**: è il nome con cui il programma riconosce il genere, e cambiarlo su una riga già usata romperebbe le regole in silenzio |
| A5 | Togli la spunta **Attivo** al bungalow e salva | Resta in elenco con la spunta vuota |
| A6 | Vai in **Tipologie Alloggi** → Nuovo → apri la tendina Genere | ⚠️ Il bungalow **non compare**: disattivato non si può più scegliere |
| A7 | Rimetti Attivo al bungalow, poi prova a **eliminarlo** | Si elimina: nessun tipo lo usa |
| A8 | Prova a eliminare **ALBERGO** | ⚠️ Rifiutato, e il messaggio dice **quanti** tipi lo usano («è il genere di 10 tipi di sistemazione») — non un generico «impossibile» |
| A9 | **Nuovo** lasciando la descrizione vuota | Il salvataggio non parte, il campo si segna in rosso |
| A10 | Cerca «tenda» nella barra di ricerca | Trova TENDA per codice o descrizione |

---

## B — Il genere sui tipi di sistemazione

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| B1 | Menu → **Tipologie Alloggi** | C'è la colonna **Genere**, popolata su tutte le 15 righe |
| B2 | Cerca «tenda» | Trova le 4 tende. ⚠️ Le trova **anche per genere**, non solo per descrizione |
| B3 | **Modifica** CAMERA MATRIMONIALE | Il campo Genere mostra «Camera in struttura ricettiva», con la spiegazione sotto |
| B4 | **Nuovo** → descrizione e occupanti, ma **non** scegliere il genere → Crea | ⚠️ Rifiutato: il genere è obbligatorio |
| B5 | Crea «CAMERA QUINTUPLA», 5 posti, genere ALBERGO | Si crea, e in elenco **compare subito il genere** (non una cella vuota) |
| B6 | Modifica quella riga: cambia solo la descrizione e salva | Il genere **resta** quello scelto, non si azzera |
| B7 | Elimina «CAMERA QUINTUPLA» | Si elimina |
| B8 | Modifica CAMERA MATRIMONIALE e prova a portarne il genere a **Tenda** | ⚠️ **Rifiutato**: «con questo genere 219 assegnazioni già registrate diventerebbero incoerenti, su: …». Cambiare il genere di un tipo in uso invaliderebbe la storia in silenzio |
| B9 | Modifica CAMERA MATRIMONIALE cambiando **solo la descrizione** | Passa: il controllo guarda il genere, non ogni modifica |
| B10 | Cambia il genere di **TENDA 4 POSTI NOLEGGIATA** (mai usata) verso Albergo | ⚠️ **Passa**, ed è voluto: nessuna assegnazione ne resta invalidata, e vietarlo impedirebbe di correggere una classificazione sbagliata |

---

## C — Le sistemazioni previste da un pernottamento

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| C1 | Menu → **Tipologie Pernottamento** | C'è la colonna **Sistemazioni previste**: ALBERGO per «ALBERGO», «Camera… · Tenda…» per il misto, «Tenda…» per SOLO CAMPI TENDATI, **NESSUNA** per NESSUNO. Accanto a «NESSUNO» c'è un **lucchetto** |
| C2 | **Modifica** «ALBERGO» | ⚠️ La spunta «Con Albergo» **non c'è più**. Ci sono le spunte delle sistemazioni previste, con ALBERGO spuntato |
| C3 | Spunta anche TENDA e salva | In elenco la riga mostra entrambe |
| C4 | Guarda la colonna «Con Albergo» | ⚠️ È ancora `Y`, **senza che tu l'abbia toccata**: ora è una conseguenza dei generi, non una scelta |
| C5 | Modifica «SOLO CAMPI TENDATI»: **togli** TENDA, **metti** ALBERGO, salva | La colonna «Con Albergo» passa da vuota a spuntata **da sola** |
| C6 | Rimetti TENDA e togli ALBERGO | «Con Albergo» torna vuota |
| C7 | Prova a **modificare** «NESSUNO» | ⚠️ **Non si apre nemmeno**: «è una configurazione di sistema… non si può modificare né cancellare». Non è più possibile spuntargli dei generi — ed era proprio quel gesto a creare la trappola da cui non si tornava indietro |
| C7b | Prova a **eliminare** «NESSUNO» | ⚠️ Stesso avviso, stesso rifiuto |
| C8 | In una qualunque scheda, cerca la voce «Nessuna sistemazione» fra le spunte | ⚠️ **Non c'è**, ed è giusto: vale sempre, su qualunque viaggio, e non si configura |
| C9 | Modifica «ALBERGO» e prova a **togliere** la spunta ALBERGO | ⛔️ **RIFIUTATO**, senza domande: «Non si può: 414 assegnazioni oggi valide non lo sarebbero più, su: …. Vanno cambiate prima quelle assegnazioni». Non c'è nessun «Procedi»: un clic non deve poter rompere 414 righe |
| C9b | Riapri «ALBERGO» e **risalva senza cambiare niente** | Salva, **senza avvisi**: se non si rompe nulla non si dice nulla. ⚠️ È la prova che il controllo non è rumoroso — un avviso che compare quando non serve insegna a ignorarlo |
| C9c | Modifica «ALBERGO CON QUALCHE CAMPO TENDATO» togliendo TENDA (che nessuna assegnazione usa) | Salva, **senza avvisi**: togliere un genere che nessuno sta usando non rompe niente |
| C10 | Modifica «ALBERGO» **aggiungendo** TENDA senza togliere nulla | Passa: aggiungere non scopre niente |
| C11 | Prova a **eliminare** il pernottamento «ALBERGO» | ⚠️ Rifiutato, con il conto di ciò che è collegato: viaggi, date e prenotazioni |
| C12 | Apri un **viaggio in albergo** con camere assegnate e cambiane il pernottamento a «SOLO CAMPI TENDATI» | ⚠️ **Rifiutato**, con il messaggio **per esteso**: «Con il pernottamento «SOLO CAMPI TENDATI» 37 sistemazioni già assegnate su questo viaggio non sarebbero più ammesse. Vanno cambiate prima». ⚠️ Il numero dev'esserci: un rifiuto generico («un valore non rispetta le regole di validità») non dice cosa fare |

---

## D — Quel che si può assegnare dipende dal viaggio

⚠️ Serve un viaggio in albergo e uno in campo tendato. Chiedi se non li trovi.

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| D1 | Apri un viaggio **in ALBERGO** → tab Partecipanti → gestione alloggi → nuova camera | Nella tendina dei tipi ci sono **le camere e «nessuna camera»**, ⚠️ **nessuna tenda** |
| D2 | Apri un viaggio **SOLO CAMPI TENDATI** (PIRENEI IN FUORISTRADA) → stessa strada | Ci sono **le tende e «nessuna camera»**, ⚠️ **nessuna camera d'albergo**. ⚠️ Provalo dalla scheda **Partecipanti** assegnando un passeggero: è la strada che sbagliava (`SqlScripts/610`), e le altre già funzionavano |
| D3 | Apri un viaggio con pernottamento **NESSUNO** | ⚠️ L'unica voce è **«nessuna camera»** |
| D4 | **Iscrizione veloce**: scegli un viaggio in albergo e una data, poi guarda la tendina della sistemazione | Solo camere |
| D5 | Sempre in iscrizione veloce, **cambia la data** scegliendo una partenza di un viaggio in tenda | ⚠️ La tendina si **ricarica** e mostra le tende |
| D6 | In iscrizione veloce: scegli una camera, poi **cambia data** verso un viaggio in tenda | ⚠️ La sistemazione scelta **si azzera**: su quella partenza non è più ammessa |

---

## E — La validazione al salvataggio

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| E1 | Su un viaggio in albergo, crea una **camera matrimoniale** con **due** occupanti | Si salva |
| E2 | Crea una **matrimoniale** con **un solo** occupante | ⚠️ Rifiutato: «ospita 2 persone, ne è stata indicata 1». Una doppia con uno solo si chiama «doppia uso singola» ed è un tipo suo |
| E3 | Crea una **camera singola** con 1 occupante | Si salva |
| E4 | Metti la **stessa persona** in due camere | ⚠️ Rifiutato: «una stessa persona risulta assegnata a più di una sistemazione» |
| E5 | Guarda il messaggio di errore | Una riga per rilievo, leggibile — non un errore tecnico del database |

---

## F — Il suggerimento del tipo

> **Scritto il 2026-09-06**, dopo aver accertato che non esisteva: c'erano due copie del
> calcolo, già divergenti fra loro, e ⚠️ **nessuna delle due veniva mai chiamata**. Ora la
> regola è una sola (`TipoAlloggioService.Suggerisci`) e la applica `TipoAlloggioSelect`.
>
> **La regola:** capienza **uguale** al gruppo (non «almeno»: una doppia con uno solo è una
> «doppia uso singola», tipo suo con supplemento suo); a parità, quello **senza
> supplemento**; a parità anche di quello, il più vecchio.
>
> È una **proposta**, non una decisione: si può sempre cambiare, e appena scegli a mano il
> programma non ci torna più sopra.

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| F1 | Viaggio in **albergo**, componi una camera e aggiungi **1** occupante | Propone **CAMERA SINGOLA** |
| F2 | Aggiungi il **secondo** occupante | ⚠️ La proposta si **aggiorna** a CAMERA MATRIMONIALE: finché non hai scelto tu, segue il gruppo |
| F3 | Aggiungi il **terzo**, poi il **quarto** | CAMERA TRIPLA (TRE LETTI SINGOLI), poi CAMERA QUADRUPLA (…4P) |
| F4 | Con 2 occupanti, **cambia a mano** in CAMERA DOPPIA LETTI SINGOLI, poi aggiungi il terzo | ⚠️ **Resta quella che hai scelto tu**: la proposta non sovrascrive una scelta. La capienza sbagliata la segnala la validazione (E2) |
| F5 | Viaggio **in tenda**, gruppo di **2** | Propone **TENDA 2 POSTI DI PROPRIETA'** — non quella noleggiata, che ha supplemento |
| F6 | Stesso viaggio, gruppo di **3** | ⚠️ **Nessuna proposta**: ci sono tende da 1, 2 e 4 posti, non da 3. Meglio non proporre che proporre una capienza che poi il salvataggio rifiuta |
| F6b | Viaggio **in tenda**, gruppo di **1** | Propone **TENDA 1 POSTO DI PROPRIETA'** — non la noleggiata, che ha supplemento. ⚠️ Prima non c'era nessuna tenda da uno: a chi partiva da solo il programma non proponeva niente e non aveva niente da scegliere |
| F7 | **Iscrizione Veloce**: scegli un viaggio in albergo, una data, e chiedi la sistemazione | Propone CAMERA SINGOLA: lì si iscrive una persona per volta |
| F8 | Scheda **Partecipanti**: apri un **pilota con 2 passeggeri** e chiedi la sistemazione | Propone un tipo da **3 posti**: il pilota porta con sé i suoi passeggeri |
| F9 | Stessa scheda, apri un **passeggero** | Propone un tipo da **1 posto**: un passeggero sta per conto suo |

| F13a | **Il caso vero.** Iscritto un pilota da solo con CAMERA SINGOLA, iscrivi ora una passeggera abbinata a lui e scegli «aggiungi a camera esistente» | ⚠️ La camera del pilota **compare anche se piena** (1/1). Scegliendola: «CAMERA SINGOLA è al completo. Per stare insieme a X la camera va cambiata», e sotto una tendina **«La camera diventa»**. Salvi e finisce lì: ⛔️ **nessuna registrazione finta in una singola** |
| F13a1 | Apri quella tendina | ⚠️ Contiene **solo le sistemazioni da 2 posti**: CAMERA MATRIMONIALE (proposta), CAMERA DOPPIA LETTI SINGOLI, CAMERA MATRIMONIALE DISABILI. ⚠️ La proposta è la matrimoniale ma **la scelta è tua**: due persone possono volere i letti singoli. E la DISABILI c'è, ma non è proposta |
| F13a3 | Scegli **CAMERA DOPPIA LETTI SINGOLI** e salva | La camera diventa quella, non la matrimoniale |
| F13a4 | **La scala.** Sulla matrimoniale ormai piena (2/2) aggiungi una **terza** persona, poi una **quarta** | La tendina offre le sistemazioni da **3** posti (le due triple), poi quelle da **4**. Non c'è nessun caso speciale per la coppia: è sempre «capienza = occupanti + 1» |
| F13a5 | Prova ad aggiungere una **sesta** persona a una camera da 5 | ⚠️ «CAMERA … è al completo: scegli con quale sistemazione da 6 posti sostituirla», e la tendina è **vuota** con «questo viaggio non prevede sistemazioni da 6 posti». Non si sfonda: si ferma |
| F13a2 | Stessa prova su un gruppo di **4**: scegli una quadrupla già piena | ⚠️ «per 5 persone questo viaggio non prevede nessuna sistemazione»: non si sfonda la capienza, si dice che non si può |
| F13a6 | Iscrivi un passeggero e scegli **«crea nuova camera»**: apri la tendina | ⚠️ Ci sono **solo le sistemazioni da 1 posto**. Prima si poteva scegliere una MATRIMONIALE per una persona sola — ed è successo davvero. Sotto c'è scritto perché: «per dormire con altri, scegli aggiungi a camera esistente» |
| F13a7 | Sposta una persona **fuori** da una camera occupata da due o più | ⚠️ Prima di salvare compare **«La sistemazione di chi resta»**: «Spostando X, in CAMERA DOPPIA resta Y — 1 persona. Con quale sistemazione va sostituita?», con l'elenco ristretto alla capienza rimasta. ⛔️ Il programma **non sceglie da solo**: due amici non vanno messi in matrimoniale senza che qualcuno l'abbia deciso |
| F13a8 | Nella finestra «La sistemazione di chi resta» premi **Annulla** | ⚠️ **Non si salva niente**, nemmeno lo spostamento: o si decide tutto, o non è successo nulla |
| F13a0 | Apri i partecipanti e guarda la scheda **prima di scegliere il cliente** | ⚠️ «Tipo Sistemazione» è **vuota**, con sotto «Si compila da sé quando scegli la persona». Nessun riquadro verde: proporre una camera prima di sapere per chi è indistinguibile da un residuo del salvataggio precedente |
| F13a0b | Scegli il cliente | ⚠️ **Ora** compare la proposta (CAMERA SINGOLA per una persona) con il riepilogo |
| F13a9 | Iscrivi un **passeggero abbinato a un pilota** e scegli «crea nuova camera» | ⚠️ Prima di salvare: «**Una camera tutta sua?** — X viaggia con Y, che ha una CAMERA SINGOLA (1/1). Stai per assegnargli una sistemazione indipendente: è corretto?» |
| F13a10 | Rispondi **«No, torno indietro»** | ⚠️ **Non viene salvato niente**, nemmeno l'iscrizione: si torna alla scheda e puoi scegliere «aggiungi a camera esistente» |
| F13a11 | Rifai e rispondi **«Sì, sistemazione indipendente»** | Salva regolarmente: capita che due che viaggiano insieme dormano separati, e non è un divieto |
| F13a12 | Iscrivi un **pilota** (non un passeggero) con camera nuova | ⚠️ **Nessuna domanda**: chi guida non viaggia «con» qualcun altro |
| F13a13 | Iscrivi un passeggero scegliendo **«aggiungi a camera esistente»** | ⚠️ **Nessuna domanda**: lì la scelta di stare insieme l'hai già fatta. Un avviso che compare quando non serve insegna a ignorarlo |
| F15a | Apri i partecipanti di una partenza dove qualcuno non ha sistemazione | ⚠️ Accanto a «Partecipanti» e «Alloggi» c'è una **terza linguetta** con il triangolo d'attenzione: **«Partecipanti senza camere (1)»**. Si vede entrando, senza aprire nessun tab |
| F15a1 | Aprila | Stesso elenco degli altri tab — nominativo, ruolo, veicolo — con in fondo un pulsante **Assegna** |
| F15a2 | Premi **Assegna** | Si apre la gestione alloggi **già puntata su quella persona**, con la domanda «Dove dorme X?» |
| F15a4 | Assegna l'ultimo rimasto e torna indietro | ⚠️ La linguetta **sparisce**: non resta una «(0)» accesa a vuoto, che insegnerebbe a non guardarla |
| F15a3 | Guarda «Tipo Sistemazione» su una scheda di inserimento vuota | ⚠️ È **vuoto**, non scrive «0». Prima, senza scelta fatta, il campo mostrava lo zero del valore interno |
| F15b | Premi **Assegna** e scegli **«Una sistemazione sua»** | Si apre «Dove dorme X» con lui già dentro: scegli il tipo e salvi |
| F15c | Premi **Assegna** e scegli **«Con qualcun altro»** | ⚠️ Si sceglie la sistemazione fra quelle esistenti — **tutte, anche se piene**, perché con la capienza rigorosa non ce ne sono con posti liberi — e poi con quale sostituirla: «Diventeranno in 2» |
| F15d | Conferma | La sistemazione cambia tipo e accoglie la persona, in una sola operazione. Il riquadro «Senza sistemazione» si svuota |
| F15e | Ripeti su una partenza **senza nessuna camera** e scegli «Con qualcun altro» | ⚠️ «Non c'è ancora nessuna sistemazione su questa partenza: puoi solo creargliene una» — invece di una tendina vuota senza spiegazione |
| F14a | **Il buco.** Da una matrimoniale con due persone togline una e accetta la singola proposta per chi resta | ⚠️ Compare **«Partecipa ancora al viaggio?»**: «X è rimasto senza sistemazione. Se parte, va messo in una camera; se non parte più, va tolto anche dall'iscrizione» |
| F14b | Rispondi **«Parte: gli assegno una sistemazione»** | ⚠️ Si apre subito **«Dove dorme X»**, con la persona **già dentro** come occupante: manca solo il tipo. Non una scheda di nuovo inserimento — l'iscrizione c'è già |
| F14b2 | In quella scheda scegli il tipo e salva | La persona ha la sua sistemazione, e sparisce dai «senza camera» |
| F14b3 | In quella scheda premi **Annulla** | ⚠️ Resta iscritto **senza** camera: legittimo, ma l'avviso giallo torna a segnalarlo. La domanda l'hai vista, la scelta è tua |
| F14c | Rifai e rispondi **«Non parte più: cancella l'iscrizione»** | ⚠️ Sparisce dal viaggio, non solo dalla camera. Nessun avviso giallo da ignorare |
| F14d | Rifai togliendo un **pilota che ha passeggeri** e scegli di cancellarlo | ⚠️ Prima di procedere: «X guida, e senza di lui restano senza mezzo: Y, Z. Cancellando lui si cancellano anche loro» — con i nomi, non un numero |
| F14e | In quella finestra premi **Annulla** | Non si cancella nessuno: il pilota resta iscritto, solo senza camera |
| F13b | **Il vicolo cieco.** Iscrivi un pilota con CAMERA SINGOLA; aggiungi una passeggera abbinata a lui, dandole una singola sua; poi cambia la camera del pilota in **MATRIMONIALE** e prova ad aggiungerci la passeggera | ⚠️ Lei **compare** fra gli assegnabili, con il segno «**si sposta da CAMERA SINGOLA**». Salvando, entra nella matrimoniale e **la sua singola sparisce da sola**. Prima non compariva affatto — aveva già una camera — e da lì non si usciva più |
| F13c | Rifai F13b ma con una camera di partenza da **2 posti occupata da due persone**: sposta solo una delle due | La camera di partenza **resta**, con l'altra persona dentro. Si elimina solo quando rimane vuota |
| F13d | Rifai F13b e, subito dopo il salvataggio, **riapri la gestione alloggi** | La camera di lei non c'è più e la matrimoniale ha due occupanti. ⚠️ Le due cose avvengono in **una sola** operazione del database (`fn_alloggi_salva_camera`): non esiste un istante in cui lei risulta in due camere o in nessuna |
| F13 | Iscrivi un **pilota** con una CAMERA SINGOLA, poi aggiungi una **passeggera** abbinata a lui e chiedi «aggiungi a camera esistente» | ⚠️ Non c'è nessuna camera libera, ed è giusto. Ma il messaggio ora **nomina la situazione**: «X ha una CAMERA SINGOLA, già al completo. Se devono stare insieme, cambia quella camera con la matita — creandone una seconda si pagano due sistemazioni» |
| F14 | Dalla matita sulla camera del pilota, cambiala in **MATRIMONIALE** e aggiungi la passeggera | Si salva: due occupanti su due posti |
| F15 | In alternativa, crea per lei una **seconda singola** e salva | ⚠️ **Passa, ed è voluto**: due singole con un occupante ciascuna sono valide quanto una matrimoniale, e a volte è proprio quello che si vuole. Il programma non lo vieta — avvisa, e la scelta resta di chi lavora |
| F10 | Viaggio in albergo, gruppo di **1**: apri la tendina e guarda l'elenco | ⚠️ **CAMERA SINGOLA DISABILI c'è**, si può scegliere — ma **non è quella proposta**: esce CAMERA SINGOLA |
| F11 | Menu → **Tipologie Alloggi**: guarda la colonna «Mai proposta» | Il segno c'è sulle due righe DISABILI e su nessun'altra |
| F12 | Modifica una sistemazione qualunque e spunta «Non proporre mai d'ufficio», poi rifai F1 | Sparisce dalle proposte ma **resta in elenco**. ⚠️ È una scelta dell'operatore, non una cosa che posso cambiare solo io con una UPDATE a mano |

⚠️ **Perché serviva una colonna** (`SqlScripts/611`). Per una persona sola in albergo
esistono tre tipi da 1 posto, tutti con supplemento: CAMERA SINGOLA, CAMERA DOPPIA USO
SINGOLA e **CAMERA SINGOLA DISABILI**. Fino al 6 settembre usciva CAMERA SINGOLA solo perché
era la più vecchia delle tre — **per fortuna, non per regola**: bastava creare una riga
nuova per far proporre a caso una camera attrezzata a chi non l'aveva chiesta. Ora lo dice il
dato (`tipo_alloggio_mai_proposta`). ⛔️ Riconoscerla dal nome non si fa: è il difetto tolto
dai generi.

---

## G — Che le due strade dicano la stessa cosa

⚠️ È il gruppo che conta: le regole stanno a database e valgono per chiunque scriva.

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| G1 | Prova a scrivere **a mano nel database** una camera d'albergo su un viaggio in tenda | ⚠️ **Rifiutata dal database** (`SqlScripts/602`), con un messaggio che dice il tipo, il pernottamento del viaggio e quali generi sarebbero ammessi |
| G1b | Scrivi a mano una **tenda** sullo stesso viaggio | Passa |
| G1c | Scrivi a mano «nessuna camera» sullo stesso viaggio | Passa: vale sempre |
| G1d | Prendi una riga valida e **modificale il tipo** verso uno non ammesso | Rifiutata: il vincolo vale anche in modifica, non solo in inserimento |
| G1e | Scrivi a mano una **doppia con un occupante solo** | ⚠️ **Oggi passa** — il trigger non guarda la capienza (`SqlScripts/602`). ⛔️ **Ma questa attesa è in contraddizione con la decisione del 2026-09-06**: «le camere vanno assegnate in modo rigoroso sul rapporto persone/capienza e non ci devono essere scappatoie; le eccezioni con l'albergo restano offline». Da decidere se il controllo scende nel database — vedi la nota sotto |
| G2 | Sulla partenza PIRENEI, chiedi la validazione dell'assegnazione vuota | Elenca **tutti** i partecipanti senza sistemazione |

### Esito, eseguito il 2026-09-06 sul database locale (transazione annullata)

Partenza usata: **WILD TOUR SARDEGNA IN 4X4** del 17/06/2025, pernottamento SOLO CAMPI TENDATI.

| # | Esito |
|---|---|
| G1 | ✅ **Rifiutata**: «CAMERA MATRIMONIALE non è una sistemazione prevista da questo viaggio (pernottamento: SOLO CAMPI TENDATI). Ammesse: TENDA IN CAMPO TENDATO» — il messaggio dice tipo, pernottamento e cosa sarebbe ammesso |
| G1b | ✅ La tenda da 2 passa |
| G1c | ✅ «Nessuna camera» passa: vale sempre |
| G1d | ✅ **Rifiutata anche in modifica**, non solo in inserimento |
| G1e | ⚠️ **Passa**, come previsto: il trigger guarda il genere, non la capienza. ⛔️ In contraddizione con la decisione «nessuna scappatoia» — la scrittura a mano aggira `fn_alloggi_salva_camera`, che invece la rifiuta |
| G2 | ✅ 5 iscritti sulla partenza, **5 avvisi**: nessuno dimenticato |

```sql
-- G2, da eseguire sul database locale
SELECT gravita, esito, messaggio
FROM fn_alloggi_assegnazione_valida(
       (SELECT d.data_viaggio_id FROM ana_date_viaggi d
        JOIN ana_viaggi v ON v.viaggio_id = d.viaggio_id_fk
        WHERE v.viaggio_descrizione_breve ILIKE '%PIRENEI%' LIMIT 1),
       '[]'::jsonb);
```

---

## ⚠️ In sospeso: la capienza rigorosa anche a database

Il 2026-09-06 Adriano ha deciso: **capienza rigorosa, nessuna scappatoia**. Oggi la regola
la applica solo la scheda; il trigger `trg_alloggio_coerente` (`SqlScripts/602`) guarda il
genere, non la capienza — di proposito, per la storia della «doppia pagata a uso singola».

Misurato su PROD (azienda 2, sola lettura, 2026-09-06): **131 assegnazioni, 122 esatte**.
Le altre 9:

| Caso | Quante | Che cosa sono |
|---|---|---|
| `NESSUNA CAMERA` con 1 occupante | 2 | ⚠️ **Non sono un errore**: è il modo in cui si registra chi dorme nel proprio mezzo. Capienza 0 e un occupante è il funzionamento normale — una regola `occupanti = capienza` secca le romperebbe tutte |
| Doppie con un occupante solo | 7 | Le «doppie uso singola registrate col tipo sbagliato» di cui parlava Antonio. Una è su una partenza **futura** (MAXI ENDURO TOUR DEI 2 MARI, 22/10/2026) |

Portare il controllo a database significa: escludere il genere `NESSUNA`, e sistemare
quelle 7 righe **prima**, altrimenti non saranno più modificabili. Decisione aperta.

---

## Cosa questo piano NON copre

- **Il sito di iscrizione**: il passo 5 non è ancora stato riscritto. Finché non lo è, sui
  viaggi in tenda continua a saltarlo.
- **Le combinazioni** (`fn_alloggi_combinazioni`): la funzione c'è ed è verificata, ma
  nessuna interfaccia la usa ancora. Servirà al sito.
- **Il caso misto** — albergo e tende nello stesso viaggio, notte per notte: dichiarato
  fuori portata nell'analisi, il modello lega la sistemazione alla partenza.
- **I dati storici incoerenti**: le 17 assegnazioni già in produzione non vengono corrette
  da nulla. Il nuovo controllo impedisce che se ne creino altre.
