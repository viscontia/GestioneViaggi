namespace GestioneViaggi.Models.Web;

/// <summary>
/// Indirizzo web riutilizzabile dell'azienda (script 517): sito attuale, sito nuovo, pagine
/// esistenti, collegamenti esterni. È la rubrica da cui i pulsanti della newsletter pescano,
/// invece di far scrivere un URL a mano ogni volta.
/// </summary>
public sealed class WebIndirizzo
{
    public long WebIndirizzoId { get; set; }

    /// <summary>Nome con cui l'utente lo riconosce in tendina. Unico per azienda.</summary>
    public string Descrizione { get; set; } = string.Empty;

    public string Url { get; set; } = string.Empty;
    public string? Note { get; set; }
    public int Ordine { get; set; }
    public bool Attivo { get; set; } = true;
    public int AziendaId { get; set; }
}
