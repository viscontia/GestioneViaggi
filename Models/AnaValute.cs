using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models
{
[Table("ana_valute")]
public class AnaValute : BaseEntity, IAuditable
{
    [Key]
    [Column("valuta_id")]
    public int ValutaId { get; set; }

    // Override BaseEntity.Id to map to ValutaId
    [NotMapped]
    public override int Id 
    { 
        get => ValutaId; 
        set => ValutaId = value; 
    }

    [Column("valuta_codice_iso")]
    public string ValutaCodiceIso { get; set; } = string.Empty;

    [Column("valuta_descrizione")]
    public string ValutaDescrizione { get; set; } = string.Empty;

    [Column("valuta_simbolo")]
    public string? ValutaSimbolo { get; set; }

    [Column("valuta_is_base")]
    public bool ValutaIsBase { get; set; }

    [Column("valuta_attiva")]
    public bool ValutaAttiva { get; set; } = true;

    [Column("valuta_decimali")]
    public int ValutaDecimali { get; set; } = 2;

    // === Audit Fields ===
    [Column("created_at")]
    public DateTime? Created { get; set; }

    [Column("created_by")]
    public string? CreatedBy { get; set; }

    [Column("updated_at")]
    public DateTime? Updated { get; set; }

    [Column("updated_by")]
    public string? UpdatedBy { get; set; }

    public override string ToString()
    {
        return $"{ValutaCodiceIso} - {ValutaDescrizione}";
    }
}
}
