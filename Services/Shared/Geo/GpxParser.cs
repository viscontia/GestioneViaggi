using System.Globalization;
using System.Text.RegularExpressions;

namespace GestioneViaggi.Services.Shared.Geo;

/// <summary>Punto geografico (lat/lon in gradi).</summary>
public readonly record struct GeoPoint(double Lat, double Lon);

/// <summary>Parser minimale del testo GPX: estrae i track point &lt;trkpt lat lon&gt; in ordine.</summary>
public static class GpxParser
{
    private static readonly Regex TrkptRx = new(
        "<trkpt[^>]*?lat=\"([^\"]+)\"[^>]*?lon=\"([^\"]+)\"",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    public static List<GeoPoint> Parse(string? gpx)
    {
        var pts = new List<GeoPoint>();
        if (string.IsNullOrEmpty(gpx)) return pts;
        foreach (Match m in TrkptRx.Matches(gpx))
        {
            if (double.TryParse(m.Groups[1].Value, NumberStyles.Float, CultureInfo.InvariantCulture, out var lat) &&
                double.TryParse(m.Groups[2].Value, NumberStyles.Float, CultureInfo.InvariantCulture, out var lon))
            {
                pts.Add(new GeoPoint(lat, lon));
            }
        }
        return pts;
    }
}
