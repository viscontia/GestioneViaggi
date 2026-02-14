using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models
{
    /// <summary>
    /// Anagrafica aliquote IVA per azienda
    /// Supporta multi-tenant e fatturazione elettronica
    /// </summary>
    [Table("ana_aliquote_iva")]
    public class AnaAliquotaIva : BaseEntity, IAuditable
    {
        [Key]
        [Column("iva_id")]
        public int IvaId { get; set; }

        // Override BaseEntity.Id to map to IvaId
        [NotMapped]
        public override int Id
        {
            get => IvaId;
            set => IvaId = value;
        }

        [Required]
        [Column("azienda_fk")]
        public int AziendaFk { get; set; }

        [Required]
        [Column("iva_codice")]
        [MaxLength(10)]
        public string IvaCodice { get; set; } = string.Empty;

        [Required]
        [Column("iva_descrizione")]
        [MaxLength(100)]
        public string IvaDescrizione { get; set; } = string.Empty;

        [Required]
        [Column("iva_percentuale")]
        [Range(0, 100)]
        public decimal IvaPercentuale { get; set; }

        [Column("iva_natura")]
        [MaxLength(10)]
        public string? IvaNatura { get; set; }

        [Column("is_default")]
        public bool IsDefault { get; set; }

        [Column("is_active")]
        public bool IsActive { get; set; } = true;

        [Column("ordinamento")]
        public short Ordinamento { get; set; } = 100;

        // Audit Fields
        [Column("created_at")]
        public DateTime? Created { get; set; }

        [Column("created_by")]
        [MaxLength(50)]
        public string? CreatedBy { get; set; }

        [Column("updated_at")]
        public DateTime? Updated { get; set; }

        [Column("updated_by")]
        [MaxLength(50)]
        public string? UpdatedBy { get; set; }

        // Display Properties (NotMapped)

        /// <summary>
        /// Testo completo per dropdown: "IVA Ordinaria 22% (22.00%)"
        /// </summary>
        [NotMapped]
        public string DisplayText => IvaPercentuale > 0
            ? $"{IvaDescrizione} ({IvaPercentuale:N2}%)"
            : IvaDescrizione;

        /// <summary>
        /// Testo breve per chip/badge: "22%" o "FC"
        /// </summary>
        [NotMapped]
        public string DisplayShort => IvaPercentuale > 0
            ? $"{IvaPercentuale:N0}%"
            : IvaCodice;

        /// <summary>
        /// Testo per tooltip: include natura FE se presente
        /// </summary>
        [NotMapped]
        public string DisplayTooltip => !string.IsNullOrWhiteSpace(IvaNatura)
            ? $"{IvaDescrizione} - Natura FE: {IvaNatura}"
            : IvaDescrizione;

        public override string ToString()
        {
            return DisplayText;
        }
    }
}
