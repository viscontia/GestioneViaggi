using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models
{
    [Table("mov_transazioni_righe")]
    public class MovTransazioniRighe
    {
        [Key]
        [Column("riga_id")]
        public int RigaId { get; set; }

        [Column("transazione_fk")]
        [Required]
        public int TransazioneFk { get; set; }

        [Column("riga_numero")]
        [Required]
        public int RigaNumero { get; set; }

        [Column("riga_descrizione")]
        [Required(ErrorMessage = "La descrizione della riga è obbligatoria")]
        [MaxLength(255)]
        public string RigaDescrizione { get; set; } = string.Empty;

        /// <summary>
        /// Tipologia per XML SDI.
        /// Valori: 'PRESTAZIONE', 'CASSA_PREV', 'BOLLO', 'SPESA_ART15'
        /// </summary>
        [Column("riga_tipo")]
        [Required]
        [MaxLength(20)]
        public string RigaTipo { get; set; } = "PRESTAZIONE";

        [Column("riga_imponibile")]
        [Required]
        public decimal RigaImponibile { get; set; }

        [Column("riga_aliquota_iva_fk")]
        [Required]
        public int RigaAliquotaIvaFk { get; set; }

        [Column("riga_iva_valore")]
        public decimal RigaIvaValore { get; set; }

        [Column("riga_lordo")]
        public decimal RigaLordo { get; set; }

        // === Audit Fields ===
        [Column("created_at")]
        public DateTime? CreatedAt { get; set; }

        [Column("updated_at")]
        public DateTime? UpdatedAt { get; set; }

        // === Navigation/Display Properties (NotMapped) ===
        
        [NotMapped]
        public string? AliquotaIvaCodice { get; set; }

        [NotMapped]
        public string? AliquotaIvaDescrizione { get; set; }

        [NotMapped]
        public decimal? AliquotaIvaPercentuale { get; set; }
    }
}
