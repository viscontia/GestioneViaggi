using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Session;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class AnaTassiCambioService : BaseCrudService<AnaTassiCambio>
{
    protected override string TableName => "ana_tassi_cambio";
    protected override string IdColumnName => "tasso_id";

    public AnaTassiCambioService(IDatabaseService databaseService, ILogger<AnaTassiCambioService> logger, ITenantContext tenantContext) 
        : base(databaseService, logger, tenantContext)
    {
    }

    public async Task<IEnumerable<AnaTassiCambio>> GetAllEnrichedAsync()
    {
        try
        {
            const string sql = @"
                SELECT 
                    t.tasso_id as TassoId,
                    t.tasso_valuta_da_fk as TassoValutaDaId,
                    t.tasso_valuta_a_fk as TassoValutaAId,
                    t.tasso_data_validita as TassoDataValidita,
                    t.tasso_valore as TassoValore,
                    t.tasso_fonte as TassoFonte,
                    t.tasso_note as TassoNote,
                    t.created_at as Created,
                    t.created_by as CreatedBy,
                    t.updated_at as Updated,
                    t.updated_by as UpdatedBy,
                    v1.valuta_codice_iso as ValutaDaCodice,
                    v2.valuta_codice_iso as ValutaACodice
                FROM ana_tassi_cambio t
                JOIN ana_valute v1 ON t.tasso_valuta_da_fk = v1.valuta_id
                JOIN ana_valute v2 ON t.tasso_valuta_a_fk = v2.valuta_id
                ORDER BY t.tasso_data_validita DESC, v1.valuta_codice_iso ASC";

            await using var conn = await _databaseService.GetConnectionAsync();
            return await conn.QueryAsync<AnaTassiCambio>(sql);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei tassi di cambio");
            return Enumerable.Empty<AnaTassiCambio>();
        }
    }

    public override async Task<AnaTassiCambio> CreateAsync(AnaTassiCambio entity)
    {
        await PopulateAuditFieldsAsync(entity, true);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            string sql = @"
                INSERT INTO ana_tassi_cambio (
                    tasso_valuta_da_fk,
                    tasso_valuta_a_fk,
                    tasso_data_validita,
                    tasso_valore,
                    tasso_fonte,
                    tasso_note,
                    created_at,
                    created_by
                ) VALUES (
                    @TassoValutaDaId,
                    @TassoValutaAId,
                    @TassoDataValidita,
                    @TassoValore,
                    @TassoFonte,
                    @TassoNote,
                    @Created,
                    @CreatedBy
                ) 
                ON CONFLICT (tasso_valuta_da_fk, tasso_valuta_a_fk, tasso_data_validita)
                DO UPDATE SET
                    tasso_valore = EXCLUDED.tasso_valore,
                    tasso_fonte = EXCLUDED.tasso_fonte,
                    tasso_note = EXCLUDED.tasso_note,
                    updated_at = @Updated,
                    updated_by = @UpdatedBy
                RETURNING tasso_id";

            entity.TassoId = await conn.ExecuteScalarAsync<int>(sql, entity);
            return entity;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore creazione tasso cambio");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<AnaTassiCambio> UpdateAsync(AnaTassiCambio entity)
    {
        await PopulateAuditFieldsAsync(entity, false);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            string sql = @"
                UPDATE ana_tassi_cambio SET
                    tasso_valuta_da_fk = @TassoValutaDaId,
                    tasso_valuta_a_fk = @TassoValutaAId,
                    tasso_data_validita = @TassoDataValidita,
                    tasso_valore = @TassoValore,
                    tasso_fonte = @TassoFonte,
                    tasso_note = @TassoNote,
                    updated_at = @Updated,
                    updated_by = @UpdatedBy
                WHERE tasso_id = @TassoId";

            await conn.ExecuteAsync(sql, entity);
            return entity;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore aggiornamento tasso cambio {Id}", entity.TassoId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    protected override AnaTassiCambio MapFromReader(NpgsqlDataReader reader)
    {
        return new AnaTassiCambio
        {
            TassoId = ReadInt(reader, "tasso_id"),
            TassoValutaDaId = ReadInt(reader, "tasso_valuta_da_fk"),
            TassoValutaAId = ReadInt(reader, "tasso_valuta_a_fk"),
            TassoDataValidita = reader.GetDateTime(reader.GetOrdinal("tasso_data_validita")),
            TassoValore = reader.GetDecimal(reader.GetOrdinal("tasso_valore")),
            TassoFonte = ReadNullableString(reader, "tasso_fonte"),
            TassoNote = ReadNullableString(reader, "tasso_note"),
            Created = ReadNullableDateTime(reader, "created_at"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Updated = ReadNullableDateTime(reader, "updated_at"),
            UpdatedBy = ReadNullableString(reader, "updated_by"),
            // Map BaseEntity.Id to keep it consistent
            Id = ReadInt(reader, "tasso_id")
        };
    }
}
