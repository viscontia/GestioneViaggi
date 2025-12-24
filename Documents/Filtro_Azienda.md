# Filtro Applicativo per Azienda

> Questo documento spiega come implementare il filtro per `azienda_id` nei servizi C# dopo la rimozione del layer `tenant_id`.

## Contesto

Con il refactoring del 2024-12-24, il campo `tenant_id` è stato rimosso da tutte le tabelle.  
L'isolamento dei dati è ora gestito **a livello applicativo** usando `azienda_id`.

## Ottenere l'Azienda Corrente

```csharp
// Iniettare ISessionManager nel servizio
private readonly ISessionManager _sessionManager;

// Ottenere l'azienda corrente
int? aziendaId = _sessionManager.GetCurrentAziendaId();
```

---

## Esempi di Implementazione

### 1. GetAll con Filtro Azienda

```csharp
public async Task<List<Cliente>> GetAllAsync()
{
    var aziendaId = _sessionManager.GetCurrentAziendaId();
    
    await using var connection = await _databaseService.GetConnectionAsync();
    var sql = "SELECT * FROM ana_clienti WHERE azienda_fk = @AziendaId ORDER BY cliente_id";
    
    await using var command = new NpgsqlCommand(sql, connection);
    command.Parameters.AddWithValue("AziendaId", aziendaId ?? (object)DBNull.Value);
    
    // ... esegui query
}
```

### 2. Create con Azienda

```csharp
public async Task<Cliente> CreateAsync(Cliente entity)
{
    var aziendaId = _sessionManager.GetCurrentAziendaId();
    
    var sql = @"
        INSERT INTO ana_clienti (azienda_fk, cliente_nome, cliente_cognome, ...)
        VALUES (@AziendaId, @Nome, @Cognome, ...)
        RETURNING cliente_id";
    
    command.Parameters.AddWithValue("AziendaId", aziendaId ?? (object)DBNull.Value);
    // ... altri parametri
}
```

### 3. Update con Verifica Azienda

```csharp
public async Task<Cliente> UpdateAsync(Cliente entity)
{
    var aziendaId = _sessionManager.GetCurrentAziendaId();
    
    // Aggiunge azienda_fk al WHERE per sicurezza
    var sql = @"
        UPDATE ana_clienti 
        SET cliente_nome = @Nome, ...
        WHERE cliente_id = @Id AND azienda_fk = @AziendaId";
}
```

### 4. Delete con Verifica Azienda

```csharp
public async Task<bool> DeleteAsync(int id)
{
    var aziendaId = _sessionManager.GetCurrentAziendaId();
    
    var sql = "DELETE FROM ana_clienti WHERE cliente_id = @Id AND azienda_fk = @AziendaId";
}
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
