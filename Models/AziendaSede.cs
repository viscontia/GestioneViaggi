using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta una sede aziendale (tabella ana_aziende_sedi)
/// </summary>
public class AziendaSede : BaseEntity
{
    [Required(ErrorMessage = "L'azienda è obbligatoria")]
    public int AziendaIdFk { get; set; }

    [Required(ErrorMessage = "Il tipo sede è obbligatorio")]
    public int TipoSedeIdFk { get; set; }

    [Required(ErrorMessage = "L'indirizzo è obbligatorio")]
    [StringLength(255, ErrorMessage = "L'indirizzo non può superare i 255 caratteri")]
    public string Indirizzo { get; set; } = string.Empty;

    [StringLength(20, ErrorMessage = "Il numero civico non può superare i 20 caratteri")]
    public string? NumeroCivico { get; set; }

    [Required(ErrorMessage = "Il comune è obbligatorio")]
    public int ComuneIdFk { get; set; }

    [Required(ErrorMessage = "Il telefono è obbligatorio")]
    [StringLength(30, ErrorMessage = "Il telefono non può superare i 30 caratteri")]
    public string Telefono { get; set; } = string.Empty;

    [Required(ErrorMessage = "L'email è obbligatoria")]
    [StringLength(255, ErrorMessage = "L'email non può superare i 255 caratteri")]
    public string Email { get; set; } = string.Empty;

    public string? Note { get; set; }

    public bool IsPrincipale { get; set; } = false;

    [Required(ErrorMessage = "La latitudine è obbligatoria")]
    public decimal CoordinateLat { get; set; }

    [Required(ErrorMessage = "La longitudine è obbligatoria")]
    public decimal CoordinateLng { get; set; }

    public DateTime DataCreazione { get; set; }
    public DateTime? DataUltimaModifica { get; set; }

    // Navigation properties (non mappate direttamente dal DB)
    public string? TipoSedeDescrizione { get; set; }
    public string? ComuneNome { get; set; }
    public string? ProvinciaSigla { get; set; }
}
