namespace GestioneViaggi.Models.Web;

/// <summary>
/// Immagine della libreria aziendale (script 523): icone e immagini generiche non legate ad
/// alcun viaggio. Vivono su Storage sotto il prefisso <c>libreria/{azienda}/</c>, separato da
/// quello delle gallerie dei tour.
/// </summary>
public sealed class WebImmagineLibreria
{
    public long WebImmagineLibreriaId { get; set; }
    public string Descrizione { get; set; } = string.Empty;
    public string Url { get; set; } = string.Empty;
    public string StoragePath { get; set; } = string.Empty;
    public string? Mime { get; set; }
    public int? Larghezza { get; set; }
    public int? Altezza { get; set; }
    public int Ordine { get; set; }
    public int AziendaId { get; set; }
}

/// <summary>Dove un'immagine di libreria è usata: serve a spiegare perché non si può cancellare.</summary>
public sealed record ImmagineInUso(string Oggetto, string Stato, int Blocchi);
