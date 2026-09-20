using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models
{
    /// <summary>
    /// Termini e modalità di pagamento dell'azienda (tabella <c>ana_modalita_pagamento</c>).
    /// </summary>
    /// <remarks>
    /// Il <b>codice</b> è la convenzione commerciale italiana che si legge sulle fatture
    /// (<c>30DF</c>, <c>60FM</c>, <c>RD</c>): non esiste uno standard di legge per i termini,
    /// esiste invece per la <b>fattura elettronica</b>, e i due campi <c>Sdi*</c> lo portano
    /// con sé — <c>MP01</c>…<c>MP23</c> per come si paga, <c>TP01</c>…<c>TP03</c> per quando.
    /// </remarks>
    [Table("ana_modalita_pagamento")]
    public class AnaModalitaPagamento : BaseEntity, IAuditable
    {
        [Key]
        [Column("modpag_id")]
        public int ModpagId { get; set; }

        [Column("azienda_fk")]
        [Required]
        public int AziendaFk { get; set; }

        [Column("modpag_codice")]
        [Required(ErrorMessage = "Il codice è obbligatorio")]
        [StringLength(10, ErrorMessage = "Il codice non può superare i 10 caratteri")]
        public string ModpagCodice { get; set; } = string.Empty;

        [Column("modpag_descrizione")]
        [Required(ErrorMessage = "La descrizione è obbligatoria")]
        [StringLength(100, ErrorMessage = "La descrizione non può superare i 100 caratteri")]
        public string ModpagDescrizione { get; set; } = string.Empty;

        [Column("modpag_giorni")]
        [Range(0, 365, ErrorMessage = "I giorni devono essere fra 0 e 365")]
        public int ModpagGiorni { get; set; }

        /// <summary>
        /// Se vero i giorni si contano dalla <b>fine del mese</b> della data documento.
        /// </summary>
        [Column("modpag_fine_mese")]
        public bool ModpagFineMese { get; set; }

        /// <summary>Fattura elettronica: <c>ModalitaPagamento</c>, da MP01 a MP23.</summary>
        [Column("modpag_sdi_modalita")]
        [StringLength(4)]
        public string? ModpagSdiModalita { get; set; }

        /// <summary>Fattura elettronica: <c>CondizioniPagamento</c> — TP01 a rate, TP02 completo, TP03 anticipo.</summary>
        [Column("modpag_sdi_condizioni")]
        [StringLength(4)]
        public string ModpagSdiCondizioni { get; set; } = "TP02";

        [Column("modpag_ordinamento")]
        public int ModpagOrdinamento { get; set; } = 100;

        [Column("is_active")]
        public bool IsActive { get; set; } = true;

        [Column("created_at")]
        public DateTime? Created { get; set; }

        [Column("created_by")]
        public string? CreatedBy { get; set; }

        [Column("updated_at")]
        public DateTime? Updated { get; set; }

        [Column("updated_by")]
        public string? UpdatedBy { get; set; }

        public override int Id
        {
            get => ModpagId;
            set => ModpagId = value;
        }

        /// <summary>
        /// Quello che si legge nelle tendine: «30DF — Bonifico 30 giorni data fattura».
        /// </summary>
        [NotMapped]
        public string Etichetta => $"{ModpagCodice} — {ModpagDescrizione}";

        /// <summary>
        /// La scadenza che questo termine produce a partire dalla data del documento.
        /// </summary>
        /// <remarks>
        /// ⚠️ È l'UNICO posto in cui questa regola è scritta: chiunque debba calcolare una
        /// scadenza passa di qui, così «60 fine mese» non significa due cose diverse in due
        /// schermate diverse.
        ///
        /// La differenza che conta: con <see cref="ModpagFineMese"/> i giorni NON partono dalla
        /// data della fattura ma dall'ultimo giorno del mese in cui cade. Una fattura del
        /// 3 marzo a «60 FM» scade il 30 maggio, non il 2 maggio — quasi un mese di differenza,
        /// ed è il motivo per cui i fornitori litigano sulle scadenze.
        /// </remarks>
        public DateTime CalcolaScadenza(DateTime dataDocumento)
        {
            var partenza = ModpagFineMese
                ? new DateTime(dataDocumento.Year, dataDocumento.Month,
                               DateTime.DaysInMonth(dataDocumento.Year, dataDocumento.Month))
                : dataDocumento.Date;

            return partenza.AddDays(ModpagGiorni);
        }
    }
}
