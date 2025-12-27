using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un contatto aziendale (tabella ana_aziende_contatti)
/// </summary>
public class AziendaContatto : BaseEntity
{
    [Required(ErrorMessage = "L'azienda è obbligatoria")]
    public int AziendaIdFk { get; set; }

    [Required(ErrorMessage = "La sede è obbligatoria")]
    public int SedeIdFk { get; set; }

    [Required(ErrorMessage = "Il nome è obbligatorio")]
    [StringLength(100, ErrorMessage = "Il nome non può superare i 100 caratteri")]
    public string Nome { get; set; } = string.Empty;

    [Required(ErrorMessage = "Il cognome è obbligatorio")]
    [StringLength(100, ErrorMessage = "Il cognome non può superare i 100 caratteri")]
    public string Cognome { get; set; } = string.Empty;

    [Required(ErrorMessage = "Il ruolo è obbligatorio")]
    [StringLength(150, ErrorMessage = "Il ruolo non può superare i 150 caratteri")]
    public string Ruolo { get; set; } = string.Empty;

    [StringLength(30, ErrorMessage = "Il telefono diretto non può superare i 30 caratteri")]
    public string? TelefonoDiretto { get; set; }

    [StringLength(30, ErrorMessage = "Il cellulare non può superare i 30 caratteri")]
    public string? Cellulare { get; set; }

    [StringLength(255, ErrorMessage = "L'email non può superare i 255 caratteri")]
    public string? Email { get; set; }

    public string? Note { get; set; }

    public DateTime? DataUltimaModifica { get; set; }

    // Navigation properties (non mappate direttamente dal DB)
    public string? SedeIndirizzo { get; set; }
    public string? SedeCitta { get; set; }

    /// <summary>
    /// Crea una copia dell'entità per evitare modifiche accidentali all'oggetto originale
    /// </summary>
    public AziendaContatto Clone()
    {
        return new AziendaContatto
        {
            Id = this.Id,
            AziendaIdFk = this.AziendaIdFk,
            SedeIdFk = this.SedeIdFk,
            Nome = this.Nome,
            Cognome = this.Cognome,
            Ruolo = this.Ruolo,
            TelefonoDiretto = this.TelefonoDiretto,
            Cellulare = this.Cellulare,
            Email = this.Email,
            Note = this.Note,
            DataUltimaModifica = this.DataUltimaModifica,
            SedeIndirizzo = this.SedeIndirizzo,
            SedeCitta = this.SedeCitta
        };
    }
}
