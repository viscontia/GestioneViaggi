using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta una sotto-regione geografica (tabella eba_country_sub_regions)
/// Esempi: Australia and New Zealand, Central Asia, Eastern Europe
/// </summary>
public class CountrySubRegion : BaseEntity
{
    [Required(ErrorMessage = "Il nome della sotto-regione è obbligatorio")]
    [StringLength(255, ErrorMessage = "Max 255 caratteri")]
    public string Name { get; set; } = string.Empty;
}
