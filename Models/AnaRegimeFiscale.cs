using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models
{
    [Table("ana_regimi_fiscali")]
    public class AnaRegimeFiscale : BaseEntity, IAuditable
    {
        [Key]
        [Column("regime_id")]
        public int RegimeId { get; set; }

        [NotMapped]
        public override int Id
        {
            get => RegimeId;
            set => RegimeId = value;
        }

        [Required(ErrorMessage = "Il codice regime è obbligatorio")]
        [Column("regime_codice")]
        [MaxLength(20)]
        public string RegimeCodice { get; set; } = string.Empty;

        [Required(ErrorMessage = "La descrizione è obbligatoria")]
        [Column("regime_descrizione")]
        [MaxLength(100)]
        public string RegimeDescrizione { get; set; } = string.Empty;

        // UI Behavior
        [Column("show_helper_calcolo")]
        public bool ShowHelperCalcolo { get; set; }

        // Default IVA Configuration
        [Column("default_aliquota_iva_codice")]
        [MaxLength(10)]
        public string? DefaultAliquotaIvaCodice { get; set; }

        [Column("is_iva_detraibile")]
        public bool IsIvaDetraibile { get; set; } = true;

        // Cassa Previdenziale
        [Column("cassa_prev_percentuale")]
        public decimal? CassaPrevPercentuale { get; set; }

        [Column("cassa_prev_descrizione")]
        [MaxLength(50)]
        public string? CassaPrevDescrizione { get; set; }

        [Column("cassa_prev_aliquota_codice")]
        [MaxLength(10)]
        public string? CassaPrevAliquotaCodice { get; set; }

        // Codici SDI (FatturaPA)
        [Column("regime_codice_sdi")]
        [MaxLength(4)]
        public string? RegimeCodiceSdi { get; set; }

        [Column("tipo_cassa_sdi")]
        [MaxLength(4)]
        public string? TipoCassaSdi { get; set; }

        // Imposta di Bollo
        [Column("bollo_soglia")]
        public decimal? BolloSoglia { get; set; }

        [Column("bollo_importo")]
        public decimal? BolloImporto { get; set; }

        [Column("bollo_aliquota_codice")]
        [MaxLength(10)]
        public string? BolloAliquotaCodice { get; set; }

        // Metadata
        [Column("attivo")]
        public bool Attivo { get; set; } = true;

        // IAuditable
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

        // Display Properties
        [NotMapped]
        public string DisplayText => $"{RegimeCodice} - {RegimeDescrizione}";

        public override string ToString() => DisplayText;
    }
}
