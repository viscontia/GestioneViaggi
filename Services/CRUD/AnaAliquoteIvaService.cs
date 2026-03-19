using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Service per gestione CRUD ana_aliquote_iva
/// AOT compatibile - no Dapper/Reflection.Emit
/// </summary>
public class AnaAliquoteIvaService
{
    private readonly IDatabaseService _dbService;
    private readonly ILogger<AnaAliquoteIvaService> _logger;

    public AnaAliquoteIvaService(IDatabaseService dbService, ILogger<AnaAliquoteIvaService> logger)
    {
        _dbService = dbService;
        _logger = logger;
    }

    // ==========================================
    // READ
    // ==========================================

    /// <summary>
    /// Recupera aliquota per ID
    /// </summary>
    public async Task<AnaAliquotaIva?> GetByIdAsync(int id)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            const string sql = @"
                SELECT *
                FROM ana_aliquote_iva
                WHERE iva_id = @Id";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", id);

            await using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero aliquota IVA {Id}", id);
            return null;
        }
    }

    /// <summary>
    /// Recupera tutte le aliquote per azienda
    /// </summary>
    public async Task<IEnumerable<AnaAliquotaIva>> GetByAziendaAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            const string sql = @"
                SELECT *
                FROM ana_aliquote_iva
                WHERE azienda_fk = @AziendaId
                ORDER BY ordinamento, iva_descrizione";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<AnaAliquotaIva>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero aliquote IVA per azienda {AziendaId}", aziendaId);
            return Enumerable.Empty<AnaAliquotaIva>();
        }
    }

    /// <summary>
    /// Recupera solo aliquote attive per azienda (per dropdown UI)
    /// </summary>
    public async Task<IEnumerable<AnaAliquotaIva>> GetActiveByAziendaAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            const string sql = @"
                SELECT *
                FROM ana_aliquote_iva
                WHERE azienda_fk = @AziendaId
                  AND is_active = TRUE
                ORDER BY ordinamento, iva_descrizione";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<AnaAliquotaIva>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero aliquote attive per azienda {AziendaId}", aziendaId);
            return Enumerable.Empty<AnaAliquotaIva>();
        }
    }

    /// <summary>
    /// Recupera aliquota default per azienda
    /// </summary>
    public async Task<AnaAliquotaIva?> GetDefaultByAziendaAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            const string sql = @"
                SELECT *
                FROM ana_aliquote_iva
                WHERE azienda_fk = @AziendaId
                  AND is_default = TRUE
                LIMIT 1";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero aliquota default per azienda {AziendaId}", aziendaId);
            return null;
        }
    }

    // ==========================================
    // CREATE
    // ==========================================

    /// <summary>
    /// Crea nuova aliquota IVA
    /// </summary>
    public async Task<int> CreateAsync(AnaAliquotaIva item)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            // Normalizza codice (UPPER CASE)
            item.IvaCodice = item.IvaCodice?.ToUpper() ?? throw new ArgumentNullException(nameof(item.IvaCodice));

            const string sql = @"
                INSERT INTO ana_aliquote_iva (
                    azienda_fk, iva_codice, iva_descrizione, iva_percentuale, iva_natura,
                    is_default, is_active, ordinamento, created_at, created_by
                ) VALUES (
                    @AziendaFk, @IvaCodice, @IvaDescrizione, @IvaPercentuale, @IvaNatura,
                    @IsDefault, @IsActive, @Ordinamento, NOW(), @CreatedBy
                )
                RETURNING iva_id";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("AziendaFk", item.AziendaFk);
            cmd.Parameters.AddWithValue("IvaCodice", item.IvaCodice);
            cmd.Parameters.AddWithValue("IvaDescrizione", item.IvaDescrizione);
            cmd.Parameters.AddWithValue("IvaPercentuale", item.IvaPercentuale);
            cmd.Parameters.AddWithValue("IvaNatura", (object?)item.IvaNatura ?? DBNull.Value);
            cmd.Parameters.AddWithValue("IsDefault", item.IsDefault);
            cmd.Parameters.AddWithValue("IsActive", item.IsActive);
            cmd.Parameters.AddWithValue("Ordinamento", item.Ordinamento);
            cmd.Parameters.AddWithValue("CreatedBy", (object?)item.CreatedBy ?? DBNull.Value);

            var result = await cmd.ExecuteScalarAsync();
            return Convert.ToInt32(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nella creazione aliquota IVA");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "l'aliquota IVA");
        }
    }

    // ==========================================
    // UPDATE
    // ==========================================

    /// <summary>
    /// Aggiorna aliquota IVA
    /// </summary>
    public async Task UpdateAsync(AnaAliquotaIva item)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            item.IvaCodice = item.IvaCodice?.ToUpper() ?? throw new ArgumentNullException(nameof(item.IvaCodice));

            const string sql = @"
                UPDATE ana_aliquote_iva SET
                    iva_codice = @IvaCodice,
                    iva_descrizione = @IvaDescrizione,
                    iva_percentuale = @IvaPercentuale,
                    iva_natura = @IvaNatura,
                    is_default = @IsDefault,
                    is_active = @IsActive,
                    ordinamento = @Ordinamento,
                    updated_at = NOW(),
                    updated_by = @UpdatedBy
                WHERE iva_id = @IvaId";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("IvaCodice", item.IvaCodice);
            cmd.Parameters.AddWithValue("IvaDescrizione", item.IvaDescrizione);
            cmd.Parameters.AddWithValue("IvaPercentuale", item.IvaPercentuale);
            cmd.Parameters.AddWithValue("IvaNatura", (object?)item.IvaNatura ?? DBNull.Value);
            cmd.Parameters.AddWithValue("IsDefault", item.IsDefault);
            cmd.Parameters.AddWithValue("IsActive", item.IsActive);
            cmd.Parameters.AddWithValue("Ordinamento", item.Ordinamento);
            cmd.Parameters.AddWithValue("UpdatedBy", (object?)item.UpdatedBy ?? DBNull.Value);
            cmd.Parameters.AddWithValue("IvaId", item.IvaId);

            await cmd.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nell'aggiornamento aliquota IVA {Id}", item.IvaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "l'aliquota IVA");
        }
    }

    /// <summary>
    /// Imposta aliquota come default (rimuove flag da altre)
    /// Transazione atomica
    /// </summary>
    public async Task SetAsDefaultAsync(int ivaId, int aziendaId)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            using var transaction = conn.BeginTransaction();

            try
            {
                // Rimuovi flag default da tutte le aliquote dell'azienda
                const string sqlRemove = @"
                    UPDATE ana_aliquote_iva
                    SET is_default = FALSE
                    WHERE azienda_fk = @AziendaId";

                await using var cmdRemove = new NpgsqlCommand(sqlRemove, conn, transaction);
                cmdRemove.Parameters.AddWithValue("AziendaId", aziendaId);
                await cmdRemove.ExecuteNonQueryAsync();

                // Imposta flag default sulla aliquota selezionata
                const string sqlSet = @"
                    UPDATE ana_aliquote_iva
                    SET is_default = TRUE
                    WHERE iva_id = @IvaId AND azienda_fk = @AziendaId";

                await using var cmdSet = new NpgsqlCommand(sqlSet, conn, transaction);
                cmdSet.Parameters.AddWithValue("IvaId", ivaId);
                cmdSet.Parameters.AddWithValue("AziendaId", aziendaId);
                await cmdSet.ExecuteNonQueryAsync();

                transaction.Commit();
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nell'impostare default aliquota {Id}", ivaId);
            throw;
        }
    }

    // ==========================================
    // DELETE
    // ==========================================

    /// <summary>
    /// Elimina aliquota IVA
    /// </summary>
    public async Task DeleteAsync(int id)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            // Delete fisico per attivare i vincoli di integrità del DB (RESTRICT)
            const string sql = @"
                DELETE FROM ana_aliquote_iva
                WHERE iva_id = @Id";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", id);
            await cmd.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nella cancellazione aliquota {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "l'aliquota IVA");
        }
    }

    #region Mapping Helpers (AOT compatibili)

    private static AnaAliquotaIva MapFromReader(NpgsqlDataReader reader)
    {
        return new AnaAliquotaIva
        {
            IvaId = reader.GetInt32(reader.GetOrdinal("iva_id")),
            AziendaFk = reader.GetInt32(reader.GetOrdinal("azienda_fk")),
            IvaCodice = reader.GetString(reader.GetOrdinal("iva_codice")),
            IvaDescrizione = reader.GetString(reader.GetOrdinal("iva_descrizione")),
            IvaPercentuale = reader.GetDecimal(reader.GetOrdinal("iva_percentuale")),
            IvaNatura = GetNullableString(reader, "iva_natura"),
            IsDefault = reader.GetBoolean(reader.GetOrdinal("is_default")),
            IsActive = reader.GetBoolean(reader.GetOrdinal("is_active")),
            Ordinamento = reader.GetInt16(reader.GetOrdinal("ordinamento")),
            Created = GetNullableDateTime(reader, "created_at"),
            CreatedBy = GetNullableString(reader, "created_by"),
            Updated = GetNullableDateTime(reader, "updated_at"),
            UpdatedBy = GetNullableString(reader, "updated_by")
        };
    }

    private static string? GetNullableString(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }

    private static DateTime? GetNullableDateTime(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetDateTime(ordinal);
    }

    #endregion
}
