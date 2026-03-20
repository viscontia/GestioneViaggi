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
                    t.tasso_id,
                    t.tasso_valuta_da_fk,
                    t.tasso_valuta_a_fk,
                    t.tasso_data_validita,
                    t.tasso_valore,
                    t.tasso_fonte,
                    t.tasso_note,
                    t.created_at,
                    t.created_by,
                    t.updated_at,
                    t.updated_by,
                    v1.valuta_codice_iso as valuta_da_codice,
                    v2.valuta_codice_iso as valuta_a_codice
                FROM ana_tassi_cambio t
                JOIN ana_valute v1 ON t.tasso_valuta_da_fk = v1.valuta_id
                JOIN ana_valute v2 ON t.tasso_valuta_a_fk = v2.valuta_id
                ORDER BY t.tasso_data_validita DESC, v1.valuta_codice_iso ASC";

            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(sql, conn);
            
            var results = new List<AnaTassiCambio>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            
            return results;
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

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("TassoValutaDaId", entity.TassoValutaDaId);
            cmd.Parameters.AddWithValue("TassoValutaAId", entity.TassoValutaAId);
            cmd.Parameters.AddWithValue("TassoDataValidita", entity.TassoDataValidita);
            cmd.Parameters.AddWithValue("TassoValore", entity.TassoValore);
            cmd.Parameters.AddWithValue("TassoFonte", (object?)entity.TassoFonte ?? DBNull.Value);
            cmd.Parameters.AddWithValue("TassoNote", (object?)entity.TassoNote ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Created", (object?)entity.Created ?? DBNull.Value);
            cmd.Parameters.AddWithValue("CreatedBy", (object?)entity.CreatedBy ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Updated", (object?)entity.Updated ?? DBNull.Value);
            cmd.Parameters.AddWithValue("UpdatedBy", (object?)entity.UpdatedBy ?? DBNull.Value);

            var result = await cmd.ExecuteScalarAsync();
            entity.TassoId = Convert.ToInt32(result);
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

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("TassoId", entity.TassoId);
            cmd.Parameters.AddWithValue("TassoValutaDaId", entity.TassoValutaDaId);
            cmd.Parameters.AddWithValue("TassoValutaAId", entity.TassoValutaAId);
            cmd.Parameters.AddWithValue("TassoDataValidita", entity.TassoDataValidita);
            cmd.Parameters.AddWithValue("TassoValore", entity.TassoValore);
            cmd.Parameters.AddWithValue("TassoFonte", (object?)entity.TassoFonte ?? DBNull.Value);
            cmd.Parameters.AddWithValue("TassoNote", (object?)entity.TassoNote ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Updated", (object?)entity.Updated ?? DBNull.Value);
            cmd.Parameters.AddWithValue("UpdatedBy", (object?)entity.UpdatedBy ?? DBNull.Value);

            await cmd.ExecuteNonQueryAsync();
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
        var entity = new AnaTassiCambio
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

        if (HasColumn(reader, "valuta_da_codice"))
        {
            entity.ValutaDaCodice = ReadNullableString(reader, "valuta_da_codice");
        }
        
        if (HasColumn(reader, "valuta_a_codice"))
        {
            entity.ValutaACodice = ReadNullableString(reader, "valuta_a_codice");
        }

        return entity;
    }
}
