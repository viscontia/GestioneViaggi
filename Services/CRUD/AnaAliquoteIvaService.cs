using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Service per gestione CRUD ana_aliquote_iva
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
                SELECT
                    iva_id AS IvaId,
                    azienda_fk AS AziendaFk,
                    iva_codice AS IvaCodice,
                    iva_descrizione AS IvaDescrizione,
                    iva_percentuale AS IvaPercentuale,
                    iva_natura AS IvaNatura,
                    is_default AS IsDefault,
                    is_active AS IsActive,
                    ordinamento AS Ordinamento,
                    created_at AS Created,
                    created_by AS CreatedBy,
                    updated_at AS Updated,
                    updated_by AS UpdatedBy
                FROM ana_aliquote_iva
                WHERE iva_id = @Id";

            var parameters = new DynamicParameters();
            parameters.Add("Id", id);
            return await conn.QuerySingleOrDefaultAsync<AnaAliquotaIva>(sql, parameters);
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
                SELECT
                    iva_id AS IvaId,
                    azienda_fk AS AziendaFk,
                    iva_codice AS IvaCodice,
                    iva_descrizione AS IvaDescrizione,
                    iva_percentuale AS IvaPercentuale,
                    iva_natura AS IvaNatura,
                    is_default AS IsDefault,
                    is_active AS IsActive,
                    ordinamento AS Ordinamento,
                    created_at AS Created,
                    created_by AS CreatedBy,
                    updated_at AS Updated,
                    updated_by AS UpdatedBy
                FROM ana_aliquote_iva
                WHERE azienda_fk = @AziendaId
                ORDER BY ordinamento, iva_descrizione";

            var parameters = new DynamicParameters();
            parameters.Add("AziendaId", aziendaId);
            return await conn.QueryAsync<AnaAliquotaIva>(sql, parameters);
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
                SELECT
                    iva_id AS IvaId,
                    azienda_fk AS AziendaFk,
                    iva_codice AS IvaCodice,
                    iva_descrizione AS IvaDescrizione,
                    iva_percentuale AS IvaPercentuale,
                    iva_natura AS IvaNatura,
                    is_default AS IsDefault,
                    is_active AS IsActive,
                    ordinamento AS Ordinamento
                FROM ana_aliquote_iva
                WHERE azienda_fk = @AziendaId
                  AND is_active = TRUE
                ORDER BY ordinamento, iva_descrizione";

            var parameters = new DynamicParameters();
            parameters.Add("AziendaId", aziendaId);
            return await conn.QueryAsync<AnaAliquotaIva>(sql, parameters);
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
                SELECT
                    iva_id AS IvaId,
                    azienda_fk AS AziendaFk,
                    iva_codice AS IvaCodice,
                    iva_descrizione AS IvaDescrizione,
                    iva_percentuale AS IvaPercentuale,
                    iva_natura AS IvaNatura,
                    is_default AS IsDefault,
                    is_active AS IsActive,
                    ordinamento AS Ordinamento
                FROM ana_aliquote_iva
                WHERE azienda_fk = @AziendaId
                  AND is_default = TRUE
                LIMIT 1";

            var parameters = new DynamicParameters();
            parameters.Add("AziendaId", aziendaId);
            return await conn.QuerySingleOrDefaultAsync<AnaAliquotaIva>(sql, parameters);
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

            return await conn.ExecuteScalarAsync<int>(sql, item);
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

            await conn.ExecuteAsync(sql, item);
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
            await conn.OpenAsync();

            using var transaction = await conn.BeginTransactionAsync();

            try
            {
                // Rimuovi flag default da tutte le aliquote dell'azienda
                const string sqlRemove = @"
                    UPDATE ana_aliquote_iva
                    SET is_default = FALSE
                    WHERE azienda_fk = @AziendaId";

                var removeParams = new DynamicParameters();
                removeParams.Add("AziendaId", aziendaId);
                await conn.ExecuteAsync(sqlRemove, removeParams, transaction);

                // Imposta flag default sulla aliquota selezionata
                const string sqlSet = @"
                    UPDATE ana_aliquote_iva
                    SET is_default = TRUE
                    WHERE iva_id = @IvaId AND azienda_fk = @AziendaId";

                var setParams = new DynamicParameters();
                setParams.Add("IvaId", ivaId);
                setParams.Add("AziendaId", aziendaId);
                await conn.ExecuteAsync(sqlSet, setParams, transaction);

                await transaction.CommitAsync();
            }
            catch
            {
                await transaction.RollbackAsync();
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
    /// Elimina aliquota IVA (soft delete)
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

            var parameters = new DynamicParameters();
            parameters.Add("Id", id);
            await conn.ExecuteAsync(sql, parameters);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nella cancellazione aliquota {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "l'aliquota IVA");
        }
    }
}
