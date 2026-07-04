namespace GestioneViaggi.Models.Web;

/// <summary>
/// Giornata dell'itinerario di un tour (web_tour_itinerario).
/// Audit popolato dal trigger DB trg_web_audit.
/// </summary>
public class WebTourItinerario : BaseEntity
{
    public long WebTourItinerarioId { get; set; }
    public int ViaggioIdFk { get; set; }
    public int AziendaId { get; set; }

    public int GiornoNumero { get; set; }
    public string TitoloGiornata { get; set; } = string.Empty;
    public int Ordine { get; set; }

    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }
}
