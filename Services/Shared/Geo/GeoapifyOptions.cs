namespace GestioneViaggi.Services.Shared.Geo;

/// <summary>Opzioni di rendering della mappa statica Geoapify (sezione "Geoapify" in appsettings).</summary>
public sealed class GeoapifyOptions
{
    /// <summary>Chiave API Geoapify (free tier). Per-installazione; non cifrata (vedi design Blocco 9).</summary>
    public string ApiKey { get; set; } = "";
    public string Style { get; set; } = "osm-bright";
    public int Width { get; set; } = 800;
    public int Height { get; set; } = 600;
    public string LineColor { get; set; } = "#c0392b";   // rosso outdoor
    public int LineWidth { get; set; } = 4;
    public string StartColor { get; set; } = "#27ae60";  // verde (start)
    public string EndColor { get; set; } = "#c0392b";    // rosso (end)
    public double BboxMargin { get; set; } = 0.08;
    public int MaxPolylinePoints { get; set; } = 280;    // cap per il limite di lunghezza URL
}
