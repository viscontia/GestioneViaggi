using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un indirizzo email aziendale (tabella ana_aziende_email)
/// </summary>
public class AziendaEmail : BaseEntity
{
    [Required(ErrorMessage = "L'azienda è obbligatoria")]
    public int AziendaIdFk { get; set; }

    [Required(ErrorMessage = "L'indirizzo email è obbligatorio")]
    [StringLength(255, ErrorMessage = "L'email non può superare i 255 caratteri")]
    public string Email { get; set; } = string.Empty;

    public bool IsPrincipale { get; set; } = false;

    public string? Note { get; set; }

    [Required(ErrorMessage = "Il reparto è obbligatorio")]
    public int RepartoIdFk { get; set; }

    // Navigation properties (non mappate direttamente dal DB)
    public string? RepartoNome { get; set; }

    /// <summary>
    /// Crea una copia dell'entità per evitare modifiche accidentali all'oggetto originale
    /// </summary>
    public AziendaEmail Clone()
    {
        return new AziendaEmail
        {
            Id = this.Id,
            AziendaIdFk = this.AziendaIdFk,
            Email = this.Email,
            IsPrincipale = this.IsPrincipale,
            Note = this.Note,
            RepartoIdFk = this.RepartoIdFk,
            RepartoNome = this.RepartoNome
        };
    }
}
