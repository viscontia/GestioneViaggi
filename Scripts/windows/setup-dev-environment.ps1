# =============================================================================
# setup-dev-environment.ps1
# Configura l'ambiente di sviluppo/build Windows per GestioneViaggi
#
# Installa: .NET 9 SDK, MAUI workload, verifica WebView2
# Eseguire come Amministratore: PowerShell -ExecutionPolicy Bypass -File setup-dev-environment.ps1
# =============================================================================

# Eleva automaticamente a Amministratore se necessario
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevazione privilegi necessaria. Riavvio come Amministratore..." -ForegroundColor Yellow
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$ErrorActionPreference = "Stop"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  GestioneViaggi - Setup Ambiente di Sviluppo" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Verifica versione Windows ---
Write-Host "[1/5] Verifica versione Windows..." -ForegroundColor Yellow
$winVer = [System.Environment]::OSVersion.Version
$winBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
Write-Host "  Windows Build: $winBuild"
if ([int]$winBuild -lt 17763) {
    Write-Host "ERRORE: Windows 10 versione 1809 (build 17763) o superiore richiesta." -ForegroundColor Red
    Write-Host "  Build attuale: $winBuild. Aggiorna Windows prima di procedere." -ForegroundColor Red
    exit 1
}
Write-Host "  Versione Windows: OK (build $winBuild)" -ForegroundColor Green

# --- 2. Verifica/Installa .NET 9 SDK ---
Write-Host ""
Write-Host "[2/5] Verifica .NET 9 SDK..." -ForegroundColor Yellow
$dotnetOk = $false
try {
    $dotnetVer = (dotnet --version 2>&1).ToString()
    if ($dotnetVer -match "^9\.") {
        Write-Host "  .NET SDK $dotnetVer già installato." -ForegroundColor Green
        $dotnetOk = $true
    } else {
        Write-Host "  .NET SDK $dotnetVer trovato (versione non 9). Installo .NET 9..."
    }
} catch {
    Write-Host "  .NET SDK non trovato. Procedo all'installazione..."
}

if (-not $dotnetOk) {
    # Verifica winget
    try {
        winget --version | Out-Null
        Write-Host "  Installazione .NET 9 SDK tramite winget..."
        winget install Microsoft.DotNet.SDK.9 --silent --accept-source-agreements --accept-package-agreements
        # Aggiorna PATH per questa sessione
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } catch {
        Write-Host "  winget non disponibile. Scarica manualmente .NET 9 SDK da:" -ForegroundColor Yellow
        Write-Host "  https://dotnet.microsoft.com/download/dotnet/9.0" -ForegroundColor White
        Write-Host "  Dopo l'installazione, riesegui questo script." -ForegroundColor White
        exit 0
    }
}

# --- 3. Installa MAUI workload ---
Write-Host ""
Write-Host "[3/5] Verifica MAUI workload..." -ForegroundColor Yellow
$workloads = dotnet workload list 2>&1 | Out-String
if ($workloads -match "maui-windows") {
    Write-Host "  MAUI workload già installato." -ForegroundColor Green
} else {
    Write-Host "  Installazione MAUI workload (potrebbe richiedere qualche minuto)..."
    dotnet workload install maui-windows
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERRORE durante l'installazione di MAUI workload." -ForegroundColor Red
        Write-Host "  Prova manualmente: dotnet workload install maui-windows" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  MAUI workload installato." -ForegroundColor Green
}

# --- 4. Verifica/Installa WebView2 Runtime ---
Write-Host ""
Write-Host "[4/5] Verifica Microsoft Edge WebView2 Runtime..." -ForegroundColor Yellow
$wv2Reg = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
$wv2 = Get-ItemProperty $wv2Reg -ErrorAction SilentlyContinue
if ($wv2) {
    Write-Host "  WebView2 Runtime: $($wv2.pv)" -ForegroundColor Green
} else {
    Write-Host "  WebView2 non trovato. Installazione in corso..."
    $bootstrapper = "$env:TEMP\MicrosoftEdgeWebview2Setup.exe"
    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile $bootstrapper -UseBasicParsing
    Start-Process $bootstrapper -ArgumentList "/silent /install" -Wait
    Write-Host "  WebView2 Runtime installato." -ForegroundColor Green
}

# --- 5. Riepilogo ---
Write-Host ""
Write-Host "[5/5] Verifica finale..." -ForegroundColor Yellow
$finalDotnet = (dotnet --version 2>&1).ToString()
Write-Host "  .NET SDK: $finalDotnet" -ForegroundColor Green
Write-Host "  MAUI workload: OK" -ForegroundColor Green
Write-Host "  WebView2: OK" -ForegroundColor Green

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  SETUP COMPLETATO" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  L'ambiente di build e' pronto." -ForegroundColor White
Write-Host "  Prossimo passo: esegui build-release.ps1 per compilare l'app." -ForegroundColor Cyan
Write-Host ""
