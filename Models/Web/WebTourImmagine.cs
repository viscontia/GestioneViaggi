namespace GestioneViaggi.Models.Web;

/// <summary>
/// Immagine della galleria/scheda di un tour (web_tour_immagini).
/// Il file risiede su storage (IWebMediaStorage); qui si tiene URL + storage_path.
/// Audit popolato dal trigger DB trg_web_audit.
/// </summary>
public class WebTourImmagine : BaseEntity
{
    public long WebTourImmagineId { get; set; }
    public int ViaggioIdFk { get; set; }
    public int AziendaId { get; set; }

    /// <summary>Tipo immagine (es. galleria, copertina). Default 'galleria'.</summary>
    public string Tipo { get; set; } = "galleria";
    public string Url { get; set; } = string.Empty;
    public string StoragePath { get; set; } = string.Empty;
    public string? AltText { get; set; }
    public string? Titolo { get; set; }
    public int? Larghezza { get; set; }
    public int? Altezza { get; set; }
    public string? Mime { get; set; }
    public int Ordine { get; set; }

    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }
}
