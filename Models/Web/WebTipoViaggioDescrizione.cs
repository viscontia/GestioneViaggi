namespace GestioneViaggi.Models.Web;

/// <summary>
/// Descrizione "web" di un tipo di viaggio (tabella GLOBALE web_tipi_viaggio_descrizioni,
/// ex web_categorie_sport). È una lookup condivisa: N righe di ana_tipo_viaggi possono
/// puntare alla stessa descrizione (via ana_tipo_viaggi.descrizione_web_fk), evitando testo
/// libero ripetuto (3NF). Audit popolato dal trigger DB trg_web_audit.
/// </summary>
public class WebTipoViaggioDescrizione : BaseEntity
{
    /// <summary>PK bigint (web_tipi_viaggio_descrizioni_id).</summary>
    public long WebTipoViaggioDescrizioneId { get; set; }

    /// <summary>Descrizione mostrata sul sito (es. "Viaggi 4x4"). Destinata al web (no uppercase forzato).</summary>
    public string DescrizioneWeb { get; set; } = string.Empty;

    /// <summary>Slug per URL, univoco (globale).</summary>
    public string Slug { get; set; } = string.Empty;

    public int Ordine { get; set; }

    // Audit (sola lettura lato C#: popolati dal trigger trg_web_audit)
    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }
}
