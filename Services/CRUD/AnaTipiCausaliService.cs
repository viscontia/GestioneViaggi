using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class AnaTipiCausaliService : BaseCrudService<AnaTipoCausale>
{
    public AnaTipiCausaliService(IDatabaseService databaseService, ILogger<AnaTipiCausaliService> logger, ITenantContext? tenantContext = null) 
        : base(databaseService, logger, tenantContext)
    {
    }

    protected override string TableName => "ana_tipi_causali";
    protected override string IdColumnName => "causale_id";
    protected override string? TenantColumnName => "azienda_fk";

    public override async Task<AnaTipoCausale> CreateAsync(AnaTipoCausale entity)
    {
        NormalizeEntityBeforeSave(entity);
        await PopulateAuditFieldsAsync(entity, true);

        return await CreateAsyncInternal(entity, async (e) =>
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = $@"
                INSERT INTO {TableName} (
                    azienda_fk, causale_codice, causale_descrizione,
                    causale_segno, causale_is_documento, causale_ciclo, is_active,
                    created_at, created_by, updated_at, updated_by
                ) VALUES (
                    @AziendaFk, @CausaleCodice, @CausaleDescrizione,
                    @CausaleSegno, @CausaleIsDocumento, @CausaleCiclo, @IsActive,
                    @Created, @CreatedBy, @Updated, @UpdatedBy
                ) RETURNING *";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("AziendaFk", e.AziendaFk);
            command.Parameters.AddWithValue("CausaleCodice", e.CausaleCodice);
            command.Parameters.AddWithValue("CausaleDescrizione", e.CausaleDescrizione);
            command.Parameters.AddWithValue("CausaleSegno", e.CausaleSegno);
            command.Parameters.AddWithValue("CausaleIsDocumento", e.CausaleIsDocumento);
            command.Parameters.AddWithValue("CausaleCiclo", e.CausaleCiclo);
            command.Parameters.AddWithValue("IsActive", e.IsActive);
            command.Parameters.AddWithValue("Created", (object?)e.Created ?? DBNull.Value);
            command.Parameters.AddWithValue("CreatedBy", (object?)e.CreatedBy ?? DBNull.Value);
            command.Parameters.AddWithValue("Updated", (object?)e.Updated ?? DBNull.Value);
            command.Parameters.AddWithValue("UpdatedBy", (object?)e.UpdatedBy ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }
            throw new Exception("Errore durante la creazione della causale");
        });
    }

    public override async Task<AnaTipoCausale> UpdateAsync(AnaTipoCausale entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = $@"
                UPDATE {TableName} SET
                    causale_codice = @CausaleCodice,
                    causale_descrizione = @CausaleDescrizione,
                    causale_segno = @CausaleSegno,
                    causale_is_documento = @CausaleIsDocumento,
                    causale_ciclo = @CausaleCiclo,
                    is_active = @IsActive,
                    updated_at = @Updated,
                    updated_by = @UpdatedBy
                WHERE {IdColumnName} = @CausaleId
                RETURNING *";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("CausaleId", entity.CausaleId);
            command.Parameters.AddWithValue("CausaleCodice", entity.CausaleCodice);
            command.Parameters.AddWithValue("CausaleDescrizione", entity.CausaleDescrizione);
            command.Parameters.AddWithValue("CausaleSegno", entity.CausaleSegno);
            command.Parameters.AddWithValue("CausaleIsDocumento", entity.CausaleIsDocumento);
            command.Parameters.AddWithValue("CausaleCiclo", entity.CausaleCiclo);
            command.Parameters.AddWithValue("IsActive", entity.IsActive);
            command.Parameters.AddWithValue("Updated", (object?)entity.Updated ?? DBNull.Value);
            command.Parameters.AddWithValue("UpdatedBy", (object?)entity.UpdatedBy ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }
            throw new Exception($"Causale {entity.CausaleId} non trovata per l'aggiornamento");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della causale {Id}", entity.CausaleId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    protected override AnaTipoCausale MapFromReader(NpgsqlDataReader reader)
    {
        return new AnaTipoCausale
        {
            CausaleId = ReadInt(reader, "causale_id"),
            AziendaFk = ReadInt(reader, "azienda_fk"),
            CausaleCodice = reader.GetString(reader.GetOrdinal("causale_codice")),
            CausaleDescrizione = reader.GetString(reader.GetOrdinal("causale_descrizione")),
            CausaleSegno = ReadInt(reader, "causale_segno"),
            CausaleIsDocumento = reader.GetBoolean(reader.GetOrdinal("causale_is_documento")),
            CausaleCiclo = reader.GetString(reader.GetOrdinal("causale_ciclo")),
            IsActive = reader.GetBoolean(reader.GetOrdinal("is_active")),
            Created = ReadNullableDateTime(reader, "created_at"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Updated = ReadNullableDateTime(reader, "updated_at"),
            UpdatedBy = ReadNullableString(reader, "updated_by")
        };
    }

    public async Task<IEnumerable<AnaTipoCausale>> GetActiveByAziendaAsync(int aziendaId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = $"SELECT * FROM {TableName} WHERE azienda_fk = @AziendaId AND is_active = TRUE ORDER BY causale_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await command.ExecuteReaderAsync();
            var items = new List<AnaTipoCausale>();
            while (await reader.ReadAsync())
            {
                items.Add(MapFromReader(reader));
            }
            return items;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero causali attive per azienda {AziendaId}", aziendaId);
            return Enumerable.Empty<AnaTipoCausale>();
        }
    }

    /// <summary>
    /// Recupera causali attive filtrate per azienda e ciclo contabile (ATTIVO/PASSIVO)
    /// </summary>
    public async Task<IEnumerable<AnaTipoCausale>> GetActiveByCicloAsync(int aziendaId, string ciclo)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = $"SELECT * FROM {TableName} WHERE azienda_fk = @AziendaId AND causale_ciclo = @Ciclo AND is_active = TRUE ORDER BY causale_descrizione";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("AziendaId", aziendaId);
            command.Parameters.AddWithValue("Ciclo", ciclo);

            await using var reader = await command.ExecuteReaderAsync();
            var items = new List<AnaTipoCausale>();
            while (await reader.ReadAsync())
            {
                items.Add(MapFromReader(reader));
            }
            return items;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero causali attive per azienda {AziendaId} e ciclo {Ciclo}", aziendaId, ciclo);
            return Enumerable.Empty<AnaTipoCausale>();
        }
    }
}
