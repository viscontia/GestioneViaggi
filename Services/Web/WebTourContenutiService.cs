using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Service DB-First per i contenuti web del tour (web_tour_contenuti).
/// Delega ogni operazione alle funzioni fn_web_tour_contenuti_* (Blocco 2).
/// Multi-tenant: ogni operazione è scopata per azienda_id. Audit gestito dal
/// trigger DB trg_web_audit (l'utente arriva via my.app_user impostato da GetConnectionAsync).
/// </summary>
public class WebTourContenutiService : BaseCrudService<WebTourContenuto>
{
    protected override string TableName => "web_tour_contenuti";
    protected override string IdColumnName => "web_tour_contenuti_id";
    protected override string? TenantColumnName => "azienda_id";

    public WebTourContenutiService(IDatabaseService databaseService, ILogger<WebTourContenutiService> logger, ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>Elenco dei contenuti tour di un'azienda.</summary>
    public async Task<List<WebTourContenuto>> ListByAziendaAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_contenuti_list(@AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<WebTourContenuto>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero contenuti tour per azienda {AziendaId}", aziendaId);
            return new List<WebTourContenuto>();
        }
    }

    /// <summary>Recupera un contenuto per id, scopato per azienda. NULL se non trovato/altra azienda.</summary>
    public async Task<WebTourContenuto?> GetByIdAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_contenuti_get(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero contenuto tour {Id} per azienda {AziendaId}", id, aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Recupera il contenuto associato a un viaggio (relazione 1:1), scopato per azienda.</summary>
    public async Task<WebTourContenuto?> GetByViaggioAsync(int viaggioId, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_contenuti_get_by_viaggio(@ViaggioId::integer, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("ViaggioId", viaggioId);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero contenuto per viaggio {ViaggioId} azienda {AziendaId}", viaggioId, aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebTourContenuto> CreateAsync(WebTourContenuto entity)
    {
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_tour_contenuti_insert(
                @AziendaId::integer,
                @ViaggioIdFk::integer,
                @Slug::varchar,
                @Sottotitolo::varchar,
                @DescrizioneHtml::text,
                @Difficolta::varchar,
                @DurataTesto::varchar,
                @LuoghiVisitati::text,
                @InfoPernottamentoHtml::text,
                @InfoPastiHtml::text,
                @InfoEquipaggiamentoHtml::text,
                @AltreInfoHtml::text,
                @MetaTitle::varchar,
                @MetaDescription::varchar,
                @StatoPubblicazione::varchar,
                @Ordine::integer,
                @DataPubblicazione::timestamptz
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            BindWritableParams(cmd, entity);

            var result = await cmd.ExecuteScalarAsync();
            entity.WebTourContenutoId = Convert.ToInt64(result);

            _logger.LogInformation("Contenuto tour creato con ID {Id} (viaggio {ViaggioId})", entity.WebTourContenutoId, entity.ViaggioIdFk);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante creazione contenuto tour: {Error}", pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del contenuto tour (viaggio {ViaggioId})", entity.ViaggioIdFk);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<WebTourContenuto> UpdateAsync(WebTourContenuto entity)
    {
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_tour_contenuti_update(
                @Id::bigint,
                @AziendaId::integer,
                @ViaggioIdFk::integer,
                @Slug::varchar,
                @Sottotitolo::varchar,
                @DescrizioneHtml::text,
                @Difficolta::varchar,
                @DurataTesto::varchar,
                @LuoghiVisitati::text,
                @InfoPernottamentoHtml::text,
                @InfoPastiHtml::text,
                @InfoEquipaggiamentoHtml::text,
                @AltreInfoHtml::text,
                @MetaTitle::varchar,
                @MetaDescription::varchar,
                @StatoPubblicazione::varchar,
                @Ordine::integer,
                @DataPubblicazione::timestamptz
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", entity.WebTourContenutoId);
            BindWritableParams(cmd, entity);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (rows == 0)
            {
                throw new InvalidOperationException($"Contenuto tour {entity.WebTourContenutoId} non trovato per l'azienda {entity.AziendaId}.");
            }

            _logger.LogInformation("Contenuto tour {Id} aggiornato", entity.WebTourContenutoId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante aggiornamento contenuto tour {Id}: {Error}", entity.WebTourContenutoId, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del contenuto tour {Id}", entity.WebTourContenutoId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Elimina un contenuto tour, scopato per azienda. True se una riga è stata eliminata.</summary>
    public async Task<bool> DeleteAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_web_tour_contenuti_delete(@Id::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var rows = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Contenuto tour {Id} eliminato ({Rows} righe)", id, rows);
            return rows > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante eliminazione contenuto tour {Id}: {Error}", id, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione del contenuto tour {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Aggiunge i parametri dei campi scrivibili (comuni a insert/update, stesso ordine
    /// dopo azienda/viaggio). L'id è aggiunto a parte solo nell'update.
    /// </summary>
    private static void BindWritableParams(NpgsqlCommand cmd, WebTourContenuto e)
    {
        cmd.Parameters.AddWithValue("AziendaId", e.AziendaId);
        cmd.Parameters.AddWithValue("ViaggioIdFk", e.ViaggioIdFk);
        cmd.Parameters.AddWithValue("Slug", e.Slug);
        cmd.Parameters.AddWithValue("Sottotitolo", (object?)e.Sottotitolo ?? DBNull.Value);
        cmd.Parameters.AddWithValue("DescrizioneHtml", (object?)e.DescrizioneHtml ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Difficolta", (object?)e.Difficolta ?? DBNull.Value);
        cmd.Parameters.AddWithValue("DurataTesto", (object?)e.DurataTesto ?? DBNull.Value);
        cmd.Parameters.AddWithValue("LuoghiVisitati", (object?)e.LuoghiVisitati ?? DBNull.Value);
        cmd.Parameters.AddWithValue("InfoPernottamentoHtml", (object?)e.InfoPernottamentoHtml ?? DBNull.Value);
        cmd.Parameters.AddWithValue("InfoPastiHtml", (object?)e.InfoPastiHtml ?? DBNull.Value);
        cmd.Parameters.AddWithValue("InfoEquipaggiamentoHtml", (object?)e.InfoEquipaggiamentoHtml ?? DBNull.Value);
        cmd.Parameters.AddWithValue("AltreInfoHtml", (object?)e.AltreInfoHtml ?? DBNull.Value);
        cmd.Parameters.AddWithValue("MetaTitle", (object?)e.MetaTitle ?? DBNull.Value);
        cmd.Parameters.AddWithValue("MetaDescription", (object?)e.MetaDescription ?? DBNull.Value);
        cmd.Parameters.AddWithValue("StatoPubblicazione", string.IsNullOrWhiteSpace(e.StatoPubblicazione) ? "bozza" : e.StatoPubblicazione);
        cmd.Parameters.AddWithValue("Ordine", e.Ordine);
        cmd.Parameters.AddWithValue("DataPubblicazione", (object?)e.DataPubblicazione ?? DBNull.Value);
    }

    protected override WebTourContenuto MapFromReader(NpgsqlDataReader reader)
    {
        return new WebTourContenuto
        {
            WebTourContenutoId = reader.GetInt64(reader.GetOrdinal("web_tour_contenuti_id")),
            ViaggioIdFk = ReadInt(reader, "viaggio_id_fk"),
            AziendaId = ReadInt(reader, "azienda_id"),
            Slug = reader.GetString(reader.GetOrdinal("slug")),
            Sottotitolo = ReadNullableString(reader, "sottotitolo"),
            DescrizioneHtml = ReadNullableString(reader, "descrizione_html"),
            Difficolta = ReadNullableString(reader, "difficolta"),
            DurataTesto = ReadNullableString(reader, "durata_testo"),
            LuoghiVisitati = ReadNullableString(reader, "luoghi_visitati"),
            InfoPernottamentoHtml = ReadNullableString(reader, "info_pernottamento_html"),
            InfoPastiHtml = ReadNullableString(reader, "info_pasti_html"),
            InfoEquipaggiamentoHtml = ReadNullableString(reader, "info_equipaggiamento_html"),
            AltreInfoHtml = ReadNullableString(reader, "altre_info_html"),
            MetaTitle = ReadNullableString(reader, "meta_title"),
            MetaDescription = ReadNullableString(reader, "meta_description"),
            StatoPubblicazione = reader.GetString(reader.GetOrdinal("stato_pubblicazione")),
            Ordine = ReadInt(reader, "ordine"),
            DataPubblicazione = ReadNullableDateTime(reader, "data_pubblicazione"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Created = ReadNullableDateTime(reader, "created"),
            UpdatedBy = ReadNullableString(reader, "updated_by"),
            Updated = ReadNullableDateTime(reader, "updated")
        };
    }
}
