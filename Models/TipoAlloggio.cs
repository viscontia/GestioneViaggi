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

    /// <summary>
    /// Di che genere è questa sistemazione: albergo, tenda, nessuna.
    /// ⚠️ Obbligatorio: senza, non si può sapere su quali viaggi è ammessa — ed è da lì
    /// che sono nate le 17 assegnazioni incoerenti trovate in produzione (camere d'albergo
    /// su viaggi con pernottamento «nessuno»).
    /// </summary>
    [Column("GENERE_FK")]
    [Range(1, int.MaxValue, ErrorMessage = "Il genere è obbligatorio")]
    public int GenereFk { get; set; }

    /// <summary>
    /// La sistemazione resta scegliibile, ma il programma non la propone mai d'ufficio.
    ///
    /// ⚠️ Nasce per le camere attrezzate per disabili: in elenco ci devono essere — si
    /// mostrano sempre, anche per rispetto verso la categoria — ma assegnarle a chi non le
    /// ha chieste sarebbe sbagliato. Prima non uscivano solo perché create più tardi delle
    /// altre: per fortuna, non per regola.
    /// ⛔️ Non si riconoscono dal nome: è il difetto tolto dai generi.
    /// </summary>
    [Column("TIPO_ALLOGGIO_MAI_PROPOSTA")]
    public bool MaiProposta { get; set; }

    /// <summary>Descrizione del genere, per l'elenco. Non si scrive.</summary>
    [NotMapped]
    public string? GenereDescrizione { get; set; }

    [NotMapped]
    public bool Supplemento
    {
        get => SupplementoDb == "Y";
        set => SupplementoDb = value ? "Y" : "N";
    }
}
