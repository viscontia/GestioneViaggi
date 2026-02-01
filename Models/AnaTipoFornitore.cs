using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models
{
    [Table("ana_tipo_fornitore")]
    public class AnaTipoFornitore : BaseEntity
    {
        [Key]
        [Column("tipo_fornitore_id")]
        public new int Id { get; set; } // Hides BaseEntity.Id to map explicitly if needed, or just implementation of abstract

        [Column("azienda_fk")]
        public int AziendaFk { get; set; }

        [Column("descrizione")]
        [Required]
        [MaxLength(50)]
        public string Descrizione { get; set; } = string.Empty;

        [Column("categoria")]
        [MaxLength(20)]
        public string? Categoria { get; set; } // 'COSTO', 'RICAVO', 'MISTO'

        [Column("conto_contabile_default")]
        [MaxLength(20)]
        public string? ContoContabileDefault { get; set; }

        [Column("created_at")]
        public DateTime? CreatedAt { get; set; }

        [Column("updated_at")]
        public DateTime? UpdatedAt { get; set; }
    }
}
