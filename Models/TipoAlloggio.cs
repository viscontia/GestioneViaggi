using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un tipo di alloggio (tabella ANA_TIPO_ALLOGGIO)
/// </summary>
[Table("ANA_TIPO_ALLOGGIO")]
public class TipoAlloggio : BaseEntity
{
    [Required(ErrorMessage = "La descrizione è obbligatoria")]
    [StringLength(100, ErrorMessage = "Max 100 caratteri")]
    [Column("TIPO_ALLOGGIO_DESCRIZIONE")]
    public string Descrizione { get; set; } = string.Empty;

    [Column("TIPO_ALLOGGIO_NUMERO_OCCUPANTI")]
    [Range(0, 6, ErrorMessage = "Il numero di occupanti deve essere compreso tra 0 e 6")]
    public int NumeroOccupanti { get; set; }

    [Column("TIPO_ALLOGGIO_SUPPLEMENTO")]
    public string SupplementoDb { get; set; } = "N";

    [NotMapped]
    public bool Supplemento
    {
        get => SupplementoDb == "Y";
        set => SupplementoDb = value ? "Y" : "N";
    }
}
