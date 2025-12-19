using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta una regione geografica globale (tabella eba_country_regions)
/// Esempi: Africa, America, Asia, Europe, Oceania
/// </summary>
public class CountryRegion : BaseEntity
{
    [Required(ErrorMessage = "Il nome della regione è obbligatorio")]
    [StringLength(255, ErrorMessage = "Max 255 caratteri")]
    public string Name { get; set; } = string.Empty;
}
