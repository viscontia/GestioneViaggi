namespace GestioneViaggi.Models.Web;

/// <summary>
/// Mappa statica di un tour generata da GPX (web_tour_mappa).
/// Una edizione può avere N mappe: una dell'<b>intero viaggio</b> (<see cref="WebTourItinerarioIdFk"/> null)
/// e una per ogni <b>giornata</b> dell'itinerario. I vincoli che escludono i casi ambigui (due mappe sulla
/// stessa giornata, doppia mappa d'insieme, stesso GPX ricaricato) sono sul DB — vedi SqlScripts/493.
/// GPX conservato lato server; immagine su storage. Audit popolato dal trigger DB trg_web_audit.
/// </summary>
public class WebTourMappa : BaseEntity
{
    public long WebTourMappaId { get; set; }
    /// <summary>FK al contenuto/edizione (web_tour_contenuti.web_tour_contenuti_id, BIGINT).</summary>
    public long WebTourContenutoIdFk { get; set; }
    public int AziendaId { get; set; }

    /// <summary>Giornata dell'itinerario a cui la mappa si riferisce. NULL = mappa dell'intero viaggio.</summary>
    public long? WebTourItinerarioIdFk { get; set; }

    /// <summary>Testo mostrato al cliente (tradotto in web_traduzioni). Obbligatorio per la mappa d'insieme.</summary>
    public string? Descrizione { get; set; }

    public string? GpxOriginale { get; set; }
    public string? GpxFilename { get; set; }

    /// <summary>Dimensione in byte (UTF-8) del GPX caricato: con GpxFilename impedisce di ricaricare lo stesso file.</summary>
    public int? GpxBytes { get; set; }
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
