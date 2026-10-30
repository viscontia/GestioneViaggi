using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Shared.Storage;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Prepara le immagini perche' siano utilizzabili in una email (Fase 2 newsletter a blocchi).
/// </summary>
/// <remarks>
/// Due regole, entrambe imposte da Outlook per Windows e non da preferenze:
/// <list type="bullet">
///   <item>niente URI <c>data:</c> — vanno URL pubblici https, quindi Supabase Storage (l'archivio pubblico delle
///         newsletter, <c>newsletter-media</c>: gli originali non sono pubblici, L27);</item>
///   <item>niente WebP — va JPEG, quindi le copertine dei tour (che la galleria salva in WebP)
///         hanno bisogno di un derivato dedicato.</item>
/// </list>
/// I derivati vivono sotto il prefisso <c>newsletter/</c> con percorso deterministico, cosi'
/// rigenerarli sovrascrive invece di accumulare file.
/// </remarks>
public sealed class NewsletterMediaService
{
    private readonly IWebMediaStorage _storage;
    private readonly AziendaLogoService _logoService;
    private readonly ILogger<NewsletterMediaService> _logger;

    /// <summary>
    /// URL del logo gia' preparato, per azienda. La chiave comprende l'identita' del logo e la
    /// sua data di modifica: se il logo cambia, la voce non viene riusata.
    /// </summary>
    /// <remarks>
    /// Senza questa cache il logo veniva riletto dal database (oltre 100 kB per SFT),
    /// riconvertito e <b>ricaricato su Storage a ogni anteprima e a ogni invio</b>, anche di
    /// prova. Il percorso e' deterministico, quindi il caricamento riscriveva sempre lo stesso
    /// file: lavoro e attesa per ottenere un risultato identico.
    /// Il servizio e' Scoped, quindi la cache vive quanto la sessione: nessun rischio di servire
    /// il logo di un'azienda a un'altra, perche' la chiave e' l'azienda.
    /// </remarks>
    private readonly Dictionary<int, (string Chiave, string? Url)> _cacheLogo = new();

    public NewsletterMediaService(
        IWebMediaStorage storage, AziendaLogoService logoService, ILogger<NewsletterMediaService> logger)
    {
        _storage = storage; _logoService = logoService; _logger = logger;
    }

    /// <summary>
    /// URL pubblico del logo aziendale in formato email (JPEG). Restituisce null se l'azienda non
    /// ha un logo: la newsletter parte comunque, con la ragione sociale come intestazione.
    /// </summary>
    public async Task<string?> GetLogoUrlAsync(int aziendaId, CancellationToken ct = default)
    {
        try
        {
            var logos = await _logoService.GetByAziendaIdAsync(aziendaId);
            var logo = logos.Where(l => l.IsActive && l.IsDefault).OrderBy(l => l.Priority).FirstOrDefault()
                    ?? logos.Where(l => l.IsActive).OrderBy(l => l.Priority).FirstOrDefault();
            if (logo == null) return null;

            // Chiave di validita': identita' del logo + data di modifica. Se non cambia nulla,
            // si riusa l'URL senza rileggere il binario ne' ricaricarlo.
            var chiave = $"{logo.Id}|{(logo.UpdatedAt ?? logo.CreatedAt):O}";
            if (_cacheLogo.TryGetValue(aziendaId, out var inCache) && inCache.Chiave == chiave)
                return inCache.Url;

            var bin = await _logoService.GetBinaryDataAsync(logo.Id);
            if (bin == null || bin.Length == 0) return null;

            var path = $"newsletter/logo/{aziendaId}.jpg";
            using var ms = new MemoryStream(bin);
            var jpeg = await WebImageProcessor.ToEmailJpegAsync(ms, ct);

            await using var upload = new MemoryStream(jpeg.Bytes);
            var url = await _storage.UploadNewsletterAsync(path, upload, WebImageProcessor.MimeEmail, ct);
            _cacheLogo[aziendaId] = (chiave, url);
            return url;
        }
        catch (Exception ex)
        {
            // Non critico: senza logo la newsletter esce con la ragione sociale in testa.
            _logger.LogWarning(ex, "Logo email non disponibile per azienda {Az}", aziendaId);
            return null;
        }
    }

    /// <summary>
    /// Carica l'icona di un social e ne restituisce URL pubblico e percorso.
    /// </summary>
    /// <remarks>
    /// Resta <b>PNG</b> e non diventa JPEG come le altre immagini: il JPEG non ha canale alfa e la
    /// trasparenza verrebbe appiattita su bianco, lasciando un riquadro bianco attorno al logo sul
    /// pulsante colorato. Verificato: un PNG trasparente passato per la conversione JPEG esce con
    /// gli angoli a <c>#FFFFFF</c> opachi.
    /// </remarks>
    public async Task<(string? Url, string? Path)> CaricaIconaSocialAsync(
        int aziendaId, string social, Stream contenuto, CancellationToken ct = default)
    {
        try
        {
            var path = $"newsletter/social/{aziendaId}_{social}.png";
            var icona = await WebImageProcessor.ToEmailIconPngAsync(contenuto, ct);
            await using var upload = new MemoryStream(icona.Bytes);
            return (await _storage.UploadNewsletterAsync(path, upload, WebImageProcessor.MimeIcona, ct), path);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Icona social {Social} non caricata per azienda {Az}", social, aziendaId);
            return (null, null);
        }
    }

    /// <summary>
    /// Legge un'immagine dall'archivio (con la chiave: l'originale non è pubblico, L27) e ne restituisce la versione
    /// email (JPEG).
    /// E' la strada usata quando si compila un riquadro tour: la copertina e' gia' su Storage in
    /// WebP, e va derivata in JPEG perche' Outlook non mostra il WebP.
    /// Torna l'URL originale se la conversione fallisce: meglio un'immagine che non si vede su
    /// Outlook che un riquadro senza immagine su tutti i client.
    /// </summary>
    public async Task<string?> ConvertiDaUrlAsync(string? url, string? storagePath, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(url)) return null;
        if (string.IsNullOrWhiteSpace(storagePath)) return url;

        try
        {
            var originale = await _storage.DownloadAsync(storagePath!, ct);
            if (originale is null)
            {
                _logger.LogWarning("Immagine non trovata nell'archivio: {Path}", storagePath);
                return url;
            }
            using var buffer = new MemoryStream(originale);

            return await GetImmagineEmailUrlAsync(storagePath!, buffer, ct) ?? url;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Conversione email non riuscita per {Url}: uso l'originale", url);
            return url;
        }
    }

    /// <summary>
    /// Deriva la versione email (JPEG) di un'immagine gia' in Storage e ne restituisce l'URL
    /// pubblico (archivio delle newsletter). <paramref name="storagePathOrigine"/> e' il percorso dell'originale (WebP della
    /// galleria); il derivato finisce in <c>newsletter/img/{nome}.jpg</c>.
    /// </summary>
    public async Task<string?> GetImmagineEmailUrlAsync(
        string storagePathOrigine, Stream contenutoOriginale, CancellationToken ct = default)
    {
        try
        {
            var nome = Path.GetFileNameWithoutExtension(storagePathOrigine);
            var cartella = Path.GetDirectoryName(storagePathOrigine)?.Replace('\\', '/') ?? "";
            var chiave = string.IsNullOrEmpty(cartella) ? nome : $"{cartella.Replace('/', '_')}_{nome}";
            var path = $"newsletter/img/{chiave}.jpg";

            var jpeg = await WebImageProcessor.ToEmailJpegAsync(contenutoOriginale, ct);
            await using var upload = new MemoryStream(jpeg.Bytes);
            return await _storage.UploadNewsletterAsync(path, upload, WebImageProcessor.MimeEmail, ct);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Derivato email non generato per {Path}", storagePathOrigine);
            return null;
        }
    }
}
