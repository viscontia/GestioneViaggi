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
    private readonly WebIndirizziService _indirizzi;
    private readonly ILogger<NewsletterRenderService> _logger;

    public NewsletterRenderService(
        IDatabaseService db, WebNewsletterBlocchiService blocchi, WebAziendeFunzioniService funzioni,
        NewsletterMediaService media, WebIndirizziService indirizzi,
        ILogger<NewsletterRenderService> logger)
    {
        _db = db; _blocchi = blocchi; _funzioni = funzioni; _media = media;
        _indirizzi = indirizzi; _logger = logger;
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

    /// <summary>Campi disponibili nel footer, nell'ordine in cui vengono proposti.</summary>
    public static readonly (string Campo, string Etichetta)[] CampiFooter =
    {
        ("ragione_sociale", "Ragione sociale"),
        ("indirizzo",       "Indirizzo della sede"),
        ("partita_iva",     "Partita IVA"),
        ("email",           "Email"),
        ("telefono",        "Telefono"),
        ("sito_web",        "Sito web"),
    };

    /// <summary>
    /// Salva la composizione del footer nel JSONB della funzione "newsletter" dell'azienda,
    /// preservando le altre chiavi eventualmente presenti nei parametri.
    /// </summary>
    public async Task SalvaFooterConfigAsync(int aziendaId, NewsletterFooterConfig config)
    {
        var f = await _funzioni.GetByFunzioneAsync(aziendaId, WebAziendeFunzioniService.FunzioneNewsletter);

        // Si riscrive solo la chiave "footer": i parametri possono contenere altro (oggi no, ma
        // e' lo stesso JSONB usato da altre funzioni web) e sovrascriverlo tutto sarebbe distruttivo.
        var radice = new Dictionary<string, object?>();
        if (!string.IsNullOrWhiteSpace(f?.Parametri))
        {
            try
            {
                using var doc = JsonDocument.Parse(f!.Parametri!);
                foreach (var p in doc.RootElement.EnumerateObject())
                    if (p.Name != "footer") radice[p.Name] = JsonSerializer.Deserialize<object>(p.Value.GetRawText());
            }
            catch (Exception ex) { _logger.LogWarning(ex, "Parametri azienda {Az} illeggibili: li riscrivo", aziendaId); }
        }

        radice["footer"] = new
        {
            campi = config.Campi,
            colonne = config.Colonne,
            allineamento = config.Allineamento
        };

        var json = JsonSerializer.Serialize(radice);

        if (f is null)
        {
            await _funzioni.CreateAsync(new Models.Web.WebAziendaFunzione
            {
                AziendaId = aziendaId,
                Funzione = WebAziendeFunzioniService.FunzioneNewsletter,
                Attiva = true,
                Parametri = json
            });
        }
        else
        {
            f.Parametri = json;
            await _funzioni.UpdateAsync(f);
        }
    }

    /// <summary>
    /// Tutto cio' che serve a rendere una newsletter, letto UNA volta sola. Il link di
    /// disiscrizione e' firmato per destinatario, quindi l'HTML va ricomposto per ognuno: senza
    /// questo contesto, una campagna da 400 destinatari rileggerebbe blocchi, azienda, logo e
    /// configurazione footer 400 volte.
    /// </summary>
    public sealed record ContestoRender(
        List<Models.Web.WebNewsletterBlocco> Blocchi,
        NewsletterRenderAzienda Azienda,
        NewsletterFooterConfig Footer,
        string? Token);

    public async Task<ContestoRender> PreparaAsync(long invioId, int aziendaId)
    {
        var blocchi = await _blocchi.ListAsync(invioId, aziendaId);

        // Collegamenti presi dalla rubrica: si risolvono al rendering finche' la newsletter NON
        // e' stata inviata. Cosi' correggere un indirizzo in rubrica allinea da solo tutte le
        // bozze e i modelli - che e' il motivo per cui la rubrica esiste.
        // Su una newsletter gia' inviata non si tocca nulla: e' un documento storico, e mostrare
        // un indirizzo diverso da quello spedito sarebbe una bugia.
        if (!await IsInviataAsync(invioId, aziendaId))
        {
            var conLegame = blocchi.Where(b => b.IndirizzoIdFk.HasValue).ToList();
            if (conLegame.Count > 0)
            {
                var rubrica = (await _indirizzi.ListAsync(aziendaId))
                    .ToDictionary(x => x.WebIndirizzoId, x => x.Url);
                foreach (var b in conLegame)
                    if (rubrica.TryGetValue(b.IndirizzoIdFk!.Value, out var url)) b.LinkUrl = url;
            }
        }

        var logoUrl = await _media.GetLogoUrlAsync(aziendaId);
        var azienda = await GetDatiAziendaAsync(aziendaId, logoUrl);
        var footer = await GetFooterConfigAsync(aziendaId);
        var token = await GetTokenIscrizioneAsync(aziendaId);
        return new ContestoRender(blocchi, azienda, footer, token);
    }

    /// <summary>HTML per un singolo destinatario, dal contesto gia' preparato.</summary>
    public static string Render(ContestoRender ctx, string emailDestinatario)
    {
        var unsub = NewsletterUnsubscribe.BuildUrl(ctx.Azienda.SitoWeb, emailDestinatario, ctx.Token);

        var render = ctx.Blocchi.Select(b => new NewsletterRenderBlocco(
            Tipo: b.Tipo,
            Layout: b.Layout,
            Colonne: b.Colonne,
            Titolo: b.Titolo,
            Sottotitolo: b.Sottotitolo,
            CorpoHtml: b.CorpoHtml,
            ImmagineUrl: b.ImmagineUrl,
            ImmagineAlt: b.ImmagineAlt,
            LinkUrl: b.LinkUrl,
            LinkEtichetta: b.LinkEtichetta,
            Social: b.Social,
            IconaUrl: b.IconaUrl));

        return NewsletterHtmlRenderer.Render(render, ctx.Azienda, ctx.Footer, unsub);
    }

    /// <summary>
    /// HTML completo di una newsletter. <paramref name="emailDestinatario"/> serve solo a firmare
    /// il link di disiscrizione: in anteprima si passa un indirizzo di esempio.
    /// </summary>
    public async Task<string> RenderAsync(long invioId, int aziendaId, string emailDestinatario)
        => Render(await PreparaAsync(invioId, aziendaId), emailDestinatario);

    /// <summary>Una newsletter inviata e' immutabile: nessuna risoluzione dalla rubrica.</summary>
    private async Task<bool> IsInviataAsync(long invioId, int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT stato FROM web_newsletter_invii WHERE web_newsletter_invii_id=@Id AND azienda_id=@Az", conn);
        cmd.Parameters.AddWithValue("Id", invioId);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        var v = await cmd.ExecuteScalarAsync();
        return v is string stato && stato == "inviata";
    }

    /// <summary>
    /// Scrive nei blocchi l'URL corrente della rubrica. Va chiamata PRIMA di comporre l'HTML
    /// dell'invio: da quel momento la newsletter e' un documento storico.
    /// </summary>
    public async Task<int> CongelaIndirizziAsync(long invioId, int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT fn_web_newsletter_congela_indirizzi(@Id::bigint, @Az::integer)", conn);
        cmd.Parameters.AddWithValue("Id", invioId);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        return Convert.ToInt32(await cmd.ExecuteScalarAsync());
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
