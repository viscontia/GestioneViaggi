using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class TipoFornitoreService : BaseCrudService<AnaTipoFornitore>
{
    protected override string TableName => "ana_tipo_fornitore";
    protected override string IdColumnName => "tipo_fornitore_id";

    public TipoFornitoreService(
        IDatabaseService databaseService,
        ILogger<TipoFornitoreService> logger,
        ITenantContext tenantContext)
        : base(databaseService, logger, tenantContext)
    {
    }

    public async Task<List<AnaTipoFornitore>> GetAllAsync(int? aziendaIdFilter = null)
    {
        try
        {
            var currentAziendaId = await GetCurrentAziendaIdAsync();

            // Determine which azienda_id to use:
            // - Normal User: use currentAziendaId (their company)
            // - SuperAdmin: use aziendaIdFilter if provided, otherwise NULL (all companies)
            int? effectiveAziendaId = currentAziendaId.HasValue
                ? currentAziendaId
                : aziendaIdFilter;

            await using var connection = await _databaseService.GetConnectionAsync();

            var sql = "SELECT * FROM fn_get_ana_tipo_fornitore(@AziendaId)";
            await using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("AziendaId", (object?)effectiveAziendaId ?? DBNull.Value);

            var results = new List<AnaTipoFornitore>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento dei tipi fornitore");
            throw;
        }
    }

    public override async Task<AnaTipoFornitore> CreateAsync(AnaTipoFornitore entity)
    {
        var currentAziendaId = await GetCurrentAziendaIdAsync();

        // If entity has no AziendaFk (0), try to use current context.
        // If current context is null (SuperAdmin without selection?), this is an error (Strict Multi-Tenant).
        if (entity.AziendaFk == 0)
        {
            if (currentAziendaId.HasValue)
            {
                entity.AziendaFk = currentAziendaId.Value;
            }
            else
            {
                 throw new InvalidOperationException("Impossibile creare Tipo Fornitore: Nessuna Azienda specificata.");
            }
        }

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            await using var cmd = new NpgsqlCommand("SELECT sp_ana_tipo_fornitore_create(@AziendaFk, @Descrizione, @Categoria, @ContoContabileDefault)", connection);
            cmd.Parameters.AddWithValue("AziendaFk", entity.AziendaFk);
            cmd.Parameters.AddWithValue("Descrizione", entity.Descrizione);
            cmd.Parameters.AddWithValue("Categoria", (object?)entity.Categoria ?? DBNull.Value);
            cmd.Parameters.AddWithValue("ContoContabileDefault", (object?)entity.ContoContabileDefault ?? DBNull.Value);

            var newIdResult = await cmd.ExecuteScalarAsync();
            int newId = Convert.ToInt32(newIdResult);

            // Retrieve created entity
            entity.Id = newId;
            await using var queryCmd = new NpgsqlCommand("SELECT * FROM fn_get_ana_tipo_fornitore(@AziendaId) WHERE tipo_fornitore_id = @Id", connection);
            queryCmd.Parameters.AddWithValue("AziendaId", entity.AziendaFk);
            queryCmd.Parameters.AddWithValue("Id", newId);
            
            await using var reader = await queryCmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile recuperare il tipo fornitore appena creato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del tipo fornitore");
            throw;
        }
    }

    public override async Task<AnaTipoFornitore> UpdateAsync(AnaTipoFornitore entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            await using var cmd = new NpgsqlCommand("SELECT sp_ana_tipo_fornitore_update(@TipoFornitoreId, @Descrizione, @Categoria, @ContoContabileDefault)", connection);
            cmd.Parameters.AddWithValue("TipoFornitoreId", entity.Id);
            cmd.Parameters.AddWithValue("Descrizione", entity.Descrizione);
            cmd.Parameters.AddWithValue("Categoria", (object?)entity.Categoria ?? DBNull.Value);
            cmd.Parameters.AddWithValue("ContoContabileDefault", (object?)entity.ContoContabileDefault ?? DBNull.Value);
            await cmd.ExecuteNonQueryAsync();

            // Retrieve updated entity
            await using var queryCmd = new NpgsqlCommand("SELECT * FROM fn_get_ana_tipo_fornitore(@AziendaId) WHERE tipo_fornitore_id = @Id", connection);
            queryCmd.Parameters.AddWithValue("AziendaId", entity.AziendaFk);
            queryCmd.Parameters.AddWithValue("Id", entity.Id);
            
            await using var reader = await queryCmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Tipo Fornitore con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del tipo fornitore");
            throw;
        }
    }

    public override async Task<bool> DeleteAsync(int id)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            await using var cmd = new NpgsqlCommand("SELECT sp_ana_tipo_fornitore_delete(@TipoFornitoreId)", connection);
            cmd.Parameters.AddWithValue("TipoFornitoreId", id);
            await cmd.ExecuteNonQueryAsync();

            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione del tipo fornitore con ID {Id}", id);

            // Check if it's a "record in use" error
            if (ex.Message.Contains("RECORD_IN_USE"))
            {
                return false; // Signal that deletion failed because record is in use
            }

            throw;
        }
    }

    // Mappa i risultati letti da NpgsqlDataReader a entità AnaTipoFornitore
    protected override AnaTipoFornitore MapFromReader(NpgsqlDataReader reader)
    {
        return new AnaTipoFornitore
        {
            Id = ReadInt(reader, "tipo_fornitore_id"),
            AziendaFk = ReadInt(reader, "azienda_fk"),
            Descrizione = reader.GetString(reader.GetOrdinal("descrizione")),
            Categoria = ReadNullableString(reader, "categoria"),
            ContoContabileDefault = ReadNullableString(reader, "conto_contabile_default"),
            CreatedAt = ReadNullableDateTime(reader, "created_at"),
            UpdatedAt = ReadNullableDateTime(reader, "updated_at")
        };
    }
}
