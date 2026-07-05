namespace GestioneViaggi.Models.Web;

/// <summary>
/// Categoria "Sport" del sito pubblico (FUORISTRADA, QUAD, MOTO_ENDURO, ...).
/// Mappa la tabella web_categorie_sport. Codice e slug univoci per azienda.
/// Audit popolato dal trigger DB trg_web_audit.
/// </summary>
public class WebCategoriaSport : BaseEntity
{
    /// <summary>PK bigint (web_categorie_sport_id).</summary>
    public long WebCategoriaSportId { get; set; }

    /// <summary>Azienda proprietaria (multi-tenant).</summary>
    public int AziendaId { get; set; }

    /// <summary>Codice tecnico, max 20 (es. FUORISTRADA).</summary>
    public string Codice { get; set; } = string.Empty;

    /// <summary>Etichetta mostrata sul sito, max 50.</summary>
    public string Etichetta { get; set; } = string.Empty;

    /// <summary>Slug per URL, max 50, univoco per azienda.</summary>
    public string Slug { get; set; } = string.Empty;

    public int Ordine { get; set; }

    // Audit (sola lettura lato C#: popolati dal trigger trg_web_audit)
    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }
}
