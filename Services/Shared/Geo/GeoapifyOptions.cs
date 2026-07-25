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
    /// <summary>
    /// Budget di punti con cui viene disegnato il tracciato: è il criterio di <b>generalizzazione</b>
    /// (traccia non replicabile da chi conosce il territorio), non solo un cap per la lunghezza dell'URL.
    /// Un budget è preferibile a una tolleranza in metri perché è relativo all'estensione: la stessa
    /// ruvidezza visiva sulla mappa d'insieme e su quella di una singola giornata. 70 ≈ tolleranza di
    /// ~300 m sull'intero tour. Sotto ~40 alcune tappe brevi iniziano a sembrare percorsi falsi.
    /// </summary>
    public int MaxPolylinePoints { get; set; } = 70;
}
