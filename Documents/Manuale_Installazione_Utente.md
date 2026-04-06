# Manuale di Installazione — Gestione Viaggi per Windows

**Versione**: 1.25
**Ultimo aggiornamento**: Aprile 2026
**A chi è rivolto**: Utenti finali — nessuna conoscenza tecnica richiesta

---

## Indice

1. [Prima di iniziare — Verifica i requisiti del tuo PC](#1-prima-di-iniziare--verifica-i-requisiti-del-tuo-pc)
2. [Passo 1 — Controlla la tua email](#2-passo-1--controlla-la-tua-email)
3. [Passo 2 — Scarica il file da WeTransfer](#3-passo-2--scarica-il-file-da-wetransfer)
4. [Passo 3 — Avvia l'installazione](#4-passo-3--avvia-linstallazione)
5. [Passo 4 — Segui il wizard di installazione](#5-passo-4--segui-il-wizard-di-installazione)
6. [Passo 5 — Primo avvio e accesso](#6-passo-5--primo-avvio-e-accesso)
8. [Portale Web Iscrizioni](#8-portale-web-iscrizioni)
9. [Risoluzione Problemi](#9-risoluzione-problemi)

---

## 1. Prima di iniziare — Verifica i requisiti del tuo PC

Prima di installare il programma, controlla che il tuo computer soddisfi i requisiti minimi.
**Non preoccuparti: ti spieghiamo come verificarlo passo dopo passo.**

---

### ✅ Verifica 1 — Versione di Windows

Il programma richiede **Windows 10 aggiornato** (versione maggio 2020 o successiva) oppure **Windows 11**.

**Come verificarlo:**

1. Premi i tasti **Windows** + **R** sulla tastiera contemporaneamente
   *(il tasto Windows è quello con il simbolo della bandiera di Windows, di solito in basso a sinistra)*
2. Si apre una piccola finestra. Digita `winver` e premi **Invio**
3. Appare una finestra con la versione di Windows installata

**Cosa cercare:**

| Quello che vedi | È compatibile? |
|-----------------|---------------|
| Windows 11 (qualsiasi versione) | ✅ Sì |
| Windows 10, versione 21H1 o successiva | ✅ Sì |
| Windows 10, versione 2004 o successiva | ✅ Sì |
| Windows 10, versione 1909 o precedente | ❌ No — aggiornare Windows prima di procedere |
| Windows 8 o Windows 7 | ❌ No — non supportato |

> 💡 Se non sei sicuro, guarda il numero di build tra parentesi: deve essere **19041 o superiore**.

---

### ✅ Verifica 2 — Memoria RAM disponibile

Il programma richiede almeno **4 GB di RAM** (8 GB consigliati).

**Come verificarlo:**

1. Premi i tasti **Ctrl** + **Shift** + **Esc** contemporaneamente
   *(si apre il Task Manager — il "pannello di controllo" del PC)*
2. Se vedi una finestra piccola con pochi dettagli, clicca su **"Più dettagli"** in basso
3. Clicca sulla scheda **"Prestazioni"**
4. Clicca su **"Memoria"** nel pannello di sinistra
5. In alto a destra vedi la memoria totale, ad esempio **"8,0 GB"**

> ✅ Se il numero è 4 GB o superiore, sei a posto.

---

### ✅ Verifica 3 — Spazio libero sul disco

Il programma occupa circa **500 MB** sul disco C:.

**Come verificarlo:**

1. Apri **Esplora file** (la cartella gialla nella barra delle applicazioni)
2. Clicca su **"Questo PC"** nel pannello di sinistra
3. Sotto **"Dispositivi e unità"** vedi il disco **C:** con una barra colorata
4. Guarda quanto spazio è indicato come libero

> ✅ Se hai almeno **1 GB libero** sul disco C:, sei a posto.

---

### ✅ Verifica 4 — Connessione internet

Il programma richiede una connessione internet attiva per funzionare (si connette al database online).

**Come verificarla:** Se stai leggendo questo documento online, la connessione funziona! 😊

---

## 2. Passo 1 — Controlla la tua email

Hai ricevuto un'email con un link di **WeTransfer** per scaricare il programma di installazione.

1. Apri la tua casella email
2. Cerca un'email con oggetto simile a **"Gestione Viaggi"** o proveniente dall'amministratore di sistema
3. Nell'email trovi un pulsante o link blu per scaricare il file

> ⚠️ **Il link WeTransfer scade dopo 3 giorni** dalla ricezione. Se è scaduto, contatta l'amministratore per ricevere un nuovo link.

> ⚠️ **Controlla anche la cartella Spam** (posta indesiderata) se non trovi l'email nella posta in arrivo.

---

## 3. Passo 2 — Scarica il file da WeTransfer

1. Clicca sul link nell'email — si apre il sito WeTransfer nel tuo browser
2. Clicca sul pulsante verde **"Download"** (o **"Scarica"**)
3. Se ti viene chiesto dove salvare il file, scegli la cartella **Download** (è la scelta predefinita, va benissimo)
4. Attendi che il download completi

   Nella barra in basso del browser vedrai l'avanzamento del download.

5. Al termine trovi **un solo file** nella cartella Download, chiamato **`GestioneViaggi_Setup_1.25.exe`**

> ✅ **Ricevi un unico file `.exe`** — non una cartella, non uno ZIP. È sufficiente questo file per installare tutto il programma.

> 💡 Per aprire la cartella Download, clicca sulla cartella gialla nella barra delle applicazioni, poi su **"Download"** nel pannello di sinistra.

---

## 4. Passo 3 — Avvia l'installazione

1. Vai nella cartella **Download**
2. Trova il file **`GestioneViaggi_Setup_1.25.exe`** (ha un'icona con uno schermo o un ingranaggio)
3. Fai **doppio clic** su questo file per avviare l'installazione

### ⚠️ Avviso di Windows SmartScreen — cosa fare

È molto probabile che Windows mostri un avviso di sicurezza simile a questo:

> *"Windows ha protetto il PC — Microsoft Defender SmartScreen ha impedito l'avvio di un'app non riconosciuta..."*

**Non preoccuparti: questo è normale** per i programmi nuovi non ancora "conosciuti" da Microsoft. Il programma è sicuro.

**Ecco cosa fare:**

1. Clicca su **"Altre informazioni"** (il testo blu/grigio in piccolo)

   ![Altre informazioni](img_placeholder)

2. Appare il pulsante **"Esegui comunque"** — clicca su di esso

   ![Esegui comunque](img_placeholder)

3. L'installazione parte normalmente

> 💡 Se invece compare una finestra **"Controllo account utente"** che chiede *"Vuoi consentire a questa app di apportare modifiche al dispositivo?"*, clicca **"Sì"**. È necessario per installare il programma.

---

## 5. Passo 4 — Segui il wizard di installazione

Una volta avviato il programma di installazione, appare una serie di schermate guidate (il "wizard"). Seguile nell'ordine:

### Schermata 1 — Benvenuto
Clicca **"Avanti"** (o **"Next"**) per iniziare.

### Schermata 2 — Cartella di installazione
Qui ti viene chiesto dove installare il programma.

> ⚠️ **IMPORTANTE**: **Non modificare** la cartella proposta.
> La cartella di default è `C:\GestioneViaggi\` — deve rimanere così.
> Se la cambi in `C:\Programmi\` o `C:\Program Files\` il programma **non funzionerà** (schermata nera all'avvio).

Lascia la cartella com'è e clicca **"Avanti"**.

### Schermata 3 — Icona sul Desktop
Ti viene chiesto se vuoi creare un'icona sul desktop. La casella è già spuntata di default — lasciala così e clicca **"Avanti"**.

### Schermata 4 — Pronto per l'installazione
Clicca **"Installa"** per avviare la copia dei file.

### Installazione in corso
Vedrai una barra di avanzamento. Attendi senza chiudere la finestra.

> 💡 Se durante l'installazione compare una finestra per **installare WebView2**, clicca **"Installa"** e attendi. WebView2 è un componente Microsoft necessario per il funzionamento del programma — è gratuito e sicuro.

### Schermata finale — Completato
Clicca **"Fine"**. Il programma si avvia automaticamente.

---

## 6. Passo 5 — Primo avvio e accesso

Al primo avvio appare la schermata di login.

1. Inserisci il **nome utente** fornito dall'amministratore di sistema
2. Inserisci la **password** fornita dall'amministratore di sistema
3. Clicca **"Accedi"**

> 💡 Le stesse credenziali funzionano anche sulla versione Mac se la utilizzi.

> 💡 I **documenti PDF** generati dal programma (preventivi, fatture, ecc.) vengono salvati automaticamente nella cartella `C:\Users\TuoNome\Downloads\` — la stessa cartella dove scarichi i file da internet. Per aprirli è necessario **Adobe Reader** oppure **joPDF**.

**Installazione completata! 🎉** Il programma è ora pronto all'uso.

---

## 8. Portale Web Iscrizioni

Oltre al programma installato sul PC, esiste anche un **portale web** dove i tuoi clienti possono compilare il modulo di iscrizione direttamente da browser — senza installare nulla.

### Indirizzo del portale (Azienda Sardegna Fuori Traccia)

👉 **https://iscrizioni.sardegnafuoritraccia.it/2-976f2734/**

Questo indirizzo funziona su qualsiasi browser (Chrome, Edge, Firefox, Safari) e da qualsiasi dispositivo: PC, tablet, smartphone.

---

### ⚠️ Se il tuo sito web ha un bottone che rimanda alle iscrizioni

Molti siti aziendali hanno un pulsante del tipo **"Iscriviti"**, **"Prenota"** o **"Compila il modulo"** che porta direttamente alla pagina di iscrizione.

Se quel pulsante rimandava a un vecchio indirizzo, **deve essere aggiornato** con il nuovo link indicato sopra.

**Cosa fare:**

**Se gestisci il sito web in autonomia** (hai accesso al pannello di amministrazione del sito):
1. Accedi al pannello del tuo sito (WordPress, Wix, Squarespace, ecc.)
2. Trova il pulsante o il link che porta alle iscrizioni
3. Sostituisci il vecchio indirizzo con il nuovo:
   ```
   https://iscrizioni.sardegnafuoritraccia.it/2-976f2734/
   ```
4. Salva le modifiche e verifica che il link funzioni correttamente

**Se il sito è gestito da un webmaster o agenzia web:**
Contatta il tuo webmaster **con urgenza** e forniscigli queste informazioni:

> *"Devo aggiornare il link al modulo di iscrizione sul sito. Il nuovo indirizzo è:*
> *https://iscrizioni.sardegnafuoritraccia.it/2-976f2734/*
> *Puoi aggiornarlo il prima possibile?"*

> ⚠️ Finché il link non viene aggiornato, i clienti che cliccano sul vecchio pulsante potrebbero arrivare su una pagina errata o inesistente — le nuove iscrizioni andrebbero perse.

---

## 9. Risoluzione Problemi

### ❓ Non trovo l'email di WeTransfer

- Controlla la cartella **Spam** o **Posta indesiderata** della tua email
- Il link scade dopo 3 giorni — se è passato più tempo, contatta l'amministratore

---

### ❓ Il download da WeTransfer è molto lento o si interrompe

- Prova a riavviare il download cliccando di nuovo sul link nell'email
- Assicurati di avere una connessione stabile (evita il Wi-Fi se possibile, usa il cavo di rete)
- Se il download si interrompe continuamente, contatta l'amministratore per ricevere il file in altro modo

---

### ❓ Windows mi dice "Windows ha protetto il PC" e non trovo "Esegui comunque"

Alcuni PC con impostazioni di sicurezza molto restrittive potrebbero bloccare completamente il programma.

**Soluzione:**
1. Nella stessa finestra di avviso, clicca su **"Altre informazioni"**
2. Se ancora non compare "Esegui comunque", prova a fare clic destro sul file `.exe` → **"Proprietà"**
3. In fondo alla scheda **"Generale"** cerca la voce **"Sblocca"** e metti la spunta
4. Clicca **"OK"** e riprova ad aprire il file

Se il problema persiste, contatta l'amministratore di sistema.

---

### ❓ Schermata nera o bianca all'avvio del programma

**Causa più comune**: il programma è stato installato in una cartella sbagliata (con spazi nel percorso).

**Verifica:**
1. Vai in `C:\` (il disco principale)
2. Controlla che esista la cartella `C:\GestioneViaggi\`
3. Se invece trovi il programma in `C:\Program Files\` o `C:\Programmi\`, disinstallalo e reinstallalo scegliendo la cartella corretta `C:\GestioneViaggi\`

**Come disinstallare:**
1. Clicca sul menu **Start** → **Impostazioni** (ingranaggio) → **App**
2. Cerca **"GestioneViaggi"** nell'elenco
3. Cliccaci sopra → **"Disinstalla"**
4. Poi reinstalla seguendo questo manuale dall'inizio

---

### ❓ Errore di connessione al database all'avvio

Il programma richiede internet per funzionare. Se compare un errore di connessione:

1. Verifica di essere connesso a internet (apri un sito qualsiasi nel browser)
2. Se sei in **ufficio o in azienda**, la rete potrebbe bloccare alcune connessioni. Chiedi al responsabile IT di aprire la **porta 6543** verso Supabase, oppure prova con un hotspot del telefono per verificare se il problema è la rete aziendale
3. Se la connessione funziona con l'hotspot ma non con la rete aziendale, contatta l'amministratore di sistema

---

### ❓ I PDF generati non si aprono

Il programma crea i PDF nella cartella Download, ma per aprirli serve un lettore PDF dedicato.

**Lettori consigliati:**
- **Adobe Reader** — scaricabile gratuitamente da [adobe.com/acrobat/pdf-reader](https://www.adobe.com/acrobat/pdf-reader.html)
- **joPDF** — scaricabile gratuitamente da [jo.my/jopdf](https://jo.my/jopdf)

**Soluzione:**
1. Installa uno dei lettori consigliati qui sopra
2. Vai nella cartella Download e fai doppio clic sul file PDF — si aprirà automaticamente con il lettore installato
3. Se si apre con il programma sbagliato: clic destro sul file → **"Apri con"** → scegli Adobe Reader o joPDF

---

### ❓ Il programma non si avvia dopo l'installazione

- Prova a riavviare il PC e poi ad aprire il programma dall'icona sul desktop
- Verifica che Windows sia aggiornato: Start → Impostazioni → Windows Update → Verifica aggiornamenti
- Se il problema persiste, contatta l'amministratore di sistema

---

## Contatti per Assistenza

Per qualsiasi problema non risolto con questo manuale, contatta l'**amministratore di sistema** che ti ha fornito il programma.

Quando lo contatti, cerca di descrivere:
- Che cosa stavi facendo quando si è verificato il problema
- Quale messaggio di errore è comparso (se possibile, fai uno screenshot con il tasto **Stamp** o **PrtScn** sulla tastiera)
- Il tuo sistema operativo (Windows 10 o Windows 11)

---

*Manuale realizzato per Gestione Viaggi v1.25 — Aprile 2026*
