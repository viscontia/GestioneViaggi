# Filtro Applicativo per Azienda

> Questo documento spiega come implementare il filtro per `azienda_id` nei servizi C# dopo la rimozione del layer `tenant_id`.

## Contesto

Con il refactoring del 2024-12-24, il campo `tenant_id` è stato rimosso da tutte le tabelle.  
L'isolamento dei dati è ora gestito **a livello applicativo** usando `azienda_id`.

---

## Ruoli e Accesso

| Ruolo | Accesso |
|-------|---------|
| **SuperAdmin** | Tutte le aziende, tutti i dati |
| **Altri ruoli** | Solo dati della propria azienda |

---

## Helper nel Servizio Base

Aggiungere questo metodo helper in ogni servizio che richiede filtro:

```csharp
private readonly ISessionManager _sessionManager;

/// <summary>
/// Verifica se l'utente corrente è SuperAdmin
/// </summary>
private bool IsSuperAdmin()
{
    var session = _sessionManager.GetSessionAsync().Result;
    return session?.User?.IsSuperAdmin ?? false;
}

/// <summary>
/// Restituisce aziendaId se non SuperAdmin, null se SuperAdmin (accesso globale)
/// </summary>
private int? GetFilteredAziendaId()
{
    if (IsSuperAdmin()) return null; // Nessun filtro per SuperAdmin
    return _sessionManager.GetCurrentAziendaId();
}
```

---

## Esempi di Implementazione

### 1. GetAll con Filtro Azienda (SuperAdmin bypass)

```csharp
public async Task<List<Cliente>> GetAllAsync()
{
    var aziendaId = GetFilteredAziendaId();
    
    await using var connection = await _databaseService.GetConnectionAsync();
    
    string sql;
    if (aziendaId.HasValue)
    {
        // Utente normale: filtra per azienda
        sql = "SELECT * FROM ana_clienti WHERE azienda_fk = @AziendaId ORDER BY cliente_id";
    }
    else
    {
        // SuperAdmin: vede tutti
        sql = "SELECT * FROM ana_clienti ORDER BY cliente_id";
    }
    
    await using var command = new NpgsqlCommand(sql, connection);
    if (aziendaId.HasValue)
    {
        command.Parameters.AddWithValue("AziendaId", aziendaId.Value);
    }
    
    // ... esegui query
}
```

### 2. Create con Azienda

```csharp
public async Task<Cliente> CreateAsync(Cliente entity)
{
    // Per Create, usiamo sempre l'azienda effettiva (anche SuperAdmin deve specificarla)
    var aziendaId = _sessionManager.GetCurrentAziendaId();
    
    if (!aziendaId.HasValue && !IsSuperAdmin())
    {
        throw new InvalidOperationException("Azienda non impostata per l'utente corrente");
    }
    
    // SuperAdmin: usa l'aziendaId passato nell'entity se presente
    var effectiveAziendaId = aziendaId ?? entity.AziendaFk;
    
    var sql = @"
        INSERT INTO ana_clienti (azienda_fk, cliente_nome, cliente_cognome, ...)
        VALUES (@AziendaId, @Nome, @Cognome, ...)
        RETURNING cliente_id";
    
    command.Parameters.AddWithValue("AziendaId", effectiveAziendaId ?? (object)DBNull.Value);
}
```

### 3. Update con Verifica Azienda

```csharp
public async Task<Cliente> UpdateAsync(Cliente entity)
{
    var aziendaId = GetFilteredAziendaId();
    
    string sql;
    if (aziendaId.HasValue)
    {
        // Utente normale: verifica anche azienda
        sql = @"
            UPDATE ana_clienti 
            SET cliente_nome = @Nome, ...
            WHERE cliente_id = @Id AND azienda_fk = @AziendaId";
    }
    else
    {
        // SuperAdmin: può modificare qualsiasi record
        sql = @"
            UPDATE ana_clienti 
            SET cliente_nome = @Nome, ...
            WHERE cliente_id = @Id";
    }
    
    // ... parametri
}
```

### 4. Delete con Verifica Azienda

```csharp
public async Task<bool> DeleteAsync(int id)
{
    var aziendaId = GetFilteredAziendaId();
    
    string sql;
    if (aziendaId.HasValue)
    {
        sql = "DELETE FROM ana_clienti WHERE cliente_id = @Id AND azienda_fk = @AziendaId";
    }
    else
    {
        // SuperAdmin: può eliminare qualsiasi record
        sql = "DELETE FROM ana_clienti WHERE cliente_id = @Id";
    }
}
```

### 5. GetById con Verifica Azienda

```csharp
public async Task<Cliente?> GetByIdAsync(int id)
{
    var aziendaId = GetFilteredAziendaId();
    
    string sql;
    if (aziendaId.HasValue)
    {
        sql = "SELECT * FROM ana_clienti WHERE cliente_id = @Id AND azienda_fk = @AziendaId";
    }
    else
    {
        sql = "SELECT * FROM ana_clienti WHERE cliente_id = @Id";
    }
}
```

---

## Pattern Compatto con Query Builder

Per ridurre duplicazione, usare un helper:

```csharp
private string BuildAziendaWhereClause(string baseColumn = "azienda_fk")
{
    var aziendaId = GetFilteredAziendaId();
    return aziendaId.HasValue ? $" AND {baseColumn} = @AziendaId" : "";
}

// Uso:
var sql = $"SELECT * FROM ana_clienti WHERE cliente_id = @Id{BuildAziendaWhereClause()}";
```

---

## Tabelle che Richiedono Filtro

| Tabella | Colonna FK |
|---------|------------|
| `ana_clienti` | `azienda_fk` |
| `ana_viaggi` | `azienda_id` |
| `ana_date_viaggi` | `azienda_id` |
| `ana_aziende_sedi` | `azienda_fk` |
| `ana_aziende_banche` | `azienda_fk` |
| `ana_aziende_contatti` | `azienda_fk` |
| `ana_aziende_email` | `azienda_fk` |
| `ana_aziende_smtp` | `azienda_fk` |
| `ana_aziende_logo` | `azienda_fk` |
| `reparti_aziendali` | `azienda_fk` |

## Tabelle SENZA Filtro (dati condivisi)

- `ana_geo_*` (comuni, province, regioni)
- `ana_tipo_*` (tipi vari)
- `ana_mezzi_*` (marche, modelli)
- `user_roles`

---

## Indici Creati

Sono stati creati indici su tutte le colonne `azienda_fk` per performance:

```sql
CREATE INDEX idx_ana_clienti_azienda ON ana_clienti(azienda_fk);
CREATE INDEX idx_ana_viaggi_azienda ON ana_viaggi(azienda_id);
-- ... altri 9 indici
```
