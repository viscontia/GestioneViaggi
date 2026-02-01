using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models;

[Table("ana_tassi_cambio")]
public class AnaTassiCambio : BaseEntity
{
    [Key]
    [Column("tasso_id")]
    public int TassoId { get; set; }

    [Column("tasso_valuta_da_fk")]
    public int TassoValutaDaId { get; set; }

    [Column("tasso_valuta_a_fk")]
    public int TassoValutaAId { get; set; }

    [Column("tasso_data_validita")]
    public DateTime TassoDataValidita { get; set; }

    [Column("tasso_valore")]
    public decimal TassoValore { get; set; }

    [Column("tasso_fonte")]
    public string? TassoFonte { get; set; }

    [Column("tasso_note")]
    public string? TassoNote { get; set; }

    // === Audit Fields ===
    [Column("created_at")]
    public DateTime? Created { get; set; }

    [Column("created_by")]
    public string? CreatedBy { get; set; }

    [Column("updated_at")]
    public DateTime? Updated { get; set; }

    [Column("updated_by")]
    public string? UpdatedBy { get; set; }

    // === Navigation / Display Properties ===
    [NotMapped]
    public string? ValutaDaCodice { get; set; }
    
    [NotMapped]
    public string? ValutaACodice { get; set; }
}
