# Come si genera l'installer per Windows

Procedura verificata il **2026-09-09**, compilando la versione 2.0 da Parallels Desktop.

---

## Prima di cominciare

| | |
|---|---|
| Dove si compila | **dentro Windows** — dal Mac il target Windows non esiste proprio |
| Sorgenti | si leggono direttamente dal Mac: `\\Mac\Home\Documents\Sviluppo Software\MAUI\GestioneViaggi` |

⛔️ **In Windows non serve git, e infatti non è installato.** Non c'è niente da scaricare o
aggiornare: si compilano i file del Mac così come sono in quel momento, comprese le modifiche non
ancora committate. Chi si ritrova a scrivere `git pull` qui dentro sta sbagliando procedura, non
ambiente. Basta salvare sul Mac prima di lanciare la compilazione.
| Serve | .NET 9 SDK + workload `maui-windows`, e **Inno Setup 6+** |

⛔️ **`appsettings.json` NON è su git** (è in `skip-worktree`) ed è una **risorsa incorporata**
nell'eseguibile. Compilando dai sorgenti del Mac il file giusto c'è già; se un domani si
compilasse da un clone separato, andrebbe copiato a mano — altrimenti l'eseguibile nasce senza
la stringa di connessione e il difetto si scopre solo all'avvio dal cliente.

---

## 1. Compilare

⚠️ **L'architettura giusta è `win10-x64`**, non quella predefinita. Parallels su Mac Apple
Silicon produce di default **ARM64**, che sul PC del cliente **non si avvia nemmeno**.
Verificato il 2026-09-09: il pacchetto consegnato le volte precedenti era x64.

```powershell
cd "\\Mac\Home\Documents\Sviluppo Software\MAUI\GestioneViaggi"
dotnet publish -f net9.0-windows10.0.19041.0 -c Release -r win10-x64 --self-contained true
```

⏱️ Circa 90 secondi. Gli avvisi `CS1998` (una sessantina) sono innocui e preesistenti; quello
che conta è che non ci siano **errori**.

ℹ️ `--self-contained true` include il runtime .NET nel pacchetto: l'applicazione parte anche
su un PC che non ha .NET installato.

### Verificare cosa è stato prodotto

```powershell
function Get-Arch($path) {
  $fs = [IO.File]::OpenRead($path); $br = New-Object IO.BinaryReader($fs)
  $fs.Seek(0x3C,'Begin') | Out-Null; $pe = $br.ReadInt32()
  $fs.Seek($pe + 4,'Begin') | Out-Null; $m = $br.ReadUInt16(); $fs.Close()
  switch ($m) { 0x8664 {"x64"} 0xAA64 {"ARM64"} 0x14C {"x86"} default {"sconosciuto"} }
}

$pub = "\\Mac\Home\Documents\Sviluppo Software\MAUI\GestioneViaggi\bin\Release\net9.0-windows10.0.19041.0\win10-x64\publish"
Get-Arch "$pub\GestioneViaggi.exe"                          # deve dire: x64
(Get-Item "$pub\GestioneViaggi.exe").VersionInfo.FileVersion # deve dire la versione giusta
```

⚠️ **I percorsi vanno scritti per intero.** Su cartelle di rete, .NET non usa la cartella
corrente di PowerShell: un percorso relativo verrebbe cercato in `C:\Users\...` e darebbe
«impossibile trovare una parte del percorso».

⚠️ **E vanno racchiusi fra apici**, perché contengono uno spazio («Sviluppo Software»). Senza, la
riga si spezza lì e PowerShell prova a eseguire `Software\MAUI\…` come se fosse un comando:
*«Impossibile caricare il modulo 'Software'»*. Succede facilmente incollando: gli apici si perdono.

### Le due verifiche in una riga sola

Comode quando la funzione `Get-Arch` qui sopra non è stata definita nella sessione corrente —
è una funzione, non un comando di sistema: senza averla incollata prima, PowerShell risponde
*«Termine 'Get-Arch' non riconosciuto»*.

```powershell
# versione: deve cominciare per il numero che stai rilasciando
(Get-Item '\\Mac\Home\Documents\Sviluppo Software\MAUI\GestioneViaggi\bin\Release\net9.0-windows10.0.19041.0\win10-x64\publish\GestioneViaggi.exe').VersionInfo.FileVersion

# architettura: deve dire x64
$f=[IO.File]::OpenRead('\\Mac\Home\Documents\Sviluppo Software\MAUI\GestioneViaggi\bin\Release\net9.0-windows10.0.19041.0\win10-x64\publish\GestioneViaggi.exe'); $b=New-Object IO.BinaryReader($f); $f.Seek(0x3C,'Begin')|Out-Null; $p=$b.ReadInt32(); $f.Seek($p+4,'Begin')|Out-Null; $m=$b.ReadUInt16(); $f.Close(); switch($m){0x8664{'x64'} 0xAA64{'ARM64'} 0x14C{'x86'} default{'sconosciuto'}}
```

ℹ️ La cartella si chiama `win10-x64` perché è il target che hai **chiesto**, non la prova di
quello che è **uscito**: il controllo sull'intestazione del file serve proprio a distinguere le
due cose. È così che il 2026-09-09 era passato un pacchetto ARM64.

---

## 2. Copiare in locale

⛔️ **Non compilare l'installer puntando direttamente alla cartella di rete**, e soprattutto
**mai** puntarlo a `C:\GestioneViaggi`: lì c'è il programma **già installato**, cioè la versione
vecchia. Inno Setup la impacchetterebbe senza protestare, e l'installer sembrerebbe riuscito.

```powershell
Remove-Item C:\GestioneViaggi-build -Recurse -Force -EA SilentlyContinue
New-Item -ItemType Directory C:\GestioneViaggi-build | Out-Null
Copy-Item "$pub\*" C:\GestioneViaggi-build -Recurse
```

Controllo prima di procedere:

```powershell
Get-Arch "C:\GestioneViaggi-build\GestioneViaggi.exe"
(Get-Item "C:\GestioneViaggi-build\GestioneViaggi.exe").VersionInfo.FileVersion
```

---

## 3. Generare l'installer

1. Apri `Scripts\windows\GestioneViaggi.iss` con **Inno Setup Compiler**
2. ⚠️ Verifica che `#define AppVersion` sia **la versione che stai rilasciando**
3. **Build → Compile** (Ctrl+F9)
4. L'installer esce in `C:\GestioneViaggi-build\Setup\GestioneViaggi_Setup_<versione>.exe`

ℹ️ Cosa fa l'installer, e perché è fatto così:
- installa in **`C:\GestioneViaggi`** — ⚠️ senza spazi nel percorso, perché **BlazorWebView non
  funziona da cartelle con spazi** (quindi mai «Programmi»);
- **installa WebView2** se manca, scaricandolo da Microsoft;
- ⛔️ **rifiuta di installarsi** su Windows più vecchi della build 19041 (Windows 10 v2004),
  richiesta da MAUI/WinUI 3;
- crea l'icona sul desktop per tutti gli utenti del PC.

---

## 4. Dopo l'installazione, sul PC del cliente

⛔️ **`GV_SECRET_KEY` va impostata come variabile d'ambiente di sistema**, altrimenti le schede
che toccano i segreti (Traduzioni, Configurazione email) si presentano disabilitate. La
procedura per l'utente è nel capitolo 7 del `Documents/Manuali_Utente/Manuale_Installazione_Utente.md`.

⚠️ La chiave **non va spedita insieme al programma**: si comunica per altra via.

---

## Dopo la consegna: cancellare il vecchio installer

⛔️ **Non lasciare i setup vecchi sul disco della VM, e soprattutto MAI dentro
`C:\GestioneViaggi`**, che è la cartella del programma installato.

Non è pignoleria d'ordine: il `.iss` impacchetta **tutto** quello che trova nella cartella
sorgente. Un installer dimenticato lì dentro finisce dentro il pacchetto successivo, e il
pacchetto pesa il doppio senza che nessun errore lo segnali.

**È già successo.** Verificato il 2026-09-14 confrontando i pesi:

| Versione | Peso |
|---|---|
| 1.25 | 108 MB |
| 1.30 | 102 MB |
| **1.35** | **206 MB** ⚠️ |
| 2.1 | 103 MB |

La 1.35 stava in `C:\GestioneViaggi\Setup\` insieme alla 1.30: è stata compilata puntando alla
cartella del programma installato, e si è portata dentro i 102 MB della 1.30. Il peso doppio è
l'unico sintomo che quell'errore produce.

```powershell
# dopo aver consegnato: via i pacchetti vecchi, ovunque siano
Get-ChildItem C:\ -Recurse -Filter 'GestioneViaggi_Setup_*.exe' -Depth 3 -ErrorAction SilentlyContinue |
    Select-Object FullName, LastWriteTime
```

Deve restare **solo** quello appena consegnato.

---

## Cosa consegnare

1. `GestioneViaggi_Setup_<versione>.exe`
2. `Documents/Manuali_Utente/Manuale_Installazione_Utente.md` (o il PDF)
3. Gli altri manuali: sistemazioni e iscrizioni, contenuti web, newsletter
4. La `GV_SECRET_KEY`, **separatamente**


---

## L'app sul Mac (per l'assistenza ad Antonio)

Adriano tiene installata sul Mac la stessa versione che gira in produzione, per vedere quello che
vede Antonio.

```bash
dotnet publish -f net9.0-maccatalyst -c Release
rm -rf /Applications/GestioneViaggi.app
cp -R bin/Release/net9.0-maccatalyst/GestioneViaggi.app /Applications/
```

⛔️ **La cartella da cui si copia è quella SENZA sottocartella di architettura.** `publish` ne
produce diverse:

| Percorso | Icona |
|---|---|
| `bin/Release/net9.0-maccatalyst/GestioneViaggi.app` | ✅ **questa** — universale x64+arm64 |
| `bin/Release/net9.0-maccatalyst/maccatalyst-arm64/…` | ⛔️ senza icona |
| `bin/Release/net9.0-maccatalyst/maccatalyst-x64/…` | ⛔️ senza icona |

⚠️ **Come ci si accorge di aver sbagliato**: l'app parte e funziona benissimo, ma nel Dock e nel
Finder ha **l'icona generica**. È l'unico sintomo — nient'altro cambia. Successo il 2026-09-09 e
scoperto il giorno dopo da Adriano.

ℹ️ `dotnet build -c Release` **non genera affatto** l'icona (provato): serve `publish`. In Debug
invece la genera. Verifica in un colpo solo:

```bash
plutil -p /Applications/GestioneViaggi.app/Contents/Info.plist | grep -i icon
```

Deve rispondere `CFBundleIconFile => appicon`. Se non risponde nulla, l'icona non c'è.

⚠️ Dopo la copia serve `killall Dock` perché il Finder rilegga l'icona.
