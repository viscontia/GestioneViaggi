namespace GestioneViaggi.Models.Web;

/// <summary>
/// Contenuti editoriali "web" di un tour (scheda pubblica del viaggio).
/// Mappa la tabella web_tour_contenuti. Un record per viaggio (viaggio_id_fk UNIQUE).
/// Audit (created/created_by/updated/updated_by) è popolato dal trigger DB trg_web_audit,
/// non dal codice C# — vedi Blocco 0.
/// </summary>
public class WebTourContenuto : BaseEntity
{
    /// <summary>PK bigint (web_tour_contenuti_id).</summary>
    public long WebTourContenutoId { get; set; }

    /// <summary>FK al viaggio (ana_viaggi.viaggio_id). Univoco.</summary>
    public int ViaggioIdFk { get; set; }

    /// <summary>Azienda proprietaria (multi-tenant).</summary>
    public int AziendaId { get; set; }

    /// <summary>Slug univoco per azienda (SEO), max 160.</summary>
    public string Slug { get; set; } = string.Empty;

    public string? Sottotitolo { get; set; }
    public string? DescrizioneHtml { get; set; }

    /// <summary>Difficoltà: turistica | media | medio_alta | alta.</summary>
    public string? Difficolta { get; set; }

    public string? DurataTesto { get; set; }
    public string? LuoghiVisitati { get; set; }
    public string? InfoPernottamentoHtml { get; set; }
    public string? InfoPastiHtml { get; set; }
    public string? InfoEquipaggiamentoHtml { get; set; }
    public string? AltreInfoHtml { get; set; }

    public string? MetaTitle { get; set; }
    public string? MetaDescription { get; set; }

    /// <summary>Stato: bozza | pubblicato | archiviato.</summary>
    public string StatoPubblicazione { get; set; } = "bozza";

    public int Ordine { get; set; }
    public DateTime? DataPubblicazione { get; set; }

    // Audit (sola lettura lato C#: popolati dal trigger trg_web_audit)
    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }
}
