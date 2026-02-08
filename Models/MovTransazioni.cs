using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models
{
    [Table("mov_transazioni")]
    public class MovTransazioni
    {
        [Key]
        [Column("transazione_id")]
        public int TransazioneId { get; set; }

        [Column("transazione_azienda_id")]
        public int TransazioneAziendaId { get; set; }

        [Column("transazione_viaggio_id")]
        public int? TransazioneViaggioId { get; set; }

        [Column("transazione_data_viaggio_id")]
        public int? TransazioneDataViaggioId { get; set; }

        [Column("transazione_fornitore_id")]
        [Required(ErrorMessage = "Il Fornitore è obbligatorio")]
        public int TransazioneFornitoreId { get; set; }

        [Column("transazione_tipo_movimento")]
        [Required]
        public string TransazioneTipoMovimento { get; set; } = "USCITA"; // ENTRATA o USCITA

        [Column("transazione_importo")]
        [Required(ErrorMessage = "L'importo è obbligatorio")]
        public decimal TransazioneImporto { get; set; }

        [Column("transazione_valuta_id")]
        [Required(ErrorMessage = "La Valuta è obbligatoria")]
        public int TransazioneValutaId { get; set; }

        [Column("transazione_importo_eur")]
        public decimal? TransazioneImportoEur { get; set; } // Calcolato dal DB

        [Column("transazione_data")]
        [Required(ErrorMessage = "La Data Transazione è obbligatoria")]
        public DateTime TransazioneData { get; set; } = DateTime.Now;

        [Column("transazione_data_scadenza")]
        public DateTime? TransazioneDataScadenza { get; set; }

        [Column("transazione_data_pagamento")]
        public DateTime? TransazioneDataPagamento { get; set; }

        [Column("transazione_stato")]
        [Required]
        public string TransazioneStato { get; set; } = "DA_PAGARE";

        [Column("transazione_causale")]
        [Required(ErrorMessage = "La Causale è obbligatoria")]
        public string TransazioneCausale { get; set; } = string.Empty;

        [Column("transazione_note")]
        public string? TransazioneNote { get; set; }

        [Column("transazione_numero_documento")]
        public string? TransazioneNumeroDocumento { get; set; }

        [Column("transazione_data_documento")]
        public DateTime? TransazioneDataDocumento { get; set; }

        [Column("transazione_fattura_fk")]
        public int? TransazioneFatturaFk { get; set; }

        // === Audit Fields ===
        [Column("created_at")]
        public DateTime? Created { get; set; }

        [Column("created_by")]
        public string? CreatedBy { get; set; }

        [Column("updated_at")]
        public DateTime? Updated { get; set; }

        [Column("updated_by")]
        public string? UpdatedBy { get; set; }
        
        // === Navigation/Display Properties (NotMapped) ===
        
        [NotMapped]
        public string? AziendaCodice { get; set; }

        [NotMapped]
        public string? FornitoreRagioneSociale { get; set; }

        [NotMapped]
        public string? ValutaCodiceIso { get; set; }

        [NotMapped]
        public string? ViaggioDescrizione { get; set; }

        [NotMapped]
        public DateTime? DataViaggioInizio { get; set; }

        /// <summary>
        /// Restituisce l'importo formattato con simbolo valuta (se disponibile)
        /// </summary>
        public string ImportoFormattato => $"{TransazioneImporto:N2} {ValutaCodiceIso}";
    }
}
