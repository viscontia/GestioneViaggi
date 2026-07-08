using System.Globalization;
using System.Text;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Shared.Geo;

/// <summary>Bounding box geografico (con margine già applicato).</summary>
public readonly record struct GeoBbox(double MinLat, double MinLon, double MaxLat, double MaxLon);

/// <summary>
/// Client Geoapify Static Maps (HTTP REST, no SDK). Costruisce l'URL con la polyline semplificata
/// e scarica l'immagine (JPEG). Formato validato dallo spike del Blocco 9: `area=rect` e
/// `geometry=polyline` in ordine lon,lat; colori come %23RRGGBB; caratteri strutturali (:;,|) grezzi.
/// </summary>
public sealed class GeoapifyStaticMapClient
{
    private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

    private readonly HttpClient _http;
    private readonly GeoapifyOptions _opt;
    private readonly ILogger<GeoapifyStaticMapClient> _logger;

    public GeoapifyStaticMapClient(HttpClient http, GeoapifyOptions opt, ILogger<GeoapifyStaticMapClient> logger)
    {
        _http = http;
        _opt = opt;
        _logger = logger;
    }

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_opt.ApiKey);

    /// <summary>bbox dei punti + margine configurato.</summary>
    public GeoBbox ComputeBbox(IReadOnlyList<GeoPoint> pts)
    {
        double minLa = pts[0].Lat, maxLa = pts[0].Lat, minLo = pts[0].Lon, maxLo = pts[0].Lon;
        foreach (var p in pts)
        {
            if (p.Lat < minLa) minLa = p.Lat; if (p.Lat > maxLa) maxLa = p.Lat;
            if (p.Lon < minLo) minLo = p.Lon; if (p.Lon > maxLo) maxLo = p.Lon;
        }
        double mLa = (maxLa - minLa) * _opt.BboxMargin; if (mLa <= 0) mLa = 0.01;
        double mLo = (maxLo - minLo) * _opt.BboxMargin; if (mLo <= 0) mLo = 0.01;
        return new GeoBbox(minLa - mLa, minLo - mLo, maxLa + mLa, maxLo + mLo);
    }

    /// <summary>Scarica l'immagine (JPEG) della mappa statica per la traccia semplificata.</summary>
    public async Task<byte[]> FetchAsync(IReadOnlyList<GeoPoint> simplified, GeoBbox bbox, CancellationToken ct = default)
    {
        var url = BuildUrl(simplified, bbox);
        using var resp = await _http.GetAsync(url, ct);
        if (!resp.IsSuccessStatusCode)
        {
            var body = await resp.Content.ReadAsStringAsync(ct);
            _logger.LogError("Geoapify {Status}: {Body}", (int)resp.StatusCode, body);
            throw new InvalidOperationException($"Geoapify ha restituito {(int)resp.StatusCode}. Verifica la chiave o la quota.");
        }
        return await resp.Content.ReadAsByteArrayAsync(ct);
    }

    private string BuildUrl(IReadOnlyList<GeoPoint> pts, GeoBbox b)
    {
        static string N(double v) => v.ToString("F5", Inv);
        static string Color(string hex) => hex.Replace("#", "%23");

        var poly = new StringBuilder();
        for (int i = 0; i < pts.Count; i++)
        {
            if (i > 0) poly.Append(',');
            poly.Append(N(pts[i].Lon)).Append(',').Append(N(pts[i].Lat));
        }

        var geometry = $"polyline:{poly};linewidth:{_opt.LineWidth};linecolor:{Color(_opt.LineColor)};lineopacity:0.9";

        var start = pts[0];
        var end = pts[^1];
        var marker = $"lonlat:{N(start.Lon)},{N(start.Lat)};color:{Color(_opt.StartColor)};size:medium"
                   + $"|lonlat:{N(end.Lon)},{N(end.Lat)};color:{Color(_opt.EndColor)};size:medium";

        var area = $"rect:{N(b.MinLon)},{N(b.MinLat)},{N(b.MaxLon)},{N(b.MaxLat)}";

        return $"https://maps.geoapify.com/v1/staticmap?style={_opt.Style}&width={_opt.Width}&height={_opt.Height}"
             + $"&area={area}&geometry={geometry}&marker={marker}&apiKey={_opt.ApiKey}";
    }
}
