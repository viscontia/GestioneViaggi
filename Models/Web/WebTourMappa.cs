namespace GestioneViaggi.Models.Web;

/// <summary>
/// Mappa statica di un tour generata da GPX (web_tour_mappa).
/// Relazione 1:1 col viaggio. GPX conservato lato server; immagine su storage.
/// Audit popolato dal trigger DB trg_web_audit.
/// </summary>
public class WebTourMappa : BaseEntity
{
    public long WebTourMappaId { get; set; }
    public int ViaggioIdFk { get; set; }
    public int AziendaId { get; set; }

    public string? GpxOriginale { get; set; }
    public string? GpxFilename { get; set; }
    public decimal? BboxMinLat { get; set; }
    public decimal? BboxMinLon { get; set; }
    public decimal? BboxMaxLat { get; set; }
    public decimal? BboxMaxLon { get; set; }
    public string? Provider { get; set; }
    public string? Stile { get; set; }

    /// <summary>Parametri di render (jsonb) come stringa JSON grezza.</summary>
    public string? ParametriRender { get; set; }

    public string? ImmagineUrl { get; set; }
    public string? ImmagineStoragePath { get; set; }
    public DateTime? DataGenerazione { get; set; }

    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }
}
