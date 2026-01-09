using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta il tipo di avvicinamento (tabella ana_tipo_avvicinamento)
/// </summary>
[Table("ana_tipo_avvicinamento")]
public class TipoAvvicinamento : BaseEntity
{
    [Required(ErrorMessage = "La descrizione è obbligatoria")]
    [StringLength(100, ErrorMessage = "Max 100 caratteri")]
    [Column("tipo_avvicinamento_descrizione")]
    public string Descrizione { get; set; } = string.Empty;
}
