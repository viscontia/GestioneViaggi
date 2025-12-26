using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un tipo di sede aziendale (tabella ana_tipo_sedi)
/// </summary>
public class TipoSede : BaseEntity
{
    [Required(ErrorMessage = "Il codice è obbligatorio")]
    [StringLength(30, ErrorMessage = "Il codice non può superare i 30 caratteri")]
    public string Codice { get; set; } = string.Empty;

    [Required(ErrorMessage = "La descrizione è obbligatoria")]
    [StringLength(100, ErrorMessage = "La descrizione non può superare i 100 caratteri")]
    public string Descrizione { get; set; } = string.Empty;

    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}
