# Note di Rilascio — Versione 2.3

> ### 📦 Pronta da compilare — 2026-09-27
> I numeri di versione sono stati portati a **2.3** nei quattro punti del codice (build 39 → 40) e
> nell'intestazione dei **cinque** manuali; i PDF sono rigenerati. Resta la compilazione
> dell'installer e la consegna.
> Versione precedente: **2.2** del 2026-09-21 (consegnata ad Antonio).

---

## In una riga

⛔️ **Le mail del gestionale non arrivavano**, e nessuno se ne accorgeva: il server le accettava e
poi spariva. È il motivo per cui questa versione va distribuita subito. Con lei arrivano le foto
dell'iPhone che si caricano, e le due schermate che chiudono il giro con il sito di iscrizione:
la conferma dell'email scritta dal sito e le correzioni proposte dal cliente.

---

## Sezione 1 — Correzioni

### ⛔️ 1.1 — Le mail del gestionale sparivano

Mail ai partecipanti, newsletter, reset della password, «puoi iscriverti»: il server di posta le
accettava (`250 OK`, nessun errore) e poi **non le consegnava**. Verificato il 2026-09-26 anche
dalla 2.2 installata: una mail a sé stessi dall'anagrafica clienti non arriva.

**Causa**, trovata con sedici invii cambiando una variabile alla volta: il `Message-Id` che MailKit
genera da solo (una stringa casuale `@` il nome della macchina). Con un `Message-Id` costruito dal
programma — data, codice univoco e **dominio del mittente** — la mail arriva, anche su Outlook.

`Services/Email/SmtpEmailSender.cs`, commit `aa03792`.

### 1.2 — Le foto HEIC dell'iPhone non si caricavano

Caricando nel sito una foto passata dall'iPhone al PC, compariva *«Image cannot be loaded.
Available decoders…»* (Antonio, 2026-09-26): ImageSharp non legge il formato HEIC. Ora la foto si
converte prima, con **Magick.NET** su Windows e con ImageIO sul Mac. Se il formato resta
illeggibile il messaggio dice cosa fare: *«Salva la foto come JPEG o PNG e riprova.»*

`Services/Shared/Storage/WebImageProcessor.cs`, commit `d8513f2`. ⚠️ Il pacchetto Magick.NET si
installa solo nella build Windows: la prova vera è sulla VM (§6, passo 5).

### 1.3 — Il nome delle sezioni del sito non si scrive più tutto in maiuscolo

La finestra delle sezioni del sito forzava il maiuscolo sulla descrizione web: le sezioni erano
state salvate come «VIAGGI 4X4». Ora si scrive come deve apparire sul sito. I nomi già salvati sono
stati riscritti dallo script `657` (già in PROD). Commit `660e730`.

---

## Sezione 2 — Novità

### ⭐️ 2.1 — Email arrivata dal sito: la conferma (L12)

Quando un cliente in archivio **senza email** si iscrive dal sito, l'email che scrive viene
agganciata alla sua scheda, ma nessuno ha verificato che sia sua: finché non la si conferma, il
sito non gli manda il codice per modificare i suoi dati.

Nella scheda cliente, linguetta *Residenza & Contatti*, sotto l'email compare l'avviso
*«Email inserita dal sito di iscrizione e non ancora verificata…»* con il bottone
**«È la sua email: conferma»**. Se si cambia l'email, l'avviso sparisce: quella nuova l'ha scritta
il gestionale. Script `668` (già in PROD).

### ⭐️ 2.2 — Le correzioni proposte dal cliente (L12-bis)

Chi non può ricevere il codice (per esempio con il documento scaduto) può **proporre** i dati
nuovi dal sito: documento, telefono, indirizzo. Il sito li conserva a parte e non tocca la scheda.

In cima alla scheda cliente compare il riquadro **«Correzione proposta dal sito il … da …»** con la
tabella *campo · in archivio · proposto* e i bottoni:

- **Approva** — i dati passano dalla stessa validazione del salvataggio normale; se qualcosa non
  torna l'approvazione si ferma e dice perché. Riuscita, al cliente parte la mail *«La tua scheda è
  aggiornata: puoi completare l'iscrizione»*, con il link al sito;
- **Scarta** — la scheda non cambia e nessuna mail parte.

Chiudendo la scheda l'elenco clienti si rilegge (commit `da40fe1`). Script `669`–`670` e sito già
in PROD dal 2026-09-26: con la 2.3 arriva solo la schermata.

### 2.3 — WhatsApp fra i social

Nella rubrica dei social dell'azienda WhatsApp è riconosciuto, con icona e colore. Script `656`
(già in PROD). Commit `7c87c8e`.

---

## Sezione 3 — Solo per chi sviluppa

**Posta di prova deviata.** Nel gestionale di sviluppo, se `appsettings.Development.json` contiene
`Posta:DeviaA`, **ogni** mail (anche il campo «A») va a quella casella: il DB locale ha i dati veri
dell'azienda 2 e le prove non devono scrivere ai clienti. In Release la chiave non esiste e non
cambia niente. Commit `80f0137`, `c1ffdad`.

---

## Sezione 4 — Documentazione

- Intestazione dei cinque manuali portata a **2.3**; nel manuale di installazione il file si chiama
  `GestioneViaggi_Setup_2.3.exe`. PDF rigenerati, nessun titolo mancante.
- Per Antonio: `Novita_Versione_2_3.md` (e PDF), una pagina.

---

## Sezione 5 — ✅ Già applicato in PRODUZIONE (non serve rifarlo)

| Script | Cosa |
|---|---|
| `656`–`658` | WhatsApp, nomi delle sezioni, pagamenti online spenti |
| `660`–`667` | codici usa e getta, completamento della scheda dal sito, letture del wizard dentro la propria azienda (L4, L13) |
| `668` | conferma dell'email agganciata (L12) |
| `669`–`670` | proposte di correzione dal cliente (L12-bis) |

Verificato il 2026-09-27 con i due controlli del passo 0: **nessuna firma doppia**, e ogni funzione
chiamata dal codice esiste in PROD (i soli nomi assenti sono prefissi di nomi composti e
`fn_partenza_conclusa`, citata in un commento e tolta dallo script `626`).

---

## Sezione 6 — Al momento del rilascio

0. ✅ **Fatto il 2026-09-27** — i due controlli preliminari su PROD (procedura nelle note della 2.2,
   §7 passo 0): zero firme doppie, nessuna funzione mancante.
1. ✅ **Fatto il 2026-09-27** — versione a **2.3** in `Versione.txt`, nel `#define` di Inno Setup,
   in `ApplicationDisplayVersion` (build 39 → 40) e nei cinque manuali; PDF rigenerati.
2. ✅ **Fatto il 2026-09-27** — sul Mac la 2.3 Release ha sostituito la 2.2 in
   `/Applications/GestioneViaggi.app` (rifirmata ad hoc); mail a sé stessi dall'anagrafica
   clienti **arrivata**.
3. ✅ **Fatto il 2026-09-27** — compilato su Parallels (`-r win10-x64`, 105 s, 64 avvisi e nessun
   errore): `GestioneViaggi.exe` **x64**, versione **2.3.0.0**, Magick.NET incluso. Copiato in
   `C:\GestioneViaggi-build` e installer `GestioneViaggi_Setup_2.3.exe` generato con Inno Setup.
   ⚠️ Il comando va lanciato in PowerShell **dentro Windows**: dal Terminale del Mac risponde
   `NETSDK1083 … 'win10-x64' is not recognized`.
4. ✅ **Fatto il 2026-09-27** — installato sulla VM sopra la 2.2: versione 2.3, mail a sé stessi
   **arrivata**, foto **HEIC** caricata nella Libreria immagini (e poi cancellata). Il riquadro
   Approva / Scarta non si è potuto vedere: in PROD non c'è nessuna proposta in attesa (provato in
   locale, M11-M12).
5. ⏳ Consegnare ad Antonio `GestioneViaggi_Setup_2.3.exe`, `Novita_Versione_2_3.pdf` e i manuali;
   cancellare i setup vecchi.
