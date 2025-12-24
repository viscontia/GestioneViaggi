# Troubleshooting: Database Connection Issues

## Symptoms
- ❌ Login fallisce con "Data Base non raggiungibile"
- ❌ AppInitializer non completa l'inizializzazione
- ❌ Nessun messaggio di errore nei logs

## Debug Steps

### 1. **Verifica Logging Console**
Quando lanci l'app, guarda la console DEBUG per questi messaggi:

```
[INFO] Starting application initialization...
[INFO] Connessione al database...
[INFO] Database connection pool initialized successfully
[INFO] Caricamento sessione...
[INFO] Session manager initialized successfully
[INFO] Ripristino stato autenticazione...
[INFO] Application initialization completed successfully
```

Se uno di questi è assente → problema in quella fase.

---

### 2. **Se vedi "Connessione al database..."**

**Problema**: InitializePoolAsync() sta fallendo silenziosamente.

**Causa probabile**: 
- Connection string sbagliata
- Database non accessibile da 127.0.0.1:5432
- PostgreSQL non avviato

**Fix**:
```bash
# Verifica che PostgreSQL sia avviato
pg_isready -h 127.0.0.1 -p 5432 -U postgres

# Output atteso:
# 127.0.0.1:5432 - accepting connections
```

Se non vedi "accepting connections":
1. Avvia PostgreSQL
2. Verifica la password in MauiProgram.cs (riga 40)

---

### 3. **Se vedi "Caricamento sessione..."**

**Problema**: SessionManager.InitializeAsync() fallisce.

**Causa probabile**:
- SecureStorage non disponibile sulla piattaforma
- Permessi insufficienti

**Fix**:
Aggiungi questa riga in `MauiProgram.cs` PRIMA del `.Build()`:

```csharp
#if DEBUG
builder.Logging.AddDebug();
#endif
```

Già presente? Verifica i logs per messaggi di errore dettagliati.

---

### 4. **Se vedi "Ripristino stato autenticazione..."**

**Problema**: CustomAuthStateProvider.NotifyAuthenticationStateChanged() fallisce.

**Causa probabile**:
- InjectionError in AppInitializer
- AuthStateProvider non registrato correttamente

**Fix**:
Verifica MauiProgram.cs:
```csharp
builder.Services.AddScoped<AuthenticationStateProvider, CustomAuthStateProvider>();
builder.Services.AddAuthorizationCore();
```

---

### 5. **Errore Critico: "Contatta l'assistenza tecnica"**

**Azione**:
1. **Cancella la build**:
   ```bash
   rm -rf bin obj
   dotnet clean
   dotnet build -f net9.0-maccatalyst
   ```

2. **Verifica la connection string** in `MauiProgram.cs` riga 40:
   ```csharp
   "Host=127.0.0.1;Port=5432;Database=gestione_viaggi;Username=postgres;Password=postgres;..."
   ```

3. **Testa la connessione manualmente**:
   ```bash
   psql -h 127.0.0.1 -U postgres -d gestione_viaggi -c "SELECT 1"
   ```

   Se ricevi `1` → PostgreSQL OK
   Se ricevi errore → Fix la connessione

---

## Common Issues & Solutions

### **"Unable to connect to host"**
```
Causa: PostgreSQL non avviato o non raggiungibile
Soluzione:
  macOS: brew services start postgresql
  Linux: sudo systemctl start postgresql
  Windows: Avvia PostgreSQL service dal Control Panel
```

### **"Password authentication failed"**
```
Causa: Password errata nel ConnectionString
Soluzione:
  1. Verifica la password in MauiProgram.cs
  2. Testa: psql -h 127.0.0.1 -U postgres -W
  3. Se password errata: ALTER USER postgres WITH PASSWORD 'nuova_password';
```

### **"Database 'gestione_viaggi' does not exist"**
```
Causa: Database non creato
Soluzione:
  createdb -h 127.0.0.1 -U postgres gestione_viaggi
```

### **"AppInitializer stuck at loading"**
```
Causa: OnInitializedAsync() ha un deadlock o await bloccato
Soluzione:
  1. Verifica che DatabaseConnectionManager.InitializePoolAsync() completi in < 5s
  2. Aggiungi timeout:
     Task initTask = DatabaseConnectionManager.InitializePoolAsync();
     var completed = await Task.WhenAny(
         initTask,
         Task.Delay(TimeSpan.FromSeconds(10))
     );
     if (!completed.IsCompleted) 
         throw new TimeoutException("Database initialization timeout");
```

---

## Enable Full Diagnostics

Aggiungi questo nel `MauiProgram.cs` PRIMA di `.Build()`:

```csharp
builder.Logging.ClearProviders();
builder.Logging.AddDebug();
builder.Logging.AddConsole();

#if DEBUG
builder.Services.AddLogging(loggingBuilder =>
{
    loggingBuilder.AddDebug();
    loggingBuilder.SetMinimumLevel(LogLevel.Debug);
});
#endif
```

Questo abilita logging completo per:
- ✅ DatabaseConnectionManager
- ✅ SessionManager  
- ✅ AuthenticationService
- ✅ CustomAuthStateProvider
- ✅ AppInitializer

---

## Verify Installation

```bash
# Verifica .NET version
dotnet --version
# Expected: >= 9.0.0

# Verifica PostgreSQL
psql --version
# Expected: >= 12.0

# Verifica NuGet packages
cd /path/to/GestioneViaggi
dotnet list package
# Controlla che Npgsql >= 8.0.5 sia installato
```

---

## Nuclear Option: Clean Rebuild

Se niente funziona:

```bash
cd /Users/adrianovisconti/Documents/Sviluppo\ Software/MAUI/GestioneViaggi

# 1. Pulisci tutto
rm -rf bin obj .vs *.log

# 2. Restore nuget
dotnet restore

# 3. Build
dotnet build -f net9.0-maccatalyst -v diag

# 4. Se ancora fallisce, copia l'ultimo errore:
#    e forniscilo per debug
```

---

## Next Steps

1. **Lancia l'app** e guarda i logs di AppInitializer
2. **Condividi il primo messaggio d'errore** che vedi
3. Se tutto completa OK:
   - Verifica che **Login page** si carichi
   - Testa le credenziali
   - Verifica i logs di `IsDbConnectableAsync()`

