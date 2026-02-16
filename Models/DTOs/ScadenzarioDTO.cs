namespace GestioneViaggi.Models.DTOs;

/// <summary>
/// DTO per la vista vw_scadenzario.
/// Rappresenta le scadenze di pagamento/incasso con classificazione di urgenza.
/// </summary>
public class ScadenzarioDTO
{
    public int ControparteId { get; set; }
    public string RagioneSociale { get; set; } = string.Empty;
    public string CausaleCiclo { get; set; } = string.Empty; // ATTIVO | PASSIVO
    public string CausaleDescrizione { get; set; } = string.Empty;

    public int TransazioneId { get; set; }
    public DateTime? TransazioneDataDocumento { get; set; }
    public string? TransazioneNumeroDocumento { get; set; }
    public DateTime? TransazioneDataScadenza { get; set; }

    public decimal Importo { get; set; } // Con segno
    public decimal Residuo { get; set; }  // Importo - pagamenti già effettuati

    public int GiorniAScadenza { get; set; } // Negativo = scaduto
    public string Urgenza { get; set; } = string.Empty; // SCADUTO | URGENTE | IN_SCADENZA | NORMALE

    public string TransazioneStato { get; set; } = string.Empty;
    public int? TransazioneViaggioId { get; set; }
    public string? TransazioneNote { get; set; }
}
