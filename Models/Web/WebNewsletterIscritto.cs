namespace GestioneViaggi.Models.Web;

/// <summary>
/// Iscritto newsletter (tabella web_newsletter_iscritti). Email univoca per azienda (CITEXT).
/// TokenDisiscrizione e DataIscrizione sono generati dal DB (non passati da C#).
/// Audit popolato dal trigger DB trg_web_audit.
/// </summary>
public class WebNewsletterIscritto : BaseEntity
{
    /// <summary>PK bigint (web_newsletter_iscritti_id).</summary>
    public long WebNewsletterIscrittoId { get; set; }

    /// <summary>Azienda proprietaria (multi-tenant).</summary>
    public int AziendaId { get; set; }

    /// <summary>Email (CITEXT, case-insensitive, univoca per azienda).</summary>
    public string Email { get; set; } = string.Empty;

    public string? Nome { get; set; }
    public string? Cognome { get; set; }

    /// <summary>Lingua: IT | FR | EN | DE | ES.</summary>
    public string Lingua { get; set; } = "IT";

    /// <summary>Popolata dal DB (default now()), sola lettura lato C#.</summary>
    public DateTime? DataIscrizione { get; set; }

    public bool Consenso { get; set; } = true;
    public DateTime? ConsensoData { get; set; }
    public string? ConsensoFonte { get; set; }

    /// <summary>Stato: attivo | disiscritto.</summary>
    public string Stato { get; set; } = "attivo";

    /// <summary>Token per il link di disiscrizione. Generato dal DB, sola lettura lato C#.</summary>
    public string? TokenDisiscrizione { get; set; }

    /// <summary>FK opzionale ad ana_clienti (arricchimento/dedup).</summary>
    public int? ClienteFk { get; set; }

    // Audit (sola lettura lato C#: popolati dal trigger trg_web_audit)
    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }
}
