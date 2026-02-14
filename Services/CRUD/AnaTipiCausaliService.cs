using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Service DB-First per gestione ana_tipi_causali.
/// Delega tutta la logica a stored procedures PostgreSQL.
/// </summary>
public class AnaTipiCausaliService : BaseCrudService<AnaTipoCausale>
{
    protected override string TableName => "ana_tipi_causali";
    protected override string IdColumnName => "causale_id";
    protected override string? TenantColumnName => "azienda_fk";

    public AnaTipiCausaliService(IDatabaseService databaseService, ILogger<AnaTipiCausaliService> logger, ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>
    /// Recupera tutte le causali per azienda.
    /// Ordinate per ciclo e descrizione.
    /// </summary>
    public async Task<IEnumerable<AnaTipoCausale>> GetAllByAziendaAsync(int aziendaId)
    {
        try
        {
            using var conn = await _databaseService.GetConnectionAsync();
            var results = await conn.QueryAsync<AnaTipoCausale>(
                "SELECT * FROM fn_ana_tipi_causali_get_all(@AziendaId)",
                new { AziendaId = aziendaId }
            );
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero delle causali per azienda {AziendaId}", aziendaId);
            return Enumerable.Empty<AnaTipoCausale>();
        }
    }

    /// <summary>
    /// Recupera solo le causali attive per azienda (per dropdown UI).
    /// </summary>
    public async Task<IEnumerable<AnaTipoCausale>> GetActiveByAziendaAsync(int aziendaId)
    {
        try
        {
            using var conn = await _databaseService.GetConnectionAsync();
            var results = await conn.QueryAsync<AnaTipoCausale>(
                "SELECT * FROM fn_ana_tipi_causali_get_active(@AziendaId)",
                new { AziendaId = aziendaId }
            );
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero causali attive per azienda {AziendaId}", aziendaId);
            return Enumerable.Empty<AnaTipoCausale>();
        }
    }

    /// <summary>
    /// Recupera causali attive filtrate per azienda e ciclo contabile (ATTIVO/PASSIVO).
    /// </summary>
    public async Task<IEnumerable<AnaTipoCausale>> GetActiveByCicloAsync(int aziendaId, string ciclo)
    {
        try
        {
            using var conn = await _databaseService.GetConnectionAsync();
            var results = await conn.QueryAsync<AnaTipoCausale>(
                "SELECT * FROM fn_ana_tipi_causali_get_active_by_ciclo(@AziendaId, @Ciclo)",
                new { AziendaId = aziendaId, Ciclo = ciclo }
            );
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero causali attive per azienda {AziendaId} e ciclo {Ciclo}", aziendaId, ciclo);
            return Enumerable.Empty<AnaTipoCausale>();
        }
    }

    public override async Task<AnaTipoCausale> CreateAsync(AnaTipoCausale entity)
    {
        await PopulateAuditFieldsAsync(entity, true);

        try
        {
            using var conn = await _databaseService.GetConnectionAsync();

            entity.CausaleId = await conn.ExecuteScalarAsync<int>(
                @"SELECT sp_ana_tipi_causali_create(
                    @AziendaFk,
                    @CausaleCodice,
                    @CausaleDescrizione,
                    @CausaleSegno,
                    @CausaleIsDocumento,
                    @CausaleCiclo,
                    @CausaleRichiedeScadenza,
                    @CausaleGiorniScadenzaDefault,
                    @CausaleGeneraScadenzaAuto,
                    @CausaleGeneraIva,
                    @CausaleRichiedeIva,
                    @CausaleAliquotaIvaDefaultFk,
                    @IsActive,
                    @CreatedBy,
                    @UpdatedBy
                )",
                new
                {
                    entity.AziendaFk,
                    entity.CausaleCodice,
                    entity.CausaleDescrizione,
                    entity.CausaleSegno,
                    entity.CausaleIsDocumento,
                    entity.CausaleCiclo,
                    entity.CausaleRichiedeScadenza,
                    entity.CausaleGiorniScadenzaDefault,
                    entity.CausaleGeneraScadenzaAuto,
                    entity.CausaleGeneraIva,
                    entity.CausaleRichiedeIva,
                    entity.CausaleAliquotaIvaDefaultFk,
                    entity.IsActive,
                    entity.CreatedBy,
                    entity.UpdatedBy
                }
            );

            _logger.LogInformation("Causale {Codice} creata con ID {Id}", entity.CausaleCodice, entity.CausaleId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            var errorMsg = pex.MessageText;
            _logger.LogWarning("Errore business logic durante creazione causale: {Error}", errorMsg);
            throw new InvalidOperationException(errorMsg);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della causale {Codice}", entity.CausaleCodice);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<AnaTipoCausale> UpdateAsync(AnaTipoCausale entity)
    {
        await PopulateAuditFieldsAsync(entity, false);

        try
        {
            using var conn = await _databaseService.GetConnectionAsync();

            await conn.ExecuteAsync(
                @"SELECT sp_ana_tipi_causali_update(
                    @CausaleId,
                    @CausaleCodice,
                    @CausaleDescrizione,
                    @CausaleSegno,
                    @CausaleIsDocumento,
                    @CausaleCiclo,
                    @CausaleRichiedeScadenza,
                    @CausaleGiorniScadenzaDefault,
                    @CausaleGeneraScadenzaAuto,
                    @CausaleGeneraIva,
                    @CausaleRichiedeIva,
                    @CausaleAliquotaIvaDefaultFk,
                    @IsActive,
                    @UpdatedBy
                )",
                new
                {
                    entity.CausaleId,
                    entity.CausaleCodice,
                    entity.CausaleDescrizione,
                    entity.CausaleSegno,
                    entity.CausaleIsDocumento,
                    entity.CausaleCiclo,
                    entity.CausaleRichiedeScadenza,
                    entity.CausaleGiorniScadenzaDefault,
                    entity.CausaleGeneraScadenzaAuto,
                    entity.CausaleGeneraIva,
                    entity.CausaleRichiedeIva,
                    entity.CausaleAliquotaIvaDefaultFk,
                    entity.IsActive,
                    entity.UpdatedBy
                }
            );

            _logger.LogInformation("Causale {Id} aggiornata", entity.CausaleId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            var errorMsg = pex.MessageText;
            _logger.LogWarning("Errore business logic durante aggiornamento causale {Id}: {Error}", entity.CausaleId, errorMsg);
            throw new InvalidOperationException(errorMsg);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della causale {Id}", entity.CausaleId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<bool> DeleteAsync(int id)
    {
        try
        {
            using var conn = await _databaseService.GetConnectionAsync();

            await conn.ExecuteAsync(
                "SELECT sp_ana_tipi_causali_delete(@CausaleId)",
                new { CausaleId = id }
            );

            _logger.LogInformation("Causale {Id} eliminata", id);
            return true;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            var errorMsg = pex.MessageText;
            _logger.LogWarning("Errore business logic durante eliminazione causale {Id}: {Error}", id, errorMsg);
            throw new InvalidOperationException(errorMsg);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione della causale {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    protected override AnaTipoCausale MapFromReader(NpgsqlDataReader reader)
    {
        // Questo metodo non è più utilizzato (usiamo Dapper per il mapping),
        // ma lo manteniamo per compatibilità con BaseCrudService
        return new AnaTipoCausale
        {
            CausaleId = ReadInt(reader, "causale_id"),
            AziendaFk = ReadInt(reader, "azienda_fk"),
            CausaleCodice = reader.GetString(reader.GetOrdinal("causale_codice")),
            CausaleDescrizione = reader.GetString(reader.GetOrdinal("causale_descrizione")),
            CausaleSegno = ReadInt(reader, "causale_segno"),
            CausaleIsDocumento = reader.GetBoolean(reader.GetOrdinal("causale_is_documento")),
            CausaleCiclo = reader.GetString(reader.GetOrdinal("causale_ciclo")),
            CausaleRichiedeScadenza = reader.GetBoolean(reader.GetOrdinal("causale_richiede_scadenza")),
            CausaleGiorniScadenzaDefault = ReadNullableInt(reader, "causale_giorni_scadenza_default"),
            CausaleGeneraScadenzaAuto = reader.GetBoolean(reader.GetOrdinal("causale_genera_scadenza_auto")),
            CausaleGeneraIva = reader.GetBoolean(reader.GetOrdinal("causale_genera_iva")),
            CausaleRichiedeIva = reader.GetBoolean(reader.GetOrdinal("causale_richiede_iva")),
            CausaleAliquotaIvaDefaultFk = ReadNullableInt(reader, "causale_aliquota_iva_default_fk"),
            IsActive = reader.GetBoolean(reader.GetOrdinal("is_active")),
            Created = ReadNullableDateTime(reader, "created_at"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Updated = ReadNullableDateTime(reader, "updated_at"),
            UpdatedBy = ReadNullableString(reader, "updated_by")
        };
    }
}
