using System.Text.Json;
using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.Shared.Geo;
using GestioneViaggi.Services.Shared.Storage;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Pipeline "GPX → mappa statica" (Blocco 9), tutto lato gestionale:
/// parse GPX → Douglas-Peucker → bbox → Geoapify Static Maps → WebP → Storage → web_tour_mappa.
/// La traccia (gpx_originale) resta lato server; al browser va solo l'URL dell'immagine.
/// </summary>
public sealed class WebTourMappaGeneratorService
{
    private readonly GeoapifyStaticMapClient _geo;
    private readonly GeoapifyOptions _opt;
    private readonly IWebMediaStorage _storage;
    private readonly WebTourMappaService _mappaService;
    private readonly ILogger<WebTourMappaGeneratorService> _logger;

    public WebTourMappaGeneratorService(
        GeoapifyStaticMapClient geo, GeoapifyOptions opt, IWebMediaStorage storage,
        WebTourMappaService mappaService, ILogger<WebTourMappaGeneratorService> logger)
    {
        _geo = geo;
        _opt = opt;
        _storage = storage;
        _mappaService = mappaService;
        _logger = logger;
    }

    public bool IsConfigured => _geo.IsConfigured;

    /// <summary>
    /// Genera (o rigenera) una mappa statica dal testo GPX e la salva.
    /// <paramref name="itinerarioId"/> null = mappa dell'intero viaggio (richiede <paramref name="descrizione"/>);
    /// valorizzato = mappa di quella giornata. L'upsert è per <i>(contenuto, giornata)</i>: rigenerare
    /// una mappa esistente la sovrascrive, caricare un GPX per una giornata libera ne crea una nuova.
    /// </summary>
    public async Task<WebTourMappa> GenerateAsync(long contenutoId, int aziendaId, string gpxText, string? gpxFilename,
        long? itinerarioId = null, string? descrizione = null, CancellationToken ct = default)
    {
        if (!_geo.IsConfigured)
            throw new InvalidOperationException("Chiave Geoapify non configurata (sezione 'Geoapify' in appsettings).");

        // Stessa regola del CHECK ck_web_tour_mappa_descrizione (script 497): obbligatoria per TUTTE
        // le mappe. Verificata qui per non spendere una chiamata Geoapify su un salvataggio che il DB
        // rifiuterebbe comunque.
        if (string.IsNullOrWhiteSpace(descrizione))
            throw new InvalidOperationException("La descrizione della mappa è obbligatoria.");

        var gpxBytes = System.Text.Encoding.UTF8.GetByteCount(gpxText);
        var esistenti = await _mappaService.ListByContenutoAsync(contenutoId, aziendaId);
        var existing = esistenti.FirstOrDefault(m => m.WebTourItinerarioIdFk == itinerarioId);

        // Doppione: stesso file (nome case-insensitive + dimensione) su un'ALTRA mappa della stessa
        // edizione. Controllato PRIMA di Geoapify. Come l'indice uq_web_tour_mappa_gpx_dedup, non si
        // giudica doppione ciò di cui manca nome o dimensione. Il DB resta la difesa finale.
        if (!string.IsNullOrWhiteSpace(gpxFilename))
        {
            var doppione = esistenti.FirstOrDefault(m =>
                m.WebTourMappaId != (existing?.WebTourMappaId ?? 0)
                && m.GpxBytes == gpxBytes
                && string.Equals(m.GpxFilename, gpxFilename, StringComparison.OrdinalIgnoreCase));

            if (doppione != null)
                throw new InvalidOperationException(
                    $"Questo file GPX è già stato caricato per questa edizione: \"{doppione.Descrizione ?? doppione.GpxFilename}\".");
        }

        var points = GpxParser.Parse(gpxText);
        if (points.Count < 2)
            throw new InvalidOperationException("Il file GPX non contiene una traccia valida (nessun trkpt).");

        var simplified = DouglasPeucker.Simplify(points, _opt.MaxPolylinePoints);
        var bbox = _geo.ComputeBbox(simplified);

        var jpeg = await _geo.FetchAsync(simplified, bbox, ct);

        // JPEG Geoapify → WebP ottimizzato
        using var msIn = new MemoryStream(jpeg);
        var processed = await WebImageProcessor.ToOptimizedWebpAsync(msIn, ct);

        // Un percorso per mappa: rigenerare sovrascrive lo stesso oggetto, senza accumulare file.
        // Si usa l'id della giornata e NON il giorno_numero, che cambia riordinando l'itinerario:
        // il percorso resta stabile e nessun file resta orfano dopo un riordino.
        var suffisso = itinerarioId == null ? "viaggio" : $"giornata-{itinerarioId}";
        var storagePath = $"{aziendaId}/{contenutoId}/mappa-{suffisso}.webp";
        using var msOut = new MemoryStream(processed.Bytes);
        await _storage.UploadAsync(storagePath, msOut, processed.Mime, ct);
        var url = _storage.BuildPublicUrl(storagePath);

        var parametri = JsonSerializer.Serialize(new
        {
            style = _opt.Style,
            width = _opt.Width,
            height = _opt.Height,
            punti_originali = points.Count,
            punti_semplificati = simplified.Count,
            line_color = _opt.LineColor,
            margine = _opt.BboxMargin
        });

        // Upsert per (contenuto, giornata): existing è già stato risolto sopra, prima di Geoapify.
        var entity = existing ?? new WebTourMappa { WebTourContenutoIdFk = contenutoId, AziendaId = aziendaId };
        entity.WebTourItinerarioIdFk = itinerarioId;
        entity.Descrizione = descrizione;
        entity.GpxOriginale = gpxText;
        entity.GpxFilename = gpxFilename;
        entity.GpxBytes = gpxBytes;
        entity.BboxMinLat = (decimal)bbox.MinLat;
        entity.BboxMinLon = (decimal)bbox.MinLon;
        entity.BboxMaxLat = (decimal)bbox.MaxLat;
        entity.BboxMaxLon = (decimal)bbox.MaxLon;
        entity.Provider = "geoapify";
        entity.Stile = _opt.Style;
        entity.ParametriRender = parametri;
        entity.ImmagineUrl = url;
        entity.ImmagineStoragePath = storagePath;
        entity.DataGenerazione = DateTime.UtcNow;

        var saved = existing == null ? await _mappaService.CreateAsync(entity) : await _mappaService.UpdateAsync(entity);
        _logger.LogInformation("Mappa generata per contenuto {ContenutoId} ({Abbinamento}): {Orig}→{Simpl} punti",
            contenutoId, itinerarioId == null ? "intero viaggio" : $"giornata {itinerarioId}", points.Count, simplified.Count);
        return saved;
    }
}
