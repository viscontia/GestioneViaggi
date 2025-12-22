using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un modello di veicolo (tabella ana_mezzi_modelli)
/// </summary>
public class MezzoModello : BaseEntity
{
    [Required(ErrorMessage = "La descrizione è obbligatoria")]
    [StringLength(100, ErrorMessage = "Max 100 caratteri")]
    public string Descrizione { get; set; } = string.Empty;

    [Required(ErrorMessage = "La marca è obbligatoria")]
    public int MarcaIdFk { get; set; }

    [Required(ErrorMessage = "Il tipo mezzo è obbligatorio")]
    public int TipoMezzoIdFk { get; set; }

    // Proprietà di navigazione / visualizzazione (non mappate direttamente in insert/update)
    [NotMapped]
    public string? MarcaDescrizione { get; set; }

    [NotMapped]
    public string? TipoMezzoDescrizione { get; set; }
}
