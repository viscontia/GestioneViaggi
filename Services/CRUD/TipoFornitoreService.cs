using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Dapper;
using Npgsql; // Required for MapFromReader signature (BaseCrudService compatibility)

namespace GestioneViaggi.Services.CRUD;

public class TipoFornitoreService : BaseCrudService<AnaTipoFornitore>
{
    protected override string TableName => "ana_tipo_fornitore";
    protected override string IdColumnName => "tipo_fornitore_id";

    static TipoFornitoreService()
    {
        // Configure Dapper custom mapping for AnaTipoFornitore
        // Maps tipo_fornitore_id → Id (overrides default MatchNamesWithUnderscores)
        SqlMapper.SetTypeMap(
            typeof(AnaTipoFornitore),
            new CustomPropertyTypeMap(
                typeof(AnaTipoFornitore),
                (type, columnName) =>
                {
                    return columnName switch
                    {
                        "tipo_fornitore_id" => type.GetProperty("Id"),
                        "azienda_fk" => type.GetProperty("AziendaFk"),
                        "conto_contabile_default" => type.GetProperty("ContoContabileDefault"),
                        "created_at" => type.GetProperty("CreatedAt"),
                        "updated_at" => type.GetProperty("UpdatedAt"),
                        _ => type.GetProperty(columnName.Replace("_", ""),
                            System.Reflection.BindingFlags.IgnoreCase | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance)
                    } ?? throw new InvalidOperationException($"Impossibile mappare la colonna '{columnName}' per AnaTipoFornitore");
                }
            )
        );
    }

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

            // Call PostgreSQL function using Dapper
            var sql = "SELECT * FROM fn_get_ana_tipo_fornitore(@AziendaId)";
            var result = await connection.QueryAsync<AnaTipoFornitore>(
                sql,
                new { AziendaId = effectiveAziendaId }
            );

            return result.ToList();
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

            // Call stored procedure via Dapper
            var newId = await connection.ExecuteScalarAsync<int>(
                "SELECT sp_ana_tipo_fornitore_create(@AziendaFk, @Descrizione, @Categoria, @ContoContabileDefault)",
                new
                {
                    AziendaFk = entity.AziendaFk,
                    Descrizione = entity.Descrizione,
                    Categoria = entity.Categoria,
                    ContoContabileDefault = entity.ContoContabileDefault
                }
            );

            // Retrieve created entity
            entity.Id = newId;
            var result = await connection.QueryFirstOrDefaultAsync<AnaTipoFornitore>(
                "SELECT * FROM fn_get_ana_tipo_fornitore(@AziendaId) WHERE tipo_fornitore_id = @Id",
                new { AziendaId = entity.AziendaFk, Id = newId }
            );

            return result ?? throw new Exception("Impossibile recuperare il tipo fornitore appena creato");
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

            // Call stored procedure via Dapper
            await connection.ExecuteAsync(
                "SELECT sp_ana_tipo_fornitore_update(@TipoFornitoreId, @Descrizione, @Categoria, @ContoContabileDefault)",
                new
                {
                    TipoFornitoreId = entity.Id,
                    Descrizione = entity.Descrizione,
                    Categoria = entity.Categoria,
                    ContoContabileDefault = entity.ContoContabileDefault
                }
            );

            // Retrieve updated entity
            var result = await connection.QueryFirstOrDefaultAsync<AnaTipoFornitore>(
                "SELECT * FROM fn_get_ana_tipo_fornitore(@AziendaId) WHERE tipo_fornitore_id = @Id",
                new { AziendaId = entity.AziendaFk, Id = entity.Id }
            );

            return result ?? throw new Exception($"Tipo Fornitore con ID {entity.Id} non trovato");
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

            // Call stored procedure via Dapper
            await connection.ExecuteAsync(
                "SELECT sp_ana_tipo_fornitore_delete(@TipoFornitoreId)",
                new { TipoFornitoreId = id }
            );

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

    // NOTE: MapFromReader is required for BaseCrudService compatibility but NOT USED in practice.
    // All CRUD operations use Dapper with CustomPropertyTypeMap (configured in static constructor).
    // Dapper automatically maps columns to properties using the custom mapping rules.
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
