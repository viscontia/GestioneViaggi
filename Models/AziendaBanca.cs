using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un conto bancario aziendale (tabella ana_aziende_banche)
/// </summary>
public class AziendaBanca : BaseEntity
{
    [Required(ErrorMessage = "L'azienda è obbligatoria")]
    public int AziendaIdFk { get; set; }

    [Required(ErrorMessage = "Il nome della banca è obbligatorio")]
    [StringLength(150, ErrorMessage = "Il nome banca non può superare i 150 caratteri")]
    public string NomeBanca { get; set; } = string.Empty;

    [StringLength(150, ErrorMessage = "La filiale non può superare i 150 caratteri")]
    public string? Filiale { get; set; }

    [Required(ErrorMessage = "L'IBAN è obbligatorio")]
    [StringLength(34, ErrorMessage = "L'IBAN non può superare i 34 caratteri")]
    public string Iban { get; set; } = string.Empty;

    [StringLength(11, ErrorMessage = "Il codice SWIFT/BIC non può superare gli 11 caratteri")]
    public string? SwiftBic { get; set; }

    public bool IsPredefinito { get; set; } = false;

    public string? Note { get; set; }

    /// <summary>
    /// Crea una copia dell'entità per evitare modifiche accidentali all'oggetto originale
    /// </summary>
    public AziendaBanca Clone()
    {
        return new AziendaBanca
        {
            Id = this.Id,
            AziendaIdFk = this.AziendaIdFk,
            NomeBanca = this.NomeBanca,
            Filiale = this.Filiale,
            Iban = this.Iban,
            SwiftBic = this.SwiftBic,
            IsPredefinito = this.IsPredefinito,
            Note = this.Note
        };
    }
}
