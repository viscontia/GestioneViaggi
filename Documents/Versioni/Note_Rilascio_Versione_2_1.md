# Note di Rilascio — Versione 2.1

> Prima versione **dopo il go-live**. Nasce da una giornata di domande di Antonio, il 14 settembre
> 2026: quasi tutto quello che c'è dentro è la risposta a una cosa che gli è successa mentre
> cominciava a usare il programma sul serio.
> Data: 2026-09-14 · versione precedente in produzione: **2.0.1** del 2026-09-09.

---

## Sezione 1 — Cosa cambia per chi usa il programma

### ⭐️ I testi per Google li scrive il gestionale

Nella scheda **Contenuti**, riquadro SEO, c'è un pulsante nuovo: **«Scrivili con l'AI»**. Legge
titolo, sottotitolo, durata, luoghi e descrizione della scheda e propone **meta title** e **meta
description** — i due testi che Google mostra nei risultati di ricerca.

**Perché è stato fatto:** Antonio li scriveva con ChatGPT e li incollava a mano nel gestionale. Il
motore per farlo in casa c'era già tutto — stessa chiave Claude delle traduzioni, stesso registro
dei consumi, stessa soglia di spesa — mancavano un prompt e un pulsante.

Quattro scelte che contano più del pulsante:

| | |
|---|---|
| **Scrive solo in italiano** | Le altre quattro lingue arrivano dalle traduzioni, dove passano per la revisione. Generarle qui salterebbe il controllo che impedisce di pubblicare testi che nessuno ha letto |
| **Le lunghezze sono verificate** | Se la proposta sfora i 60/155 caratteri viene richiesta una volta sola; se sfora ancora si taglia sull'ultima parola intera. I modelli sforano con regolarità |
| **Non può inventare** | Prezzi, date, posti disponibili, difficoltà e servizi che non siano già scritti nella scheda sono vietati dal prompt. Una descrizione inventata finisce in vetrina sui risultati di ricerca |
| **L'indirizzo web non lo tocca** | È l'unico campo che dopo la pubblicazione non si può più cambiare: non è il posto dove mettere una variabile |

⚠️ **È una proposta, non un verdetto.** Se i campi sono già pieni il programma chiede conferma, e
il risultato resta da rileggere e salvare a mano.

💰 **Costo:** intorno a un millesimo di dollaro a tour. Per confronto: la traduzione completa di
una scheda nelle quattro lingue costa circa sette centesimi.

*(Verificato a runtime il 2026-09-14 sulla scheda «EST SARDEGNA IN 4X4»: title 47 caratteri,
description 143, nessun fatto inventato.)*

### Tolte le due «bacchette» dai campi meta

I due pulsantini dentro *meta title* e *meta description* non ci sono più.

**Perché:** non miglioravano niente. Il primo tagliava il titolo a 60 caratteri, cioè produceva lo
**stesso testo** che il sito usa già da sé quando il campo è vuoto; il secondo tagliava la
descrizione a 155 caratteri finendo a metà frase, cioè **peggio** del sottotitolo su cui il sito
ripiega da solo. Resta l'icona ↻ dell'indirizzo web, che è un'altra cosa: lì il valore meccanico è
quello giusto.

---

## Sezione 2 — Correzioni

### `appsettings.Development.json` non viaggia più con il programma

Il file di configurazione **di sviluppo** finiva dentro l'eseguibile consegnato al cliente, pur non
venendo mai letto (il programma lo carica solo in modalità sviluppo). Ora è incluso solo in quella
modalità.

⚠️ **Il debito vero resta aperto** e non è chiuso da questa versione: la chiave dello Storage vive
ancora dentro il programma installato ed è estraibile. Dettagli, rischio e le due strade percorribili
in `Documents/Analisi_e_Design/2026-09-05-Prossime_Funzioni.md`, punto 11.

---

## Sezione 3 — Manuali

I manuali sono cresciuti di **sei capitoli**, tutti scritti rispondendo a domande vere.

| Manuale | Cosa è stato aggiunto |
|---|---|
| **Contenuti web** | La **galleria** (e la copertina senza cui non si pubblica); l'**itinerario** — il programma giorno per giorno non va nella descrizione; la **mappa** da GPX; il **SEO**; la **chiave delle traduzioni**; il **prezzo**, che non sta nella scheda web ma sulla partenza. Da 11 a 17 capitoli |
| **Newsletter** | Le **immagini**: i due archivi, il PNG che resta PNG per le icone, e la trappola delle locandine — il testo dentro l'immagine non viene tradotto |
| **Installazione** | Nessun capitolo nuovo, ma il PDF era fermo al **3 luglio** e non conteneva il capitolo sulla chiave dei segreti: chi lo leggeva non trovava le istruzioni per una cosa senza la quale metà funzioni restano spente |
| **Sistemazioni e iscrizioni** | Il PDF era indietro di tre sotto-sezioni, quelle su come si assegna una camera |

ℹ️ Tutti i PDF sono stati rigenerati e verificati: si è controllato che **nessun titolo del testo
mancasse nel PDF**, invece di fidarsi delle date dei file.

⛔️ Rimosso `Manuale_Installazione_Utente.docx`, fermo al 6 aprile: cinque mesi indietro, e chi lo
apriva per primo non aveva modo di accorgersene.

---

## Sezione 4 — Cose fatte in produzione, che NON stanno in questa versione

Sono state fatte il 14 settembre direttamente su Supabase e sono **già attive**: non arrivano con
l'installer, e non c'è niente da fare dopo averlo installato.

- **Creato il bucket `tour-media`** (pubblico). Era una casella mai spuntata della §2.4 della
  Checklist Go-Live: senza, il caricamento di foto e mappe rispondeva *«Upload immagine fallito
  (400)»*. È emerso solo ora perché Antonio è il primo a caricare media in produzione. Nessuna
  migrazione necessaria: non c'erano immagini da spostare.
- **Chiavi Storage separate** fra sviluppo e produzione, così revocarne una non blocca l'altra.
- **Chiave Claude configurata** sull'azienda 2 da Antonio: le traduzioni funzionano, prima scheda
  già tradotta.

---

## Sezione 5 — Come si consegna

La procedura è in `Scripts/windows/COME_SI_GENERA_L_INSTALLER.md`. Le due trappole già pagate una
volta:

- ⚠️ compilare per **`win10-x64`**, non ARM64: il pacchetto ARM sul PC del cliente **non si avvia**;
- ⛔️ non puntare mai Inno Setup a `C:\GestioneViaggi`, dove c'è il programma **già installato**:
  impacchetterebbe la versione vecchia senza protestare.

Da consegnare: l'installer, i **quattro manuali** (aggiornati a questa versione) e — per altra via —
la `GV_SECRET_KEY`.

ℹ️ **Antonio ha già la chiave dei segreti impostata** e il programma funzionante: per lui questo è
un aggiornamento, non una prima installazione.
