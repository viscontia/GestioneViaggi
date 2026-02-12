using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models
{
    [Table("ana_tipi_causali")]
    public class AnaTipoCausale : BaseEntity, IAuditable
    {
        [Key]
        [Column("causale_id")]
        public int CausaleId { get; set; }

        [Column("azienda_fk")]
        [Required]
        public int AziendaFk { get; set; }

        [Column("causale_codice")]
        [Required(ErrorMessage = "Il codice è obbligatorio")]
        [StringLength(10)]
        public string CausaleCodice { get; set; } = string.Empty;

        [Column("causale_descrizione")]
        [Required(ErrorMessage = "La descrizione è obbligatoria")]
        [StringLength(100)]
        public string CausaleDescrizione { get; set; } = string.Empty;

        [Column("causale_segno")]
        [Required]
        public int CausaleSegno { get; set; } = 1; // +1 o -1

        [Column("causale_is_documento")]
        public bool CausaleIsDocumento { get; set; } = true;

        [Column("causale_ciclo")]
        [Required(ErrorMessage = "Il ciclo contabile è obbligatorio")]
        [StringLength(10)]
        public string CausaleCiclo { get; set; } = "PASSIVO"; // "ATTIVO" o "PASSIVO"

        [Column("is_active")]
        public bool IsActive { get; set; } = true;

        [Column("created_at")]
        public DateTime? Created { get; set; }

        [Column("created_by")]
        [StringLength(50)]
        public string? CreatedBy { get; set; }

        [Column("updated_at")]
        public DateTime? Updated { get; set; }

        [Column("updated_by")]
        [StringLength(50)]
        public string? UpdatedBy { get; set; }
        
        [NotMapped]
        public string SegnoDisplay
        {
            get
            {
                if (CausaleCiclo == "PASSIVO")
                {
                    return CausaleSegno > 0 ? "+ (Aumenta Debito)" : "- (Diminuisce Debito)";
                }
                else // ATTIVO
                {
                    return CausaleSegno > 0 ? "+ (Aumenta Credito)" : "- (Diminuisce Credito)";
                }
            }
        }

        [NotMapped]
        public string CicloDisplay => CausaleCiclo == "ATTIVO" ? "Clienti" : "Fornitori";
    }
}
