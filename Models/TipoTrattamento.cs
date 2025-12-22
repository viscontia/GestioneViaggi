using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un tipo di trattamento alberghiero (tabella ANA_TIPO_TRATTAMENTO)
/// </summary>
[Table("ANA_TIPO_TRATTAMENTO")]
public class TipoTrattamento : BaseEntity
{
    [Required(ErrorMessage = "La descrizione è obbligatoria")]
    [StringLength(100, ErrorMessage = "Max 100 caratteri")]
    [Column("TIPO_TRATTAMENTO_DESCRIZIONE")]
    public string Descrizione { get; set; } = string.Empty;
}
