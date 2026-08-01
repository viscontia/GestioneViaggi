# Gestione Check - Architettura Sistema di Validazione

## 📋 Indice
1. [Principi Architetturali](#principi-architetturali)
2. [Struttura delle Cartelle](#struttura-delle-cartelle)
3. [Naming Conventions](#naming-conventions)
4. [Categorie di Validazione](#categorie-di-validazione)
5. [Integrazione con FluentValidation](#integrazione-con-fluentvalidation)
6. [DbErrorTranslator](#dberrortranslator)
7. [SmtpErrorTranslator](#smtperrortranslator)
8. [Catalogo Validatori](#catalogo-validatori)

---

## 🎯 Principi Architetturali

### Obiettivi
1. **Centralizzazione**: Un solo punto di verità per ogni regola di validazione
2. **Riusabilità**: Ogni validatore deve essere utilizzabile in qualsiasi entità
3. **Manutenibilità**: Modifica in un punto = beneficio globale
4. **Testabilità**: Ogni validatore è testabile in isolamento
5. **Consistenza**: Stessi messaggi di errore in tutta l'applicazione

### Design Pattern Utilizzati
- **Strategy Pattern**: Ogni validatore implementa un'interfaccia comune
- **Fluent Interface**: Validatori concatenabili per regole composite
- **Extension Methods**: Integrazione seamless con FluentValidation

---

## 📁 Struttura delle Cartelle

```
GestioneViaggi/
├── Validation/
│   ├── Core/
│   │   ├── IValidator.cs                    // Interface base
│   │   ├── ValidationResult.cs              // DTO per risultati
│   │   └── ValidationMessages.cs            // Messaggi centralizzati (ITA)
│   │
│   ├── Syntax/                               // Validatori sintattici/formali
│   │   ├── ItalianFiscalValidator.cs        // Partita IVA, Codice Fiscale
│   │   ├── EmailValidator.cs                // Email standard, PEC
│   │   ├── PhoneValidator.cs                // Telefoni (IT, internazionali)
│   │   ├── TextValidator.cs                 // Stringhe (trim, lunghezza)
│   │   └── CodeValidator.cs                 // Codici (SDI, ATECO, ecc.)
│   │
│   ├── Semantic/                             // Validatori semantici/logici
│   │   ├── DateValidator.cs                 // Range date, logica temporale
│   │   ├── NumericValidator.cs              // Range numerici, positività
│   │   └── GeographicValidator.cs           // CAP, coordinate, province
│   │
│   ├── Business/                             // Regole di business specifiche
│   │   ├── AziendaBusinessValidator.cs      // Regole complesse ana_aziende
│   │   ├── ViaggioBusinessValidator.cs      // Logica viaggi
│   │   └── ... (altri validatori entity-specific)
│   │
│   ├── Extensions/
│   │   └── FluentValidationExtensions.cs    // Extension methods per FluentValidation
│   │
│   └── Database/
│       └── DbErrorTranslator.cs             // Traduce errori PostgreSQL -> ITA
│
├── Services/
│   └── Validation/
│       └── ValidationService.cs             // Orchestrator (se necessario)
```

---

## 🏷️ Naming Conventions

### Metodi di Validazione
Tutti i metodi pubblici seguono il pattern:

```
Check{Entity}{Property}{Rule}
```

**Esempi:**
- `CheckPartitaIva()` → Generico, riutilizzabile
- `CheckCodiceFiscale()` → Generico
- `CheckEmailFormat()` → Sintassi email
- `CheckPecFormat()` → Sintassi PEC (email certificata)
- `CheckTelefonoItaly()` → Formato telefono italiano
- `CheckDateNotFuture()` → Data non futura
- `CheckPositiveDecimal()` → Numero positivo
- `CheckNotEmptyTrimmed()` → Stringa non vuota dopo trim

### Classi
- **Sintattici**: `{Domain}Validator` (es. `ItalianFiscalValidator`)
- **Semantici**: `{Concept}Validator` (es. `DateValidator`)
- **Business**: `{Entity}BusinessValidator` (es. `AziendaBusinessValidator`)

### Risultati
```csharp
public class ValidationResult
{
    public bool IsValid { get; set; }
    public string ErrorMessage { get; set; }  // In italiano
    public string ErrorCode { get; set; }     // Codice tecnico (CHK_PIVA_001)
}
```

---

## 🔍 Categorie di Validazione

### 1. **Syntax Validators** (Validatori Sintattici)
Verificano la **forma** del dato senza semantica.

**Caratteristiche:**
- Regex-based o algoritmi standard (es. checksum)
- No accesso al DB
- No dipendenze da altre entità
- Deterministici e veloci

**Esempi:**
- Partita IVA: 11 cifre numeriche
- Codice Fiscale: Pattern alfanumerico 16 caratteri
- Email: RFC 5322 compliant
- PEC: Email + dominio certificato
- Telefono: Pattern +39 / fisso / mobile

### 2. **Semantic Validators** (Validatori Semantici)
Verificano la **logica** del dato in contesto.

**Caratteristiche:**
- Dipendono da valori multipli
- Confronti, range, date logic
- No accesso al DB
- Context-aware

**Esempi:**
- Data inizio < Data fine
- Capitale sociale > 0
- Età >= 18 anni
- Coordinate geografiche valide
- **Plausibilità dell'anno** (`DateValidator.CheckAnnoPlausibile`, soglie `AnnoMinimo`/`AnnoMassimo`)

> ⚠️ **Relativo non basta.** Un controllo che confronta due date fra loro non intercetta un refuso
> sull'anno, perché il refuso sposta entrambe le date insieme e ordine e durata restano corretti.
> Serve almeno un controllo **assoluto**. Caso reale: partenza salvata con anno 262 (vedi
> `Documents/Digitazione_Date.md`). Da qui anche `DateValidator.MotivoDaConfermare`, che non vieta ma
> chiede conferma sulle date insolite — l'unico modo di cogliere un refuso *dentro* l'intervallo lecito.

### 3. **Business Validators** (Validatori di Business)
Verificano **regole di dominio complesse**.

**Caratteristiche:**
- Possono accedere al DB (async)
- Verificano unicità, foreign keys, stati
- Entity-specific ma componibili
- Possono chiamare Syntax/Semantic validators

**Esempi:**
- Partita IVA unica nel sistema
- REA unico per provincia
- Azienda in stato attivo per creare viaggio
- Budget disponibile sufficiente

---

## 🔗 Integrazione con FluentValidation

### Extension Methods Pattern

```csharp
// FluentValidationExtensions.cs
public static class FluentValidationExtensions
{
    public static IRuleBuilderOptions<T, string> CheckPartitaIva<T>(
        this IRuleBuilder<T, string> ruleBuilder)
    {
        return ruleBuilder
            .Must(value => ItalianFiscalValidator.CheckPartitaIva(value).IsValid)
            .WithMessage(ValidationMessages.PartitaIvaInvalid);
    }
    
    public static IRuleBuilderOptions<T, string> CheckCodiceFiscale<T>(
        this IRuleBuilder<T, string> ruleBuilder)
    {
        return ruleBuilder
            .Must(value => ItalianFiscalValidator.CheckCodiceFiscale(value).IsValid)
            .WithMessage(ValidationMessages.CodiceFiscaleInvalid);
    }
}
```

### Utilizzo in Entity Validator

```csharp
// AziendaValidator.cs (FluentValidation)
public class AziendaValidator : AbstractValidator<Azienda>
{
    public AziendaValidator()
    {
        RuleFor(x => x.PartitaIva)
            .NotEmpty()
            .CheckPartitaIva();  // Extension method!
            
        RuleFor(x => x.CodiceFiscale)
            .CheckCodiceFiscale()
            .When(x => !string.IsNullOrEmpty(x.CodiceFiscale));
            
        RuleFor(x => x.Pec)
            .CheckPecFormat()
            .When(x => !string.IsNullOrEmpty(x.Pec));
            
        RuleFor(x => x.CapitaleSociale)
            .CheckPositiveDecimal()
            .When(x => x.CapitaleSociale.HasValue);
    }
}
```

---

## 🗄️ DbErrorTranslator

### Responsabilità
Traduce vincoli PostgreSQL in messaggi user-friendly italiani.

### Struttura

```csharp
public class DbErrorTranslator
{
    private static readonly Dictionary<string, string> ConstraintMessages = new()
    {
        // Check Constraints
        ["chk_partita_iva"] = "Partita IVA non valida. Deve contenere esattamente 11 cifre.",
        ["chk_codice_fiscale"] = "Codice Fiscale non valido. Deve essere alfanumerico di 11-16 caratteri.",
        ["chk_pec"] = "Indirizzo PEC non valido.",
        ["chk_telefono_principale"] = "Numero di telefono non valido.",
        ["chk_codice_sdi"] = "Codice Destinatario SDI non valido. Deve essere di 7 caratteri alfanumerici.",
        ["chk_forma_giuridica"] = "Forma giuridica obbligatoria.",
        ["ana_aziende_capitale_sociale_check"] = "Il capitale sociale deve essere un valore positivo.",
        
        // Unique Constraints
        ["partita_iva_unique"] = "Partita IVA già presente nel sistema.",
        ["idx_unique_codice_fiscale"] = "Codice Fiscale già presente nel sistema.",
        ["rea_unique"] = "Numero REA già registrato per questa provincia.",
        
        // Foreign Keys
        ["ana_aziende_rea_provincia_fk_fkey"] = "Provincia REA non valida.",
    };

    public static string Translate(PostgresException ex)
    {
        if (!string.IsNullOrEmpty(ex.ConstraintName) && 
            ConstraintMessages.TryGetValue(ex.ConstraintName, out var message))
        {
            return message;
        }
        
        // Fallback generico
        return ex.SqlState switch
        {
            "23505" => "Valore duplicato: il record è già presente nel database.",
            "23503" => "Riferimento non valido: l'entità collegata non esiste.",
            "23514" => "Valore non valido: il dato non rispetta i vincoli definiti.",
            _ => $"Errore database: {ex.MessageText}"
        };
    }
}
```

### Utilizzo nei Component

```csharp
try
{
    await _dbService.SaveAziendaAsync(azienda);
    _snackbar.Add("Azienda salvata con successo.", Severity.Success);
}
catch (PostgresException ex)
{
    var userMessage = DbErrorTranslator.Translate(ex);
    _snackbar.Add(userMessage, Severity.Error);
}
```

### DatabaseExceptionHelper (usato dai CRUD service)

I servizi CRUD basati su `BaseCrudService` non usano `DbErrorTranslator` ma `Helpers/DatabaseExceptionHelper.WrapException(ex, TableName)`, che traduce la `PostgresException` in `GestioneViaggiException` con messaggio ITA. Due punti di estensione:

- **Messaggio dedicato per unique constraint** → aggiungere una riga in `DescribeUniqueConstraint(ex.ConstraintName)` (dice all'utente *quale* campo è duplicato). Esempi mappati: `uq_web_tour_contenuti_slug` → *"Esiste già un tour con questo indirizzo web…"*, `web_tour_contenuti_viaggio_id_fk_key` → *"Questo viaggio ha già una scheda di contenuti web."*
- **Nome tabella nei messaggi generici** → `TranslateTableName()` traduce il nome tecnico in etichetta ITA (mai esporre il nome grezzo della tabella all'utente). Aggiungere qui i nuovi elementi.

---

## 📧 SmtpErrorTranslator

### Responsabilità
Punto **UNICO** dei messaggi d'errore SMTP (ITA) — mirror di `DbErrorTranslator` ma per il dominio rete/posta (connessione, DNS, TLS, autenticazione) invece che per i vincoli PostgreSQL.

### Struttura
Classe statica `Services/Email/SmtpErrorTranslator.cs`:

```csharp
public enum SmtpPhase { Connect, Authenticate }

public static class SmtpErrorTranslator
{
    public static string Translate(Exception ex, SmtpPhase phase, string host, int port) => ex switch
    {
        SocketException se when se.SocketErrorCode is SocketError.HostNotFound
                                                    or SocketError.NoData
                                                    or SocketError.TryAgain
            => $"Server di posta non trovato (DNS): controlla il nome host \"{host}\".",
        SocketException se when se.SocketErrorCode == SocketError.ConnectionRefused
            => $"Connessione rifiutata sulla porta {port}: porta chiusa o servizio non attivo su \"{host}\".",
        SocketException
            => $"Rete non raggiungibile verso \"{host}:{port}\": controlla la connessione.",
        SslHandshakeException
            => $"Errore TLS/SSL su \"{host}:{port}\": metodo di sicurezza o certificato non compatibili con la porta.",
        AuthenticationException
            => "Credenziali rifiutate: username o password errati.",
        SmtpCommandException sce
            => $"Errore SMTP dal server: {sce.Message}",
        SmtpProtocolException
            => "Errore di protocollo SMTP nella comunicazione con il server.",
        OperationCanceledException
            => $"Timeout: nessuna risposta da \"{host}:{port}\".",
        _ => "Errore imprevisto durante l'operazione SMTP. Dettaglio tecnico nei log."
    };
}
```

### Diagnostica timeout (VPN vs host irraggiungibile)
Un `OperationCanceledException` da solo non dice se il problema è un host morto o una porta bloccata da firewall/VPN. `IsHostReachableOnWebAsync(host)` fa una probe TCP breve (timeout 4s) su **443 poi 80**: se una delle due risponde, l'host è raggiungibile sul web ma la porta SMTP no → `TimeoutMessage(hostReachableOnWeb: true, host, port)` restituisce un messaggio che invita a **disattivare la VPN** (molti server di posta bloccano gli IP VPN/datacenter); se nessuna risponde → messaggio "host irraggiungibile".

### Utilizzo
- `AziendaSmtpService.TestConnectionAsync` → cattura le eccezioni MailKit/Socket del test connessione e le traduce con `Translate(ex, SmtpPhase, host, port)`; sui timeout chiama `IsHostReachableOnWebAsync` per scegliere il messaggio giusto.
- Predisposto per l'invio effettivo (non solo il test) — stesso punto da riusare quando `SmtpEmailSender` dovrà tradurre gli errori di invio.

### Come si estende
Aggiungere un nuovo ramo allo `switch` di `Translate()` per un nuovo tipo di eccezione (pattern match su tipo/proprietà, come `SocketException se when ...`). Non duplicare la logica altrove: qualsiasi nuovo punto che parli SMTP/MailKit deve passare da qui.

---

## 📚 Catalogo Validatori

### Validatori già mappati da ana_aziende

| Check Constraint DB | Validatore Client | Metodo | File |
|---------------------|-------------------|--------|------|
| `chk_partita_iva` | ItalianFiscalValidator | `CheckPartitaIva()` | Syntax/ItalianFiscalValidator.cs |
| `chk_codice_fiscale` | ItalianFiscalValidator | `CheckCodiceFiscale()` | Syntax/ItalianFiscalValidator.cs |
| `chk_pec` | EmailValidator | `CheckPecFormat()` | Syntax/EmailValidator.cs |
| `chk_telefono_principale` | PhoneValidator | `CheckTelefonoItaly()` | Syntax/PhoneValidator.cs |
| `chk_codice_sdi` | CodeValidator | `CheckCodiceSdi()` | Syntax/CodeValidator.cs |
| `chk_forma_giuridica` | TextValidator | `CheckNotEmptyTrimmed()` | Syntax/TextValidator.cs |
| `ana_aziende_capitale_sociale_check` | NumericValidator | `CheckPositiveDecimal()` | Semantic/NumericValidator.cs |

### Validatori Generici Riutilizzabili

| Validatore Client | Metodo | Descrizione | File |
|-------------------|--------|-------------|------|
| GeographicValidator | `CheckCap()` | Verifica CAP italiano (5 cifre, zero significativo) | Semantic/GeographicValidator.cs |
| DateValidator | `CheckDateRange()` | Confronto date: fine >= inizio | Semantic/DateValidator.cs |
| DateValidator | `CheckNotFuture()` | Verifica data non futura | Semantic/DateValidator.cs |
| DateValidator | `CheckNotPast()` | Verifica data non passata | Semantic/DateValidator.cs |
| DateValidator | `CheckDateBetween()` | Data in range specifico | Semantic/DateValidator.cs |
| DateValidator | `CheckMinimumAge()` | Verifica età minima da data nascita | Semantic/DateValidator.cs |

---

## 🚀 Roadmap Implementazione

### Fase 1: Core Infrastructure ✅ COMPLETATA
- [x] Creare cartella `Validation/Core/`
- [x] Implementare `ValidationResult.cs`
- [x] Implementare `ValidationMessages.cs` (resource file ITA)

### Fase 2: Syntax Validators (Priority 1) ✅ COMPLETATA
- [x] `ItalianFiscalValidator.cs` (Partita IVA, CF)
- [x] `EmailValidator.cs` (Email, PEC)
- [x] `PhoneValidator.cs` (Telefoni IT)
- [x] `TextValidator.cs` (Trim, lunghezza)
- [x] `CodeValidator.cs` (SDI, codici vari)

### Fase 3: Semantic Validators ✅ COMPLETATA
- [x] `NumericValidator.cs` (Range, positività)
- [x] `GeographicValidator.cs` (CAP italiano)
- [x] `DateValidator.cs` (Range date, logica temporale, età)

### Fase 4: Integration 🔜 PROSSIMA FASE
- [ ] `FluentValidationExtensions.cs`
- [ ] `DbErrorTranslator.cs`

### Fase 5: Business Validators (On-Demand)
- [ ] Creati quando necessari per regole complesse

---

## 📝 Note Tecniche

### Threading Safety
Tutti i validatori sintattici/semantici sono **stateless** e thread-safe.

### Performance
- Validatori sintattici: < 1ms (regex compiled)
- Validatori semantici: < 5ms (calcoli in-memory)
- Validatori business: dipende da DB access

### Localizzazione
Messaggi attualmente in italiano. Futura estensione con `.resx` per multi-lingua.

### Testing
Ogni validatore avrà corrispondente test unitario con:
- ✅ Happy path
- ❌ Edge cases
- ⚠️ Boundary values

---

## 🔄 Versioning

**Versione:** 1.0  
**Data:** 2024-12-24  
**Autore:** Architecture Team  
**Status:** 🟢 Approved - Ready for Implementation
