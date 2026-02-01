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
            // If filter provided (SuperAdmin), use it. Else use context.
            // Note: If filter is provided, we respect valid value.
            // If filter is explicitly null/0 from UI but intended as "Global Only" or "All", logic varies.
            // Based on Clienti.razor, simple filter is passed.

            // Logic:
            // 1. Base condition: Global types always visible? YES (azienda_fk IS NULL)
            // 2. Specific types:
            //    - If context exists (User): visible only context.
            //    - If context is null (SuperAdmin) AND filter is passed: visible only filter.
            //    - If context is null (SuperAdmin) AND filter is null: visible ALL?

             await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM ana_tipo_fornitore WHERE 1=1";

            if (currentAziendaId.HasValue)
            {
                 // Normal User: Own company ONLY
                 sql += $" AND azienda_fk = {currentAziendaId.Value}";
            }
            else
            {
                // SuperAdmin
                if (aziendaIdFilter.HasValue && aziendaIdFilter.Value > 0)
                {
                    // Filter by specific company
                    sql += $" AND azienda_fk = {aziendaIdFilter.Value}";
                }
                else
                {
                    // No filter -> Show All
                    // 1=1 is sufficient
                }
            }
            
            sql += " ORDER BY descrizione ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var list = new List<AnaTipoFornitore>();
            while (await reader.ReadAsync())
            {
                list.Add(MapFromReader(reader));
            }
            return list;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento dei tipi fornitore");
            throw;
        }
    }

    public override async Task<AnaTipoFornitore> CreateAsync(AnaTipoFornitore entity)
    {
        // Set context Azienda if not provided (assuming usually user creates for their company)
        // If user is superadmin could potentially create NULL (system), but for now default to current context if strictly multi-tenant
        var currentAziendaId = await GetCurrentAziendaIdAsync();
        
        // If entity has no AziendaFk (0), try to use current context.
        // If current context is null (SuperAdmin without selection?), this is an error now (Strict Multi-Tenant).
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
            var sql = @"
                INSERT INTO ana_tipo_fornitore (
                    azienda_fk,
                    descrizione,
                    categoria,
                    conto_contabile_default
                )
                VALUES (
                    @aziendaFk,
                    @descrizione,
                    @categoria,
                    @contoContabileDefault
                )
                RETURNING *";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaFk", entity.AziendaFk);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("categoria", (object?)entity.Categoria ?? DBNull.Value);
            command.Parameters.AddWithValue("contoContabileDefault", (object?)entity.ContoContabileDefault ?? DBNull.Value);


            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il tipo fornitore");
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
            var sql = @"
                UPDATE ana_tipo_fornitore
                SET
                    descrizione = @descrizione,
                    categoria = @categoria,
                    conto_contabile_default = @contoContabileDefault
                WHERE tipo_fornitore_id = @id
                RETURNING *";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("categoria", (object?)entity.Categoria ?? DBNull.Value);
            command.Parameters.AddWithValue("contoContabileDefault", (object?)entity.ContoContabileDefault ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
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
