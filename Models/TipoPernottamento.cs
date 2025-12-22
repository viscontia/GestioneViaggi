using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un tipo di pernottamento (tabella ANA_TIPO_PERNOTTAMENTO)
/// </summary>
[Table("ANA_TIPO_PERNOTTAMENTO")]
public class TipoPernottamento : BaseEntity
{
    [Required(ErrorMessage = "La descrizione è obbligatoria")]
    [StringLength(100, ErrorMessage = "Max 100 caratteri")]
    [Column("ANA_TIPO_PERNOTTAMENTO_DESCRIZIONE")]
    public string Descrizione { get; set; } = string.Empty;

    [Column("ANA_TIPO_PERNOTTAMENTO_CON_ALBERGO")]
    public string ConAlbergoDb { get; set; } = "N";

    [NotMapped]
    public bool ConAlbergo
    {
        get => ConAlbergoDb == "Y";
        set => ConAlbergoDb = value ? "Y" : "N";
    }
}
