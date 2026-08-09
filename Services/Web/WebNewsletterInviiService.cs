using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Service DB-First per gli invii newsletter (web_newsletter_invii).
/// Delega ogni operazione alle funzioni fn_web_newsletter_invii_* (Blocco 2).
/// Multi-tenant: ogni operazione è scopata per azienda_id. Audit gestito dal
/// trigger DB trg_web_audit (l'utente arriva via my.app_user impostato da GetConnectionAsync).
/// </summary>
public class WebNewsletterInviiService : BaseCrudService<WebNewsletterInvio>
{
    protected override string TableName => "web_newsletter_invii";
    protected override string IdColumnName => "web_newsletter_invii_id";
    protected override string? TenantColumnName => "azienda_id";

    public WebNewsletterInviiService(IDatabaseService databaseService, ILogger<WebNewsletterInviiService> logger, ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>
    /// Elenco per la pagina Newsletter: bozze e inviate (<paramref name="modelli"/> = false) oppure
    /// i soli modelli riutilizzabili (= true). Include il conteggio dei blocchi.
    /// </summary>
    public async Task<List<WebNewsletterElencoVoce>> ElencoAsync(int aziendaId, bool modelli = false)
    {
        var results = new List<WebNewsletterElencoVoce>();
        await using var conn = await _databaseService.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT * FROM fn_web_newsletter_elenco(@Az::integer, @Modelli::boolean)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("Modelli", modelli);

        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            results.Add(new WebNewsletterElencoVoce(
                r.GetInt64(r.GetOrdinal("web_newsletter_invii_id")),
                r.GetString(r.GetOrdinal("oggetto")),
                r.GetString(r.GetOrdinal("stato")),
                r.IsDBNull(r.GetOrdinal("data_invio")) ? null : r.GetDateTime(r.GetOrdinal("data_invio")),
                r.IsDBNull(r.GetOrdinal("numero_destinatari")) ? null : r.GetInt32(r.GetOrdinal("numero_destinatari")),
                r.IsDBNull(r.GetOrdinal("canale")) ? null : r.GetString(r.GetOrdinal("canale")),
                r.GetBoolean(r.GetOrdinal("is_modello")),
                r.GetInt32(r.GetOrdinal("n_blocchi")),
                r.GetDateTime(r.GetOrdinal("created"))));
        }
        return results;
    }

    /// <summary>Crea una bozza (o un modello) gia' con dentro i blocchi obbligatori.</summary>
    public async Task<long> CreaBozzaAsync(int aziendaId, string oggetto, bool isModello = false)
    {
        await using var conn = await _databaseService.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT fn_web_newsletter_crea_bozza(@Az::integer, @Oggetto::varchar, @Modello::boolean)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("Oggetto", oggetto);
        cmd.Parameters.AddWithValue("Modello", isModello);
        return Convert.ToInt64(await cmd.ExecuteScalarAsync());
    }

    /// <summary>Duplica una newsletter (o un modello): la copia nasce sempre come bozza.</summary>
    public async Task<long> ClonaAsync(long invioId, int aziendaId, string? nuovoOggetto = null, bool comeModello = false)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_newsletter_clona(@Id::bigint, @Az::integer, @Oggetto::varchar, @Modello::boolean)", conn);
            cmd.Parameters.AddWithValue("Id", invioId);
            cmd.Parameters.AddWithValue("Az", aziendaId);
            cmd.Parameters.AddWithValue("Oggetto", (object?)nuovoOggetto ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Modello", comeModello);
            return Convert.ToInt64(await cmd.ExecuteScalarAsync());
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            throw new InvalidOperationException(pex.MessageText);
        }
    }

    /// <summary>Elenco degli invii newsletter di un'azienda (storico).</summary>
    public async Task<List<WebNewsletterInvio>> ListByAziendaAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_newsletter_invii_list(@AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<WebNewsletterInvio>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero invii newsletter per azienda {AziendaId}", aziendaId);
            return new List<WebNewsletterInvio>();
        }
    }

    /// <summary>Recupera un invio per id, scopato per azienda. NULL se non trovato/altra azienda.</summary>
    public async Task<WebNewsletterInvio?> GetByIdAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_newsletter_invii_get(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero invio newsletter {Id} per azienda {AziendaId}", id, aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebNewsletterInvio> CreateAsync(WebNewsletterInvio entity)
    {
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_newsletter_invii_insert(
                @AziendaId::integer,
                @Oggetto::varchar,
                @CorpoHtml::text,
                @Stato::varchar,
                @DataInvio::timestamptz,
                @NumeroDestinatari::integer,
                @Canale::varchar
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            BindWritableParams(cmd, entity);

            var result = await cmd.ExecuteScalarAsync();
            entity.WebNewsletterInvioId = Convert.ToInt64(result);

            _logger.LogInformation("Invio newsletter creato con ID {Id} ({Oggetto})", entity.WebNewsletterInvioId, entity.Oggetto);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante creazione invio newsletter: {Error}", pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione dell'invio newsletter ({Oggetto})", entity.Oggetto);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebNewsletterInvio> UpdateAsync(WebNewsletterInvio entity)
    {
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_newsletter_invii_update(
                @Id::bigint,
                @AziendaId::integer,
                @Oggetto::varchar,
                @CorpoHtml::text,
                @Stato::varchar,
                @DataInvio::timestamptz,
                @NumeroDestinatari::integer,
                @Canale::varchar
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", entity.WebNewsletterInvioId);
            BindWritableParams(cmd, entity);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (rows == 0)
            {
                throw new InvalidOperationException($"Invio newsletter {entity.WebNewsletterInvioId} non trovato per l'azienda {entity.AziendaId}.");
            }

            _logger.LogInformation("Invio newsletter {Id} aggiornato", entity.WebNewsletterInvioId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante aggiornamento invio newsletter {Id}: {Error}", entity.WebNewsletterInvioId, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento dell'invio newsletter {Id}", entity.WebNewsletterInvioId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Elimina un invio newsletter (CASCADE sui destinatari), scopato per azienda. True se eliminato.</summary>
    public async Task<bool> DeleteAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_web_newsletter_invii_delete(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Invio newsletter {Id} eliminato ({Rows} righe)", id, rows);
            return rows > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante eliminazione invio newsletter {Id}: {Error}", id, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione dell'invio newsletter {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Aggiunge i parametri dei campi scrivibili (comuni a insert/update, stesso ordine
    /// dopo azienda). L'id è aggiunto a parte solo nell'update.
    /// </summary>
    private static void BindWritableParams(NpgsqlCommand cmd, WebNewsletterInvio e)
    {
        cmd.Parameters.AddWithValue("AziendaId", e.AziendaId);
        cmd.Parameters.AddWithValue("Oggetto", e.Oggetto);
        cmd.Parameters.AddWithValue("CorpoHtml", e.CorpoHtml);
        cmd.Parameters.AddWithValue("Stato", string.IsNullOrWhiteSpace(e.Stato) ? "bozza" : e.Stato);
        cmd.Parameters.AddWithValue("DataInvio", (object?)e.DataInvio ?? DBNull.Value);
        cmd.Parameters.AddWithValue("NumeroDestinatari", (object?)e.NumeroDestinatari ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Canale", (object?)e.Canale ?? DBNull.Value);
    }

    protected override WebNewsletterInvio MapFromReader(NpgsqlDataReader reader)
    {
        return new WebNewsletterInvio
        {
            WebNewsletterInvioId = reader.GetInt64(reader.GetOrdinal("web_newsletter_invii_id")),
            AziendaId = ReadInt(reader, "azienda_id"),
            Oggetto = reader.GetString(reader.GetOrdinal("oggetto")),
            CorpoHtml = reader.GetString(reader.GetOrdinal("corpo_html")),
            Stato = reader.GetString(reader.GetOrdinal("stato")),
            DataInvio = ReadNullableDateTime(reader, "data_invio"),
            NumeroDestinatari = ReadNullableInt(reader, "numero_destinatari"),
            Canale = ReadNullableString(reader, "canale"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Created = ReadNullableDateTime(reader, "created"),
            UpdatedBy = ReadNullableString(reader, "updated_by"),
            Updated = ReadNullableDateTime(reader, "updated")
        };
    }
}
