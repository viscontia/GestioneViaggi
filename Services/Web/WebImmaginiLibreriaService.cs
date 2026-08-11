using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Shared.Storage;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Libreria immagini dell'azienda (script 523): icone e immagini generiche non legate a un viaggio.
/// </summary>
/// <remarks>
/// I file stanno sotto il prefisso <c>libreria/{azienda}/</c>, separato da quello delle gallerie
/// dei tour: la separazione che serve è logica, e il prefisso la garantisce senza richiedere un
/// secondo bucket con la sua configurazione e le sue policy.
/// </remarks>
public sealed class WebImmaginiLibreriaService
{
    private readonly IDatabaseService _db;
    private readonly IWebMediaStorage _storage;
    private readonly ILogger<WebImmaginiLibreriaService> _logger;

    public WebImmaginiLibreriaService(
        IDatabaseService db, IWebMediaStorage storage, ILogger<WebImmaginiLibreriaService> logger)
    {
        _db = db; _storage = storage; _logger = logger;
    }

    public async Task<List<WebImmagineLibreria>> ListAsync(int aziendaId)
    {
        var list = new List<WebImmagineLibreria>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT * FROM fn_web_immagini_libreria_list(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        return list;
    }

    /// <summary>
    /// Carica un file nella libreria. <paramref name="nomeOriginale"/> serve a due cose: decidere
    /// se conservare il PNG (trasparenza delle icone) e proporre una descrizione di partenza.
    /// </summary>
    public async Task<long> CaricaAsync(
        int aziendaId, string nomeOriginale, string? descrizione, Stream contenuto, CancellationToken ct = default)
    {
        var isPng = nomeOriginale.EndsWith(".png", StringComparison.OrdinalIgnoreCase);
        var elaborata = await WebImageProcessor.ToEmailLibreriaAsync(contenuto, isPng, ct);

        var estensione = isPng ? "png" : "jpg";
        var path = $"libreria/{aziendaId}/{Guid.NewGuid():N}.{estensione}";

        await using (var upload = new MemoryStream(elaborata.Bytes))
            await _storage.UploadAsync(path, upload, elaborata.Mime, ct);

        var url = _storage.BuildPublicUrl(path);
        var nome = string.IsNullOrWhiteSpace(descrizione)
            ? Path.GetFileNameWithoutExtension(nomeOriginale)
            : descrizione!.Trim();
        if (nome.Length < 2) nome = $"Immagine {DateTime.Now:yyyyMMdd-HHmmss}";

        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(@"
                SELECT fn_web_immagini_libreria_insert(
                    @Az::integer, @Descr::varchar, @Url::varchar, @Path::varchar,
                    @Mime::varchar, @W::integer, @H::integer)", conn);
            cmd.Parameters.AddWithValue("Az", aziendaId);
            cmd.Parameters.AddWithValue("Descr", nome);
            cmd.Parameters.AddWithValue("Url", url);
            cmd.Parameters.AddWithValue("Path", path);
            cmd.Parameters.AddWithValue("Mime", elaborata.Mime);
            cmd.Parameters.AddWithValue("W", elaborata.Width);
            cmd.Parameters.AddWithValue("H", elaborata.Height);
            return Convert.ToInt64(await cmd.ExecuteScalarAsync());
        }
        catch (Exception ex)
        {
            // Il file è già su Storage: se la riga non si scrive, il file resterebbe orfano.
            _logger.LogError(ex, "Libreria: riga non creata per {Path}, rimuovo il file caricato", path);
            try { await _storage.DeleteAsync(path, ct); } catch { }
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "web_immagini_libreria");
        }
    }

    public async Task<bool> RinominaAsync(long id, int aziendaId, string descrizione)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_immagini_libreria_rinomina(@Id::bigint, @Az::integer, @Descr::varchar)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("Az", aziendaId);
            cmd.Parameters.AddWithValue("Descr", descrizione);
            return Convert.ToInt32(await cmd.ExecuteScalarAsync()) > 0;
        }
        catch (Exception ex)
        {
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "web_immagini_libreria");
        }
    }

    /// <summary>Dove l'immagine è usata. Vuoto = si può eliminare.</summary>
    public async Task<List<ImmagineInUso>> UsiAsync(long id, int aziendaId)
    {
        var list = new List<ImmagineInUso>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT oggetto, stato, blocchi FROM fn_web_immagini_libreria_in_uso(@Id::bigint, @Az::integer)", conn);
        cmd.Parameters.AddWithValue("Id", id);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(new ImmagineInUso(r.GetString(0), r.GetString(1), r.GetInt32(2)));
        return list;
    }

    /// <summary>
    /// Elimina l'immagine, prima dal database e poi da Storage. La guardia sull'uso sta nella
    /// function: se l'immagine è in una newsletter, la <c>DELETE</c> viene rifiutata e il file
    /// resta al suo posto.
    /// </summary>
    public async Task<bool> EliminaAsync(WebImmagineLibreria img, CancellationToken ct = default)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_immagini_libreria_delete(@Id::bigint, @Az::integer)", conn);
            cmd.Parameters.AddWithValue("Id", img.WebImmagineLibreriaId);
            cmd.Parameters.AddWithValue("Az", img.AziendaId);
            var righe = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (righe == 0) return false;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            throw new InvalidOperationException(pex.MessageText);
        }

        // File orfano tollerato: meglio un file di troppo su Storage che una riga fantasma.
        try { await _storage.DeleteAsync(img.StoragePath, ct); }
        catch (Exception ex) { _logger.LogWarning(ex, "Libreria: file {Path} non rimosso da Storage", img.StoragePath); }

        return true;
    }

    private static WebImmagineLibreria Map(NpgsqlDataReader r) => new()
    {
        WebImmagineLibreriaId = r.GetInt64(r.GetOrdinal("web_immagini_libreria_id")),
        Descrizione           = r.GetString(r.GetOrdinal("descrizione")),
        Url                   = r.GetString(r.GetOrdinal("url")),
        StoragePath           = r.GetString(r.GetOrdinal("storage_path")),
        Mime                  = r.IsDBNull(r.GetOrdinal("mime")) ? null : r.GetString(r.GetOrdinal("mime")),
        Larghezza             = r.IsDBNull(r.GetOrdinal("larghezza")) ? null : r.GetInt32(r.GetOrdinal("larghezza")),
        Altezza               = r.IsDBNull(r.GetOrdinal("altezza")) ? null : r.GetInt32(r.GetOrdinal("altezza")),
        Ordine                = r.GetInt32(r.GetOrdinal("ordine")),
        AziendaId             = r.GetInt32(r.GetOrdinal("azienda_id")),
    };
}
