using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta una regione italiana (tabella ana_geo_regioni_ita)
/// </summary>
public class Regione : BaseEntity
{
    [Required(ErrorMessage = "La descrizione è obbligatoria")]
    [StringLength(100, ErrorMessage = "Max 100 caratteri")]
    public string Descrizione { get; set; } = string.Empty;

    public int? NumeroResidenti { get; set; }
    public decimal? PercentualeResidenti { get; set; }
    public decimal? DensitaKmq { get; set; }

    [Required(ErrorMessage = "Il numero di province è obbligatorio")]
    public int NumeroProvince { get; set; }

    [Required(ErrorMessage = "Il numero di comuni è obbligatorio")]
    public int NumeroComuni { get; set; }

    [Required(ErrorMessage = "Il paese è obbligatorio")]
    public int CountryIdFk { get; set; }

    // Navigation property (non mappato direttamente dal DB)
    public string? CountryName { get; set; }
}
