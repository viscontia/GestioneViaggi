using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models;

/// <summary>
/// Titolo di cortesia di una persona fisica (tabella GLOBALE ana_titolo_persone).
/// Ogni titolo porta il proprio sesso: è la sorgente di ana_clienti.cliente_sesso,
/// che il DB deriva da qui con un trigger. Per questo esistono solo forme di genere
/// non ambigue — SIG./SIG.RA, DOTT./DOTT.SSA — e mai una riga valida per entrambi.
/// </summary>
[Table("ana_titolo_persone")]
public class AnaTitoloPersone : BaseEntity
{
    [Column("titolo_persone_cod")]
    public override int Id { get; set; }

    [Required(ErrorMessage = "La descrizione è obbligatoria")]
    [StringLength(30, ErrorMessage = "Max 30 caratteri")]
    [Column("titolo_persone_descrizione")]
    public string Descrizione { get; set; } = string.Empty;

    [Required(ErrorMessage = "Il sesso è obbligatorio")]
    [RegularExpression("[MF]", ErrorMessage = "Selezionare M o F")]
    [Column("titolo_persone_sesso")]
    public char Sesso { get; set; } = 'M';
}
