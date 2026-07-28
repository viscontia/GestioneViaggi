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

    private readonly WebTraduzioniService? _traduzioni;

    public WebTourContenutiService(IDatabaseService databaseService, ILogger<WebTourContenutiService> logger, ITenantContext? tenantContext = null, WebTraduzioniService? traduzioni = null)
        : base(databaseService, logger, tenantContext)
    {
        _traduzioni = traduzioni;
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

    /// <summary>Recupera il contenuto di un'edizione (data_viaggio), relazione 1:1, scopato per azienda. NULL se non esiste.</summary>
    public async Task<WebTourContenuto?> GetByDataViaggioAsync(int dataViaggioId, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_contenuti_get_by_data_viaggio(@DataViaggioId::integer, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("DataViaggioId", dataViaggioId);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero contenuto per edizione {DataViaggioId} azienda {AziendaId}", dataViaggioId, aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Elenco edizioni (date) di un viaggio con stato contenuto e flag effettuazione, per il selettore edizione.</summary>
    public async Task<List<EdizioneViaggio>> ListEdizioniAsync(int viaggioId, int aziendaId)
    {
        var list = new List<EdizioneViaggio>();
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_edizioni_per_viaggio(@ViaggioId::integer, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("ViaggioId", viaggioId);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                var contenutoOrd = reader.GetOrdinal("web_tour_contenuti_id");
                list.Add(new EdizioneViaggio(
                    ReadInt(reader, "data_viaggio_id"),
                    ReadNullableDateTime(reader, "data_inizio"),
                    ReadNullableDateTime(reader, "data_fine"),
                    (ReadNullableString(reader, "effettuato_sino") ?? "N") == "Y",
                    reader.IsDBNull(contenutoOrd) ? (long?)null : reader.GetInt64(contenutoOrd),
                    ReadNullableString(reader, "stato_pubblicazione")));
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero edizioni per viaggio {ViaggioId} azienda {AziendaId}", viaggioId, aziendaId);
        }
        return list;
    }

    /// <summary>
    /// Fatti sullo stato delle sezioni (Contenuti/Galleria/Itinerario/Traduzioni) di un'edizione, in una sola query.
    /// Usato dal semaforo dei sotto-tab all'apertura, quando i sotto-tab non sono ancora istanziati.
    /// NULL se il contenuto non esiste o è di altra azienda.
    /// </summary>
    public async Task<WebTourStatoSezioni?> GetStatoSezioniAsync(long contenutoId, int aziendaId, string[] lingue)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_stato_sezioni(@ContenutoId::bigint, @AziendaId::integer, @Lingue::varchar[])", conn);
            cmd.Parameters.AddWithValue("ContenutoId", contenutoId);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);
            cmd.Parameters.AddWithValue("Lingue", lingue);

            await using var reader = await cmd.ExecuteReaderAsync();
            if (!await reader.ReadAsync()) return null;

            return new WebTourStatoSezioni(
                reader.GetBoolean(reader.GetOrdinal("ha_slug")),
                reader.GetBoolean(reader.GetOrdinal("ha_sottotitolo")),
                reader.GetBoolean(reader.GetOrdinal("ha_descrizione")),
                reader.GetInt32(reader.GetOrdinal("n_immagini")),
                reader.GetBoolean(reader.GetOrdinal("ha_principale")),
                reader.GetInt32(reader.GetOrdinal("n_giornate")),
                reader.GetInt32(reader.GetOrdinal("n_traducibili")),
                reader.GetInt32(reader.GetOrdinal("n_tradotte")),
                reader.GetInt32(reader.GetOrdinal("n_revisionate")));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero stato sezioni del contenuto {ContenutoId} azienda {AziendaId}", contenutoId, aziendaId);
            return null;
        }
    }

    /// <summary>
    /// Fatti per le verifiche NON bloccanti sui contenuti di una edizione (giornate senza foto/mappa/passi,
    /// galleria vuota, SEO, incluso/escluso, capienza). NULL se il contenuto non esiste o è di altra azienda.
    /// </summary>
    public async Task<WebTourVerificheFatti?> GetVerificheAsync(long contenutoId, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_tour_verifiche(@ContenutoId::bigint, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("ContenutoId", contenutoId);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            if (!await reader.ReadAsync()) return null;

            return new WebTourVerificheFatti(
                reader.GetInt32(reader.GetOrdinal("n_giornate")),
                reader.GetInt32(reader.GetOrdinal("n_giornate_senza_passi")),
                reader.GetInt32(reader.GetOrdinal("n_giornate_senza_foto")),
                reader.GetInt32(reader.GetOrdinal("n_giornate_senza_mappa")),
                reader.GetBoolean(reader.GetOrdinal("ha_mappa_insieme")),
                reader.GetInt32(reader.GetOrdinal("n_immagini")),
                reader.GetBoolean(reader.GetOrdinal("ha_meta_title")),
                reader.GetBoolean(reader.GetOrdinal("ha_meta_description")),
                reader.GetBoolean(reader.GetOrdinal("ha_incluso")),
                reader.GetBoolean(reader.GetOrdinal("ha_escluso")),
                reader.GetBoolean(reader.GetOrdinal("ha_capienza")));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero verifiche del contenuto {ContenutoId} azienda {AziendaId}", contenutoId, aziendaId);
            return null;
        }
    }

    /// <summary>Clona un contenuto (con figlie e traduzioni) su una nuova data del medesimo viaggio. Ritorna l'id del nuovo contenuto.</summary>
    public async Task<long> ClonaAsync(long contenutoSorgenteId, int dataViaggioDestId, int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_web_tour_contenuti_clona(@Src::bigint, @Dest::integer, @AziendaId::integer)", conn);
            cmd.Parameters.AddWithValue("Src", contenutoSorgenteId);
            cmd.Parameters.AddWithValue("Dest", dataViaggioDestId);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);
            return Convert.ToInt64(await cmd.ExecuteScalarAsync());
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business durante clone contenuto {Id}: {Error}", contenutoSorgenteId, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il clone del contenuto {Id}", contenutoSorgenteId);
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
                @DataViaggioIdFk::integer,
                @Slug::varchar,
                @Sottotitolo::varchar,
                @DescrizioneHtml::text,
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
        // Snapshot pre-update per marcare obsolete le traduzioni dei campi IT cambiati (Blocco 10).
        var old = _traduzioni != null ? await GetByIdAsync(entity.WebTourContenutoId, entity.AziendaId) : null;

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            const string sql = @"SELECT fn_web_tour_contenuti_update(
                @Id::bigint,
                @AziendaId::integer,
                @ViaggioIdFk::integer,
                @DataViaggioIdFk::integer,
                @Slug::varchar,
                @Sottotitolo::varchar,
                @DescrizioneHtml::text,
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
            await MarcaTraduzioniObsoleteAsync(old, entity);
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

    /// <summary>Marca obsolete le traduzioni dei campi editoriali IT cambiati (Blocco 10). No-op senza _traduzioni.</summary>
    private async Task MarcaTraduzioniObsoleteAsync(WebTourContenuto? old, WebTourContenuto nuovo)
    {
        if (_traduzioni == null || old == null) return;
        var campi = new List<string>();
        void Chk(string campo, string? o, string? n) { if (!string.Equals(o ?? "", n ?? "", StringComparison.Ordinal)) campi.Add(campo); }
        Chk("sottotitolo", old.Sottotitolo, nuovo.Sottotitolo);
        Chk("descrizione_html", old.DescrizioneHtml, nuovo.DescrizioneHtml);
        Chk("durata_testo", old.DurataTesto, nuovo.DurataTesto);
        Chk("luoghi_visitati", old.LuoghiVisitati, nuovo.LuoghiVisitati);
        Chk("info_pernottamento_html", old.InfoPernottamentoHtml, nuovo.InfoPernottamentoHtml);
        Chk("info_pasti_html", old.InfoPastiHtml, nuovo.InfoPastiHtml);
        Chk("info_equipaggiamento_html", old.InfoEquipaggiamentoHtml, nuovo.InfoEquipaggiamentoHtml);
        Chk("altre_info_html", old.AltreInfoHtml, nuovo.AltreInfoHtml);
        Chk("meta_title", old.MetaTitle, nuovo.MetaTitle);
        Chk("meta_description", old.MetaDescription, nuovo.MetaDescription);
        foreach (var campo in campi)
            await _traduzioni.MarkObsoleteAsync(nuovo.AziendaId, "web_tour_contenuti", nuovo.WebTourContenutoId, campo);
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
        cmd.Parameters.AddWithValue("DataViaggioIdFk", e.DataViaggioIdFk);
        cmd.Parameters.AddWithValue("Slug", e.Slug);
        cmd.Parameters.AddWithValue("Sottotitolo", (object?)e.Sottotitolo ?? DBNull.Value);
        cmd.Parameters.AddWithValue("DescrizioneHtml", (object?)e.DescrizioneHtml ?? DBNull.Value);
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
            DataViaggioIdFk = ReadInt(reader, "data_viaggio_id_fk"),
            AziendaId = ReadInt(reader, "azienda_id"),
            Slug = reader.GetString(reader.GetOrdinal("slug")),
            Sottotitolo = ReadNullableString(reader, "sottotitolo"),
            DescrizioneHtml = ReadNullableString(reader, "descrizione_html"),
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
