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
///   <item>niente URI <c>data:</c> — vanno URL pubblici https, quindi Supabase Storage;</item>
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

            var bin = await _logoService.GetBinaryDataAsync(logo.Id);
            if (bin == null || bin.Length == 0) return null;

            var path = $"newsletter/logo/{aziendaId}.jpg";
            using var ms = new MemoryStream(bin);
            var jpeg = await WebImageProcessor.ToEmailJpegAsync(ms, ct);

            await using var upload = new MemoryStream(jpeg.Bytes);
            await _storage.UploadAsync(path, upload, WebImageProcessor.MimeEmail, ct);

            return _storage.BuildPublicUrl(path);
        }
        catch (Exception ex)
        {
            // Non critico: senza logo la newsletter esce con la ragione sociale in testa.
            _logger.LogWarning(ex, "Logo email non disponibile per azienda {Az}", aziendaId);
            return null;
        }
    }

    /// <summary>
    /// Deriva la versione email (JPEG) di un'immagine gia' in Storage e ne restituisce l'URL
    /// pubblico. <paramref name="storagePathOrigine"/> e' il percorso dell'originale (WebP della
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
            await _storage.UploadAsync(path, upload, WebImageProcessor.MimeEmail, ct);

            return _storage.BuildPublicUrl(path);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Derivato email non generato per {Path}", storagePathOrigine);
            return null;
        }
    }
}
