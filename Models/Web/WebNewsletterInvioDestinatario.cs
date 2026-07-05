namespace GestioneViaggi.Models.Web;

/// <summary>
/// Log di consegna per destinatario di un invio newsletter
/// (tabella web_newsletter_invii_destinatari, FK con ON DELETE CASCADE sull'invio).
/// Audit popolato dal trigger DB trg_web_audit.
/// </summary>
public class WebNewsletterInvioDestinatario : BaseEntity
{
    /// <summary>PK bigint (web_newsletter_invii_destinatari_id).</summary>
    public long WebNewsletterInvioDestinatarioId { get; set; }

    /// <summary>Azienda proprietaria (multi-tenant).</summary>
    public int AziendaId { get; set; }

    /// <summary>FK all'invio (web_newsletter_invii).</summary>
    public long InvioIdFk { get; set; }

    /// <summary>Email del destinatario (CITEXT).</summary>
    public string Email { get; set; } = string.Empty;

    /// <summary>Lingua della copia inviata: IT | FR | EN | DE | ES.</summary>
    public string? Lingua { get; set; }

    /// <summary>Esito consegna (es. inviata, errore, bounce).</summary>
    public string? StatoConsegna { get; set; }

    public DateTime? Data { get; set; }

    // Audit (sola lettura lato C#: popolati dal trigger trg_web_audit)
    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }
}
