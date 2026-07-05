namespace GestioneViaggi.Models.Web;

/// <summary>
/// Soppressione newsletter (tabella web_newsletter_soppressioni): email esclusa
/// da ogni invio (bounce, spam, richiesta). Email univoca per azienda (CITEXT).
/// Audit popolato dal trigger DB trg_web_audit.
/// </summary>
public class WebNewsletterSoppressione : BaseEntity
{
    /// <summary>PK bigint (web_newsletter_soppressioni_id).</summary>
    public long WebNewsletterSoppressioneId { get; set; }

    /// <summary>Azienda proprietaria (multi-tenant).</summary>
    public int AziendaId { get; set; }

    /// <summary>Email soppressa (CITEXT, univoca per azienda).</summary>
    public string Email { get; set; } = string.Empty;

    /// <summary>Motivo: bounce | spam | richiesta | altro, max 20.</summary>
    public string Motivo { get; set; } = string.Empty;

    /// <summary>Data soppressione (default now() lato DB se non passata).</summary>
    public DateTime? Data { get; set; }

    // Audit (sola lettura lato C#: popolati dal trigger trg_web_audit)
    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }
}
