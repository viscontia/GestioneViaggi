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

*(ancora niente)*

---

## Sezione 2 — Correzioni

*(ancora niente)*

---

## Sezione 3 — Documentazione

*(ancora niente)*

---

## Sezione 4 — Database

| Script | Cosa | In PROD |
|---|---|---|
| | | |

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
