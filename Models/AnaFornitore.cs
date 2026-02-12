using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using GestioneViaggi.Validation.Syntax;

namespace GestioneViaggi.Models
{
    [Table("ana_controparti")]
    public class AnaFornitore : BaseEntity, IAuditable, IValidatableObject
    {
        [Key]
        [Column("controparte_id")]
        public new int Id { get; set; }

        [Column("azienda_fk")]
        public int AziendaFk { get; set; }

        [Column("ragione_sociale")]
        [Required(ErrorMessage = "La Ragione Sociale è obbligatoria")]
        [MaxLength(100)]
        public string RagioneSociale { get; set; } = string.Empty;

        [Column("nome_breve")]
        [MaxLength(50)]
        public string? NomeBreve { get; set; }

        // NUOVI FLAG FONDAMENTALI PER CONTROPARTI
        [Column("is_fornitore")]
        [Required]
        public bool IsFornitore { get; set; } = false;

        [Column("is_cliente")]
        [Required]
        public bool IsCliente { get; set; } = false;

        [Column("indirizzo")]
        [MaxLength(100)]
        public string? Indirizzo { get; set; }

        [Column("comune_fk")]
        public int? ComuneFk { get; set; }
        
        [Column("telefono_prefisso")]
        [MaxLength(5)]
        public string? TelefonoPrefisso { get; set; }

        [Column("telefono_numero")]
        [MaxLength(20)]
        public string? TelefonoNumero { get; set; }

        [Column("email")]
        [MaxLength(100)]
        [EmailAddress(ErrorMessage = "Email non valida")]
        public string? Email { get; set; }

        [Column("pec")]
        [MaxLength(100)]
        [EmailAddress(ErrorMessage = "PEC non valida")]
        public string? Pec { get; set; }

        [Column("sito_web")]
        [MaxLength(100)]
        public string? SitoWeb { get; set; }

        [Column("fornitore_estero")]
        public bool FornitoreEstero { get; set; } = false;

        [Column("codice_destinatario_sdi")]
        [MaxLength(7)]
        public string? CodiceSdi { get; set; }

        [Column("partita_iva")]
        [MaxLength(20)]
        public string? PartitaIva { get; set; }

        [Column("codice_fiscale")]
        [MaxLength(16)]
        public string? CodiceFiscale { get; set; }

        [Column("tipo_fornitore_fk")]
        public int? TipoFornitoreFk { get; set; }

        [Column("attivo")]
        public bool Attivo { get; set; } = true;

        [Column("priorita")]
        [Range(1, 10, ErrorMessage = "La priorità deve essere tra 1 e 10")]
        public int Priorita { get; set; } = 5;

        [Column("note")]
        public string? Note { get; set; }

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


        // ==========================================================
        // Navigation Properties
        // ==========================================================
        [NotMapped]
        public Comune? Comune { get; set; }

        // ==========================================================
        // UI / View Helper Properties
        // ==========================================================
        [NotMapped]
        public string? TipoFornitoreDescrizione { get; set; }

        [NotMapped]
        public string? ComuneDescrizione { get; set; }

        [NotMapped]
        public string? ProvinciaSigla { get; set; }

        [NotMapped]
        public string TipoControparteDisplay
        {
            get
            {
                if (IsFornitore && IsCliente) return "Fornitore/Cliente";
                if (IsFornitore) return "Fornitore";
                if (IsCliente) return "Cliente";
                return "N/D";
            }
        }

        // ==========================================================
        // Validazioni Condizionali (IValidatableObject)
        // ==========================================================

        /// <summary>
        /// Validazioni custom basate sul tipo controparte (Fornitore/Cliente, Italiano vs Estero).
        /// </summary>
        public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
        {
            var results = new List<ValidationResult>();

            // ===== VALIDAZIONE RUOLO =====
            // Almeno uno dei due flag deve essere TRUE
            if (!IsFornitore && !IsCliente)
            {
                results.Add(new ValidationResult(
                    "La controparte deve essere almeno un Fornitore o un Cliente",
                    new[] { nameof(IsFornitore), nameof(IsCliente) }
                ));
            }

            // ===== VALIDAZIONE TIPO FORNITORE =====
            // Se è un fornitore, il tipo fornitore è obbligatorio
            if (IsFornitore && (!TipoFornitoreFk.HasValue || TipoFornitoreFk.Value == 0))
            {
                results.Add(new ValidationResult(
                    "Il Tipo Fornitore è obbligatorio per le controparti marcate come Fornitore",
                    new[] { nameof(TipoFornitoreFk) }
                ));
            }

            // ===== CONTROPARTI ITALIANE =====
            if (!FornitoreEstero)
            {
                // 1. P.IVA E/O CF obbligatori (almeno uno dei due)
                if (string.IsNullOrWhiteSpace(PartitaIva) && string.IsNullOrWhiteSpace(CodiceFiscale))
                {
                    results.Add(new ValidationResult(
                        "Per controparti italiane è obbligatorio inserire almeno Partita IVA o Codice Fiscale",
                        new[] { nameof(PartitaIva), nameof(CodiceFiscale) }
                    ));
                }

                // 2. Validazione sintassi P.IVA italiana (11 cifre)
                if (!string.IsNullOrWhiteSpace(PartitaIva))
                {
                    var pivaResult = ItalianFiscalValidator.CheckPartitaIva(PartitaIva);
                    if (!pivaResult.IsValid)
                    {
                        results.Add(new ValidationResult(
                            pivaResult.ErrorMessage,
                            new[] { nameof(PartitaIva) }
                        ));
                    }
                }

                // 3. Validazione sintassi CF italiano (11-16 alfanumerici)
                if (!string.IsNullOrWhiteSpace(CodiceFiscale))
                {
                    var cfResult = ItalianFiscalValidator.CheckCodiceFiscale(CodiceFiscale);
                    if (!cfResult.IsValid)
                    {
                        results.Add(new ValidationResult(
                            cfResult.ErrorMessage,
                            new[] { nameof(CodiceFiscale) }
                        ));
                    }
                }

                // 4. Validazione Codice SDI (se presente)
                if (!string.IsNullOrWhiteSpace(CodiceSdi))
                {
                    var sdiResult = CodeValidator.CheckCodiceSdi(CodiceSdi, allowSpecialValues: true);
                    if (!sdiResult.IsValid)
                    {
                        results.Add(new ValidationResult(
                            sdiResult.ErrorMessage,
                            new[] { nameof(CodiceSdi) }
                        ));
                    }
                }
            }
            // ===== CONTROPARTI ESTERE =====
            else
            {
                // 1. VAT Number obbligatorio
                if (string.IsNullOrWhiteSpace(PartitaIva))
                {
                    results.Add(new ValidationResult(
                        "Per controparti estere il VAT Number è obbligatorio",
                        new[] { nameof(PartitaIva) }
                    ));
                }
                else
                {
                    // 2. Validazione sintassi VAT Number (prefisso paese + codice)
                    var vatResult = EuropeanVatValidator.CheckVatNumber(PartitaIva);
                    if (!vatResult.IsValid)
                    {
                        results.Add(new ValidationResult(
                            vatResult.ErrorMessage,
                            new[] { nameof(PartitaIva) }
                        ));
                    }
                }

                // 3. CF opzionale per esteri (no validazione specifica)
                // 4. SDI sarà auto-impostato a "XXXXXXX" in NormalizeEntityBeforeSave
            }

            return results;
        }
    }
}
