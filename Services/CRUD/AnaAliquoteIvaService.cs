using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class AnaAliquoteIvaService : BaseCrudService<AnaAliquotaIva>
{
    protected override string TableName => "ana_aliquote_iva";
    protected override string IdColumnName => "iva_id";

    public AnaAliquoteIvaService(IDatabaseService dbService, ILogger<AnaAliquoteIvaService> logger, ITenantContext tenantContext)
        : base(dbService, logger, tenantContext)
    {
    }

    /// <summary>
    /// Recupera tutte le aliquote IVA per azienda.
    /// Ordinate per ordinamento crescente.
    /// </summary>
    public async Task<IEnumerable<AnaAliquotaIva>> GetAllAliquoteAsync(int aziendaId)
    {
        try
        {
            using var conn = await _databaseService.GetConnectionAsync();
            var results = await conn.QueryAsync<AnaAliquotaIva>(
                "SELECT * FROM fn_ana_aliquote_iva_get_all(@AziendaId)",
                new { AziendaId = aziendaId }
            );
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero delle aliquote IVA per azienda {AziendaId}", aziendaId);
            return Enumerable.Empty<AnaAliquotaIva>();
        }
    }

    /// <summary>
    /// Recupera solo le aliquote IVA attive per azienda (per dropdown UI).
    /// </summary>
    public async Task<IEnumerable<AnaAliquotaIva>> GetActiveAliquoteAsync(int aziendaId)
    {
        try
        {
            using var conn = await _databaseService.GetConnectionAsync();
            var results = await conn.QueryAsync<AnaAliquotaIva>(
                "SELECT * FROM fn_ana_aliquote_iva_get_active(@AziendaId)",
                new { AziendaId = aziendaId }
            );
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero delle aliquote IVA attive per azienda {AziendaId}", aziendaId);
            return Enumerable.Empty<AnaAliquotaIva>();
        }
    }

    /// <summary>
    /// Recupera l'aliquota IVA default per azienda.
    /// </summary>
    public async Task<AnaAliquotaIva?> GetDefaultAliquotaAsync(int aziendaId)
    {
        try
        {
            using var conn = await _databaseService.GetConnectionAsync();
            return await conn.QuerySingleOrDefaultAsync<AnaAliquotaIva>(
                "SELECT * FROM fn_ana_aliquote_iva_get_default(@AziendaId)",
                new { AziendaId = aziendaId }
            );
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dell'aliquota IVA default per azienda {AziendaId}", aziendaId);
            return null;
        }
    }

    public override async Task<AnaAliquotaIva> CreateAsync(AnaAliquotaIva entity)
    {
        await PopulateAuditFieldsAsync(entity, true);

        try
        {
            using var conn = await _databaseService.GetConnectionAsync();

            entity.IvaId = await conn.ExecuteScalarAsync<int>(
                @"SELECT sp_ana_aliquote_iva_create(
                    @AziendaFk,
                    @IvaCodice,
                    @IvaDescrizione,
                    @IvaPercentuale,
                    @IvaNatura,
                    @IsDefault,
                    @IsActive,
                    @Ordinamento,
                    @CreatedBy,
                    @UpdatedBy
                )",
                new
                {
                    entity.AziendaFk,
                    entity.IvaCodice,
                    entity.IvaDescrizione,
                    entity.IvaPercentuale,
                    entity.IvaNatura,
                    entity.IsDefault,
                    entity.IsActive,
                    entity.Ordinamento,
                    entity.CreatedBy,
                    entity.UpdatedBy
                }
            );

            return entity;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione dell'aliquota IVA {Codice}", entity.IvaCodice);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<AnaAliquotaIva> UpdateAsync(AnaAliquotaIva entity)
    {
        await PopulateAuditFieldsAsync(entity, false);

        try
        {
            using var conn = await _databaseService.GetConnectionAsync();

            await conn.ExecuteAsync(
                @"SELECT sp_ana_aliquote_iva_update(
                    @IvaId,
                    @IvaCodice,
                    @IvaDescrizione,
                    @IvaPercentuale,
                    @IvaNatura,
                    @IsDefault,
                    @IsActive,
                    @Ordinamento,
                    @UpdatedBy
                )",
                new
                {
                    entity.IvaId,
                    entity.IvaCodice,
                    entity.IvaDescrizione,
                    entity.IvaPercentuale,
                    entity.IvaNatura,
                    entity.IsDefault,
                    entity.IsActive,
                    entity.Ordinamento,
                    entity.UpdatedBy
                }
            );

            return entity;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento dell'aliquota IVA {Id}", entity.IvaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Imposta un'aliquota come default (rimuove flag dalle altre).
    /// Il trigger fn_check_single_default_iva gestisce automaticamente la rimozione del flag dalle altre aliquote.
    /// </summary>
    public async Task SetAsDefaultAsync(int ivaId, int aziendaId)
    {
        try
        {
            using var conn = await _databaseService.GetConnectionAsync();

            await conn.ExecuteAsync(
                "SELECT sp_ana_aliquote_iva_set_default(@IvaId, @AziendaId)",
                new { IvaId = ivaId, AziendaId = aziendaId }
            );
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'impostazione dell'aliquota default {IvaId} per azienda {AziendaId}", ivaId, aziendaId);
            throw;
        }
    }

    public override async Task<bool> DeleteAsync(int id)
    {
        try
        {
            using var conn = await _databaseService.GetConnectionAsync();

            await conn.ExecuteAsync(
                "SELECT sp_ana_aliquote_iva_delete(@IvaId)",
                new { IvaId = id }
            );

            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione dell'aliquota IVA {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    protected override AnaAliquotaIva MapFromReader(NpgsqlDataReader reader)
    {
        return new AnaAliquotaIva
        {
            IvaId = ReadInt(reader, "iva_id"),
            AziendaFk = ReadInt(reader, "azienda_fk"),
            IvaCodice = reader.GetString(reader.GetOrdinal("iva_codice")),
            IvaDescrizione = reader.GetString(reader.GetOrdinal("iva_descrizione")),
            IvaPercentuale = reader.GetDecimal(reader.GetOrdinal("iva_percentuale")),
            IvaNatura = ReadNullableString(reader, "iva_natura"),
            IsDefault = reader.GetBoolean(reader.GetOrdinal("is_default")),
            IsActive = reader.GetBoolean(reader.GetOrdinal("is_active")),
            Ordinamento = reader.GetInt16(reader.GetOrdinal("ordinamento")),
            Created = ReadNullableDateTime(reader, "created_at"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Updated = ReadNullableDateTime(reader, "updated_at"),
            UpdatedBy = ReadNullableString(reader, "updated_by")
        };
    }
}
