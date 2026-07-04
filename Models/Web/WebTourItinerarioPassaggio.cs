namespace GestioneViaggi.Models.Web;

/// <summary>
/// Passaggio (blocco di contenuto) di una giornata dell'itinerario
/// (web_tour_itinerario_passaggi). Audit popolato dal trigger DB trg_web_audit.
/// </summary>
public class WebTourItinerarioPassaggio : BaseEntity
{
    public long WebTourItinerarioPassaggioId { get; set; }

    /// <summary>FK alla giornata (web_tour_itinerario.web_tour_itinerario_id), bigint.</summary>
    public long ItinerarioIdFk { get; set; }
    public int AziendaId { get; set; }

    public string TestoHtml { get; set; } = string.Empty;
    public string? ImmagineUrl { get; set; }
    public string? ImmagineStoragePath { get; set; }
    public string? ImmagineDidascalia { get; set; }
    public int Ordine { get; set; }

    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }
}
