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

    /// <summary>Genera (o rigenera) la mappa statica del viaggio dal testo GPX. Upsert 1:1 su web_tour_mappa.</summary>
    public async Task<WebTourMappa> GenerateAsync(long contenutoId, int aziendaId, string gpxText, string? gpxFilename, CancellationToken ct = default)
    {
        if (!_geo.IsConfigured)
            throw new InvalidOperationException("Chiave Geoapify non configurata (sezione 'Geoapify' in appsettings).");

        var points = GpxParser.Parse(gpxText);
        if (points.Count < 2)
            throw new InvalidOperationException("Il file GPX non contiene una traccia valida (nessun trkpt).");

        var simplified = DouglasPeucker.Simplify(points, _opt.MaxPolylinePoints);
        var bbox = _geo.ComputeBbox(simplified);

        var jpeg = await _geo.FetchAsync(simplified, bbox, ct);

        // JPEG Geoapify → WebP ottimizzato
        using var msIn = new MemoryStream(jpeg);
        var processed = await WebImageProcessor.ToOptimizedWebpAsync(msIn, ct);

        var storagePath = $"{aziendaId}/{contenutoId}/mappa.webp";
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

        // Upsert 1:1
        var existing = await _mappaService.GetByContenutoAsync(contenutoId, aziendaId);
        var entity = existing ?? new WebTourMappa { WebTourContenutoIdFk = contenutoId, AziendaId = aziendaId };
        entity.GpxOriginale = gpxText;
        entity.GpxFilename = gpxFilename;
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
        _logger.LogInformation("Mappa generata per contenuto {ContenutoId}: {Orig}→{Simpl} punti", contenutoId, points.Count, simplified.Count);
        return saved;
    }
}
