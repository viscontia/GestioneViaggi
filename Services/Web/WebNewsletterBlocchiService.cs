using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// CRUD dei blocchi che compongono una newsletter (script 512). Tutte le operazioni sono scopate
/// per azienda: le guardie autoritative (unicita' dei blocchi obbligatori, non eliminabilita',
/// appartenenza della newsletter al tenant) stanno nelle function DB, qui si traducono solo i
/// loro messaggi.
/// </summary>
public sealed class WebNewsletterBlocchiService
{
    private readonly IDatabaseService _db;
    private readonly ILogger<WebNewsletterBlocchiService> _logger;

    public WebNewsletterBlocchiService(IDatabaseService db, ILogger<WebNewsletterBlocchiService> logger)
    {
        _db = db; _logger = logger;
    }

    public async Task<List<WebNewsletterTipoBlocco>> GetCatalogoAsync()
    {
        var list = new List<WebNewsletterTipoBlocco>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT tipo, etichetta, obbligatorio, max_occorrenze, ordine_catalogo FROM fn_web_newsletter_tipi_blocco() ORDER BY ordine_catalogo", conn);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            list.Add(new WebNewsletterTipoBlocco(
                r.GetString(0), r.GetString(1), r.GetBoolean(2),
                r.IsDBNull(3) ? null : r.GetInt32(3), r.GetInt32(4)));
        }
        return list;
    }

    /// <summary>
    /// Tutte le foto della galleria dell'azienda, per il picker della newsletter. A differenza
    /// dell'itinerario — che pesca dal singolo tour — qui si compone da tutto il repertorio.
    /// </summary>
    public async Task<List<Components.Shared.ImmaginePicker.Voce>> GetGalleriaAziendaAsync(int aziendaId)
    {
        var list = new List<Components.Shared.ImmaginePicker.Voce>();

        // La LIBRERIA per prima: icone e immagini generiche sono la scelta piu' probabile per una
        // newsletter, e tenerle in un contesto separato evita di scorrere le foto dei tour per
        // trovare un'icona.
        await using (var connLib = await _db.GetConnectionAsync())
        await using (var cmdLib = new NpgsqlCommand(
            "SELECT url, storage_path, descrizione FROM fn_web_immagini_libreria_list(@Az::integer)", connLib))
        {
            cmdLib.Parameters.AddWithValue("Az", aziendaId);
            await using var rl = await cmdLib.ExecuteReaderAsync();
            while (await rl.ReadAsync())
            {
                list.Add(new Components.Shared.ImmaginePicker.Voce(
                    Url: rl.GetString(0),
                    StoragePath: rl.GetString(1),
                    Alt: rl.IsDBNull(2) ? null : rl.GetString(2),
                    Contesto: "Libreria immagini"));
            }
        }

        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT url, storage_path, alt_text, contesto FROM fn_web_immagini_azienda(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            list.Add(new Components.Shared.ImmaginePicker.Voce(
                Url: r.GetString(0),
                StoragePath: r.GetString(1),
                Alt: r.IsDBNull(2) ? null : r.GetString(2),
                Contesto: r.IsDBNull(3) ? null : r.GetString(3)));
        }
        return list;
    }

    public async Task<List<WebNewsletterBlocco>> ListAsync(long invioId, int aziendaId)
    {
        var list = new List<WebNewsletterBlocco>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT * FROM fn_web_newsletter_blocchi_list(@Invio::bigint, @Az::integer)", conn);
        cmd.Parameters.AddWithValue("Invio", invioId);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        return list;
    }

    public async Task<long> CreateAsync(WebNewsletterBlocco b)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(@"
                SELECT fn_web_newsletter_blocchi_insert(
                    @Az::integer, @Invio::bigint, @Tipo::varchar, NULL::integer,
                    @Layout::varchar, @Colonne::smallint,
                    @Titolo::varchar, @Sottotitolo::varchar, @Corpo::text,
                    @ImgUrl::varchar, @ImgPath::varchar, @ImgAlt::varchar,
                    @LinkUrl::varchar, @LinkEtichetta::varchar, @DataViaggio::integer, @Indirizzo::bigint, @Social::varchar, @IconaUrl::varchar)", conn);

            cmd.Parameters.AddWithValue("Az", b.AziendaId);
            cmd.Parameters.AddWithValue("Invio", b.InvioIdFk);
            cmd.Parameters.AddWithValue("Tipo", b.Tipo);
            cmd.Parameters.AddWithValue("Layout", b.Layout ?? "pieno");
            cmd.Parameters.AddWithValue("Colonne", b.Colonne == 0 ? (short)1 : b.Colonne);
            AddNullable(cmd, "Titolo", b.Titolo);
            AddNullable(cmd, "Sottotitolo", b.Sottotitolo);
            AddNullable(cmd, "Corpo", b.CorpoHtml);
            AddNullable(cmd, "ImgUrl", b.ImmagineUrl);
            AddNullable(cmd, "ImgPath", b.ImmagineStoragePath);
            AddNullable(cmd, "ImgAlt", b.ImmagineAlt);
            AddNullable(cmd, "LinkUrl", b.LinkUrl);
            AddNullable(cmd, "LinkEtichetta", b.LinkEtichetta);
            cmd.Parameters.AddWithValue("DataViaggio", (object?)b.DataViaggioIdFk ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Indirizzo", (object?)b.IndirizzoIdFk ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Social", (object?)b.Social ?? DBNull.Value);
        cmd.Parameters.AddWithValue("IconaUrl", (object?)b.IconaUrl ?? DBNull.Value);

            return Convert.ToInt64(await cmd.ExecuteScalarAsync());
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            // Guardie del DB (max occorrenze, tenant altrui): il messaggio e' gia' per l'utente.
            throw new InvalidOperationException(pex.MessageText);
        }
    }

    public async Task<bool> UpdateAsync(WebNewsletterBlocco b)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(@"
            SELECT fn_web_newsletter_blocchi_update(
                @Id::bigint, @Az::integer, @Layout::varchar, @Colonne::smallint,
                @Titolo::varchar, @Sottotitolo::varchar, @Corpo::text,
                @ImgUrl::varchar, @ImgPath::varchar, @ImgAlt::varchar,
                @LinkUrl::varchar, @LinkEtichetta::varchar, @DataViaggio::integer, @Indirizzo::bigint, @Social::varchar, @IconaUrl::varchar)", conn);

        cmd.Parameters.AddWithValue("Id", b.WebNewsletterBloccoId);
        cmd.Parameters.AddWithValue("Az", b.AziendaId);
        cmd.Parameters.AddWithValue("Layout", b.Layout ?? "pieno");
        cmd.Parameters.AddWithValue("Colonne", b.Colonne == 0 ? (short)1 : b.Colonne);
        AddNullable(cmd, "Titolo", b.Titolo);
        AddNullable(cmd, "Sottotitolo", b.Sottotitolo);
        AddNullable(cmd, "Corpo", b.CorpoHtml);
        AddNullable(cmd, "ImgUrl", b.ImmagineUrl);
        AddNullable(cmd, "ImgPath", b.ImmagineStoragePath);
        AddNullable(cmd, "ImgAlt", b.ImmagineAlt);
        AddNullable(cmd, "LinkUrl", b.LinkUrl);
        AddNullable(cmd, "LinkEtichetta", b.LinkEtichetta);
        cmd.Parameters.AddWithValue("DataViaggio", (object?)b.DataViaggioIdFk ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Indirizzo", (object?)b.IndirizzoIdFk ?? DBNull.Value);
        cmd.Parameters.AddWithValue("Social", (object?)b.Social ?? DBNull.Value);
        cmd.Parameters.AddWithValue("IconaUrl", (object?)b.IconaUrl ?? DBNull.Value);

        return Convert.ToInt32(await cmd.ExecuteScalarAsync()) > 0;
    }

    public async Task<bool> DeleteAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_newsletter_blocchi_delete(@Id::bigint, @Az::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("Az", aziendaId);
            return Convert.ToInt32(await cmd.ExecuteScalarAsync()) > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            throw new InvalidOperationException(pex.MessageText);
        }
    }

    public async Task<int> ReorderAsync(int aziendaId, long invioId, IReadOnlyList<long> idsInOrdine)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT fn_web_newsletter_blocchi_reorder(@Az::integer, @Invio::bigint, @Ids::bigint[])", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("Invio", invioId);
        cmd.Parameters.AddWithValue("Ids", idsInOrdine.ToArray());
        return Convert.ToInt32(await cmd.ExecuteScalarAsync());
    }

    private static void AddNullable(NpgsqlCommand cmd, string nome, string? valore)
        => cmd.Parameters.AddWithValue(nome, string.IsNullOrWhiteSpace(valore) ? DBNull.Value : valore);

    private static WebNewsletterBlocco Map(NpgsqlDataReader r) => new()
    {
        WebNewsletterBloccoId = r.GetInt64(r.GetOrdinal("web_newsletter_blocchi_id")),
        InvioIdFk             = r.GetInt64(r.GetOrdinal("invio_id_fk")),
        Tipo                  = r.GetString(r.GetOrdinal("tipo")),
        Ordine                = r.GetInt32(r.GetOrdinal("ordine")),
        Layout                = r.GetString(r.GetOrdinal("layout")),
        Colonne               = r.GetInt16(r.GetOrdinal("colonne")),
        Titolo                = Str(r, "titolo"),
        Sottotitolo           = Str(r, "sottotitolo"),
        CorpoHtml             = Str(r, "corpo_html"),
        ImmagineUrl           = Str(r, "immagine_url"),
        ImmagineStoragePath   = Str(r, "immagine_storage_path"),
        ImmagineAlt           = Str(r, "immagine_alt"),
        LinkUrl               = Str(r, "link_url"),
        LinkEtichetta         = Str(r, "link_etichetta"),
        DataViaggioIdFk       = r.IsDBNull(r.GetOrdinal("data_viaggio_id_fk")) ? null : r.GetInt32(r.GetOrdinal("data_viaggio_id_fk")),
        IndirizzoIdFk         = r.IsDBNull(r.GetOrdinal("indirizzo_id_fk")) ? null : r.GetInt64(r.GetOrdinal("indirizzo_id_fk")),
        Social                = r.IsDBNull(r.GetOrdinal("social")) ? null : r.GetString(r.GetOrdinal("social")),
        IconaUrl              = r.IsDBNull(r.GetOrdinal("icona_url")) ? null : r.GetString(r.GetOrdinal("icona_url")),
        AziendaId             = r.GetInt32(r.GetOrdinal("azienda_id")),
    };

    private static string? Str(NpgsqlDataReader r, string col)
    {
        var i = r.GetOrdinal(col);
        return r.IsDBNull(i) ? null : r.GetString(i);
    }
}
