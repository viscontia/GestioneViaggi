using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un tipo di partecipante (tabella ANA_TIPO_PARTECIPANTE)
/// </summary>
[Table("ANA_TIPO_PARTECIPANTE")]
public class TipoPartecipante : BaseEntity
{
    [Required(ErrorMessage = "La descrizione è obbligatoria")]
    [StringLength(100, ErrorMessage = "Max 100 caratteri")]
    [Column("TIPO_PARTECIPANTE_DESCRIZIONE")]
    public string Descrizione { get; set; } = string.Empty;

    [Column("TIPO_PARTECIPANTE_DATI_MEZZO_OBB")]
    public bool DatiMezzoObbligatori { get; set; }

    [Column("TIPO_PARTECIPANTE_PILOTA")]
    public bool Pilota { get; set; }
}
