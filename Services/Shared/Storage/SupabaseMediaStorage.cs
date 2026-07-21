using System.Net.Http.Headers;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Shared.Storage;

/// <summary>
/// Implementazione di <see cref="IWebMediaStorage"/> su Supabase Storage via HTTP REST (no SDK).
/// storage_path = sorgente di verità; l'URL pubblico si ricompone dal BaseUrl d'ambiente.
///
/// SICUREZZA (Blocco 7): la ServiceKey (service-role) è letta da appsettings e usata contro il
/// bucket di TEST. In produzione NON deve restare nel binario MAUI (estraibile): a go-live va
/// sostituita con una chiave scoped al bucket o l'upload va instradato server-side (debito documentato).
/// </summary>
public sealed class SupabaseMediaStorage : IWebMediaStorage
{
    private readonly HttpClient _http;
    private readonly WebMediaStorageOptions _opt;
    private readonly ILogger<SupabaseMediaStorage> _logger;

    public SupabaseMediaStorage(HttpClient http, WebMediaStorageOptions opt, ILogger<SupabaseMediaStorage> logger)
    {
        _http = http;
        _opt = opt;
        _logger = logger;
    }

    // BaseUrl è l'URL pubblico (…/object/public); l'endpoint di scrittura è …/object (senza /public).
    private string ApiRoot => _opt.BaseUrl.EndsWith("/public", StringComparison.Ordinal)
        ? _opt.BaseUrl[..^"/public".Length]
        : _opt.BaseUrl;

    public async Task<string> UploadAsync(string storagePath, Stream content, string contentType, CancellationToken ct = default)
    {
        var url = $"{ApiRoot}/{_opt.Bucket}/{storagePath}";
        using var req = new HttpRequestMessage(HttpMethod.Put, url);
        // Le nuove chiavi Supabase (sb_secret_…) NON sono JWT: vanno passate nell'header `apikey`.
        // Solo il Bearer causava "Invalid Compact JWS" (l'API prova a decodificarla come JWT) → 400.
        req.Headers.TryAddWithoutValidation("apikey", _opt.ServiceKey);
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _opt.ServiceKey);
        req.Headers.TryAddWithoutValidation("x-upsert", "true");
        req.Content = new StreamContent(content);
        req.Content.Headers.ContentType = new MediaTypeHeaderValue(contentType);

        using var resp = await _http.SendAsync(req, ct);
        if (!resp.IsSuccessStatusCode)
        {
            var body = await resp.Content.ReadAsStringAsync(ct);
            _logger.LogError("Upload storage fallito {Status} su {Path}: {Body}", (int)resp.StatusCode, storagePath, body);
            throw new InvalidOperationException($"Upload immagine fallito ({(int)resp.StatusCode}). Verifica la configurazione dello storage.");
        }
        return storagePath;
    }

    public string BuildPublicUrl(string storagePath)
        => $"{_opt.BaseUrl.TrimEnd('/')}/{_opt.Bucket}/{storagePath}";

    public async Task DeleteAsync(string storagePath, CancellationToken ct = default)
    {
        var url = $"{ApiRoot}/{_opt.Bucket}/{storagePath}";
        using var req = new HttpRequestMessage(HttpMethod.Delete, url);
        req.Headers.TryAddWithoutValidation("apikey", _opt.ServiceKey);
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _opt.ServiceKey);

        using var resp = await _http.SendAsync(req, ct);
        if (!resp.IsSuccessStatusCode)
        {
            var body = await resp.Content.ReadAsStringAsync(ct);
            // Non lanciamo: l'orfano su storage è tollerato (purge differito). Solo log.
            _logger.LogWarning("Delete storage fallito {Status} su {Path}: {Body}", (int)resp.StatusCode, storagePath, body);
        }
    }
}
