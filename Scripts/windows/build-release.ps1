# =============================================================================
# build-release.ps1
# Compila GestioneViaggi per Windows (x64) e genera la cartella di distribuzione
#
# REQUISITI:
#   - Eseguire da un percorso LOCALE (non UNC tipo \\Mac\Home\...) - altrimenti
#     il compilatore XAML di WinUI fallisce silenziosamente
#   - .NET 9 SDK + MAUI workload installati (usa setup-dev-environment.ps1)
#
# WORKFLOW CONSIGLIATO (da Parallels/Windows):
#   1. xcopy /E /I /H /Y "\\Mac\Home\...\GestioneViaggi" "C:\Build\GestioneViaggi"
#   2. cd C:\Build\GestioneViaggi
#   3. PowerShell -ExecutionPolicy Bypass -File Scripts\windows\build-release.ps1
# =============================================================================

param(
    [string]$Configuration = "Release",
    [string]$OutputDir = "dist-windows",
    [string]$MauiPackageVersion = ""
)

$ErrorActionPreference = "Stop"
$TFM = "net9.0-windows10.0.19041.0"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  GestioneViaggi - Build Windows Release" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Verifica percorso locale (non UNC) ---
$currentPath = (Get-Location).Path
if ($currentPath -like "\\*" -or $currentPath -like "Microsoft.PowerShell.Core\FileSystem::\\*") {
    Write-Host "ERRORE: Stai eseguendo da un percorso UNC (rete)." -ForegroundColor Red
    Write-Host "  Il compilatore WinUI non funziona da percorsi UNC." -ForegroundColor Red
    Write-Host "  Copia il progetto in locale, es:" -ForegroundColor Yellow
    Write-Host '  xcopy /E /I /H /Y "\\Mac\Home\...\GestioneViaggi" "C:\Build\GestioneViaggi"' -ForegroundColor White
    exit 1
}

# --- 2. Verifica .NET 9 SDK ---
Write-Host "[1/5] Verifica prerequisiti..." -ForegroundColor Yellow
try {
    $dotnetVersion = (dotnet --version 2>&1)
    if ($dotnetVersion -notmatch "^9\.") {
        Write-Host "  ATTENZIONE: .NET SDK $dotnetVersion trovato. Raccomandato .NET 9." -ForegroundColor Yellow
    } else {
        Write-Host "  .NET SDK: $dotnetVersion OK" -ForegroundColor Green
    }
} catch {
    Write-Host "ERRORE: dotnet CLI non trovato. Installa .NET 9 SDK da https://dotnet.microsoft.com/download" -ForegroundColor Red
    exit 1
}

# --- 3. Verifica MAUI workload ---
$workloads = dotnet workload list 2>&1 | Out-String
if ($workloads -notmatch "maui") {
    Write-Host "ERRORE: MAUI workload non installato. Esegui: dotnet workload install maui-windows" -ForegroundColor Red
    exit 1
}
Write-Host "  MAUI workload: OK" -ForegroundColor Green

# --- 4. Determina la root del progetto ---
$scriptDir = $PSScriptRoot
$projectRoot = (Resolve-Path (Join-Path $scriptDir "../../")).Path
$csprojPath = Join-Path $projectRoot "GestioneViaggi.csproj"

if (-not (Test-Path $csprojPath)) {
    Write-Host "ERRORE: GestioneViaggi.csproj non trovato in $projectRoot" -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host "[2/5] Progetto: $csprojPath" -ForegroundColor Yellow

# --- 5. Fix $(MauiVersion) ---
# Su Windows $(MauiVersion) non viene impostato dal workload MAUI.
# Rilevare la versione dal NuGet cache e sostituirla nel csproj temporaneamente.
Write-Host ""
Write-Host "[3/5] Risoluzione versione MAUI..." -ForegroundColor Yellow

if ($MauiPackageVersion -eq "") {
    $nugetCachePath = "$env:USERPROFILE\.nuget\packages\microsoft.maui.controls"
    if (Test-Path $nugetCachePath) {
        $versions = Get-ChildItem $nugetCachePath -Directory | Sort-Object Name -Descending
        if ($versions) {
            $MauiPackageVersion = $versions[0].Name
            Write-Host "  Versione MAUI rilevata: $MauiPackageVersion" -ForegroundColor Green
        }
    }
}

if ($MauiPackageVersion -eq "") {
    Write-Host "ERRORE: impossibile rilevare la versione MAUI. Passa -MauiPackageVersion X.X.X" -ForegroundColor Red
    exit 1
}

# Backup e patch csproj
$csprojContent = Get-Content $csprojPath -Raw
$csprojPatched = $csprojContent -replace '\$\(MauiVersion\)', $MauiPackageVersion
$csprojPatched | Set-Content $csprojPath -NoNewline

# --- 6. Pulizia e restore ---
Write-Host ""
Write-Host "[4/5] Restore NuGet..." -ForegroundColor Yellow
Push-Location $projectRoot
try {
    dotnet restore --nologo
    if ($LASTEXITCODE -ne 0) { Write-Host "ERRORE: dotnet restore fallito" -ForegroundColor Red; exit 1 }

    # --- 7. dotnet publish ---
    Write-Host ""
    Write-Host "[5/5] Compilazione e publish (win10-x64, SelfContained)..." -ForegroundColor Yellow
    Write-Host "  Prima compilazione: ~2-3 minuti. Compilazioni successive: ~45 sec."
    Write-Host ""

    dotnet publish `
        -f $TFM `
        -c $Configuration `
        -p:RuntimeIdentifier=win10-x64 `
        -p:SelfContained=true `
        --nologo

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERRORE: dotnet publish fallito (codice $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}

# --- 8. Crea cartella di output ---
$publishDir = Join-Path $projectRoot "bin\Release\$TFM\win10-x64\publish"
$distPath = Join-Path $projectRoot $OutputDir

if (Test-Path $distPath) { Remove-Item $distPath -Recurse -Force }
New-Item -ItemType Directory -Path $distPath | Out-Null

robocopy $publishDir $distPath /E /NFL /NDL /NJH /NJS | Out-Null

$installScript = Join-Path $scriptDir "install-app.ps1"
if (Test-Path $installScript) { Copy-Item $installScript $distPath }

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  BUILD COMPLETATA CON SUCCESSO" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Output: $distPath" -ForegroundColor White
Write-Host ""
Write-Host "  Prossimi passi:" -ForegroundColor Cyan
Write-Host "  1. Test rapido:   $distPath\GestioneViaggi.exe" -ForegroundColor White
Write-Host "  2. Installer:     apri Scripts\windows\GestioneViaggi.iss con InnoSetup" -ForegroundColor White
Write-Host "  3. Distribuzione: invia GestioneViaggi_Setup_*.exe ai clienti" -ForegroundColor White
Write-Host ""
Write-Host "  NOTA: non installare in 'Program Files' (path con spazio rompe BlazorWebView)" -ForegroundColor Yellow
Write-Host "  Cartella corretta: C:\GestioneViaggi\" -ForegroundColor Yellow
Write-Host ""
