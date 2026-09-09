# Manuale — I contenuti web dei tour

**A chi è rivolto**: chi prepara e pubblica le schede dei tour sul sito. Nessuna conoscenza tecnica richiesta.

> ### 📌 Riferito a **Gestione Viaggi 2.0.1** · manuale aggiornato il **9 settembre 2026**
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
5. [Clonare una scheda da un'altra partenza](#5-clonare-una-scheda-da-unaltra-partenza)
6. [Clonare fra partenze di durata diversa](#6-clonare-fra-partenze-di-durata-diversa)
7. [Le traduzioni](#7-le-traduzioni)
8. [Le verifiche che non bloccano](#8-le-verifiche-che-non-bloccano)
9. [Eliminare una scheda web](#9-eliminare-una-scheda-web)
10. [Eliminare una partenza](#10-eliminare-una-partenza)
11. [Riepilogo in una pagina](#11-riepilogo-in-una-pagina)

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

![Il campo Stato con i tre valori e il punto interrogativo dell'aiuto](img_web_stato)

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
   *revisionate* (capitolo 7).
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

![L'etichetta di stato con il suo suggerimento](img_web_stato_partenza)

---

## 5. Clonare una scheda da un'altra partenza

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

![La finestra di creazione con le due opzioni e la nota su foto e mappe](img_web_clona)

---

## 6. Clonare fra partenze di durata diversa

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

## 7. Le traduzioni

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

## 8. Le verifiche che non bloccano

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

## 9. Eliminare una scheda web

⛔️ **L'eliminazione è irreversibile. Non esiste un cestino.**

**Si può eliminare solo da Bozza o Archiviato.** Una scheda pubblicata va prima tolta dal sito;
se ci provi, il programma lo dice e non procede.

La conferma **elenca cosa stai perdendo**, con i numeri veri di quella scheda: giornate di
itinerario con i loro passaggi, immagini in galleria, mappe caricate da GPX, traduzioni comprese
quelle già revisionate. **Leggi quell'elenco**: è il lavoro editoriale più costoso da rifare.

⚠️ **I file di foto e mappe restano in archivio.** Non è una dimenticanza: possono essere
condivisi con una scheda clonata (capitolo 5), e cancellarli danneggerebbe l'altra. Quello che
va perso davvero sono **testi, ordinamento e revisioni delle traduzioni**.

---

## 10. Eliminare una partenza

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

## 11. Riepilogo in una pagina

| Situazione | Spiegazione |
|---|---|
| Metto «Pubblicato», salvo, torna a «Bozza» | Il controllo è al salvataggio. Il messaggio dice cosa manca (cap. 2) |
| «Archiviato» non sembra fare niente | Per il sito è identico a «Bozza». La differenza è solo editoriale (cap. 1) |
| Il tour è sparito dal sito ma è ancora «Pubblicato» | La partenza è iniziata: il filtro è in lettura, lo stato non cambia (cap. 3) |
| Non riesco a pubblicare, le traduzioni ci sono | Devono essere **revisionate**, non solo tradotte (cap. 2 e 7) |
| «Approva tutte» è spento | Manca il campione: revisionane almeno una per lingua (cap. 7) |
| Ho cancellato una foto e sparisce da due schede | Sono lo stesso file: la scheda è stata clonata (cap. 5) |
| Non riesco a eliminare una partenza | Uno dei quattro blocchi. Il messaggio dice quale (cap. 10) |
| Etichetta arancione sulla partenza | Anomalia fra spunta e calendario: si corregge nella scheda Date (cap. 4) |

### Le tre cose da non fare

1. ⛔️ **Non** eliminare una scheda web senza leggere l'elenco di cosa va perso: non si recupera.
2. ⛔️ **Non** approvare le traduzioni in blocco senza aver controllato un campione per lingua:
   stai dichiarando di averle lette.
3. ⛔️ **Non** clonare fra partenze di durata diversa e pubblicare senza rileggere **l'ultima
   giornata**: descrive una tappa intermedia, non un finale.

---

*📌 Gestione Viaggi **2.0.1** — manuale aggiornato il 9 settembre 2026.*
*Se aggiorni questo manuale, aggiorna anche il numero di versione qui e in testa: serve a sapere
a quale versione del programma le istruzioni si riferiscono davvero.*
