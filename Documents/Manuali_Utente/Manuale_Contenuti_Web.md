# Manuale — I contenuti web dei tour

**A chi è rivolto**: chi prepara e pubblica le schede dei tour sul sito. Nessuna conoscenza tecnica richiesta.

> ### 📌 Riferito a **Gestione Viaggi 2.0.1** · manuale aggiornato il **14 settembre 2026**
>
> ⚠️ **Controlla che il numero corrisponda** a quello che leggi in basso nella barra di stato del
> programma. Se non corrisponde, questo manuale può descrivere schermate diverse da quelle che
> hai davanti: chiedi la versione aggiornata prima di seguirlo.


---

## Perché questo manuale

Il programma decide da solo alcune cose — quando un tour compare sul sito, quando sparisce, cosa
si può cancellare e cosa no. Sono decisioni **corrette**, ma se non ne conosci il motivo
sembrano difetti.

Durante i collaudi sono emerse otto o nove situazioni di questo tipo. Sono tutte qui.

⚠️ **La più frequente in assoluto**: metti «Pubblicato», salvi, e il programma torna a
«Bozza». Non è un guasto — vedi il capitolo 2.

---

## Indice

1. [I tre stati di una scheda](#1-i-tre-stati-di-una-scheda)
2. [Il controllo scatta al salvataggio, non alla scelta](#2-il-controllo-scatta-al-salvataggio-non-alla-scelta)
3. [Il tour sparisce dal sito da solo](#3-il-tour-sparisce-dal-sito-da-solo)
4. [Lo stato della partenza e le sue due anomalie](#4-lo-stato-della-partenza-e-le-sue-due-anomalie)
5. [La galleria: caricare le foto del tour](#5-la-galleria-caricare-le-foto-del-tour)
6. [L'itinerario: giornate e passaggi](#6-litinerario-giornate-e-passaggi)
7. [La mappa: dal GPX all'immagine](#7-la-mappa-dal-gpx-allimmagine)
8. [Il SEO: farsi trovare su Google](#8-il-seo-farsi-trovare-su-google)
9. [Il prezzo, e le altre cose che non stanno nella scheda web](#9-il-prezzo-e-le-altre-cose-che-non-stanno-nella-scheda-web)
10. [Clonare una scheda da un'altra partenza](#10-clonare-una-scheda-da-unaltra-partenza)
11. [Clonare fra partenze di durata diversa](#11-clonare-fra-partenze-di-durata-diversa)
12. [La chiave delle traduzioni: dove si prende e chi la paga](#12-la-chiave-delle-traduzioni-dove-si-prende-e-chi-la-paga)
13. [Le traduzioni](#13-le-traduzioni)
14. [Le verifiche che non bloccano](#14-le-verifiche-che-non-bloccano)
15. [Eliminare una scheda web](#15-eliminare-una-scheda-web)
16. [Eliminare una partenza](#16-eliminare-una-partenza)
17. [Riepilogo in una pagina](#17-riepilogo-in-una-pagina)

---

## 1. I tre stati di una scheda

Nel riquadro **Pubblicazione**, il campo **Stato** ha tre voci:

| Stato | Sul sito | A cosa serve |
|---|---|---|
| **Bozza** | ⛔️ non visibile | Lo stato normale mentre prepari: modifichi tutto senza conseguenze |
| **Pubblicato** | ✅ visibile | Il tour è online |
| **Archiviato** | ⛔️ non visibile | **Per il sito è identico a Bozza** |

⚠️ **«Archiviato» non fa niente di diverso da «Bozza».** Il programma tratta i due stati allo
stesso modo. La differenza è **solo per te**: serve a distinguere ciò che è finito e non va più
toccato da ciò che è ancora in lavorazione.

Chi si aspetta che «archiviato» faccia qualcosa di più — nasconderlo altrove, spostarlo, tenerne
una copia — resta spiazzato. Non fa nulla di tutto questo.

✅ **Tornare a Bozza o Archiviato è sempre possibile**, e toglie il tour dal sito subito.


---

## 2. Il controllo scatta al salvataggio, non alla scelta

> ⚠️ **Questa è la cosa che sembra un difetto e non lo è.**

Scegli «Pubblicato» nel menu a tendina: il programma **non dice niente**. Salvi: lo stato
**torna a «Bozza»** e compare un messaggio che spiega cosa manca.

Non è che il campo non funzioni: il controllo si fa **al salvataggio**, perché solo in quel
momento il programma sa com'è messa tutta la scheda.

### Cosa serve per pubblicare davvero

Servono **due condizioni insieme**:

1. **Tutte le sezioni complete** — le icone in alto devono essere verdi. Comprese le
   **traduzioni revisionate**: ⚠️ non basta che siano tradotte, devono essere state
   *revisionate* (capitolo 13).
2. **Una partenza che deve ancora iniziare**, e non segnata come effettuata. La soglia è la
   data di **inizio**, e dev'essere almeno **il giorno dopo oggi**: pubblicare una partenza che
   parte oggi non serve a nessuno, perché nessuno può più prenotarla.

Se manca qualcosa, il messaggio ti dice **cosa**: leggilo, contiene già la risposta.

---

## 3. Il tour sparisce dal sito da solo

Il giorno in cui la partenza inizia, **il tour smette di comparire sul sito**, anche se lo stato
resta «Pubblicato».

⚠️ **Lo stato che vedi nella scheda non cambia**: continuerà a dire «Pubblicato». Non è una
dimenticanza del programma.

**Perché non c'è un automatismo che lo cambi:** il tempo che passa non produce nessun evento nel
programma. Nessuno "accende" il giorno della partenza. Quindi il filtro si applica **al
momento in cui il sito legge**, non modificando la scheda: il sito guarda la data e, se la
partenza è già cominciata, non la mostra.

Il risultato per chi visita il sito è quello giusto — non vede partenze non più prenotabili — e
tu non devi ricordarti di archiviare niente.

---

## 4. Lo stato della partenza e le sue due anomalie

Accanto alle partenze compare un'etichetta colorata. Nasce incrociando **due** informazioni: la
spunta «Viaggio Effettuato» (scheda Date del viaggio) e la **data di fine**.

| Spunta | Data | Etichetta | Cosa significa |
|---|---|---|---|
| ✅ sì | conclusa | **Partenza effettuata** | ✅ Coerente: viaggio fatto e registrato |
| ⛔️ no | futura | **Partenza da effettuare** | ✅ Coerente: partenza in programma |
| ⛔️ no | conclusa | ⚠️ **Conclusa ma non registrata** | **Anomalia** |
| ✅ sì | futura | ⚠️ **Effettuata ma non ancora conclusa** | **Anomalia** |

### Le due anomalie, e cosa fare

- **«Conclusa ma non registrata»** — la partenza è finita ma nessuno ha spuntato «Viaggio
  Effettuato». O il viaggio è stato fatto e manca l'aggiornamento, oppure era in programma e
  non si è realizzato. Solo tu lo sai.
- **«Effettuata ma non ancora conclusa»** — risulta spuntata, ma la partenza non è ancora
  terminata. Quasi sempre è una spunta messa per errore o in anticipo.

**Dove si corregge, in entrambi i casi:** nella **scheda Date del viaggio**.

⚠️ Il giorno stesso della data di fine il viaggio è considerato **ancora in corso**, non
concluso.


---

## 5. La galleria: caricare le foto del tour

La scheda **Galleria** è la seconda linguetta dei contenuti web. È il solo posto da cui entrano le
foto di un viaggio: quelle che si vedono sul sito, quelle che si agganciano ai passaggi
dell'itinerario e quelle che si possono scegliere nelle newsletter vengono tutte da qui.

### Caricare

1. Pulsante **«Carica immagini»**
2. Seleziona i file — **anche trenta insieme**
3. Aspetta: una finestrella conta *«Caricamento 3 di 12»*

I limiti sono **30 file per volta** e **20 MB l'uno**: una foto più pesante non viene caricata, e
il programma te lo dice con il nome del file.

✅ **Non ridimensionare e non convertire niente a mano.** Il programma porta il lato lungo a
**2000 pixel** e riscrive la foto in un formato più leggero, adatto al sito. Una foto da 8 MB
appena uscita dal telefono va bene così com'è.

ℹ️ **Le foto già caricate vengono saltate.** Se rilanci lo stesso caricamento, quelle con un nome
di file già presente non entrano una seconda volta, e a fine caricamento il programma ti dice
quante ne ha saltate e quali. Non è un errore: è quello che deve succedere.

---

### ⚠️ La copertina, senza la quale non si pubblica

La **stella ⭐** su una foto la elegge a **copertina**: è quella che rappresenta il tour negli
elenchi del sito.

| Situazione | L'icona della scheda Galleria | Si può pubblicare? |
|---|---|---|
| Nessuna foto | 🔴 vuota | ⛔️ no |
| Foto caricate, **nessuna stella** | 🟠 incompleta | ⛔️ no |
| Foto caricate **+ una copertina** | 🟢 completa | ✅ sì |

⚠️ **Caricare le foto non basta.** È l'errore più facile: si caricano venti foto, l'icona resta
arancione e non si capisce perché il tour non si pubblica. Manca la stella.

La copertina è **una sola**: mettere la stella su un'altra foto la sposta, non ne aggiunge una
seconda. In vista Dettaglio sta in cima, grande, con la fascetta **COPERTINA**.

---

### Titolo e testo alternativo

Ogni foto ha due campi, e servono a due cose diverse:

| Campo | A cosa serve |
|---|---|
| **Titolo** | Il testo che compare sul sito passandoci sopra il mouse |
| **Testo alternativo** | Quello che viene letto al posto della foto: dagli screen reader di chi non vede, dai motori di ricerca, e da chiunque abbia le immagini spente |

Si scrivono nella vista **Dettaglio** e **si salvano da soli** appena esci dal campo: non c'è un
pulsante Salva da cercare.

⚠️ **In vista Griglia i due campi non sono modificabili.** La griglia serve a guardare tutte le
foto insieme, non a scriverci: per modificarli torna a **Dettaglio**.

✅ Il riquadro **«Applica a tutte le foto»** compila titolo e testo alternativo di tutte in un
colpo solo — utile quando le foto di un tour raccontano la stessa cosa. ⚠️ **Sovrascrive quello
che c'è già**, quindi usalo prima di rifinire le singole, non dopo.

ℹ️ Finito un caricamento, il programma ricorda quante foto sono rimaste senza titolo e senza testo
alternativo. Non blocca niente: è un promemoria, e va preso come tale.

---

### Eliminare: due casi in cui il programma non lo fa

- 🗑 **Una foto agganciata a un passaggio dell'itinerario non si elimina**: il cestino è spento, e
  il suggerimento dice il perché. Va prima staccata da quel passaggio.
- 🗑 **«Elimina tutte le foto»** toglie tutto, copertina compresa — ⚠️ e senza copertina l'anteprima
  e la pubblicazione non sono più possibili. Le foto usate in un passaggio **restano**: il
  programma le salta e ti dice quante ne ha mantenute.

⛔️ **Se la scheda è stata clonata, la foto che cancelli sparisce anche dall'altra.** Le due schede
non hanno due copie: hanno **lo stesso file**. È la conseguenza della clonazione — vedi il
capitolo 10.

---

### Le immagini che non passano da qui

ℹ️ Le **icone, i loghi e le locandine** usate nelle newsletter **non** vanno caricate nella
galleria di un tour: hanno un posto loro, **Tabelle → Tabelle web → Libreria immagini**. La
separazione serve a non dover scorrere quattrocento fotografie per trovare un'icona. Il
*Manuale — La newsletter* lo spiega al capitolo 4.

---

## 6. L'itinerario: giornate e passaggi

> ### ⛔️ Il programma del viaggio **non** va scritto nella Descrizione
>
> Nella scheda **Contenuti** c'è una sola grande casella, e la tentazione è di infilarci dentro
> tutto: *tappa 1*, *tappa 2*, *tappa 3*… **Non è il posto giusto.** Quella casella è la
> **presentazione** del viaggio — che viaggio è, a chi si rivolge, che tipo di esperienza —, non il
> programma.
>
> Il programma giorno per giorno ha una scheda sua: **Itinerario**, la terza linguetta. E non è una
> questione di ordine: **senza l'itinerario compilato il tour non si pubblica** (§ più sotto).

La scheda è divisa in due colonne: a **sinistra** l'elenco delle **Giornate**, a **destra** il
dettaglio con i **Passaggi** della giornata scelta.

ℹ️ Dentro la scheda c'è un pulsante **«Guida»**: apre la stessa spiegazione, con le icone vere
sotto gli occhi.

| | Cos'è | Cosa contiene |
|---|---|---|
| **Giornata** | Un giorno del viaggio | Un **titolo**, scritto da te — es. *GIORNO 1 : Olbia - Monte Limbara - Tempio* |
| **Passaggio** | Un momento di quella giornata | Un **testo**, una **foto** presa dalla galleria del tour e la sua **didascalia** |

Il titolo della giornata lo decidi tu, **numerazione compresa**: il programma propone
*«GIORNO X :»* e si aspetta che tu completi.

---

### ⚠️ Aggiungere una giornata: il passo che sembra non funzionare

Premendo **«Aggiungi una Giornata»** non compare una riga vuota: si apre **subito la finestra del
primo passaggio**. È voluto — una giornata senza contenuto non ha senso di esistere.

⚠️ **Se a quel punto annulli, non viene creato niente**: né la giornata né il passaggio. Chi si
aspettava la riga vuota pensa che il pulsante sia rotto. Non lo è: bisogna arrivare in fondo alla
finestra e salvare.

---

### Titolo e passaggi sono indivisibili

Sono tre regole che discendono tutte dalla stessa idea — una giornata **è** il suo contenuto:

1. Una giornata **nasce già con il suo primo passaggio**.
2. Eliminando l'**ultimo** passaggio si elimina **l'intera giornata**. Il programma non lo fa di
   nascosto: te lo chiede, nominando la giornata che sta per sparire.
3. Un passaggio **non si sposta** in un'altra giornata. Se hai sbagliato giornata, si riscrive.

---

### Riordinare

| Cosa | Come |
|---|---|
| **Giornate** | Si **trascinano** nell'elenco di sinistra, oppure con le frecce ▲▼ nel dettaglio a destra |
| **Passaggi** | Solo con le frecce ▲▼, e ⚠️ **solo dentro la stessa giornata** |

✅ Il numero progressivo delle giornate **si rifà da solo** dopo ogni spostamento: non devi
rinumerare niente. Il **titolo**, invece, resta quello che hai scritto — se dentro c'è scritto
«GIORNO 3» e la sposti in seconda posizione, il titolo continua a dire 3. Correggilo a mano.

---

### ⚠️ Quante giornate servono per poter pubblicare

Ne serve **una per ogni giorno di durata del viaggio** — il campo *numero giorni* dell'anagrafica.

| Giornate inserite | Semaforo della scheda | Pubblicazione |
|---|---|---|
| Meno del dovuto | 🟠 gialla | ⛔️ bloccata |
| Quante ne servono | 🟢 verde | ✅ possibile |
| **Più** del dovuto | 🟢 verde | ✅ possibile, ma compare un **avviso** fra le verifiche |

✅ **L'anteprima funziona comunque**, anche a itinerario incompleto: puoi guardarti il lavoro a
metà strada senza dover prima finire tutto.

ℹ️ Inserire **più** giornate del previsto è consentito — capita con una giornata opzionale o di
riposo. L'avviso non blocca niente, serve solo a farti notare la differenza nel caso sia una
distrazione (capitolo 14).

---

### Le foto dei passaggi

Si **scelgono**, non si caricano: la striscia di miniature mostra la **galleria di quel tour**. Se
è vuota, si carica prima dalla scheda **Galleria** (capitolo 5).

⚠️ **Una foto usata in un passaggio non si può più eliminare dalla galleria**: il cestino è spento
finché non la stacchi da lì. È la stessa regola vista al capitolo 5, guardata dall'altro lato.

---

### Perché non conviene scrivere tutto in un blocco unico

Anche riuscendo a pubblicare, un programma schiacciato dentro la Descrizione ha due difetti che si
pagano dopo:

1. **Sul sito esce un muro di testo.** Le foto non si intercalano più al racconto: restano tutte
   ammucchiate in galleria, e la pagina perde il ritmo giorno-per-giorno che è il motivo per cui
   uno la legge.
2. **Le traduzioni costano di più, per sempre.** Ogni giornata e ogni passaggio si traduce come
   pezzo a sé: se correggi la tappa 4, si ritraduce **solo la tappa 4**. Un blocco unico da
   seimila caratteri si ritraduce **tutto intero**, in tutte le lingue, ogni volta che ci sposti
   una virgola (capitolo 13).

---

## 7. La mappa: dal GPX all'immagine

✅ **La mappa è l'unica scheda che non blocca mai la pubblicazione.** Il suo semaforo è sempre
verde, anche quando non c'è nessuna mappa. Le mancanze compaiono solo fra le verifiche, come
avvisi (capitolo 14).

Quello che fa è semplice da dire: prendi il **file GPX** — la traccia registrata dal navigatore —
e il programma ne ricava **un'immagine** del percorso. Un disegno, non una mappa da trascinare col
dito: sul sito il cliente vede una figura. Sotto compare la scritta **© OpenStreetMap
contributors**, che è il credito dovuto a chi fornisce le mappe e non si toglie.

---

### ⛔️ Una mappa per giornata, oppure una per l'intero viaggio. Nient'altro.

| Tipo di mappa | Quante se ne possono avere |
|---|---|
| **Intero viaggio** | **Una sola** per edizione |
| **Una giornata** | **Una sola** per giornata dell'itinerario |

⛔️ **Non sono ammessi GPX che coprono mezza giornata, o due giornate e mezzo.** Non è una
limitazione della finestra: è una regola del programma, perché una traccia «da metà del giorno 2 a
metà del giorno 3» non si saprebbe dove mostrarla sul sito.

ℹ️ Le opzioni già occupate compaiono **spente**, con scritto accanto il motivo: *(già presente)*
per l'intero viaggio, e una spiegazione diversa a seconda che l'itinerario sia **vuoto** o abbia
tutte le giornate **già coperte**.

---

### Come si carica

1. Scheda **Mappa** → **«Scegli GPX»**. Si accettano **solo file .gpx**, fino a **20 MB**.
2. ⚠️ **Solo dopo aver scelto il file** compaiono le opzioni di abbinamento. Prima non ci sono, e
   chi le cerca pensa che manchino: c'è una riga che lo dice, ma è facile non vederla.
3. Scegli se la mappa è dell'**intero viaggio** o di **una giornata**. In questo secondo caso la
   tendina elenca **solo le giornate ancora libere**.
4. Scrivi la **Descrizione**: è **obbligatoria**, è il nome che vede il cliente sul sito (es.
   *«Mappa Giorno 1»*), e **viene tradotta** nelle lingue del sito. ⚠️ È una cosa diversa dal nome
   del file GPX, che al cliente non interessa.
5. **«Genera mappa»**, e aspetta qualche secondo: il disegno viene fatto **passando da internet**.

⚠️ **Lo stesso GPX non si carica due volte nella stessa edizione.** Il programma riconosce il
doppione dal nome e dalla dimensione del file e lo rifiuta. È una protezione contro il doppio
caricamento per distrazione, non un dispetto.

---

### I tre pulsanti su una mappa già fatta

| Pulsante | Cosa fa |
|---|---|
| **Modifica** | Cambia **descrizione** e **abbinamento** senza ricaricare il GPX. ✅ Se tocchi solo la descrizione non viene rigenerato niente |
| **Rigenera** | Rifà l'immagine partendo **dallo stesso GPX** già caricato |
| **Elimina** | Toglie la mappa **e il file dell'immagine** |

⚠️ **«Rigenera» serve solo se l'immagine è venuta male o è andata persa.** Ogni rigenerazione è una
richiesta a un servizio esterno: non è gratis e non è istantanea. Non farlo per abitudine, perché
il risultato sarà identico.

---

### ⚠️ Le due trappole

**1. Una giornata che ha una mappa non si elimina.** Il programma blocca l'operazione invece di
far sparire la mappa di nascosto. L'ordine giusto è: prima elimini la mappa, poi la giornata
(capitolo 6).

**2. Dopo una clonazione l'immagine della mappa è lo STESSO file dell'originale**, esattamente
come succede alle foto. Eliminando la mappa su una delle due schede, **l'immagine sparisce anche
dall'altra** (capitolo 10).

ℹ️ Quando si clona verso una partenza **più corta**, le mappe delle giornate che non sono state
copiate vengono semplicemente **saltate**: non diventano una seconda mappa d'insieme, che sarebbe
vietata.

---

### Se compare «Chiave Geoapify non configurata»

Non è un errore tuo e non si risolve nella scheda. Il disegno delle mappe passa da un servizio
esterno, e la sua chiave sta nella **configurazione del programma**: va chiesta a chi ha
installato il gestionale.

ℹ️ Nel frattempo **tutto il resto continua a funzionare**: resta spento solo il pulsante «Genera
mappa». E dato che la mappa non blocca la pubblicazione, il tour può andare online lo stesso.

---

## 8. Il SEO: farsi trovare su Google

In fondo alla scheda **Contenuti** c'è un riquadro intitolato **SEO**. Sono tre campi, e non sono
un di più: è tutto quello che il tuo tour dice a Google di sé.

| Campo | Cos'è | Quanto lungo |
|---|---|---|
| **Indirizzo web (URL)** | L'indirizzo della pagina sul sito — la parte finale, es. `…/tour-dune-gallura` | corto, minuscolo, parole separate da trattini |
| **Meta title** | Il titolo **azzurro** che Google mostra nei risultati, e il nome della scheda nel browser | ~60 caratteri |
| **Meta description** | Le due righe grigie sotto il titolo, nei risultati: servono a far venire voglia di cliccare | ~150 caratteri |

ℹ️ Accanto a ogni campo c'è il **punto interrogativo** con la spiegazione, e dentro il campo
un'**icona a destra** che propone un valore di partenza. Non devi partire dal foglio bianco.

---

### ⛔️ L'indirizzo web non si tocca dopo la pubblicazione

È l'unico dei tre **obbligatorio**: senza, la scheda Contenuti non diventa verde e il tour non si
pubblica.

Ed è anche l'unico **irreversibile nei fatti**. Cambiarlo dopo la pubblicazione significa cambiare
l'indirizzo della pagina, e quindi:

- chi aveva salvato o condiviso il link vecchio **trova una pagina che non esiste**;
- Google **riparte da zero** su quella pagina: la posizione guadagnata è persa.

✅ **Deciderlo bene la prima volta** è l'unico modo di non pagarlo dopo. Corto, in minuscolo, con
le parole che contano: `dalle-dune-alla-gallura` è giusto, `tour-n-3-primavera-2026-definitivo`
no.

⚠️ **Due tour della stessa azienda non possono avere lo stesso indirizzo**, nemmeno se sono due
partenze dello stesso viaggio: il programma rifiuta il salvataggio. Ogni edizione ha il suo.

---

### Se lasci vuoti i due «meta»

Non è un errore e non blocca niente: il sito **ripiega** sul titolo del tour e sul sottotitolo.
Fra le verifiche compare come **suggerimento**, non come problema (capitolo 14).

⚠️ Ma un ripiego è un ripiego: il titolo del tour è scritto per te, non per chi cerca su Google.
Vale la pena compilarli.

---

### Cosa fa davvero il pulsante dei suggerimenti

Le tre icone fanno un lavoro **meccanico**, non intelligente:

| Campo | Cosa propone |
|---|---|
| Indirizzo web | Il titolo del viaggio ridotto: tutto minuscolo, accenti tolti, spazi trasformati in trattini |
| Meta title | Il titolo del viaggio **tagliato a 60 caratteri** |
| Meta description | Le prime ~155 lettere della **descrizione**, ripulite dalla formattazione |

⚠️ **La descrizione tagliata finisce quasi sempre a metà frase.** Va bene come punto di partenza,
non come testo definitivo: rileggilo e riscrivilo perché stia in piedi da solo.

---

### ⭐️ «Scrivili con l'AI»: il pulsante che li scrive davvero

Accanto al titolo **SEO** c'è un secondo pulsante, **«Scrivili con l'AI»**. Non taglia: **legge** i
testi che hai scritto nella scheda — titolo, sottotitolo, durata, luoghi e descrizione — e propone
un meta title e una meta description pensati per chi cerca su Google.

| | Le icone dentro i campi | «Scrivili con l'AI» |
|---|---|---|
| Cosa fa | Taglia il testo alla lunghezza giusta | Scrive un testo nuovo leggendo la scheda |
| Serve la chiave? | ⛔️ no, funziona sempre | ✅ sì, la stessa delle traduzioni (capitolo 12) |
| Costo | nessuno | qualche **millesimo** di euro |

**Come si usa:** compila prima la scheda — descrizione compresa — poi premi il pulsante. Se i due
campi sono già pieni il programma **chiede conferma** prima di sostituirli: un testo scritto a mano
non si butta via di nascosto.

⚠️ **È una proposta, non un verdetto.** I due campi restano modificabili, e il testo entra in scheda
ma **non è ancora salvato**: rileggilo e premi *Salva Contenuti Web*. Se non ti convince, cambia
scheda senza salvare e non è successo niente.

ℹ️ **Scrive solo in italiano**, di proposito. Le altre quattro lingue arrivano dalle traduzioni,
dove passano per la revisione: farle scrivere direttamente qui salterebbe il controllo che
impedisce di pubblicare testi che nessuno ha letto.

✅ **Non inventa.** Il programma gli vieta di aggiungere prezzi, date, posti disponibili, difficoltà
o servizi che non siano già scritti nella scheda. ⚠️ Resta comunque da **rileggere**: è un
suggerimento scritto da una macchina, e finisce in vetrina sui risultati di ricerca.

ℹ️ Se il pulsante è **spento**, passaci sopra il mouse: il suggerimento dice quale delle due cose
manca, la chiave Claude o GV_SECRET_KEY.

---

### ⚠️ Dopo aver clonato una scheda, rileggi sempre questi tre campi

La clonazione (capitolo 10) se la cava da sola con l'indirizzo web: lo compone dallo slug di
partenza più le date della nuova partenza, e se esiste già aggiunge un numero. Il risultato
**funziona**, ma è lungo e brutto — vale la pena riscriverlo finché la scheda è ancora in bozza.

⛔️ **Meta title e meta description invece vengono copiati identici.** Due partenze con lo stesso
titolo e la stessa descrizione sono, per Google, **due pagine doppione**: ne mostra una sola e
decide lui quale. Se le due edizioni hanno qualcosa che le distingue — la stagione, le date, un
tratto diverso — deve comparire lì dentro.

---

### Scrivere i testi con un assistente (ChatGPT e simili)

Si può, ed è un uso sensato. Tre regole perché serva a qualcosa:

1. ✅ **Chiedi esattamente i due formati**: un meta title entro 60 caratteri e una meta description
   intorno ai 150. Senza il vincolo di lunghezza escono testi che Google taglia a metà.
2. ⛔️ **Incollali nei due campi**, non in mezzo alla descrizione. Fuori da quei campi non fanno
   SEO: sono solo altre righe di testo.
3. ⚠️ **Falli rileggere a chi il viaggio l'ha fatto davvero.** Nomi di località, distanze,
   difficoltà, durata delle tappe: su questo un assistente inventa con grande scioltezza, e
   l'errore finisce in vetrina su Google.

⚠️ **Non gonfiare i testi «per il SEO».** Ogni parola in più va tradotta in tutte le lingue, e
ritradotta a ogni correzione: un testo lungo il doppio costa il doppio, per sempre (capitolo 13).

ℹ️ **Anche meta title e meta description si traducono**, come gli altri testi della scheda: chi
cerca in tedesco vede il meta title tedesco. Il che significa che vanno **revisionati** come tutto
il resto prima di poter pubblicare.

---

## 9. Il prezzo, e le altre cose che non stanno nella scheda web

⛔️ **Nella scheda dei contenuti web non esiste nessun campo prezzo.** Cercarlo è tempo perso: il
prezzo che si legge sul sito non è stato scritto lì, e da lì non si può cambiare.

### Il prezzo lo calcola il programma, e ne mostra **uno solo**

Sul sito compare una cifra sola, nella forma **«da 890 €»**. È il **prezzo più basso fra le sei
tariffe di quella partenza**:

- costo pilota
- costo passeggero
- costo passeggero in auto/guida
- costo bambino 0-2
- costo bambino 2-6
- costo bambino 6-12

Le tariffe **lasciate vuote o a zero vengono ignorate**: una casella non compilata non fa
sprofondare il prezzo a zero.

> ### ⚠️ La cosa da controllare prima di pubblicare
>
> Il «da» è un **minimo**, e il minimo è quasi sempre una **tariffa bambino**. Se su una partenza
> compili il costo bambino 0-2 a 150 €, il sito annuncia **«da 150 €»** anche se il pilota ne paga
> 1.900. Non è un errore del programma: è esattamente quello che gli hai chiesto.
>
> ✅ Prima di pubblicare, guarda le sei tariffe della data e chiediti quale di quelle vuoi vedere
> in vetrina.

### Il prezzo è della **partenza**, non del viaggio

Due date dello stesso tour con tariffe diverse mostrano sul sito **due prezzi diversi**. È voluto:
la stessa traversata a giugno e a ottobre non costa uguale.

✅ **Si cambia in «Anagrafica Viaggi e Date», sulla singola data.** Nei contenuti web non c'è
niente da toccare e **niente da ripubblicare**: il sito legge la tariffa nel momento in cui
qualcuno apre la pagina, esattamente come fa con le date di partenza (capitolo 3).

ℹ️ **Al sito arriva solo il «da».** La griglia completa delle sei tariffe non esce mai dal
gestionale: chi guarda il sito non può ricostruire quanto paga un passeggero o un bambino.

---

### Le altre cose che vengono da fuori

La scheda web è meno di quello che sembra. Buona parte di ciò che si vede sul sito arriva
dall'anagrafica, non da lì:

| Cosa si vede sul sito | Da dove arriva | Dove si cambia |
|---|---|---|
| **Titolo** del tour | La descrizione breve del **viaggio** | Anagrafica Viaggi e Date → il viaggio |
| **Difficoltà** | Il **viaggio** | Anagrafica Viaggi e Date → il viaggio |
| **Numero di giorni** | Il **viaggio** | Anagrafica Viaggi e Date → il viaggio |
| **Incluso / Escluso** | Il **viaggio** (e si traducono come ogni altro testo) | Anagrafica Viaggi e Date → il viaggio |
| **«SOLD OUT»** e **«Rimangono solo N posti»** | Capienza e soglia di allerta del **viaggio**, meno i mezzi già occupati su quella data | Anagrafica Viaggi e Date → il viaggio |
| **Date** di partenza e rientro | La **data** | Anagrafica Viaggi e Date → la data |
| **Prezzo «da»** | Le tariffe della **data** | Anagrafica Viaggi e Date → la data |
| Sezione **«tour giornalieri»** | Una spunta sul **tipo** di viaggio | Tabelle → tipi di viaggio |

⚠️ **Guarda la colonna di mezzo, dice più di quanto sembra.** Quello che arriva dal **viaggio**
cambia **su tutte le partenze insieme**: correggi l'«Incluso» una volta e si aggiorna ovunque,
anche sulle edizioni già pubblicate. Quello che arriva dalla **data** — prezzo e date — riguarda
**solo quella partenza**.

### Cosa sta davvero nella scheda web

Solo questo: **sottotitolo**, **descrizione**, **durata a parole**, le informazioni su
**pernottamento, pasti, equipaggiamento e altro**, i **testi per i motori di ricerca**, le
**foto**, l'**itinerario** e la **mappa**. Tutto il resto viene da fuori — ed è il motivo per cui
una scheda web non va tenuta allineata a mano: si allinea da sola.

---

## 10. Clonare una scheda da un'altra partenza

Quando crei la scheda di una partenza, il programma chiede se partire da zero o **clonare** da
un'altra partenza dello stesso viaggio.

⚠️ **Se c'è qualcosa da copiare, il clone è già selezionato**: è quasi sempre quello che vuoi —
stesso viaggio, cambiano solo le date. Resta comunque una scelta.

### Cosa viene copiato

✅ Testi, itinerario con i suoi passaggi, foto, mappe, e **le traduzioni già approvate**.

### Tre cose da sapere

1. **La copia nasce sempre in «Bozza»**, e resta modificabile. Non finisce sul sito da sola.
2. ⚠️ **Foto e mappe restano gli STESSI file dell'originale.** Non ne viene fatta una copia: se
   elimini un'immagine dalla partenza di origine, **sparisce anche dalla copia**.
3. Se nessun'altra partenza di quel viaggio ha una scheda, l'opzione è spenta e il programma lo
   dice.


---

## 11. Clonare fra partenze di durata diversa

Può succedere che le due partenze abbiano **un numero di giorni diverso**, pur essendo lo stesso
viaggio: basta che qualcuno abbia cambiato la durata in anagrafica dopo aver creato le partenze.
Le partenze già esistenti mantengono la loro.

Il programma se ne accorge e **chiede**, prima di procedere.

### Se la partenza di destinazione è più CORTA

Vengono copiate solo le giornate che ci stanno; le ultime si perdono, **insieme alle mappe
abbinate**.

⛔️ **Serve poi una verifica manuale, e il programma te lo ripete anche dopo.** L'ultima giornata
copiata descrive **una tappa intermedia, non una conclusione**: in un viaggio più corto il
finale cambia (si rientra al punto di partenza? ci si ferma dove si è arrivati?) e va riscritto
a mano. Non è una decisione che un programma possa prendere.

### Se la partenza di destinazione è più LUNGA

Viene copiato tutto quello che c'è, e **restano delle giornate da scrivere a mano**. Il
programma dice quante.

---

## 12. La chiave delle traduzioni: dove si prende e chi la paga

> ### ⛔️ Senza questa chiave non si pubblica **nessun** tour
>
> Non è un accessorio per chi vuole il sito in tedesco. Le traduzioni devono risultare
> **revisionate** perché una scheda si possa pubblicare (capitolo 13), e senza chiave non c'è
> traduzione da revisionare: il semaforo resta giallo e la pubblicazione è bloccata, per quanto
> bene tu abbia compilato tutto il resto.

### ⚠️ Tre chiavi diverse, e non c'entrano una con l'altra

È il punto in cui ci si confonde, perché si chiamano tutte «chiave»:

| Quale | Dove sta | A cosa serve |
|---|---|---|
| **GV_SECRET_KEY** | Nelle variabili d'ambiente di **Windows** | Non traduce niente: apre i dati riservati conservati cifrati. Vedi il *Manuale di Installazione*, cap. 7 |
| **Chiave Claude (Anthropic)** | **Dentro il programma**, in Anagrafica Azienda | Traduce i contenuti web. È questa | 
| Chiave dello **storage** | Nella configurazione del programma | Foto e mappe. Non la si tocca mai |

⚠️ **La prima serve alla seconda.** La chiave Claude viene conservata **cifrata** nel database, e
la cifratura usa GV_SECRET_KEY: se manca, il programma non riesce **né a salvarla né a rileggerla**
e nella scheda compare l'avviso *«Master key dei segreti non disponibile»*. L'ordine è: prima la
variabile d'ambiente, poi la chiave Claude.

---

### Dove si prende

Si crea sulla **console di Anthropic** (`console.anthropic.com`), con **l'account dell'azienda** e
**la sua carta**. Non è una chiave che arriva insieme al programma: la traduzione automatica è un
servizio a consumo, e **lo paga chi possiede la chiave**.

⚠️ **Anthropic mostra la chiave in chiaro una volta sola**, al momento in cui la crea. Copiala e
mettila da parte subito: dopo, dalla console, si vede che esiste ma non si rilegge più.

### Dove si incolla

Due strade, stesso identico campo — è indifferente quale usi:

- **Anagrafica Azienda → scheda Traduzioni** ⭐️ (qui c'è anche la spesa e la soglia)
- la scheda **Traduzioni** di un tour qualsiasi

Incolli e premi **Salva**. Sotto il campo deve comparire **«Chiave configurata»** in verde. Se
leggi *«Nessuna chiave: traduzione automatica non disponibile»*, non è stata salvata.

ℹ️ Quando è già configurata il campo mostra dei **pallini**: la chiave non si rilegge nemmeno da
qui. Per sostituirla se ne incolla una nuova sopra; **Rimuovi** la cancella.

---

### ✅ Si fa una volta sola, e non è «sul computer»

La chiave **sta nel database**, non nel PC. Due conseguenze pratiche:

- Se domani il programma viene installato su un **secondo computer**, lì non c'è niente da
  rifare: la chiave è già dove serve.
- ⚠️ Ma quel secondo computer deve avere **la stessa identica GV_SECRET_KEY**, altrimenti da lì la
  chiave risulta illeggibile. È la stessa regola delle tre avvertenze del manuale di
  installazione, vista dall'altro lato.

---

### Quanto costa

| | |
|---|---|
| Modello usato | Claude Haiku 4.5, il più economico adatto al lavoro |
| Costo indicativo | circa **$0,30** per un tour intero — una ventina di campi per quattro lingue |
| Come si controlla | **Azienda → Traduzioni**: spesa registrata e **soglia** con avviso al 90% |

⚠️ **Il credito residuo non si può vedere.** Anthropic non lo espone, quindi il gestionale mostra
solo **quanto ha speso lui**: se la stessa chiave viene usata anche altrove, quel consumo non
compare e la stima resta ottimistica. Il saldo vero si guarda sulla console Anthropic.

⛔️ **Se il credito finisce, le traduzioni smettono di funzionare** — e con esse la possibilità di
pubblicare nuove schede. Vale la pena impostare la soglia il giorno stesso in cui si mette la
chiave, non il giorno in cui serve.

---

### Come si verifica che sia tutto a posto

Apri un tour qualsiasi → scheda **Traduzioni**: se il pulsante **«Traduci mancanti (EN/DE/FR/ES)»**
è **attivo**, la chiave c'è e funziona. Se è spento, manca la chiave oppure manca GV_SECRET_KEY —
e l'avviso in cima alla scheda dice quale dei due.

---

## 13. Le traduzioni

Le lingue sono quattro: **EN / DE / FR / ES**.

### Perché la revisione è obbligatoria per pubblicare

Una traduzione automatica non revisionata è testo che nessuno ha letto. Finirebbe sul sito così
com'è, sotto il nome dell'azienda. Per questo la scheda non si può pubblicare finché le
traduzioni non risultano **revisionate**.

### I due pulsanti, e cosa fanno davvero

| Pulsante | Cosa fa |
|---|---|
| **Traduci mancanti (EN/DE/FR/ES)** | Traduce solo ciò che **manca o è diventato obsoleto** |
| **Approva tutte** | Marca revisionate le traduzioni rimanenti, **senza toccarne il testo** |

⚠️ **«Traduci mancanti» non ritraduce quello che c'è già**, ed è voluto: ritradurre azzererebbe
la spunta «revisionato» e butterebbe via il lavoro di revisione già fatto.

### «Approva tutte» ha una condizione

Controllare a mano ottanta traduzioni non è realistico: si verifica un campione e si approva il
resto. Ma il campione deve coprire **ogni lingua**: finché non hai revisionato almeno una
traduzione per ciascuna, il pulsante resta spento e il programma ti dice quali lingue mancano.

⚠️ La conferma dice chiaramente cosa stai dichiarando: *«Dichiari di averle controllate a
campione e di assumertene la responsabilità: finiranno sul sito così come sono.»*

### Le traduzioni costano

La traduzione automatica è **a consumo**, con la chiave dell'azienda.

- In **Azienda → Traduzioni** trovi la spesa registrata e puoi impostare una **soglia di spesa**,
  con avviso al 90%.
- ⚠️ È una **stima** calcolata sui consumi registrati **da questo gestionale**: se la stessa
  chiave viene usata altrove, quel consumo non compare e la stima resta ottimistica.
- L'avviso di soglia parte **una volta sola**: per riaverlo dopo una ricarica, si riavvia il
  conteggio (lo storico non viene cancellato).
- Senza chiave configurata, la traduzione automatica semplicemente non è disponibile.

---

## 14. Le verifiche che non bloccano

Oltre ai controlli che impediscono di pubblicare, ce n'è un secondo gruppo: **promemoria**.
Giornate senza foto, giornate senza mappa, «incluso/escluso» non compilati.

✅ **Non sono errori e non impediscono di pubblicare.** Le trovi sempre visibili, dal chip in
alto: cliccandolo si apre l'elenco.

⚠️ Al momento di pubblicare, se ce ne sono, il programma **te le mostra comunque** con due
pulsanti:

- **Torna e correggi**
- **Pubblica lo stesso**

Non è un blocco: serve solo a farti **vedere** le segnalazioni prima che il contenuto finisca
sul sito. Il messaggio lo dice: *«Il tour è pubblicabile, ma queste cose sembrano dimenticate.
Nessuna è obbligatoria.»*

---

## 15. Eliminare una scheda web

⛔️ **L'eliminazione è irreversibile. Non esiste un cestino.**

**Si può eliminare solo da Bozza o Archiviato.** Una scheda pubblicata va prima tolta dal sito;
se ci provi, il programma lo dice e non procede.

La conferma **elenca cosa stai perdendo**, con i numeri veri di quella scheda: giornate di
itinerario con i loro passaggi, immagini in galleria, mappe caricate da GPX, traduzioni comprese
quelle già revisionate. **Leggi quell'elenco**: è il lavoro editoriale più costoso da rifare.

⚠️ **I file di foto e mappe restano in archivio.** Non è una dimenticanza: possono essere
condivisi con una scheda clonata (capitolo 10), e cancellarli danneggerebbe l'altra. Quello che
va perso davvero sono **testi, ordinamento e revisioni delle traduzioni**.

---

## 16. Eliminare una partenza

> ### **Lo storico non si cancella.**

Il programma controlla **quattro cose, in quest'ordine**, e si ferma alla prima che non va:

1. **È segnata come effettuata?** → rifiutato: fa parte dello storico aziendale.
2. **È già iniziata?** → rifiutato: si può eliminare solo una partenza che deve ancora iniziare.
3. **Ha una scheda di contenuti web?** → rifiutato, e il messaggio dice **in che stato è**: se è
   pubblicata va prima riportata a bozza, poi eliminata la scheda.
4. **Ha prenotazioni o camere assegnate?** → rifiutato, con il conto di quanti clienti e quanti
   alloggi.

⚠️ **Una data inserita per sbaglio nel passato non si può eliminare** (blocco 2): prima si
**corregge** la data portandola nel futuro, poi si elimina.

---

## 17. Riepilogo in una pagina

| Situazione | Spiegazione |
|---|---|
| Metto «Pubblicato», salvo, torna a «Bozza» | Il controllo è al salvataggio. Il messaggio dice cosa manca (cap. 2) |
| Ho caricato le foto ma non riesco a pubblicare | Manca la **copertina**: metti la stella su una foto (cap. 5) |
| Non so dove scrivere il programma giorno per giorno | Nella scheda **Itinerario**, mai nella Descrizione (cap. 6) |
| Il semaforo dell'Itinerario resta giallo | Mancano giornate: ne serve una per ogni giorno di durata (cap. 6) |
| Il pulsante «Traduci mancanti» è spento | Manca la chiave Anthropic in Anagrafica Azienda, o manca GV_SECRET_KEY (cap. 12) |
| «Genera mappa» è spento | Manca la chiave del servizio mappe nella configurazione del programma (cap. 7) |
| Non riesco a eliminare una giornata | Ha una mappa abbinata: elimina prima la mappa (cap. 7) |
| Google mostra un titolo diverso da quello che ho scritto | Meta title vuoto: il sito ripiega sul titolo del tour (cap. 8) |
| Ho cambiato l'indirizzo web e i vecchi link non funzionano più | Lo slug non si tocca dopo la pubblicazione (cap. 8) |
| Il sito mostra un prezzo più basso di quello che mi aspettavo | È il **minimo** delle sei tariffe della partenza, di solito una bambino (cap. 9) |
| Non trovo dove si scrive il prezzo nella scheda web | Non c'è: sta sulla **data**, in Anagrafica Viaggi e Date (cap. 9) |
| «Archiviato» non sembra fare niente | Per il sito è identico a «Bozza». La differenza è solo editoriale (cap. 1) |
| Il tour è sparito dal sito ma è ancora «Pubblicato» | La partenza è iniziata: il filtro è in lettura, lo stato non cambia (cap. 3) |
| Non riesco a pubblicare, le traduzioni ci sono | Devono essere **revisionate**, non solo tradotte (cap. 2 e 13) |
| «Approva tutte» è spento | Manca il campione: revisionane almeno una per lingua (cap. 13) |
| Ho cancellato una foto e sparisce da due schede | Sono lo stesso file: la scheda è stata clonata (cap. 10) |
| Non riesco a eliminare una partenza | Uno dei quattro blocchi. Il messaggio dice quale (cap. 16) |
| Etichetta arancione sulla partenza | Anomalia fra spunta e calendario: si corregge nella scheda Date (cap. 4) |

### Le tre cose da non fare

1. ⛔️ **Non** eliminare una scheda web senza leggere l'elenco di cosa va perso: non si recupera.
2. ⛔️ **Non** approvare le traduzioni in blocco senza aver controllato un campione per lingua:
   stai dichiarando di averle lette.
3. ⛔️ **Non** clonare fra partenze di durata diversa e pubblicare senza rileggere **l'ultima
   giornata**: descrive una tappa intermedia, non un finale.

---

*📌 Gestione Viaggi **2.0.1** — manuale aggiornato il 14 settembre 2026.*
*Se aggiorni questo manuale, aggiorna anche il numero di versione qui e in testa: serve a sapere
a quale versione del programma le istruzioni si riferiscono davvero.*
