using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using GestioneViaggi.Helpers;
using Microsoft.Extensions.Logging;
using Npgsql;
using System.Data;
using System.Text.Json;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Implementazione base per operazioni CRUD su database PostgreSQL.
/// Supporta multi-tenancy attraverso ITenantContext.
/// </summary>
/// <typeparam name="T">Tipo di entità che eredita da BaseEntity</typeparam>
public abstract class BaseCrudService<T> : ICrudService<T> where T : BaseEntity, new()
{
    protected readonly IDatabaseService _databaseService;
    protected readonly ILogger _logger;
    protected readonly ITenantContext? _tenantContext;

    protected abstract string TableName { get; }
    protected abstract string IdColumnName { get; }

    /// <summary>
    /// Nome della colonna FK per il tenant (es. "azienda_id_fk").
    /// Ritornare NULL se l'entità non è tenant-scoped (es. geo_province).
    /// Override in servizi che richiedono multi-tenancy.
    /// </summary>
    protected virtual string? TenantColumnName => null;

    protected BaseCrudService(IDatabaseService databaseService, ILogger logger, ITenantContext? tenantContext = null)
    {
        _databaseService = databaseService;
        _logger = logger;
        _tenantContext = tenantContext;
    }

    /// <summary>
    /// Verifica se l'utente corrente può accedere ai dati di una specifica azienda.
    /// SuperAdmin: sempre true. Altri ruoli: true solo se aziendaId == UserInfo.AziendaId
    /// </summary>
    protected async Task<bool> CanAccessAziendaAsync(int aziendaId)
    {
        if (_tenantContext == null)
        {
            _logger.LogWarning("TenantContext not injected - allowing access (backward compatibility)");
            return true;
        }

        return await _tenantContext.CanAccessAziendaAsync(aziendaId);
    }

    /// <summary>
    /// Solleva UnauthorizedAccessException se l'utente non può accedere ai dati dell'azienda.
    /// </summary>
    protected async Task ValidateTenantAccessAsync(int aziendaId)
    {
        if (_tenantContext == null)
        {
            _logger.LogWarning("TenantContext not injected - skipping validation (backward compatibility)");
            return;
        }

        await _tenantContext.ValidateAccessAsync(aziendaId);
    }

    /// <summary>
    /// Restituisce l'AziendaId dell'utente corrente (NULL per SuperAdmin).
    /// </summary>
    protected async Task<int?> GetCurrentAziendaIdAsync()
    {
        if (_tenantContext == null)
        {
            _logger.LogWarning("TenantContext not injected - returning NULL");
            return null;
        }

        return await _tenantContext.GetCurrentAziendaIdAsync();
    }

    /// <summary>
    /// Genera la clausola WHERE per filtrare per tenant.
    /// Se TenantColumnName è NULL o user è SuperAdmin, ritorna stringa vuota.
    /// </summary>
    protected async Task<string> GetTenantFilterWhereClauseAsync()
    {
        if (string.IsNullOrWhiteSpace(TenantColumnName) || _tenantContext == null)
        {
            return string.Empty;
        }

        return await _tenantContext.GetTenantFilterSqlAsync(TenantColumnName, includeWhereKeyword: true);
    }

    /// <summary>
    /// Genera la condizione AND per filtrare per tenant (senza WHERE).
    /// Utile quando ci sono già altre condizioni WHERE.
    /// </summary>
    protected async Task<string> GetTenantFilterAndClauseAsync()
    {
        if (string.IsNullOrWhiteSpace(TenantColumnName) || _tenantContext == null)
        {
            return string.Empty;
        }

        var filter = await _tenantContext.GetTenantFilterSqlAsync(TenantColumnName, includeWhereKeyword: false);
        
        return string.IsNullOrEmpty(filter) ? string.Empty : $"AND {filter}";
    }

    public virtual async Task<List<T>> GetAllAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = $"SELECT * FROM {TableName} ORDER BY {IdColumnName}";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var items = new List<T>();
            while (await reader.ReadAsync())
            {
                items.Add(MapFromReader(reader));
            }

            return items;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero di tutti gli elementi da {TableName}", TableName);
            throw DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public virtual async Task<T?> GetByIdAsync(int id)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = $"SELECT * FROM {TableName} WHERE {IdColumnName} = @id";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", id);

            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dell'elemento {Id} da {TableName}", id, TableName);
            throw DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public abstract Task<T> CreateAsync(T entity);
    public abstract Task<T> UpdateAsync(T entity);

    /// <summary>
    /// Normalizza l'entità prima del salvataggio:
    /// - Converte stringhe vuote in NULL per evitare violazioni di constraint DB
    /// - Chiamare SEMPRE prima di INSERT/UPDATE nei servizi concreti
    /// </summary>
    protected void NormalizeEntityBeforeSave(T entity)
    {
        EntityNormalizer.NormalizeNullableStrings(entity);
    }

    /// <summary>
    /// Popola automaticamente i campi di audit trail (created_by, created, updated_by, updated).
    /// </summary>
    protected async Task PopulateAuditFieldsAsync(T entity, bool isCreation)
    {
        if (entity is not IAuditable auditable)
        {
            return;
        }

        var user = _tenantContext != null ? await _tenantContext.GetCurrentUserAsync() : null;
        var username = user?.Username ?? "SYSTEM";

        if (isCreation)
        {
            auditable.CreatedBy = username;
            auditable.Created = DateTime.UtcNow;
        }

        auditable.UpdatedBy = username;
        auditable.Updated = DateTime.UtcNow;
    }

    public virtual async Task<bool> DeleteAsync(int id)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = $"DELETE FROM {TableName} WHERE {IdColumnName} = @id";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", id);

            var rowsAffected = await command.ExecuteNonQueryAsync();
            return rowsAffected > 0;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione dell'elemento {Id} da {TableName}", id, TableName);
            throw DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Mappa un DataReader su un'entità T
    /// </summary>
    protected abstract T MapFromReader(NpgsqlDataReader reader);

    /// <summary>
    /// Helper per leggere un valore nullable dal reader
    /// </summary>
    protected string? ReadNullableString(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }

    /// <summary>
    /// Helper per leggere un int dal reader
    /// </summary>
    protected int ReadInt(NpgsqlDataReader reader, string columnName)
    {
        return reader.GetInt32(reader.GetOrdinal(columnName));
    }

    /// <summary>
    /// Helper per leggere un int nullable dal reader
    /// </summary>
    protected int? ReadNullableInt(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetInt32(ordinal);
    }

    /// <summary>
    /// Helper per leggere un decimal nullable dal reader
    /// </summary>
    protected decimal? ReadNullableDecimal(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetDecimal(ordinal);
    }

    protected DateTime? ReadNullableDateTime(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetDateTime(ordinal);
    }

    /// <summary>
    /// Metodo helper per creare un'entità con retry automatico in caso di errore sequence
    /// </summary>
    protected async Task<T> CreateAsyncInternal(T entity, Func<T, Task<T>> createAction, bool allowRetry = true)
    {
        try
        {
            return await createAction(entity);
        }
        catch (PostgresException ex) when (allowRetry && (ex.SqlState == "42P01" || ex.SqlState == "23505"))
        {
            // 42P01: undefined_table (spesso confuso con sequence mancante)
            // 23505: unique_violation (se la sequence è indietro rispetto agli ID)

            _logger.LogWarning(ex, "Errore database ({SqlState}). Tentativo di auto-fix della sequence per {TableName}.", ex.SqlState, TableName);

            try
            {
                await FixSequenceAsync();
                return await CreateAsyncInternal(entity, createAction, false); // Retry once
            }
            catch (Exception fixEx)
            {
                _logger.LogError(fixEx, "Tentativo di fix sequence fallito per {TableName}", TableName);
                throw DatabaseExceptionHelper.WrapException(fixEx, TableName);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione dell'elemento in {TableName}", TableName);
            throw DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Tenta di riparare la sequence della tabella corrente
    /// </summary>
    protected virtual async Task FixSequenceAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sequenceName = $"{TableName}_{IdColumnName}_seq"; // Naming convention standard PostgreSQL

            // Per sicurezza, cerchiamo il nome esatto della sequence se diverso dallo standard
            // Ma per ora assumiamo lo standard serial/identity di default

            var sql = $@"
                DO $$
                DECLARE
                    seq_name text := '{TableName}_seq'; -- Fallback name
                    max_id integer;
                BEGIN
                    -- Cerca di indovinare il nome sequence corretto se esiste una dipendenza
                    BEGIN
                        SELECT pg_get_serial_sequence('{TableName}', '{IdColumnName}') INTO seq_name;
                    EXCEPTION WHEN OTHERS THEN
                        seq_name := '{TableName}_seq';
                    END;

                    IF seq_name IS NULL THEN
                        seq_name := '{TableName}_seq';
                    END IF;

                    -- Calcola ID massimo attuale
                    SELECT COALESCE(MAX({IdColumnName}), 0) + 1 INTO max_id FROM {TableName};
                    
                    -- Log per debug
                    RAISE NOTICE 'Fixing sequence % to %', seq_name, max_id;
                    
                    -- Aggiorna la sequence
                    PERFORM setval(seq_name, max_id, false);
                END $$;";

            await using var command = new NpgsqlCommand(sql, connection);
            await command.ExecuteNonQueryAsync();

            _logger.LogInformation("Sequence fix completato per {TableName}", TableName);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore critico durante il fix della sequence per {TableName}", TableName);
            throw;
        }
    }
}
