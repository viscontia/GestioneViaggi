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
Utilizzato per l'ambiente di produzione in Cloud.
```json
{
  "ConnectionStrings": {
    "PostgreSQL": "Host=aws-1-eu-central-1.pooler.supabase.com;Port=5432;Database=postgres;Username=postgres.wqbqvhshojbfuwcuiams;Password=U9Y7KSjQVfZ3N1Ca;Pooling=true;MinPoolSize=1;MaxPoolSize=20;Timeout=30;CommandTimeout=30;SSL Mode=Require;Trust Server Certificate=true;"
  }
}
```

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
Credenziali per il database in Cloud.

| Parametro | Valore |
|-----------|--------|
| **Project Name** | `Gestione Viaggi` |
| **Project ID** | `wqbqvhshojbfuwcuiams` |
| **Host** | `aws-1-eu-central-1.pooler.supabase.com` |
| **Porta** | `5432` |
| **Database** | `postgres` |
| **Username** | `postgres.wqbqvhshojbfuwcuiams` |
| **Password** | `U9Y7KSjQVfZ3N1Ca` |
| **Session Pooler (URI)** | `postgresql://postgres.wqbqvhshojbfuwcuiams:U9Y7KSjQVfZ3N1Ca@aws-1-eu-central-1.pooler.supabase.com:5432/postgres` |
| **Type** | `URI` |

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
