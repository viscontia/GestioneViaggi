using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta una provincia italiana (tabella ana_geo_province)
/// </summary>
public class Provincia : BaseEntity
{
    [Required(ErrorMessage = "La descrizione è obbligatoria")]
    [StringLength(100, ErrorMessage = "Max 100 caratteri")]
    public string Descrizione { get; set; } = string.Empty;

    [Required(ErrorMessage = "La sigla è obbligatoria")]
    [StringLength(2, ErrorMessage = "Max 2 caratteri")]
    public string Sigla { get; set; } = string.Empty;

    public decimal? Superficie { get; set; }
    public int? Residenti { get; set; }
    public int? NumeroComuni { get; set; }

    [Required(ErrorMessage = "La regione è obbligatoria")]
    public int RegioneIdFk { get; set; }

    // Campo non salvato nel DB, solo per visualizzazione nella grid
    public string? RegioneDescrizione { get; set; }
}
