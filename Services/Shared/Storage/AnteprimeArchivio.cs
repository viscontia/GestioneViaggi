using System.Collections.Concurrent;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Shared.Storage;

/// <summary>
/// Le anteprime di foto e video nel gestionale (L27): gli originali non sono più pubblici, quindi l'indirizzo salvato
/// nel database non si apre più. Qui diventa un indirizzo firmato di un'ora, chiesto una volta per file e tenuto in
/// memoria finché vale. Gli indirizzi d'altro tipo (immagini delle newsletter, file appena scelti, data:) restano
/// come sono. Lo usa il componente <c>ArchivioSrc</c>.
/// </summary>
public sealed class AnteprimeArchivio
{
    private const int ValiditaSecondi = 3600;
    /// <summary>Un indirizzo che scade fra meno di questo si rinnova: una schermata aperta a lungo resta buona.</summary>
    private static readonly TimeSpan Margine = TimeSpan.FromMinutes(10);
    // Per tutta l'applicazione: il servizio è Scoped, le firme valgono per chiunque le usi nel gestionale.
    private static readonly ConcurrentDictionary<string, (string Url, DateTime Scade)> Firme = new();

    private readonly IWebMediaStorage _storage;
    private readonly ILogger<AnteprimeArchivio> _logger;

    public AnteprimeArchivio(IWebMediaStorage storage, ILogger<AnteprimeArchivio> logger)
    {
        _storage = storage; _logger = logger;
    }

    /// <summary>L'indirizzo da mettere in <c>src</c>: firmato se è un originale dell'archivio, altrimenti com'è.</summary>
    public async Task<string?> IndirizzoAsync(string? url, CancellationToken ct = default)
    {
        var path = _storage.StoragePathFromUrl(url);
        if (path is null) return url;
        if (Firme.TryGetValue(path, out var f) && f.Scade - DateTime.UtcNow > Margine) return f.Url;
        try
        {
            var firmato = await _storage.SignedUrlAsync(path, ValiditaSecondi, ct);
            if (firmato is null) return url;
            Firme[path] = (firmato, DateTime.UtcNow.AddSeconds(ValiditaSecondi));
            return firmato;
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            // Senza rete o con lo storage giù l'anteprima resta vuota, come una foto che non si carica: niente errore.
            _logger.LogWarning(ex, "Anteprima non firmata per {Path}", path);
            return url;
        }
    }
}
