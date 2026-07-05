namespace GestioneViaggi.Models.Web;

/// <summary>
/// Traduzione per-campo polimorfica (tabella web_traduzioni).
/// Chiave logica: (entita, entita_id, campo, lingua). IT è la sorgente e non vive qui.
/// Audit popolato dal trigger DB trg_web_audit.
/// </summary>
public class WebTraduzione : BaseEntity
{
    /// <summary>PK bigint (web_traduzioni_id).</summary>
    public long WebTraduzioneId { get; set; }

    /// <summary>Azienda proprietaria (multi-tenant).</summary>
    public int AziendaId { get; set; }

    /// <summary>Entità tradotta (es. web_tour_contenuti), max 40.</summary>
    public string Entita { get; set; } = string.Empty;

    /// <summary>Id del record dell'entità tradotta.</summary>
    public long EntitaId { get; set; }

    /// <summary>Campo tradotto (es. sottotitolo), max 60.</summary>
    public string Campo { get; set; } = string.Empty;

    /// <summary>Lingua: FR | EN | DE | ES.</summary>
    public string Lingua { get; set; } = string.Empty;

    public string Testo { get; set; } = string.Empty;

    /// <summary>True se prodotta dalla traduzione automatica (Claude API).</summary>
    public bool TradottoAuto { get; set; } = true;

    /// <summary>True se rivista da un operatore.</summary>
    public bool Revisionato { get; set; }

    /// <summary>True se il testo IT sorgente è cambiato dopo la traduzione.</summary>
    public bool Obsoleto { get; set; }

    public DateTime? DataTraduzione { get; set; }

    // Audit (sola lettura lato C#: popolati dal trigger trg_web_audit)
    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }
}
