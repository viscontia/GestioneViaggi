namespace GestioneViaggi.Models.Web;

/// <summary>
/// Contenuti editoriali "web" di un tour, per EDIZIONE (viaggio + data_viaggio).
/// Mappa la tabella web_tour_contenuti. Un record per edizione (data_viaggio_id_fk UNIQUE);
/// n record per viaggio. Audit popolato dal trigger DB trg_web_audit (Blocco 0).
/// </summary>
public class WebTourContenuto : BaseEntity
{
    /// <summary>PK bigint (web_tour_contenuti_id).</summary>
    public long WebTourContenutoId { get; set; }

    /// <summary>FK al viaggio (ana_viaggi.viaggio_id). NON univoco (n edizioni per viaggio).</summary>
    public int ViaggioIdFk { get; set; }

    /// <summary>FK all'edizione/data (ana_date_viaggi.data_viaggio_id). Univoco: 1 contenuto per data.</summary>
    public int DataViaggioIdFk { get; set; }

    /// <summary>Azienda proprietaria (multi-tenant).</summary>
    public int AziendaId { get; set; }

    /// <summary>Slug univoco per azienda (SEO), max 160.</summary>
    public string Slug { get; set; } = string.Empty;

    public string? Sottotitolo { get; set; }
    public string? DescrizioneHtml { get; set; }

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

/// <summary>
/// Riga del selettore edizione (fn_web_edizioni_per_viaggio): una data del viaggio con
/// stato del contenuto web (ContenutoId null = nessun contenuto) ed effettuazione.
/// </summary>
public sealed record EdizioneViaggio(
    int DataViaggioId,
    DateTime? DataInizio,
    DateTime? DataFine,
    bool Effettuato,
    long? ContenutoId,
    string? StatoPubblicazione)
{
    public bool HaContenuto => ContenutoId.HasValue;

    /// <summary>
    /// Durata in giorni di QUESTA partenza. Non coincide per forza con ana_viaggi.viaggio_numero_giorni:
    /// il trigger sulle date valida la durata al momento dell'inserimento, quindi se in anagrafica il
    /// numero di giorni viene cambiato dopo, le partenze già esistenti mantengono la loro durata.
    /// </summary>
    public int? Giorni => DataInizio is { } i && DataFine is { } f ? (f.Date - i.Date).Days + 1 : null;

    /// <summary>Etichetta dell'edizione per selettori e messaggi. Nel modello perché serve in più punti (selettore, dialogo di creazione, conferme).</summary>
    public string Etichetta
    {
        get
        {
            var range = $"{DataInizio?.ToString("dd/MM/yyyy") ?? "?"} – {DataFine?.ToString("dd/MM/yyyy") ?? "?"}";
            var stato = HaContenuto ? $"• {StatoPubblicazione}" : "• senza contenuto";
            var eff = Effettuato ? " • effettuato" : "";
            return $"{range} {stato}{eff}";
        }
    }
}
