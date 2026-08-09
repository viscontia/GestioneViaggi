using System.Text.Json;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Email;
using GestioneViaggi.Services.Shared;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Ponte fra i blocchi salvati e <see cref="NewsletterHtmlRenderer"/>: raccoglie dati azienda,
/// logo, composizione del footer e link di disiscrizione, e produce l'HTML finale.
/// </summary>
/// <remarks>
/// Il renderer e' volutamente puro e non sa nulla di database: tutto il lavoro di raccolta sta
/// qui. E' anche il punto in cui si decide cosa vede l'anteprima, che deve mostrare
/// <b>esattamente</b> cio' che partira' — altrimenti non serve a niente.
/// </remarks>
public sealed class NewsletterRenderService
{
    private readonly IDatabaseService _db;
    private readonly WebNewsletterBlocchiService _blocchi;
    private readonly WebAziendeFunzioniService _funzioni;
    private readonly NewsletterMediaService _media;
    private readonly ILogger<NewsletterRenderService> _logger;

    public NewsletterRenderService(
        IDatabaseService db, WebNewsletterBlocchiService blocchi, WebAziendeFunzioniService funzioni,
        NewsletterMediaService media, ILogger<NewsletterRenderService> logger)
    {
        _db = db; _blocchi = blocchi; _funzioni = funzioni; _media = media; _logger = logger;
    }

    /// <summary>
    /// Contenuto di un riquadro tour ricavato da un'edizione. <c>Pubblicato</c> false significa
    /// che la scheda e' ancora in bozza e il link porterebbe a una pagina inesistente.
    /// </summary>
    public sealed record DatiTour(
        string Titolo, string? Periodo, string? Testo, string Slug, bool Pubblicato,
        string? ImmagineUrl, string? ImmagineStoragePath, string? LinkCompleto);

    /// <summary>
    /// Compila un riquadro tour dall'edizione scelta: titolo, periodo, testo, copertina (gia'
    /// convertita in JPEG per l'email) e link costruito da sito web + slug.
    /// </summary>
    public async Task<DatiTour?> GetDatiTourAsync(int dataViaggioId, int aziendaId, bool convertiImmagine = true)
    {
        DatiTour? dati = null;

        await using (var conn = await _db.GetConnectionAsync())
        await using (var cmd = new NpgsqlCommand(
            "SELECT titolo, periodo, testo, slug, pubblicato, immagine_url, immagine_storage_path FROM fn_web_newsletter_dati_tour(@Data::integer, @Az::integer)", conn))
        {
            cmd.Parameters.AddWithValue("Data", dataViaggioId);
            cmd.Parameters.AddWithValue("Az", aziendaId);
            await using var r = await cmd.ExecuteReaderAsync();
            if (await r.ReadAsync())
            {
                dati = new DatiTour(
                    Titolo: r.GetString(0),
                    Periodo: Str(r, 1),
                    Testo: Str(r, 2),
                    Slug: r.GetString(3),
                    Pubblicato: r.GetBoolean(4),
                    ImmagineUrl: Str(r, 5),
                    ImmagineStoragePath: Str(r, 6),
                    LinkCompleto: null);
            }
        }

        if (dati is null) return null;

        var azienda = await GetDatiAziendaAsync(aziendaId);
        var baseUrl = (azienda.SitoWeb ?? "").TrimEnd('/');
        var link = string.IsNullOrWhiteSpace(baseUrl) ? null : $"{baseUrl}/tour/{dati.Slug}";

        // La copertina della galleria e' WebP: per l'email serve il derivato JPEG.
        var immagine = convertiImmagine
            ? await _media.ConvertiDaUrlAsync(dati.ImmagineUrl, dati.ImmagineStoragePath)
            : dati.ImmagineUrl;

        return dati with { ImmagineUrl = immagine, LinkCompleto = link };
    }

    /// <summary>Dati aziendali per intestazione e footer (fn_web_newsletter_dati_azienda).</summary>
    public async Task<NewsletterRenderAzienda> GetDatiAziendaAsync(int aziendaId, string? logoUrl = null)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT ragione_sociale, partita_iva, indirizzo, email, telefono, sito_web FROM fn_web_newsletter_dati_azienda(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();

        if (!await r.ReadAsync())
            return new NewsletterRenderAzienda("(azienda non trovata)");

        return new NewsletterRenderAzienda(
            RagioneSociale: r.GetString(0),
            LogoUrl: logoUrl,
            Indirizzo: Str(r, 2),
            PartitaIva: Str(r, 1),
            Email: Str(r, 3),
            Telefono: Str(r, 4),
            SitoWeb: Str(r, 5));
    }

    /// <summary>
    /// Composizione del footer configurata per l'azienda, dal JSONB
    /// <c>web_aziende_funzioni.parametri</c> della funzione "newsletter". Formato atteso:
    /// <code>{"footer":{"campi":["ragione_sociale","indirizzo"],"colonne":1,"allineamento":"centro"}}</code>
    /// Assente o malformato → composizione di default: meglio un footer standard che nessun footer.
    /// </summary>
    public async Task<NewsletterFooterConfig> GetFooterConfigAsync(int aziendaId)
    {
        try
        {
            var f = await _funzioni.GetByFunzioneAsync(aziendaId, WebAziendeFunzioniService.FunzioneNewsletter);
            if (string.IsNullOrWhiteSpace(f?.Parametri)) return NewsletterFooterConfig.Default;

            using var doc = JsonDocument.Parse(f!.Parametri!);
            if (!doc.RootElement.TryGetProperty("footer", out var footer)) return NewsletterFooterConfig.Default;

            var campi = footer.TryGetProperty("campi", out var c) && c.ValueKind == JsonValueKind.Array
                ? c.EnumerateArray().Select(x => x.GetString() ?? "").Where(x => x.Length > 0).ToList()
                : NewsletterFooterConfig.Default.Campi.ToList();

            if (campi.Count == 0) campi = NewsletterFooterConfig.Default.Campi.ToList();

            var colonne = footer.TryGetProperty("colonne", out var col) && col.TryGetInt32(out var n) ? n : 1;
            var align = footer.TryGetProperty("allineamento", out var a) ? a.GetString() ?? "centro" : "centro";

            return new NewsletterFooterConfig(campi, colonne == 2 ? 2 : 1, align);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Composizione footer non leggibile per azienda {Az}: uso quella di default", aziendaId);
            return NewsletterFooterConfig.Default;
        }
    }

    /// <summary>
    /// HTML completo di una newsletter. <paramref name="emailDestinatario"/> serve solo a firmare
    /// il link di disiscrizione: in anteprima si passa un indirizzo di esempio.
    /// </summary>
    public async Task<string> RenderAsync(long invioId, int aziendaId, string emailDestinatario)
    {
        var blocchi = await _blocchi.ListAsync(invioId, aziendaId);
        var logoUrl = await _media.GetLogoUrlAsync(aziendaId);
        var azienda = await GetDatiAziendaAsync(aziendaId, logoUrl);
        var footer = await GetFooterConfigAsync(aziendaId);

        var token = await GetTokenIscrizioneAsync(aziendaId);
        var unsub = NewsletterUnsubscribe.BuildUrl(azienda.SitoWeb, emailDestinatario, token);

        var render = blocchi.Select(b => new NewsletterRenderBlocco(
            Tipo: b.Tipo,
            Layout: b.Layout,
            Colonne: b.Colonne,
            Titolo: b.Titolo,
            Sottotitolo: b.Sottotitolo,
            CorpoHtml: b.CorpoHtml,
            ImmagineUrl: b.ImmagineUrl,
            ImmagineAlt: b.ImmagineAlt,
            LinkUrl: b.LinkUrl,
            LinkEtichetta: b.LinkEtichetta));

        return NewsletterHtmlRenderer.Render(render, azienda, footer, unsub);
    }

    private async Task<string?> GetTokenIscrizioneAsync(int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT token_iscrizione FROM ana_aziende WHERE azienda_id=@Id", conn);
        cmd.Parameters.AddWithValue("Id", aziendaId);
        var v = await cmd.ExecuteScalarAsync();
        return v == null || v == DBNull.Value ? null : (string)v;
    }

    private static string? Str(NpgsqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
}
