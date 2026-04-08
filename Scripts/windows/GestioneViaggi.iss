; =============================================================================
; GestioneViaggi.iss - Script InnoSetup
; Genera GestioneViaggi_Setup.exe per distribuzione a clienti Windows
;
; Prerequisiti: InnoSetup 6+ (https://jrsoftware.org/isinfo.php)
; Uso:
;   1. Apri questo file con InnoSetup Compiler
;   2. Clicca Build > Compile (o Ctrl+F9)
;   3. L'output GestioneViaggi_Setup.exe viene creato in C:\Output\
; =============================================================================

#define AppName "GestioneViaggi"
#define AppVersion "1.30"
#define AppPublisher "Adriano Visconti"
#define AppExeName "GestioneViaggi.exe"
#define AppDescription "Sistema di Gestione Viaggi e Turismo"

; PERCORSO dei file pubblicati (output di dotnet publish / build-release.ps1)
#define SourceDir "C:\GestioneViaggi"

[Setup]
AppId={{7229DAF4-6720-48BF-9590-F903A3F02D7D}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} v{#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://www.sardegnafuoritraccia.it
AppSupportURL=https://www.sardegnafuoritraccia.it

; IMPORTANTE: BlazorWebView non funziona da percorsi con spazi (es. "Program Files")
; Installare SEMPRE in un percorso senza spazi es. C:\GestioneViaggi
DefaultDirName={sd}\{#AppName}
DefaultGroupName={#AppName}

; Icona sul desktop creata di default (senza chiedere all'utente)
AllowNoIcons=no

; Cartella output del Setup.exe generato
OutputDir=C:\GestioneViaggi\Setup
OutputBaseFilename=GestioneViaggi_Setup_{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

; Versione minima Windows 10 v2004 (richiesta da WinUI 3 / MAUI)
MinVersion=10.0.19041
PrivilegesRequired=admin
ShowLanguageDialog=no

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
; Icona desktop selezionata di default
Name: "desktopicon"; Description: "Crea icona sul Desktop"; GroupDescription: "Icone aggiuntive:"; Flags: checkedonce

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Menu Start
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Comment: "{#AppDescription}"
Name: "{group}\Disinstalla {#AppName}"; Filename: "{uninstallexe}"
; Desktop — creata per tutti gli utenti del PC
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Comment: "{#AppDescription}"; Tasks: desktopicon

[Run]
; Installa WebView2 se non presente
Filename: "powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -Command ""$wv2 = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' -EA SilentlyContinue; if(-not $wv2){{ $b='$env:TEMP\wv2.exe'; Invoke-WebRequest 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $b -UseBasicParsing; Start-Process $b '/silent /install' -Wait }}"""; \
    StatusMsg: "Installazione Microsoft Edge WebView2 Runtime (se necessario)..."; \
    Flags: runhidden waituntilterminated

; Avvia l'app al termine dell'installazione
Filename: "{app}\{#AppExeName}"; Description: "Avvia {#AppName}"; Flags: nowait postinstall skipifsilent

[Code]
// Controlla versione Windows minima (19041 = Windows 10 v2004)
function InitializeSetup(): Boolean;
var
  Version: TWindowsVersion;
begin
  GetWindowsVersionEx(Version);
  if Version.Build < 19041 then
  begin
    MsgBox('Questo software richiede Windows 10 versione 2004 (build 19041) o superiore.' + #13#10 +
           'Versione rilevata: build ' + IntToStr(Version.Build) + '.' + #13#10 +
           'Aggiorna Windows tramite Windows Update prima di procedere.', mbError, MB_OK);
    Result := False;
  end else
    Result := True;
end;
