namespace GestioneViaggi.Models.Web;

/// <summary>
/// Invio newsletter (tabella web_newsletter_invii). Contenuto in IT;
/// le traduzioni vivono in web_traduzioni. Audit popolato dal trigger trg_web_audit.
/// </summary>
public class WebNewsletterInvio : BaseEntity
{
    /// <summary>PK bigint (web_newsletter_invii_id).</summary>
    public long WebNewsletterInvioId { get; set; }

    /// <summary>Azienda proprietaria (multi-tenant).</summary>
    public int AziendaId { get; set; }

    public string Oggetto { get; set; } = string.Empty;
    public string CorpoHtml { get; set; } = string.Empty;

    /// <summary>Stato: bozza | in_invio | inviata.</summary>
    public string Stato { get; set; } = "bozza";

    public DateTime? DataInvio { get; set; }
    public int? NumeroDestinatari { get; set; }

    /// <summary>Canale di invio (smtp | esp).</summary>
    public string? Canale { get; set; }

    // Audit (sola lettura lato C#: popolati dal trigger trg_web_audit)
    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }
}
