# =============================================================================
# install-app.ps1
# Installa GestioneViaggi su Windows (app unpackaged)
#
# Uso: Copiare questo script nella stessa cartella dell'exe, poi eseguire.
# Alternativa raccomandata: usare GestioneViaggi_Setup.exe (creato con InnoSetup)
# Eseguire come Amministratore (il script si auto-eleva)
# =============================================================================

# Auto-elevazione UAC
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevazione privilegi necessaria. Riavvio come Amministratore..." -ForegroundColor Yellow
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$ErrorActionPreference = "Stop"
$AppName = "GestioneViaggi"
# IMPORTANTE: non usare "Program Files" - il path con spazi rompe BlazorWebView
$InstallDir = "C:\$AppName"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  Installazione $AppName" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Verifica Windows ---
$winBuild = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
if ($winBuild -lt 17763) {
    Write-Host "ERRORE: Windows 10 v1809 (build 17763) o superiore richiesta." -ForegroundColor Red
    exit 1
}
Write-Host "[1/5] Windows build $winBuild - OK" -ForegroundColor Green

# --- 2. Verifica/Installa WebView2 Runtime ---
Write-Host "[2/5] Verifica WebView2 Runtime..." -ForegroundColor Yellow
$wv2 = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" -ErrorAction SilentlyContinue
if ($wv2) {
    Write-Host "  WebView2 $($wv2.pv) - OK" -ForegroundColor Green
} else {
    Write-Host "  WebView2 non trovato. Installazione automatica..." -ForegroundColor Yellow
    try {
        $bootstrapper = "$env:TEMP\MicrosoftEdgeWebview2Setup.exe"
        Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile $bootstrapper -UseBasicParsing
        Start-Process $bootstrapper -ArgumentList "/silent /install" -Wait
        Write-Host "  WebView2 installato." -ForegroundColor Green
    } catch {
        Write-Host "  ATTENZIONE: Impossibile installare WebView2 automaticamente." -ForegroundColor Yellow
        Write-Host "  Scaricalo manualmente da: https://developer.microsoft.com/microsoft-edge/webview2/" -ForegroundColor White
    }
}

# --- 3. Copia file nell'installazione ---
Write-Host "[3/5] Installazione in $InstallDir ..." -ForegroundColor Yellow
$sourceDir = $PSScriptRoot

if (Test-Path $InstallDir) {
    # Aggiornamento: ferma l'app se in esecuzione
    $process = Get-Process -Name $AppName -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "  Chiusura istanza $AppName in esecuzione..."
        $process | Stop-Process -Force
        Start-Sleep -Seconds 2
    }
    Remove-Item "$InstallDir\*" -Recurse -Force -ErrorAction SilentlyContinue
} else {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
}

Copy-Item -Path "$sourceDir\*" -Destination $InstallDir -Recurse -Force -Exclude "install-app.ps1"
Write-Host "  File copiati." -ForegroundColor Green

# --- 4. Crea shortcut sul Desktop ---
Write-Host "[4/5] Creazione collegamento sul Desktop..." -ForegroundColor Yellow
$exePath = Join-Path $InstallDir "$AppName.exe"
$shortcutPath = "$env:PUBLIC\Desktop\$AppName.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $exePath
$shortcut.WorkingDirectory = $InstallDir
$shortcut.Description = "Gestione Viaggi - Sistema di gestione tour e viaggi"
$shortcut.Save()
Write-Host "  Collegamento creato: $shortcutPath" -ForegroundColor Green

# Shortcut anche nel menu Start
$startMenuPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$AppName.lnk"
$shortcut2 = $shell.CreateShortcut($startMenuPath)
$shortcut2.TargetPath = $exePath
$shortcut2.WorkingDirectory = $InstallDir
$shortcut2.Description = "Gestione Viaggi"
$shortcut2.Save()

# --- 5. Completo ---
Write-Host "[5/5] Installazione completata." -ForegroundColor Green
Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  $AppName INSTALLATO" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Percorso: $exePath" -ForegroundColor White
Write-Host "  Collegamento: Desktop e Menu Start" -ForegroundColor White
Write-Host ""
Write-Host "  NOTA: alla prima esecuzione Windows potrebbe mostrare" -ForegroundColor Yellow
Write-Host "  'Windows ha protetto il PC'. Clicca 'Altre informazioni'" -ForegroundColor Yellow
Write-Host "  poi 'Esegui comunque'." -ForegroundColor Yellow
Write-Host ""

$avvia = Read-Host "Vuoi avviare $AppName adesso? (S/N)"
if ($avvia -eq "S" -or $avvia -eq "s") {
    Start-Process $exePath
}
