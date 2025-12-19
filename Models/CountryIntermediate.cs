using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta una regione intermedia geografica (tabella eba_country_intermediates)
/// Esempi: Caribbean, Central America, Eastern Africa, Middle Africa
/// </summary>
public class CountryIntermediate : BaseEntity
{
    [Required(ErrorMessage = "Il nome della regione intermedia è obbligatorio")]
    [StringLength(255, ErrorMessage = "Max 255 caratteri")]
    public string Name { get; set; } = string.Empty;
}
