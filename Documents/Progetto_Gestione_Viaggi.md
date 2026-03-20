# Progetto Gestione Viaggi - Documentazione Tecnica e Credenziali

Questo documento raccoglie tutte le informazioni critiche del progetto Gestione Viaggi per facilitare lo sviluppo, la manutenzione e la migrazione verso l'infrastruttura Cloud (Supabase).

---

## 📌 Indice
1. [Scopo del Progetto](#-scopo-del-progetto)
2. [Strategia di Migrazione e Deployment](#-strategia-di-migrazione-e-deployment)
3. [Script di Migrazione Automatica](#-script-di-migrazione-automatica)
4. [Gestione Dual-Config (Sviluppo/Produzione)](#-gestione-dual-config-sviluppo-produzione)
5. [Connessioni e Credenziali](#-connessioni-e-credenziali)
    - [Database Locale](#database-locale)
    - [Database Supabase](#database-supabase)
6. [Elenco Utenti Applicativi](#-elenco-utenti-applicativi)
7. [Schema del Database (E/R)](#-schema-del-database-er)
8. [Configurazione SMTP](#-configurazione-smtp)
9. [Gestione Versione Applicazione](#-gestione-versione-applicazione)
10. [Fix Static Web Assets in Release Build](#-fix-static-web-assets-in-release-build)
11. [Posizione delle Stampe PDF](#-posizione-delle-stampe-pdf)
12. [Gestione Percorsi PDF e Sandbox macOS](#-gestione-percorsi-pdf-e-sandbox-macos)
13. [Standardizzazione Colori e Font nelle Stampe PDF](#-standardizzazione-colori-e-font-nelle-stampe-pdf)

---

## 🎯 Scopo del Progetto
Il progetto **Gestione Viaggi Offroad** è una soluzione enterprise (MAUI Blazor Hybrid) progettata per la gestione integrale di tour ed escursioni. 
Le caratteristiche principali includono:
- **Architettura Multi-Azienda**: Isolamento dei dati tra diverse entità organizzative.
- **Gestione Contabile**: Engine avanzato per la registrazione di transazioni, gestione IVA (incluso regime forfettario), bilanci preventivi e consuntivi per viaggio.
- **Logistica e Operatività**: Gestione partecipanti, assegnazione alloggi (Rooming List), gestione mezzi/flotta e scadenziari.
- **Reporting**: Generazione di report professionali in PDF per la stampa di documenti contabili e operativi.

---

## 🚀 Strategia di Migrazione e Deployment

### Nota di Contesto
Il database `gestione_viaggi` attualmente operativo su ambiente **Docker locale** (PostgreSQL 17.5, container `postgres_db`) deve essere migrato su **Supabase** per il deployment in produzione. 

**Caratteristiche del DB:**
- **Dimensione:** ~30 MB (base dati contenuta ma strutturalmente complessa).
- **Oggetti:** 65 tabelle nel core `public` (+1 staging).
- **Logica Programmabile:** 154 funzioni, 25 stored procedure e 31 trigger. Uso intensivo di **PL/pgSQL** per l'integrità dei dati e la logica di business.

### Approccio alla Migrazione
L'approccio scelto per minimizzare i rischi e preservare la complessa struttura di trigger e funzioni è:
**`pg_dump` → `psql`**

> [!IMPORTANT]
> Supabase utilizza il database predefinito chiamato `postgres` (non `gestione_viaggi`). Di conseguenza, durante la migrazione, lo schema verrà importato interamente nel database `postgres` sotto lo schema `public`.

---

## 🔄 Script di Migrazione Automatica

Per sincronizzare il database locale (Docker) con Supabase è disponibile uno script bash che automatizza l'intero processo.

### Posizione
```
Scripts/migrate_to_supabase.sh
```

### Cosa fa lo script
Lo script esegue in sequenza, con verifiche ad ogni passaggio:

| Step | Operazione | Dettaglio |
|------|-----------|-----------|
| 1 | Verifica Docker | Controlla che il container `postgres_db` sia in esecuzione |
| 2 | Verifica Supabase | Testa la connessione al database cloud |
| 3 | pg_dump | Esporta l'intero DB locale (schema + dati) con flag di compatibilità Supabase (`--no-owner`, `--no-privileges`, `--no-tablespaces`) |
| 4 | Pulizia dump | Rimuove comandi incompatibili (`\restrict`, `CREATE SCHEMA public`) |
| 5 | Estensioni | Abilita `citext`, `pgcrypto`, `uuid-ossp`, `pg_trgm` su Supabase |
| 6 | DROP + Ricreazione | Elimina lo schema `public` e `staging` su Supabase e li ricrea vuoti (**chiede conferma**) |
| 7 | Import | Importa il dump completo su Supabase |
| 8 | Fix FK | Corregge eventuali riferimenti orfani in `mov_clienti_viaggi` e ricrea i vincoli FK |
| 9 | Ruoli | Crea i ruoli applicativi (`app_superadmin`, `app_azienda_admin`, ecc.) |
| 10 | Verifica | Mostra un report con conteggio tabelle, funzioni, trigger e righe delle tabelle chiave |

### Prerequisiti
- **Docker** in esecuzione con il container `postgres_db` attivo
- **psql** installato sul Mac (incluso con `brew install postgresql`)
- **Connessione internet** per raggiungere Supabase

### Esecuzione

```bash
# Dalla root del progetto
cd "/Users/adrianovisconti/Documents/Sviluppo Software/MAUI/GestioneViaggi"

# Esegui lo script
./Scripts/migrate_to_supabase.sh
```

> [!IMPORTANT]
> Lo script chiede una **conferma esplicita** (y/N) prima di eseguire il `DROP SCHEMA public CASCADE` su Supabase. Questa operazione è distruttiva e cancella tutti i dati presenti sul cloud prima di reimportarli dal locale.

### Quando usarlo
- Dopo aver aggiornato dati o struttura sul DB locale (import Excel, nuove migrazioni SQL, modifiche schema)
- Prima di distribuire una nuova versione dell'app in produzione
- Per riallineare Supabase con lo stato attuale del DB di sviluppo

### Output
Lo script genera un file di dump con timestamp in `/tmp/`:
```
/tmp/migration_dump_YYYYMMDD_HHMMSS.sql
```
Il dump viene conservato per eventuali verifiche o rollback manuali.

---

## 🛠️ Gestione Dual-Config (Sviluppo/Produzione)

Per permettere uno sviluppo fluido senza conflitti tra ambienti, è stata adottata una gestione **dual-config esternalizzata**.

### Esternalizzazione Connection String
Attualmente, la stringa di connessione è hardcoded in `MauiProgram.cs:L74` tramite `AddInMemoryCollection`. Questa configurazione deve essere rimossa dal codice e spostata nei file di configurazione con uno **switch automatico** basato sul profilo di compilazione (Debug/Release).

### File di Configurazione

#### [NEW] `appsettings.json` (Produzione - Supabase)
Utilizzato per l'ambiente di produzione in Cloud (Transaction Pooler).
```json
{
  "ConnectionStrings": {
    "PostgreSQL": "Server=aws-1-eu-central-1.pooler.supabase.com;Port=6543;Database=postgres;User Id=postgres.wqbqvhshojbfuwcuiams;Password=U9Y7KSjQVfZ3N1Ca;Pooling=true;MinPoolSize=0;MaxPoolSize=30;Keepalive=30;No Reset On Close=true;Timeout=30;CommandTimeout=30;SSL Mode=Require;Trust Server Certificate=true;"
  }
}
```

> [!IMPORTANT]
> **`Multiplexing=true`** è **obbligatorio** per il Transaction Pooler di Supabase (PgBouncer). Senza questo parametro, Npgsql usa prepared statements che non sono supportati in modalità transaction pooling, causando il blocco delle query.

#### [NEW] `appsettings.Development.json` (Sviluppo - Docker Locale)
Utilizzato per lo sviluppo locale su Docker.
```json
{
  "ConnectionStrings": {
    "PostgreSQL": "Host=127.0.0.1;Port=5432;Database=gestione_viaggi;Username=postgres;Password=postgres;Pooling=true;MinPoolSize=1;MaxPoolSize=20;Timeout=30;CommandTimeout=30;"
  }
}
```

- **`dotnet run` (Debug)**: L'app riconosce l'ambiente di sviluppo e carica `appsettings.Development.json`. La connessione punta al **Docker locale**.
- **`dotnet publish` (Release)**: L'app viene compilata per la produzione. Viene utilizzato solo `appsettings.json` (o i valori non sovrascritti), garantendo la connessione a **Supabase**.

### Comandi Rapidi Utility
Per ottimizzare i tempi di sviluppo e test:

- **Avvio senza ricompilare**:
  ```bash
  dotnet run --no-build -f net9.0-maccatalyst -c Release
  ```
- **Apertura diretta del pacchetto Mac**:
  ```bash
  open bin/Release/net9.0-maccatalyst/maccatalyst-arm64/GestioneViaggi.app
  ```

### Clean Build per Release

> [!WARNING]
> Dopo modifiche al `.csproj` (aggiunta/rimozione di `EmbeddedResource`, pacchetti NuGet, configurazione risorse) **eseguire sempre una clean build** prima di avviare in Release. Un build incrementale potrebbe produrre un `.app` con artefatti stale, causando l'errore fatale **"There is no content at"** nel BlazorWebView all'avvio.

**Caso reale (2026-03-08):** Dopo l'aggiunta di `Resources/Version/Versione.txt` come `EmbeddedResource` e le modifiche a `StatusBar`/`StatusBarService`, l'app in Release mostrava "There is no content at" e non si avviava. Il build Debug funzionava regolarmente. Una clean build ha risolto il problema.

```bash
# Clean + Rebuild Release
dotnet clean -c Release -f net9.0-maccatalyst && dotnet build -c Release -f net9.0-maccatalyst
```

---

## 🔑 Connessioni e Credenziali

### Database Locale
Dati per la connessione al database PostgreSQL in esecuzione su Docker.

| Parametro | Valore |
|-----------|--------|
| **Host** | `127.0.0.1` |
| **Porta** | `5432` |
| **Database** | `gestione_viaggi` |
| **Username** | `postgres` |
| **Password** | `postgres` |

### Database Supabase
Credenziali per il database in Cloud (Transaction Pooler).

| Parametro | Valore |
|-----------|--------|
| **Project Name** | `Gestione Viaggi` |
| **Project ID** | `wqbqvhshojbfuwcuiams` |
| **Host** | `aws-1-eu-central-1.pooler.supabase.com` |
| **Porta** | `6543` |
| **Database** | `postgres` |
| **Username** | `postgres.wqbqvhshojbfuwcuiams` |
| **Password** | `U9Y7KSjQVfZ3N1Ca` |
| **Keepalive** | `30` |
| **No Reset On Close** | `true` |
| **Pool Mode** | `transaction` |
| **Transaction Pooler (URI)** | `postgresql://postgres.wqbqvhshojbfuwcuiams:U9Y7KSjQVfZ3N1Ca@aws-1-eu-central-1.pooler.supabase.com:6543/postgres` |
| **IPv4 Compatible** | Sì |
| **Npgsql Required** | `Pooling=true;Keepalive=30;No Reset On Close=true;` |

> [!NOTE]
> **Parametri Npgsql per Transaction Pooler (Risoluzione Stream Exception & Deadlock):**
> - `Pooling=true`: Abilita il pooling lato client con `MaxPoolSize=30` (sufficiente per chiamate parallele iniziali).
> - `Keepalive=30`: Mantiene vivo il canale con PgBouncer evitando disconnessioni dello stream.
> - `No Reset On Close=true`: **Vitale** per PgBouncer/Supavisor; evita deadlock impedendo l'invio di comandi di reset sessione non supportati.
> - `Multiplexing=false`: Garantisce stabilità dello stream su reti variabili.

---

## 👤 Elenco Utenti Applicativi
Elenco delle credenziali per l'accesso all'applicazione.

| Email / Username | Password | Ruolo / Azienda |
|------------------|----------|-----------------|
| `visconti.adriano@gmail.com` | `Test123!` | SuperAdmin |
| `mirania008@gmail.com` | `Mirania008!` | Azienda 6 |
| `segreteria@sardegnafuoritraccia.it` | `Sardegna2025!` | Azienda 2 |

---

## 📊 Schema del Database (E/R)
Rappresentazione grafica delle tabelle presenti nel database (Schema `public`).

```mermaid
erDiagram
    ana_aliquote_iva ||--o{ mov_transazioni : "iva"
    ana_api_config ||--|| ana_aziende : "config"
    ana_aziende ||--o{ app_users : "users"
    ana_aziende ||--o{ ana_aziende_smtp : "smtp"
    ana_aziende ||--o{ ana_aziende_banche : "banche"
    ana_aziende ||--o{ ana_aziende_contatti : "contatti"
    ana_aziende ||--o{ ana_aziende_email : "email"
    ana_aziende ||--o{ ana_aziende_logo : "logo"
    ana_aziende ||--o{ ana_aziende_sedi : "sedi"
    ana_aziende ||--o{ ana_viaggi : "viaggi"
    ana_aziende ||--o{ ana_clienti : "clienti"
    ana_aziende ||--o{ mov_transazioni : "transazioni"
    ana_viaggi ||--o{ ana_date_viaggi : "date"
    ana_viaggi ||--o{ mov_clienti_viaggi : "partecipanti"
    ana_date_viaggi ||--o{ mov_clienti_viaggi : "prenotazioni"
    ana_clienti ||--o{ mov_clienti_viaggi : "partecipazioni"
    mov_transazioni ||--o{ mov_transazioni_righe : "righe"
    
    subgraph Tabelle_Anagrafiche
        ana_aliquote_iva
        ana_api_config
        ana_aziende
        ana_aziende_banche
        ana_aziende_contatti
        ana_aziende_email
        ana_aziende_logo
        ana_aziende_sedi
        ana_aziende_smtp
        ana_business_events
        ana_clienti
        ana_clienti_bak
        ana_controparti
        ana_date_viaggi
        ana_date_viaggi_bak
        ana_geo_capoluogo
        ana_geo_comuni
        ana_geo_ita_ripgeo
        ana_geo_province
        ana_geo_regioni_ita
        ana_mezzi
        ana_mezzi_modelli
        ana_mezzi_modelli_bak
        ana_tassi_cambio
        ana_tipi_causali
        ana_tipo_alloggio
        ana_tipo_avvicinamento
        ana_tipo_fornitore
        ana_tipo_mezzi
        ana_tipo_partecipante
        ana_tipo_pernottamento
        ana_tipo_sedi
        ana_tipo_trattamento
        ana_tipo_viaggi
        ana_valute
        ana_viaggi
        ana_viaggi_bak
    end

    subgraph Tabelle_Applicative
        app_user_role_map
        app_users
        audit_login
        eba_countries
        eba_country_intermediates
        eba_country_organizations
        eba_country_regions
        eba_country_sub_regions
        idempotency_keys
        master_detail_field_config
        master_detail_relations
        password_reset_attempts
        password_reset_results
        password_reset_tokens
        reparti_aziendali
        sys_logo_types
        sys_menu_items
        sys_menu_role_grants
        sys_redis_endpoints
        user_roles
        user_table_settings
    end

    subgraph Tabelle_Movimenti
        mov_clienti_alloggi
        mov_clienti_alloggi_bak
        mov_clienti_viaggi
        mov_clienti_viaggi_bak
        mov_contatori_protocollo_iva
        mov_transazioni
        mov_transazioni_righe
    end
```

---

## 📧 Configurazione SMTP
Dettagli per l'invio delle email di sistema.

### Azienda 2: Sardegna Fuori Traccia
- **Host**: `mail.sardegnafuoritraccia.it`
- **Porta**: `587`
- **Username**: `segreteria@sardegnafuoritraccia.it`
- **Password**: _(Utilizzare password utente: Sardegna2025!)_
- **Sicurezza**: TLSAttivo, StartTLS Disattivo
- **Protocollo**: SMTPS

### Azienda 6: Offroad Adventures (Test Gmail)
- **Host**: `smtp.gmail.com`
- **Porta**: `587`
- **Username**: `visconti.adriano@gmail.com`
- **Password**: `qrdq shro bhsg skgw` (App Password)
- **Sicurezza**: TLS Disattivo, StartTLS Attivo
- **Protocollo**: SMTP

---

## 🏷️ Gestione Versione Applicazione

La versione dell'applicazione è gestita tramite un file di testo esterno, separato dal codice sorgente, per semplificare gli aggiornamenti.

### File Sorgente
```
Resources/Version/Versione.txt
```

### Formato
Il file contiene due righe:
```
1.1
2026-03-07
```
- **Riga 1**: Numero di versione (es. `1.1`)
- **Riga 2**: Data di rilascio in formato `YYYY-MM-DD`

### Come Funziona
1. Il file è incluso nel progetto come **EmbeddedResource** (configurato in `GestioneViaggi.csproj`)
2. All'avvio dell'app, `StatusBarService.LoadAppVersion()` legge la risorsa embedded dall'assembly
3. La versione viene visualizzata nella **StatusBar** in basso a destra, nel formato `v1.1 (2026-03-07)`

### Come Aggiornare la Versione
Per rilasciare una nuova versione è sufficiente:
1. Modificare `Resources/Version/Versione.txt` con il nuovo numero e la data
2. Aggiornare `ApplicationDisplayVersion` e `ApplicationVersion` nel `.csproj` per coerenza con il sistema operativo

### File Coinvolti
| File | Ruolo |
|------|-------|
| `Resources/Version/Versione.txt` | Sorgente unico della versione |
| `GestioneViaggi.csproj` | Include il file come EmbeddedResource + versioni OS |
| `Models/StatusBarInfo.cs` | Proprietà `AppVersion` |
| `Services/UI/StatusBarService.cs` | Metodo `LoadAppVersion()` che legge la risorsa |
| `Components/Shared/StatusBar.razor` | Visualizzazione nella barra di stato |

### Storico Versioni
| Versione | Data | Note |
|----------|------|------|
| 1.0 | - | Versione iniziale |
| 1.1 | 2026-03-07 | Export XML FatturaPA SDI, estrazione clienti, versioning esternalizzato |

---

## 🔧 Fix Static Web Assets in Release Build

### Il Problema
In MAUI Blazor Hybrid con .NET 9+, le build in modalità **Release** includono solo le versioni compresse (`.br`, `.gz`) dei file statici (CSS, JS, HTML) nella cartella `wwwroot`. I file originali non compressi vengono omessi per ridurre le dimensioni del pacchetto.

Questo causa il fallimento del caricamento dell'interfaccia:
- **Sintomo**: La pagina di login appare senza stile (CSS non caricato), layout completamente rotto
- **Causa**: Il BlazorWebView non riesce a servire i file `.br`/`.gz` direttamente, necessita dei file originali

### File Coinvolti
Il problema riguarda:
1. **File del progetto** (`wwwroot/`): `index.html`, `app.css`, file JS
2. **File da NuGet packages** (`_content/`): MudBlazor CSS/JS, Blazored.TextEditor, ecc.

### La Soluzione
È stato aggiunto un **MSBuild Target** nel file `GestioneViaggi.csproj` che copia i file originali non compressi dopo ogni build Release:

```xml
<!-- Fix static web assets in Release builds - copy uncompressed files -->
<Target Name="CopyUncompressedWwwroot" AfterTargets="Build"
        Condition="'$(Configuration)' == 'Release' AND '$(TargetFramework)' == 'net9.0-maccatalyst'">
    <PropertyGroup>
        <WwwrootDestination>$(OutputPath)maccatalyst-arm64\$(AssemblyName).app\Contents\Resources\wwwroot\</WwwrootDestination>
        <NuGetPackagesPath Condition="'$(NuGetPackagesPath)' == ''">$(HOME)/.nuget/packages</NuGetPackagesPath>
    </PropertyGroup>
    <ItemGroup>
        <!-- Project wwwroot files -->
        <WwwrootFiles Include="$(ProjectDir)wwwroot\**\*.*"
                      Exclude="$(ProjectDir)wwwroot\**\*.br;$(ProjectDir)wwwroot\**\*.gz;$(ProjectDir)wwwroot\**\.DS_Store" />
        <!-- MudBlazor static assets from NuGet -->
        <MudBlazorFiles Include="$(NuGetPackagesPath)/mudblazor/8.15.0/staticwebassets/*.*" />
        <!-- Blazored.TextEditor static assets from NuGet -->
        <BlazoredTextEditorFiles Include="$(NuGetPackagesPath)/blazored.texteditor/1.1.0/staticwebassets/**/*.*" />
    </ItemGroup>
    <Copy SourceFiles="@(WwwrootFiles)"
          DestinationFiles="@(WwwrootFiles->'$(WwwrootDestination)%(RecursiveDir)%(Filename)%(Extension)')"
          SkipUnchangedFiles="false" />
    <Copy SourceFiles="@(MudBlazorFiles)"
          DestinationFolder="$(WwwrootDestination)_content/MudBlazor/"
          SkipUnchangedFiles="false" />
    <Copy SourceFiles="@(BlazoredTextEditorFiles)"
          DestinationFiles="@(BlazoredTextEditorFiles->'$(WwwrootDestination)_content/Blazored.TextEditor/%(RecursiveDir)%(Filename)%(Extension)')"
          SkipUnchangedFiles="false" />
</Target>
```

### Come Funziona
1. **Esecuzione**: Il target si attiva automaticamente dopo ogni `dotnet build -c Release`
2. **Copia wwwroot**: Copia tutti i file dal `wwwroot/` del progetto (esclusi `.br`, `.gz`, `.DS_Store`)
3. **Copia MudBlazor**: Recupera i file CSS/JS originali dalla cache NuGet (`~/.nuget/packages/mudblazor/...`)
4. **Copia Blazored.TextEditor**: Idem per il rich text editor

### Manutenzione
> [!WARNING]
> Se aggiorni la versione di **MudBlazor** o **Blazored.TextEditor** nel progetto, devi aggiornare anche i path nel target MSBuild con la nuova versione del pacchetto.

Esempio: se MudBlazor passa da `8.15.0` a `8.16.0`:
```xml
<!-- Vecchio -->
<MudBlazorFiles Include="$(NuGetPackagesPath)/mudblazor/8.15.0/staticwebassets/*.*" />
<!-- Nuovo -->
<MudBlazorFiles Include="$(NuGetPackagesPath)/mudblazor/8.16.0/staticwebassets/*.*" />
```

### Verifica
Per verificare che i file siano stati copiati correttamente:
```bash
# Dopo il build Release
ls -la bin/Release/net9.0-maccatalyst/maccatalyst-arm64/GestioneViaggi.app/Contents/Resources/wwwroot/

# Deve mostrare sia file originali che compressi:
# index.html        (originale)
# index.html.br     (compresso)
# index.html.gz     (compresso)

# Verifica MudBlazor
ls -la bin/Release/net9.0-maccatalyst/maccatalyst-arm64/GestioneViaggi.app/Contents/Resources/wwwroot/_content/MudBlazor/
# Deve contenere:
# MudBlazor.min.css (originale ~610KB)
# MudBlazor.min.js  (originale ~75KB)
```

---

## 📄 Posizione delle Stampe PDF

### Dove Vengono Salvati i PDF

Tutti i PDF generati dall'applicazione (fatture, bilanci, stampe viaggi, ecc.) vengono salvati in una **cartella cache** specifica per la piattaforma:

#### macOS (Release/Production)
```bash
~/Library/Containers/com.adrianovisconti.gestioneviaggi/Data/Library/Caches/
```

**Apertura rapida dalla cartella:**
```bash
open ~/Library/Containers/com.adrianovisconti.gestioneviaggi/Data/Library/Caches/
```

**Dall'applicazione:**
- Menu **Utilità** → **Posizione delle Stampe PDF** (apre direttamente la cartella nel Finder)

#### Windows
```
C:\Users\[username]\Downloads\
```
Fallback: `C:\Users\[username]\AppData\Local\Packages\[AppId]\LocalCache\`

#### Linux
```
/home/[user]/Downloads/
```

### Persistenza dei File

| Piattaforma | Comportamento alla Chiusura App | Durata |
|-------------|----------------------------------|--------|
| **macOS/iOS/Android** | I file **rimangono salvati** | Fino a quando il sistema non ha bisogno di spazio (pulizia automatica cache) |
| **Windows/Linux** | I file **rimangono permanentemente** (se in Downloads) | Permanente |

> [!WARNING]
> **Importante**: La cartella cache è **temporanea** per design. I PDF importanti dovrebbero essere:
> - Aperti e salvati manualmente dall'utente in una posizione permanente
> - Esportati via email o altri canali
> - Archiviati in un sistema di backup esterno
>
> Il sistema operativo può cancellare i file in cache in qualsiasi momento per liberare spazio, specialmente su dispositivi mobili (iOS/Android).

### Come Accedere ai PDF Salvati

1. **Durante la generazione**: L'app apre automaticamente il PDF appena generato
2. **Manualmente tramite menu**: Menu Utilità → Posizione delle Stampe PDF
3. **Da Terminale (macOS)**: `open ~/Library/Containers/com.adrianovisconti.gestioneviaggi/Data/Library/Caches/`
4. **Finder (macOS)**: Cmd+Shift+G → Incolla il percorso sopra

---

## 📄 Gestione Percorsi PDF e Sandbox macOS

### Il Problema

Su macOS, le applicazioni MAUI sono **sandboxate** per motivi di sicurezza. Questo significa che l'app viene eseguita in un container isolato (`/Users/[user]/Library/Containers/[bundle-id]/Data/`) e non può accedere liberamente al filesystem dell'utente.

**Sintomo dell'errore:**
```
UnauthorizedAccess_IODenied_Path, /Users/[user]/Library/Containers/com.adrianovisconti.gestioneviaggi/Data/Downloads/
```

Quando l'applicazione tentava di salvare i PDF generati usando il percorso standard `Environment.GetFolderPath(Environment.SpecialFolder.UserProfile) + "Downloads"`, il sistema restituiva un errore di permessi perché:
1. La cartella Downloads **non esisteva** nel container sandboxato
2. L'app non aveva i permessi per crearla in quel percorso specifico

### La Soluzione Implementata

È stato creato un **metodo centralizzato** nel servizio `IPdfOpenerService` che gestisce automaticamente i percorsi dei PDF in modo cross-platform e compatibile con il sandboxing:

#### File Modificato
- **`Services/Printing/PdfOpenerService.cs`**

#### Implementazione (Versione Finale)

```csharp
public interface IPdfOpenerService
{
    Task<bool> OpenPdfAsync(string filePath, string title = "Stampa Completata");
    string GetPdfOutputFolder();
}

public class PdfOpenerService : IPdfOpenerService
{
    public string GetPdfOutputFolder()
    {
        // Su macOS/iOS/Android le app sono sandboxate e non possono scrivere
        // liberamente nel filesystem. Usiamo direttamente la cache dell'app.
        #if MACCATALYST || IOS || ANDROID
        return FileSystem.CacheDirectory;
        #else
        // Su Windows/Linux proviamo la cartella Downloads standard
        var targetFolder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            "Downloads"
        );

        try
        {
            if (!Directory.Exists(targetFolder))
                Directory.CreateDirectory(targetFolder);

            // Test di scrittura per verificare i permessi
            var testFile = Path.Combine(targetFolder, ".write_test");
            File.WriteAllText(testFile, "test");
            File.Delete(testFile);

            return targetFolder;
        }
        catch
        {
            return FileSystem.CacheDirectory;
        }
        #endif
    }
}
```

**Modifica chiave**: Su macOS usa **direttamente** `FileSystem.CacheDirectory` senza tentare di creare Downloads, evitando errori di permessi.

### Come Funziona

#### Su piattaforme sandboxate (macOS/iOS/Android)
Usa **direttamente** `FileSystem.CacheDirectory`:
```csharp
#if MACCATALYST || IOS || ANDROID
return FileSystem.CacheDirectory;
#endif
```
- **Nessun tentativo** di creare Downloads
- **Nessun errore** di permessi possibile
- Percorso garantito accessibile

#### Su Windows/Linux
1. **Tenta Downloads**: `Path.Combine(UserProfile, "Downloads")`
2. **Test permessi**: Crea e cancella un file di test
3. **Fallback cache**: Se fallisce, usa `FileSystem.CacheDirectory`

### Percorsi Utilizzati

#### macOS (Release) - **CACHE SEMPRE**
```
/Users/[user]/Library/Containers/com.adrianovisconti.gestioneviaggi/Data/Library/Caches/
```
✅ **Comando per aprire**: `open ~/Library/Containers/com.adrianovisconti.gestioneviaggi/Data/Library/Caches/`

#### Windows
```
C:\Users\[user]\Downloads\
```
Fallback: `C:\Users\[user]\AppData\Local\Packages\[AppId]\LocalCache\`

#### Linux
```
/home/[user]/Downloads/
```

### File Aggiornati

Tutti i componenti che generano PDF sono stati aggiornati per usare il metodo centralizzato `GetPdfOutputFolder()` invece di costruire manualmente il percorso:

| File | Modifiche |
|------|-----------|
| `Services/Printing/PdfOpenerService.cs` | Implementazione metodo centralizzato |
| `Components/Shared/StampaSchedaViaggioDialog.razor` | Usa metodo centralizzato |
| `Components/Shared/NavMenu.razor` | Aggiunto inject + usa metodo centralizzato |
| `Components/Shared/ViaggioPartecipantiManagerDialog.razor` | Usa metodo centralizzato |
| `Components/Pages/DashboardSuperAdmin.razor` | Aggiunto inject + usa metodo centralizzato |
| `Components/Pages/DashboardAdmin.razor` | Aggiunto inject + usa metodo centralizzato |
| `Components/Pages/StampaFattureAttivePage.razor` | Usa metodo centralizzato |
| `Components/Pages/MovTransazioniPage.razor` | Usa metodo centralizzato |
| `Components/Shared/StampaRegistroIvaDialog.razor` | Usa metodo centralizzato |
| `Components/Shared/StampaBilancioViaggioDialog.razor` | Usa metodo centralizzato |
| `Components/Shared/StampaBilancioAnnualeViaggiDialog.razor` | Usa metodo centralizzato |
| `Components/Shared/StampaScadenzarioDialog.razor` | Usa metodo centralizzato |
| `Components/Shared/StampaMovimentiDialog.razor` | Usa metodo centralizzato |
| `Components/Pages/Tools/DatabaseDocumentationPage.razor` | Aggiunto inject + usa metodo centralizzato |

### Pattern di Utilizzo

**Prima (vecchio approccio - problematico):**
```csharp
var targetFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads");
var outputPath = Path.Combine(targetFolder, fileName);
```

**Dopo (nuovo approccio - centralizzato):**
```csharp
var targetFolder = PdfOpenerService.GetPdfOutputFolder();
var outputPath = Path.Combine(targetFolder, fileName);
```

### Compatibilità Cross-Platform

✅ **macOS (Sandboxed)**: Crea automaticamente la cartella nel container, fallback su cache
✅ **Windows**: Usa la cartella Downloads standard dell'utente
✅ **Linux**: Usa la cartella Downloads standard dell'utente
✅ **iOS/Android**: `FileSystem.CacheDirectory` funziona nativamente

### Vantaggi

1. **Centralizzazione**: Un unico punto di gestione dei percorsi PDF
2. **Resilienza**: Fallback automatico in caso di errori di permessi
3. **Cross-platform**: Funziona su tutte le piattaforme MAUI
4. **Manutenibilità**: Facile da modificare in futuro (es. permettere all'utente di scegliere il percorso)
5. **Sandbox-friendly**: Compatibile con le restrizioni di sicurezza macOS

### Dove trovare i PDF salvati

#### macOS (Release/Production)
Su macOS in modalità Release, i PDF vengono salvati nella **cache dell'app**:
```bash
# Visualizzare i PDF salvati
ls -la ~/Library/Containers/com.adrianovisconti.gestioneviaggi/Data/Library/Caches/

# Aprire la cartella nel Finder
open ~/Library/Containers/com.adrianovisconti.gestioneviaggi/Data/Library/Caches/
```

#### Windows
```bash
# Percorso standard Downloads
C:\Users\[username]\Downloads\

# Fallback (se Downloads non accessibile)
C:\Users\[username]\AppData\Local\Packages\[AppId]\LocalCache\
```

### Troubleshooting

Se i PDF non vengono trovati:
1. Verificare i log dell'applicazione per il percorso effettivo utilizzato
2. Su macOS, usare sempre il comando `open` per aprire la cartella cache
3. L'app apre automaticamente il PDF dopo la generazione tramite `IPdfOpenerService.OpenPdfAsync()`

### Sviluppi Futuri

Possibili miglioramenti:
- Aggiungere un **file picker** per permettere all'utente di scegliere dove salvare il PDF
- Implementare una **preferenza utente** per il percorso di salvataggio predefinito
- Aggiungere un **dialog di conferma** dopo il salvataggio con link per aprire la cartella

---

## 🎨 Standardizzazione Colori e Font nelle Stampe PDF

### Il Problema

Prima della standardizzazione (marzo 2026), ogni printer PDF dell'applicazione definiva indipendentemente:
- Una **classe `BrandColors` privata** con colori duplicati
- **Costanti `FontSize*` private** con valori diversi tra printer

Questa situazione causava:
- **Inconsistenza visiva**: Report con colori e dimensioni font differenti
- **Duplicazione codice**: 6 definizioni identiche della classe `BrandColors`
- **Manutenzione difficile**: Per modificare un colore, bisognava intervenire su 6 file diversi
- **Due gruppi di font**: Standard (18/12/9/8) e Compact (16/11/8/7) senza una logica chiara

### La Soluzione Implementata

È stata effettuata una **centralizzazione completa** di tutti i colori e font in `ReportHeaderHelper`, trasformandolo nel **single source of truth** per lo stile visivo di tutti i report PDF.

#### File Centrale
**`Services/Printing/ReportHeaderHelper.cs`**

### Dettagli Tecnici

#### Colori Centralizzati

Tutti i colori del brand sono stati consolidati nella classe statica `ReportHeaderHelper.BrandColors`:

```csharp
public static class BrandColors
{
    // Colori Base (preesistenti)
    public static readonly string Primary = "#2B3A42";      // Dark Slate (testata, titoli)
    public static readonly string Secondary = "#8D99AE";    // Cool Grey (testo secondario)
    public static readonly string Accent = "#E74C3C";       // Rosso (evidenziazioni, alert)
    public static readonly string Text = "#000000";         // Nero (testo principale)
    public static readonly string LightGray = "#F0F0F0";   // Grigio chiaro (sfondi alternati)
    public static readonly string Border = "#CCCCCC";       // Grigio (bordi tabelle)

    // Colori Semantici (aggiunti con la standardizzazione)
    public static readonly string Success = "#27AE60";      // Verde (Entrate, Crediti, Positivo)
    public static readonly string Warning = "#F39C12";      // Arancione (Urgente, Attenzione)
    public static readonly string Danger = "#C0392B";       // Rosso scuro (Scaduto, Critico)

    // Colori Layout (aggiunti con la standardizzazione)
    public static readonly string GroupHeader = "#D5E8D4";  // Verde chiaro (Intestazioni gruppi)
    public static readonly string SubTotal = "#FFF2CC";     // Giallo chiaro (Subtotali)
    public static readonly string Total = "#DAE8FC";        // Blu chiaro (Totali generali)
    public static readonly string IvaHeader = "#E1F5FE";    // Azzurro chiaro (Sezioni IVA)
}
```

#### Font Size Centralizzati

Sono stati definiti **due set di font** per gestire diverse densità di layout:

```csharp
// Font Size Standard (Portrait, con spazio - es. Viaggi, RoomingList)
public const float FontSizeHeader = 18;
public const float FontSizeSubHeader = 12;
public const float FontSizeBody = 9;
public const float FontSizeSmall = 8;

// Font Size Compact (Landscape, tabelle dense - es. Fatture, Registro IVA, Transazioni)
public const float FontSizeHeaderCompact = 16;
public const float FontSizeSubHeaderCompact = 11;
public const float FontSizeBodyCompact = 8;
public const float FontSizeSmallCompact = 7;

// Font Size Extra
public const float FontSizeCaption = 7;  // Note legali e disclaimer
```

### File Modificati

Tutti i 6 printer PDF sono stati aggiornati per usare le definizioni centralizzate:

| File | Font Set Usato | Modifiche |
|------|----------------|-----------|
| `Services/Printing/FatturaAttivaPrinter.cs` | Compact | Rimossa classe `BrandColors` privata + costanti font |
| `Services/Printing/ViaggiPrinter.cs` | Standard | Rimossa classe `BrandColors` privata + costanti font |
| `Services/Printing/RoomingListPrinter.cs` | Standard | Rimossa classe `BrandColors` privata + costanti font |
| `Services/Printing/RegistroIvaPrinter.cs` | Compact | Rimossa classe `BrandColors` privata + costanti font |
| `Services/Printing/ScadenzarioPrinter.cs` | Compact | Rimossa classe `BrandColors` privata + costanti font |
| `Services/Printing/MovTransazioniPrinter.cs` | Compact | Rimossa classe `BrandColors` privata + costanti font |

### Pattern di Utilizzo

**Prima (approccio duplicato):**
```csharp
// Ogni printer aveva la propria definizione
private static class BrandColors
{
    public static readonly string Primary = "#2B3A42";
    public static readonly string Accent = "#E74C3C";
    // ... altri colori duplicati
}

private const float FontSizeHeader = 16;
private const float FontSizeBody = 8;

// Uso nel codice
.FontColor(BrandColors.Primary)
.FontSize(FontSizeBody)
```

**Dopo (approccio centralizzato):**
```csharp
// Nessuna definizione locale, solo uso diretto
.FontColor(ReportHeaderHelper.BrandColors.Primary)
.FontSize(ReportHeaderHelper.FontSizeBodyCompact)
```

### Verifica Implementazione

Per verificare che non ci siano più duplicazioni:

```bash
# Verifica assenza di classi BrandColors private
grep -r "private static class BrandColors" Services/Printing/
# Output atteso: nessun risultato

# Verifica assenza di costanti FontSize private
grep -r "private const float FontSize" Services/Printing/
# Output atteso: nessun risultato

# Compilazione senza errori
dotnet build -c Release -f net9.0-maccatalyst
# Output atteso: Compilazione completata, 0 errori
```

### Benefici Ottenuti

1. **Consistenza visiva totale**: Tutti i report hanno lo stesso look & feel
2. **Manutenibilità**: Modificare un colore o una dimensione in un solo punto
3. **Scalabilità**: Nuovi printer possono riutilizzare facilmente i colori/font standard
4. **Brand identity**: Facile implementare un rebrand globale modificando solo `ReportHeaderHelper`
5. **Leggibilità codice**: Nessuna duplicazione, codice più pulito e professionale
6. **DRY principle**: Don't Repeat Yourself - eliminata completamente la duplicazione

### Manutenzione Futura

Per modificare lo stile globale dei report PDF:
1. Modificare le costanti in `Services/Printing/ReportHeaderHelper.cs`
2. Ricompilare l'applicazione
3. Tutti i report rifletteranno automaticamente i nuovi valori

> [!NOTE]
> La distinzione tra font **Standard** e **Compact** è intenzionale e serve a ottimizzare la leggibilità in base al tipo di documento:
> - **Standard**: Per report portrait con poche colonne e contenuto descrittivo
> - **Compact**: Per report landscape con molte colonne e layout densi

### Data Implementazione
**16 Marzo 2026** - Standardizzazione completata su tutti i 6 printer PDF del progetto
