# Note di Rilascio — Versione 2.4

> ### 🛠️ In preparazione — aperta il 2026-09-27
> Versione precedente: **2.3** del 2026-09-27 (consegnata ad Antonio).
> Cosa entra: le voci di `../Analisi_e_Design/2026-09-27-Cose_Da_Fare_MAUI_Versione_2_4.md`, a
> cominciare dal **promemoria all'apertura** (L2). Ogni cosa finita va segnata qui e nella sezione
> «Già nel codice, da portare con la 2.4» di quella lista.

---

## In una riga

*(da scrivere al rilascio)*

---

## Sezione 1 — Novità

### ⭐️ 1.1 — Il promemoria all'apertura (L2)

All'avvio, se c'è qualcosa in sospeso, compare la finestra **«Cose in sospeso»**: una tabella con
una riga per caso, i bottoni-filtro per voce con il conteggio, la ricerca e le pagine da 25. Ogni
riga ha **Apri**, che porta dove il caso si risolve; chiusa la scheda, la tabella si rilegge.

Le voci: correzioni dal sito da approvare, documenti scaduti o in scadenza degli iscritti, iscritti
che oggi non potrebbero iscriversi, partenze future senza scheda web / in bozza / senza foto,
viaggi senza capienza o soglia, partenze entro N giorni senza newsletter inviata, partenze passate
non segnate come effettuate. Le decide tutte il database (`fn_promemoria_apertura`, script 671).

- Non si chiude cliccando fuori, con Esc o con la rotella; **«Non mostrarmelo più oggi»** vale per
  quell'utente e quel giorno. Se non c'è niente, non compare.
- Si riapre dal menu, voce **«Promemoria (N)»**.
- **Anagrafica Aziende → Funzioni Web**: interruttore «Promemoria all'apertura» e il campo
  **«Giorni di anticipo per la newsletter»** (90 se non impostato).
- La scheda del viaggio ora si può aprire direttamente sui **Contenuti Web** di una partenza.

Disegno e piano: `Documents/Progetti/Promemoria_Apertura/`.

### ⭐️ 1.2 — La mail del lunedì (L18)

Ogni lunedì alle 7:30 le stesse righe del promemoria arrivano per email, leggibili dal telefono.
In **Funzioni Web**: interruttore «Mail del lunedì» (spento di default) e «Destinatari» (vuoto =
email principale dell'azienda, per SFT `segreteria@`). Non parte se non c'è niente in sospeso.
La spedisce il server del sito (`promemoria_lunedi.py` + timer systemd), non il gestionale.

✅ **Già in produzione dal 2026-09-27**, prima della 2.4 (decisione di Adriano: la spedisce il
server, non dipende dall'eseguibile). Script 671 e 673 in PROD, sito pubblicato dal ramo
`feature/mail-lunedi` (solo i 6 file nuovi), timer `iscrizione-promemoria-2.timer` attivo, prova
dal server deviata ad Adriano arrivata, `mail_lunedi` accesa per SFT → prima mail vera lunedì
2026-09-28 alle 7:30 a `segreteria@`. Con la 2.4 arriva solo la schermata di Funzioni Web per
accenderla, spegnerla e cambiare i destinatari (fino ad allora: da database).

---

## Sezione 2 — Correzioni

### 2.1 — Le icone delle date viaggio sfalsate da una riga all'altra

Nella griglia «Date in Programma» l'ultima icona (stato della scheda web) è un **pulsante** quando la
scheda manca e un'**icona semplice** quando c'è: la seconda è più stretta, e la fila centrata
scivolava di lato (segnalato da Adriano il 2026-09-27, Capodanno in Ogliastra). Ora l'icona semplice
occupa lo stesso spazio di un pulsante (`StatoContenutoWebIcon`, parametro `IngombroPulsante`).

---

## Sezione 3 — Documentazione

*(ancora niente)*

---

## Sezione 4 — Database

| Script | Cosa | In PROD |
|---|---|---|
| `671_Promemoria_Apertura.sql` | `fn_promemoria_apertura`, `fn_promemoria_giorni_newsletter`, riga `promemoria` a 90 giorni per ogni azienda. Test `Test_671_…` | ✅ 2026-09-27 (anticipato per la mail del lunedì; la finestra arriva con l'eseguibile 2.4) |
| `673_Promemoria_Mail_Lunedi.sql` | `fn_promemoria_mail_destinatari`, riga `mail_lunedi` spenta per ogni azienda. Test `Test_673_…` | ✅ 2026-09-27; `mail_lunedi` **accesa per l'azienda 2** |
| `672_Elimina_Viaggio_Di_Test_2.sql` | Via il «VIAGGIO DI TEST 2» (903) con le sue 2 iscrizioni e 2 camere; anagrafiche intatte. Pulizia dati, non serve all'eseguibile | ✅ 2026-09-27 |

⚠️ **Uno script che sta in `SqlScripts/` non è uno script applicato.** Ogni riga qui sopra si
chiude solo con la data dell'applicazione in PROD.

---

## Sezione 5 — Al momento del rilascio

La stessa sequenza della 2.3, con le lezioni imparate lì.

0. **Controlli preliminari su PROD** (procedura nelle note della 2.2, §7 passo 0):
   `SELECT * FROM fn_check_firme_duplicate();` deve rispondere zero righe, e ogni funzione chiamata
   dal codice deve esistere in PROD.
1. **Numero di versione a 2.4** in `Resources/Version/Versione.txt` (versione e data), nel
   `#define AppVersion` di `Scripts/windows/GestioneViaggi.iss`, in `ApplicationDisplayVersion`
   (build 40 → 41) e nell'intestazione e nel piè di pagina dei cinque manuali, più il nome
   `GestioneViaggi_Setup_2.4.exe` nel manuale di installazione. PDF rigenerati.
2. **Mac**: `dotnet build -f net9.0-maccatalyst -c Release`, poi sostituire
   `/Applications/GestioneViaggi.app` (quella nel Dock) con il bundle **universale**
   `bin/Release/net9.0-maccatalyst/GestioneViaggi.app`.
   ⛔️ Non quelli in `maccatalyst-arm64/` o `maccatalyst-x64/`: sono intermedi, senza icona e con
   la firma non valida (è successo con la 2.2 e con la 2.3). Prova: una mail a sé stessi
   dall'anagrafica clienti deve arrivare.
3. **Windows**, in PowerShell **dentro Parallels** (dal Terminale del Mac risponde `NETSDK1083`):
   ```powershell
   cd '\\Mac\Home\Documents\Sviluppo Software\MAUI\GestioneViaggi'
   dotnet publish -f net9.0-windows10.0.19041.0 -c Release -r win10-x64 --self-contained true
   ```
   Poi copia in `C:\GestioneViaggi-build` (svuotata prima) e Inno Setup, seguendo
   `Scripts/windows/COME_SI_GENERA_L_INSTALLER.md`. Controllare **x64** e versione **2.4.0.0**.
4. **Prova sulla VM**: installare sopra la 2.3 e provare le novità di questa versione.
5. **Consegna ad Antonio**: setup, `Novita_Versione_2_4.pdf` (da scrivere, voce aziendale) e i
   manuali; cancellare i setup vecchi. Segnare «consegnata» qui, nella lista della 2.4 e, per le
   voci `L*`, anche nella lista gemella del sito.
