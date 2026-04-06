# Installazione GestioneViaggi su Windows

**Versione**: 1.25
**Ultimo aggiornamento**: Marzo 2026
**Tecnologia**: .NET 9 MAUI Blazor Hybrid — App Unpackaged
**Database**: Supabase (cloud) — nessun server locale richiesto

---

## Indice

1. [Panoramica e Requisiti di Sistema](#1-panoramica-e-requisiti-di-sistema)
2. [Gotchas Critici — Leggi Prima di Tutto](#2-gotchas-critici--leggi-prima-di-tutto)
3. [Per lo Sviluppatore: Compilare per Windows](#3-per-lo-sviluppatore-compilare-per-windows)
4. [Creare lInstaller con InnoSetup](#4-creare-linstaller-con-innosetup)
5. [Per lUtente Finale: Installazione](#5-per-lutente-finale-installazione)
6. [Prima Configurazione e Accesso](#6-prima-configurazione-e-accesso)
7. [Note su Firewall e Reti Aziendali](#7-note-su-firewall-e-reti-aziendali)
8. [Risoluzione Problemi](#8-risoluzione-problemi)

---

## 1. Panoramica e Requisiti di Sistema

### Architettura

```
┌─────────────────────────┐        HTTPS (porta 443)        ┌──────────────────┐
│  PC Windows Utente      │  ──────────────────────────►   │  Supabase Cloud  │
│  GestioneViaggi.exe     │        PostgreSQL (porta 6543)  │  (AWS eu-central) │
│  (MAUI Blazor + WinUI)  │  ──────────────────────────►   │  PostgreSQL 17.5  │
└─────────────────────────┘                                  └──────────────────┘
```

Nessun database locale. Nessun Docker. Solo connessione internet.

### Requisiti Minimi — Utente Finale

| Componente | Requisito |
|-----------|-----------|
| Sistema Operativo | Windows 10 v2004 (build 19041) o superiore, Windows 11 |
| RAM | 4 GB (8 GB raccomandati) |
| Spazio disco | 500 MB nella cartella `C:\GestioneViaggi\` |
| Connessione internet | Richiesta — HTTPS porta 443 + PostgreSQL porta 6543 |
| Microsoft Edge WebView2 | Incluso in Windows 11; lo script lo installa automaticamente su Windows 10 |

> ⚠️ **Versione Windows minima**: build **19041** (Windows 10 v2004, maggio 2020).
> Il TFM `net9.0-windows10.0.19041.0` è richiesto da WinUI 3 per le librerie grafiche MAUI.
> Windows 10 v1809 (17763) NON è supportato.

### Requisiti — Ambiente di Build (Sviluppatore)

| Componente | Requisito |
|-----------|-----------|
| OS | Windows 10 build 19041+ o Windows 11 (fisico, VM, o Parallels) |
| .NET SDK | .NET 9 (`dotnet --version` deve mostrare `9.x.x`) |
| MAUI workload | `dotnet workload install maui-windows` |
| InnoSetup | v6+ per creare il Setup.exe (opzionale, gratuito) |

---

## 2. Gotchas Critici — Leggi Prima di Tutto

Queste sono le "trappole" scoperte durante il porting Mac → Windows. Ignorarle causa ore di debug.

### ❌ Gotcha 1: Non compilare da percorso UNC

**Problema**: Se il progetto si trova su `\\Mac\Home\...` (percorso di rete Parallels), il compilatore XAML di WinUI fallisce silenziosamente con errori `CS0234` / `CS0246` tipo `MauiWinUIApplication non trovato`.

**Soluzione**: Copiare sempre il progetto in locale prima di compilare:
```powershell
xcopy /E /I /H /Y "\\Mac\Home\Documents\Sviluppo Software\MAUI\GestioneViaggi" "C:\Build\GestioneViaggi"
cd C:\Build\GestioneViaggi
```

### ❌ Gotcha 2: $(MauiVersion) non viene impostato su Windows

**Problema**: La property `$(MauiVersion)` usata nel `.csproj` per i package reference (`Microsoft.Maui.Controls`) non viene impostata dal workload MAUI su Windows. Il risultato è che MAUI non viene trovato (`MauiWinUIApplication`, `MauiApp` — CS0234).

**Soluzione**: Sostituire `$(MauiVersion)` con la versione esplicita prima di compilare:
```powershell
(Get-Content GestioneViaggi.csproj -Raw) -replace '\$\(MauiVersion\)', '9.0.120' | Set-Content GestioneViaggi.csproj -NoNewline
```
> Verificare la versione disponibile in `$env:USERPROFILE\.nuget\packages\microsoft.maui.controls\`

Lo script `build-release.ps1` esegue questa sostituzione automaticamente.

### ❌ Gotcha 3: TFM deve essere 19041.0, non 17763.0

**Problema**: Usando `net9.0-windows10.0.17763.0` come Target Framework il compilatore non trova le classi WinUI 3 (`MauiWinUIApplication` — CS0246).

**Soluzione**: Usare `net9.0-windows10.0.19041.0`. La retrocompatibilità con Windows 10 più vecchi è gestita da `<SupportedOSPlatformVersion>` (non dal TFM).

### ❌ Gotcha 4: Non installare in "Program Files" — path con spazio

**Problema**: BlazorWebView su Windows non riesce a caricare i file statici se il percorso dell'exe contiene spazi. `C:\Program Files\GestioneViaggi\` → schermata nera all'avvio senza errori visibili.

**Soluzione**: Installare sempre in un percorso senza spazi:
```
✅ C:\GestioneViaggi\
✅ C:\Apps\GestioneViaggi\
❌ C:\Program Files\GestioneViaggi\
❌ C:\Programmi\GestioneViaggi\
```

### ❌ Gotcha 5: App.xaml.cs richiede using espliciti su Windows

**Problema**: Gli using impliciti MAUI non includono `MauiWinUIApplication` e `MauiApp` su Windows.

**Soluzione**: `Platforms/Windows/App.xaml.cs` deve avere:
```csharp
using Microsoft.Maui;
using Microsoft.Maui.Hosting;
using Microsoft.UI.Xaml;
```
E usare nomi completamente qualificati per la classe base:
```csharp
public partial class App : Microsoft.Maui.MauiWinUIApplication
protected override Microsoft.Maui.Hosting.MauiApp CreateMauiApp() => ...
```

---

## 3. Per lo Sviluppatore: Compilare per Windows

### 3.1 Configurare lAmbiente di Build

**Opzione A — Parallels Desktop** (Mac con chip M-series):
- La VM Windows in Parallels monta il Mac come `\\Mac\Home\`
- **Non compilare dal percorso UNC** — copiare in locale (vedi Gotcha 1)

**Opzione B — PC Windows fisico**:
- Clonare/copiare il progetto sul PC

Eseguire lo script di setup (come Amministratore):
```powershell
PowerShell -ExecutionPolicy Bypass -File Scripts\windows\setup-dev-environment.ps1
```

### 3.2 Workflow di Build Completo

```powershell
# 1. Copia in locale (da Parallels)
xcopy /E /I /H /Y "\\Mac\Home\Documents\Sviluppo Software\MAUI\GestioneViaggi" "C:\Build\GestioneViaggi"
cd C:\Build\GestioneViaggi

# 2. Build (include automaticamente fix MauiVersion e controllo percorso)
PowerShell -ExecutionPolicy Bypass -File Scripts\windows\build-release.ps1
```

### 3.3 Comando Manuale (alternativa)

```powershell
# Fix MauiVersion (obbligatorio su Windows)
(Get-Content GestioneViaggi.csproj -Raw) -replace '\$\(MauiVersion\)', '9.0.120' | Set-Content GestioneViaggi.csproj -NoNewline

dotnet restore
dotnet publish -f net9.0-windows10.0.19041.0 -c Release -p:RuntimeIdentifier=win10-x64 -p:SelfContained=true
```

Output: `bin\Release\net9.0-windows10.0.19041.0\win10-x64\publish\`

### 3.4 Verificare che la Build Mac Funzioni Ancora

```bash
# Dal Mac (dopo ogni modifica al .csproj)
dotnet build -f net9.0-maccatalyst
```

Il multi-targeting è condizionale all'OS di build: Mac compila solo `maccatalyst`, Windows solo `windows`. Nessun conflitto.

---

## 4. Creare lInstaller con InnoSetup

### 4.1 Installare InnoSetup

Download gratuito: [https://jrsoftware.org/isinfo.php](https://jrsoftware.org/isinfo.php)
Versione minima: **6.x** (testato con 6.7.1)

### 4.2 Preparare lo Script

Lo script `GestioneViaggi_Setup.iss` si trova nel repository Mac in `Scripts/windows/`.
Prima di ogni nuova build, copiarlo in locale su Windows:

```powershell
Copy-Item "\\Mac\Home\Documents\Sviluppo Software\MAUI\GestioneViaggi\Scripts\windows\GestioneViaggi.iss" -Destination "C:\GestioneViaggi\GestioneViaggi_Setup.iss" -Force
```

### 4.3 Compilare lInstaller

1. Aprire `C:\GestioneViaggi\GestioneViaggi_Setup.iss` con InnoSetup Compiler
2. **Ctrl+F9** per compilare
3. Output: `C:\GestioneViaggi\Setup\GestioneViaggi_Setup_1.25.exe`

> ⚠️ **Gotcha InnoSetup**: il file di lingua italiano non include il messaggio `{cm:DesktopFolder}`.
> Usare la stringa letterale `"Crea icona sul Desktop"` nella sezione `[Tasks]`.

### 4.4 Cosa Include lInstaller

- Tutti i file dell'app (exe + DLL + wwwroot)
- Installazione automatica WebView2 se assente (download silenzioso)
- **Icona sul Desktop creata automaticamente** (spuntata di default, non richiede azione all'utente)
- Icona nel Menu Start
- **Cartella di installazione: `C:\GestioneViaggi\`** (senza spazi — obbligatorio per BlazorWebView)
- Uninstaller integrato (Pannello di controllo → Programmi)
- Wizard in italiano
- Verifica versione Windows minima (build 19041)
- Avvio automatico dell'app al termine dell'installazione

### 4.5 Struttura Cartelle su Windows (sviluppatore)

```
C:\GestioneViaggi\          ← app installata + file pubblicati
C:\GestioneViaggi\Setup\    ← GestioneViaggi_Setup_1.25.exe (da distribuire)
C:\GestioneViaggi\GestioneViaggi_Setup.iss  ← script InnoSetup
C:\Build\GestioneViaggi\    ← copia locale del sorgente per la build
```

### 4.6 Distribuzione ai Clienti

Il file da inviare al cliente si trova **nella VM Windows** (Parallels) in:

```
C:\GestioneViaggi\Setup\GestioneViaggi_Setup_1.25.exe
```

> ⚠️ Il file esiste **solo su Windows** — non è presente nel filesystem Mac finché non lo trasferisci.

**Per trasferirlo sul Mac (e poi inviarlo al cliente):**

**Opzione A — Drag & Drop** (più semplice):
Trascina il file dalla finestra Parallels al desktop o in una cartella Finder.

**Opzione B — Copia da PowerShell**:
```powershell
Copy-Item "C:\GestioneViaggi\Setup\GestioneViaggi_Setup_1.25.exe" "\\Mac\Home\Desktop\"
```

Una volta sul Mac, invia il file al cliente via email / link / chiavetta USB.
Il file è completamente autonomo — il cliente fa doppio clic e segue il wizard.

---

## 5. Per lUtente Finale: Installazione

### Metodo A — Installer Automatico (raccomandato)

1. Ricevere `GestioneViaggi_Setup_1.25.exe`
2. Doppio clic per avviare il wizard
3. Se compare **"Windows ha protetto il PC"** (SmartScreen):
   - Cliccare **"Altre informazioni"** → **"Esegui comunque"**
4. Seguire il wizard — accettare la cartella di default `C:\GestioneViaggi\`
   > ⚠️ Non cambiare in `C:\Program Files\` — causa schermata nera all'avvio
5. L'installer installa WebView2 se necessario
6. Avviare dal desktop o menu Start

### Metodo B — Installazione Manuale (ZIP)

1. Estrarre il contenuto in `C:\GestioneViaggi\` (percorso senza spazi — obbligatorio)
2. Eseguire `install-app.ps1` come Amministratore
3. Avviare `GestioneViaggi.exe`

---

## 6. Prima Configurazione e Accesso

- Nessuna configurazione del database (Supabase preconfigurato)
- Login con username + password forniti dall'amministratore del sistema
- Le credenziali sono le stesse della versione Mac — il database è condiviso

**Posizione PDF generati su Windows**: `C:\Users\<utente>\Downloads\`

---

## 7. Note su Firewall e Reti Aziendali

### Porte Richieste

| Porta | Destinazione | Uso |
|-------|-------------|-----|
| **443** | `*.supabase.com` | API REST, autenticazione |
| **6543** | `aws-1-eu-central-1.pooler.supabase.com` | Connessione PostgreSQL (PgBouncer) |

### Se la Porta 6543 è Bloccata

In reti aziendali con firewall restrittivi (solo 80/443 in uscita) la connessione PostgreSQL fallisce.

**Soluzioni:**
1. Chiedere all'IT di aprire la porta 6543 verso Supabase
2. Usare la porta 5432 diretta (modifica connection string)
3. VPN aziendale — verificare che il traffico verso Supabase passi correttamente
4. Hotspot mobile per testing rapido

---

## 8. Risoluzione Problemi

| Sintomo | Causa | Soluzione |
|---------|-------|-----------|
| **Schermata nera all'avvio** | Path con spazi (es. `Program Files`) | Installare in `C:\GestioneViaggi\` |
| Schermata bianca all'avvio | WebView2 non installato | Reinstallare WebView2 da [aka.ms/webview2](https://developer.microsoft.com/microsoft-edge/webview2/) |
| Errore connessione DB | Porta 6543 bloccata | Vedi [Sezione 7](#7-note-su-firewall-e-reti-aziendali) |
| "Windows ha protetto il PC" | Exe senza firma digitale | "Altre informazioni" → "Esegui comunque" |
| PDF non si apre | Nessun lettore PDF predefinito | Installare Adobe Reader o impostare lettore predefinito |
| App non si avvia | Windows < build 19041 | Aggiornare Windows |
| Build: `MauiWinUIApplication not found` | Compilando da percorso UNC | Copiare in locale (Gotcha 1) |
| Build: `CS0234 MauiApp` | `$(MauiVersion)` non impostato | Sostituire con versione esplicita (Gotcha 2) |
| Build: `CS0246` su Windows 17763 | TFM sbagliato | Usare `net9.0-windows10.0.19041.0` (Gotcha 3) |

---

## Script di Riferimento

| Script | Posizione | Uso |
|--------|-----------|-----|
| `setup-dev-environment.ps1` | `Scripts\windows\` | Setup .NET 9 + MAUI + WebView2 (eseguire una volta) |
| `build-release.ps1` | `Scripts\windows\` | Build completo con fix automatici |
| `GestioneViaggi.iss` | `Scripts\windows\` | Genera `GestioneViaggi_Setup.exe` con InnoSetup |
| `install-app.ps1` | `Scripts\windows\` | Installazione manuale (incluso nel ZIP) |

---

*Per assistenza tecnica: contattare l'amministratore di sistema.*
