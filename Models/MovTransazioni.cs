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

        [Column("transazione_controparte_id")]
        [Required(ErrorMessage = "La Controparte è obbligatoria")]
        public int TransazioneControparteId { get; set; }

        [Column("transazione_causale_tipo_id")]
        [Required(ErrorMessage = "La Causale Contabile è obbligatoria")]
        public int TransazioneCausaleTipoId { get; set; }

        [Column("transazione_tipo_movimento")]
        [Required(ErrorMessage = "Il Tipo Movimento è obbligatorio")]
        public string TransazioneTipoMovimento { get; set; } = "USCITA";

        [Column("transazione_importo")]
        [Required(ErrorMessage = "L'importo è obbligatorio")]
        public decimal TransazioneImporto { get; set; }

        [Column("transazione_valuta_id")]
        [Required(ErrorMessage = "La Valuta è obbligatoria")]
        public int TransazioneValutaId { get; set; }

        [Column("transazione_importo_eur_old")]
        [Obsolete("Usare TransazioneLordoEur invece - Deprecato dalla migrazione IVA del 14/02/2026")]
        public decimal? TransazioneImportoEur { get; set; } 

        // ==========================================
        // IVA - Aggiunte 14/02/2026
        // ==========================================

        /// <summary>
        /// FK a aliquota IVA - NULL se transazione in valuta estera o causale senza IVA
        /// </summary>
        [Column("transazione_aliquota_iva_fk")]
        public int? TransazioneAliquotaIvaFk { get; set; }

        /// <summary>
        /// Importo netto (senza IVA) in EUR - editabile per correzioni arrotondamenti
        /// </summary>
        [Column("transazione_imponibile_eur")]
        public decimal? TransazioneImponibileEur { get; set; }

        /// <summary>
        /// Importo IVA in EUR - editabile per correzioni arrotondamenti
        /// </summary>
        [Column("transazione_iva_eur")]
        public decimal? TransazioneIvaEur { get; set; }

        /// <summary>
        /// Importo totale (imponibile + IVA) in EUR - deve coincidere con fattura cartacea
        /// </summary>
        [Column("transazione_lordo_eur")]
        public decimal? TransazioneLordoEur { get; set; }

        /// <summary>
        /// Modalità inserimento: LORDO (scorporo) o NETTO (calcolo IVA)
        /// Auto-determinata da ciclo causale se NULL
        /// </summary>
        [Column("transazione_iva_modalita_input")]
        [MaxLength(10)]
        public string? TransazioneIvaModalitaInput { get; set; }

        /// <summary>
        /// Numero protocollo IVA progressivo annuale per azienda+ciclo.
        /// NULL se transazione non qualifica per protocollo IVA.
        /// </summary>
        [Column("transazione_numero_protocollo_iva")]
        public int? TransazioneNumeroProtocolloIva { get; set; }

        [Column("transazione_tasso_cambio_applicato")]
        public decimal? TransazioneTassoCambioApplicato { get; set; }

        [Column("transazione_tasso_fonte")]
        public string? TransazioneTassoFonte { get; set; }

        [Column("transazione_tasso_data_validita")]
        public DateTime? TransazioneTassoDataValidita { get; set; }

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
        public string? ControparteRagioneSociale { get; set; }

        [NotMapped]
        public string? ValutaCodiceIso { get; set; }

        [NotMapped]
        public string? CausaleDescrizione { get; set; }

        [NotMapped]
        public int? CausaleSegno { get; set; }

        [NotMapped]
        public string? CausaleCiclo { get; set; }

        [NotMapped]
        public bool IsFatturaAttiva => CausaleCiclo == "ATTIVO";

        [NotMapped]
        public string? ViaggioDescrizione { get; set; }

        [NotMapped]
        public DateTime? DataViaggioInizio { get; set; }

        // ==========================================
        // Display Properties per IVA (NotMapped)
        // ==========================================

        /// <summary>
        /// Descrizione aliquota IVA (join)
        /// </summary>
        [NotMapped]
        public string? AliquotaIvaDescrizione { get; set; }

        /// <summary>
        /// Percentuale aliquota IVA (join)
        /// </summary>
        [NotMapped]
        public decimal? AliquotaIvaPercentuale { get; set; }

        /// <summary>
        /// Codice aliquota IVA (join) - es. "22", "FC"
        /// </summary>
        [NotMapped]
        public string? AliquotaIvaCodice { get; set; }

        /// <summary>
        /// Testo formattato per visualizzazione importo con IVA
        /// Es. "100.00 + IVA 22.00 = 122.00 EUR" oppure "150.00 USD"
        /// </summary>
        [NotMapped]
        public string ImportoConIVADisplay
        {
            get
            {
                if (TransazioneAliquotaIvaFk.HasValue &&
                    TransazioneImponibileEur.HasValue &&
                    TransazioneIvaEur.HasValue &&
                    TransazioneLordoEur.HasValue)
                {
                    return $"{TransazioneImponibileEur:N2} + IVA {TransazioneIvaEur:N2} = {TransazioneLordoEur:N2} EUR";
                }
                else if (TransazioneLordoEur.HasValue)
                {
                    return $"{TransazioneLordoEur:N2} EUR";
                }
                else
                {
                    return $"{TransazioneImporto:N2} {ValutaCodiceIso}";
                }
            }
        }

        /// <summary>
        /// Chip display per aliquota IVA
        /// Es. "22%" oppure "FC"
        /// </summary>
        [NotMapped]
        public string? AliquotaIvaChip => AliquotaIvaPercentuale.HasValue && AliquotaIvaPercentuale > 0
            ? $"{AliquotaIvaPercentuale:N0}%"
            : AliquotaIvaCodice;

        /// <summary>
        /// Restituisce l'importo formattato con simbolo valuta (se disponibile)
        /// </summary>
        public string ImportoFormattato => $"{TransazioneImporto:N2} {ValutaCodiceIso}";

        // ==========================================
        // Dettaglio Righe (Master-Detail)
        // ==========================================
        
        [NotMapped]
        public List<MovTransazioniRighe> Righe { get; set; } = new();
    }
}
