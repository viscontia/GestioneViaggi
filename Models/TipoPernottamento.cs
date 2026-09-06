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

    /// <summary>
    /// I generi di sistemazione che questo pernottamento ammette.
    ///
    /// ⚠️ Non è una colonna: sta in <c>ana_tipo_pernottamento_generi</c>, molti a molti,
    /// perché il misto esiste — un viaggio può prevedere albergo E tende. Un booleano per
    /// genere è già fallito una volta con <c>ConAlbergo</c>, che all'arrivo delle tende
    /// non ha saputo dire niente.
    /// </summary>
    [NotMapped]
    public List<int> GeneriAmmessi { get; set; } = new();
}
