using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Service DB-First per le traduzioni per-campo polimorfiche (web_traduzioni).
/// Delega ogni operazione alle funzioni fn_web_traduzioni_* (Blocco 2).
/// Multi-tenant: ogni operazione è scopata per azienda_id. Audit gestito dal
/// trigger DB trg_web_audit (l'utente arriva via my.app_user impostato da GetConnectionAsync).
/// </summary>
public class WebTraduzioniService : BaseCrudService<WebTraduzione>
{
    protected override string TableName => "web_traduzioni";
    protected override string IdColumnName => "web_traduzioni_id";
    protected override string? TenantColumnName => "azienda_id";

    public WebTraduzioniService(IDatabaseService databaseService, ILogger<WebTraduzioniService> logger, ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>Upsert di una traduzione per (entita, entita_id, campo, lingua). Resetta i flag (ri-tradotto auto).</summary>
    public async Task<long> UpsertAsync(int aziendaId, string entita, long entitaId, string campo, string lingua, string testo)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_traduzioni_upsert(@Az::integer, @E::varchar, @Eid::bigint, @C::varchar, @L::varchar, @T::text)", conn);
            cmd.Parameters.AddWithValue("Az", aziendaId);
            cmd.Parameters.AddWithValue("E", entita);
            cmd.Parameters.AddWithValue("Eid", entitaId);
            cmd.Parameters.AddWithValue("C", campo);
            cmd.Parameters.AddWithValue("L", lingua);
            cmd.Parameters.AddWithValue("T", testo);
            return Convert.ToInt64(await cmd.ExecuteScalarAsync());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore upsert traduzione {Entita}/{Campo}/{Lingua}", entita, campo, lingua);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Marca obsolete tutte le traduzioni (ogni lingua) di un campo sorgente quando l'IT cambia.
    /// Non lancia: l'obsolescenza non deve rompere il salvataggio della sorgente.
    /// </summary>
    public async Task<int> MarkObsoleteAsync(int aziendaId, string entita, long entitaId, string campo)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_traduzioni_marca_obsolete(@Az::integer, @E::varchar, @Eid::bigint, @C::varchar)", conn);
            cmd.Parameters.AddWithValue("Az", aziendaId);
            cmd.Parameters.AddWithValue("E", entita);
            cmd.Parameters.AddWithValue("Eid", entitaId);
            cmd.Parameters.AddWithValue("C", campo);
            return Convert.ToInt32(await cmd.ExecuteScalarAsync());
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Marca-obsolete traduzioni fallita {Entita}/{Campo} (ignorato)", entita, campo);
            return 0;
        }
    }

    /// <summary>Marca obsolete le traduzioni di un campo di un'entità GLOBALE (senza filtro azienda). Non lancia.</summary>
    public async Task<int> MarkObsoleteGlobalAsync(string entita, long entitaId, string campo)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_traduzioni_marca_obsolete_global(@E::varchar, @Eid::bigint, @C::varchar)", conn);
            cmd.Parameters.AddWithValue("E", entita);
            cmd.Parameters.AddWithValue("Eid", entitaId);
            cmd.Parameters.AddWithValue("C", campo);
            return Convert.ToInt32(await cmd.ExecuteScalarAsync());
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Marca-obsolete-global traduzioni fallita {Entita}/{Campo} (ignorato)", entita, campo);
            return 0;
        }
    }

    /// <summary>Elenco di tutte le traduzioni di un'azienda.</summary>
    public async Task<List<WebTraduzione>> ListByAziendaAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_traduzioni_list(@AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<WebTraduzione>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero traduzioni per azienda {AziendaId}", aziendaId);
            return new List<WebTraduzione>();
        }
    }

    /// <summary>Tutte le traduzioni (ogni campo/lingua) di un record di un'entità.</summary>
    public async Task<List<WebTraduzione>> ListByEntitaAsync(string entita, long entitaId, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_traduzioni_list_by_entita(@Entita::varchar, @EntitaId::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Entita", entita);
            cmd.Parameters.AddWithValue("EntitaId", entitaId);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<WebTraduzione>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero traduzioni per {Entita} {EntitaId} azienda {AziendaId}", entita, entitaId, aziendaId);
            return new List<WebTraduzione>();
        }
    }

    /// <summary>Recupera una traduzione per id, scopata per azienda. NULL se non trovata/altra azienda.</summary>
    public async Task<WebTraduzione?> GetByIdAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_traduzioni_get(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero traduzione {Id} per azienda {AziendaId}", id, aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebTraduzione> CreateAsync(WebTraduzione entity)
    {
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_traduzioni_insert(
                @AziendaId::integer,
                @Entita::varchar,
                @EntitaId::bigint,
                @Campo::varchar,
                @Lingua::varchar,
                @Testo::text,
                @TradottoAuto::boolean,
                @Revisionato::boolean,
                @Obsoleto::boolean,
                @DataTraduzione::timestamptz
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            BindWritableParams(cmd, entity);

            var result = await cmd.ExecuteScalarAsync();
            entity.WebTraduzioneId = Convert.ToInt64(result);

            _logger.LogInformation("Traduzione creata con ID {Id} ({Entita}/{Campo}/{Lingua})", entity.WebTraduzioneId, entity.Entita, entity.Campo, entity.Lingua);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante creazione traduzione: {Error}", pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della traduzione ({Entita}/{Campo}/{Lingua})", entity.Entita, entity.Campo, entity.Lingua);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebTraduzione> UpdateAsync(WebTraduzione entity)
    {
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_traduzioni_update(
                @Id::bigint,
                @AziendaId::integer,
                @Entita::varchar,
                @EntitaId::bigint,
                @Campo::varchar,
                @Lingua::varchar,
                @Testo::text,
                @TradottoAuto::boolean,
                @Revisionato::boolean,
                @Obsoleto::boolean,
                @DataTraduzione::timestamptz
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", entity.WebTraduzioneId);
            BindWritableParams(cmd, entity);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (rows == 0)
            {
                throw new InvalidOperationException($"Traduzione {entity.WebTraduzioneId} non trovata per l'azienda {entity.AziendaId}.");
            }

            _logger.LogInformation("Traduzione {Id} aggiornata", entity.WebTraduzioneId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante aggiornamento traduzione {Id}: {Error}", entity.WebTraduzioneId, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della traduzione {Id}", entity.WebTraduzioneId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Elimina una traduzione, scopata per azienda. True se una riga è stata eliminata.</summary>
    public async Task<bool> DeleteAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_web_traduzioni_delete(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Traduzione {Id} eliminata ({Rows} righe)", id, rows);
            return rows > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante eliminazione traduzione {Id}: {Error}", id, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione della traduzione {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Aggiunge i parametri dei campi scrivibili (comuni a insert/update, stesso ordine
    /// dopo azienda). L'id è aggiunto a parte solo nell'update.
    /// </summary>
    private static void BindWritableParams(NpgsqlCommand cmd, WebTraduzione e)
    {
        cmd.Parameters.AddWithValue("AziendaId", e.AziendaId);
        cmd.Parameters.AddWithValue("Entita", e.Entita);
        cmd.Parameters.AddWithValue("EntitaId", e.EntitaId);
        cmd.Parameters.AddWithValue("Campo", e.Campo);
        cmd.Parameters.AddWithValue("Lingua", e.Lingua);
        cmd.Parameters.AddWithValue("Testo", e.Testo);
        cmd.Parameters.AddWithValue("TradottoAuto", e.TradottoAuto);
        cmd.Parameters.AddWithValue("Revisionato", e.Revisionato);
        cmd.Parameters.AddWithValue("Obsoleto", e.Obsoleto);
        cmd.Parameters.AddWithValue("DataTraduzione", (object?)e.DataTraduzione ?? DBNull.Value);
    }

    protected override WebTraduzione MapFromReader(NpgsqlDataReader reader)
    {
        return new WebTraduzione
        {
            WebTraduzioneId = reader.GetInt64(reader.GetOrdinal("web_traduzioni_id")),
            AziendaId = ReadInt(reader, "azienda_id"),
            Entita = reader.GetString(reader.GetOrdinal("entita")),
            EntitaId = reader.GetInt64(reader.GetOrdinal("entita_id")),
            Campo = reader.GetString(reader.GetOrdinal("campo")),
            Lingua = reader.GetString(reader.GetOrdinal("lingua")).Trim(),
            Testo = reader.GetString(reader.GetOrdinal("testo")),
            TradottoAuto = reader.GetBoolean(reader.GetOrdinal("tradotto_auto")),
            Revisionato = reader.GetBoolean(reader.GetOrdinal("revisionato")),
            Obsoleto = reader.GetBoolean(reader.GetOrdinal("obsoleto")),
            DataTraduzione = ReadNullableDateTime(reader, "data_traduzione"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Created = ReadNullableDateTime(reader, "created"),
            UpdatedBy = ReadNullableString(reader, "updated_by"),
            Updated = ReadNullableDateTime(reader, "updated")
        };
    }
}
