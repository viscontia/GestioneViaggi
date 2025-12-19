using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un paese (tabella eba_countries)
/// </summary>
public class Country : BaseEntity
{
    [Required(ErrorMessage = "Il nome del paese è obbligatorio")]
    [StringLength(100, ErrorMessage = "Max 100 caratteri")]
    public string Name { get; set; } = string.Empty;

    [Required(ErrorMessage = "La nazionalità è obbligatoria")]
    [StringLength(50, ErrorMessage = "Max 50 caratteri")]
    public string Nationality { get; set; } = string.Empty;

    [Required(ErrorMessage = "Il codice paese è obbligatorio")]
    [StringLength(3, ErrorMessage = "Max 3 caratteri")]
    public string CountryCode { get; set; } = string.Empty;

    [Required(ErrorMessage = "Il codice ISO Alpha2 è obbligatorio")]
    [StringLength(2, MinimumLength = 2, ErrorMessage = "Deve essere esattamente 2 caratteri")]
    public string IsoAlpha2 { get; set; } = string.Empty;

    [StringLength(100, ErrorMessage = "Max 100 caratteri")]
    public string? Capital { get; set; }

    public long? Population { get; set; }
    public decimal? AreaKm2 { get; set; }

    // Foreign Keys
    public int? RegionId { get; set; }
    public int? SubRegionId { get; set; }
    public int? IntermediateRegionId { get; set; }
    public int? OrganizationRegionId { get; set; }

    // Proprietà navigazionali (popolate da JOIN nel Service)
    public string? RegionName { get; set; }
    public string? SubRegionName { get; set; }
    public string? IntermediateName { get; set; }
    public string? OrganizationName { get; set; }
}
