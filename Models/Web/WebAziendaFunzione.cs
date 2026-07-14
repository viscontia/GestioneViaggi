namespace GestioneViaggi.Models.Web;

/// <summary>
/// Toggle di una funzione web per-azienda (tabella web_aziende_funzioni):
/// abilita/disabilita una funzionalità (newsletter, recensioni, blog, pagamenti_online, …).
/// Chiave logica univoca (azienda_id, funzione). Audit popolato dal trigger DB trg_web_audit.
/// </summary>
public class WebAziendaFunzione : BaseEntity
{
    /// <summary>PK bigint (web_aziende_funzioni_id).</summary>
    public long WebAziendeFunzioniId { get; set; }

    /// <summary>Azienda proprietaria (multi-tenant).</summary>
    public int AziendaId { get; set; }

    /// <summary>Codice funzione (max 40): newsletter | recensioni | blog | pagamenti_online | …</summary>
    public string Funzione { get; set; } = string.Empty;

    /// <summary>Flag attivazione della funzione per l'azienda.</summary>
    public bool Attiva { get; set; }

    /// <summary>Parametri di configurazione della funzione (JSONB grezzo). Es. per 'recensioni': {"google_place_id":"…","tripadvisor_url":"…"}. NULL se non configurati.</summary>
    public string? Parametri { get; set; }

    // Audit (sola lettura lato C#: popolati dal trigger trg_web_audit)
    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }
}
