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
    public int? NumeroProvince { get; set; }
    public int? NumeroComuni { get; set; }
    public int CountryIdFk { get; set; }
}
