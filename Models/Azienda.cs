using System.ComponentModel.DataAnnotations;
using GestioneViaggi.Validation.Syntax;
using GestioneViaggi.Validation.Semantic;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un'azienda (tabella ana_aziende)
/// </summary>
public class Azienda : BaseEntity, IAuditable, IValidatableObject
{
    [Required(ErrorMessage = "La ragione sociale è obbligatoria")]
    [StringLength(255, ErrorMessage = "La ragione sociale non può superare i 255 caratteri")]
    public string RagioneSociale { get; set; } = string.Empty;

    [Required(ErrorMessage = "La forma giuridica è obbligatoria")]
    [StringLength(100, ErrorMessage = "La forma giuridica non può superare i 100 caratteri")]
    public string FormaGiuridica { get; set; } = string.Empty;

    public DateTime? DataCostituzione { get; set; }

    public DateTime? DataInizioAttivita { get; set; }

    [Range(0, double.MaxValue, ErrorMessage = "Il capitale sociale deve essere un valore positivo o zero")]
    public decimal? CapitaleSociale { get; set; }

    public bool SocioUnico { get; set; } = false;

    public bool InLiquidazione { get; set; } = false;

    [Required(ErrorMessage = "La Partita IVA è obbligatoria")]
    [StringLength(11, MinimumLength = 11, ErrorMessage = "La Partita IVA deve essere di 11 cifre")]
    [RegularExpression(@"^[0-9]{11}$", ErrorMessage = "La Partita IVA deve contenere solo cifre numeriche")]
    public string PartitaIva { get; set; } = string.Empty;

    [StringLength(16, ErrorMessage = "Il Codice Fiscale non può superare i 16 caratteri")]
    [RegularExpression(@"^[A-Z0-9]{11,16}$", ErrorMessage = "Il Codice Fiscale deve essere alfanumerico maiuscolo")]
    public string? CodiceFiscale { get; set; }

    public int? ReaProvinciaFk { get; set; }

    [StringLength(20, ErrorMessage = "Il numero REA non può superare i 20 caratteri")]
    public string? ReaNumero { get; set; }

    public DateTime? ReaDataIscrizione { get; set; }

    [StringLength(7, MinimumLength = 7, ErrorMessage = "Il Codice SDI deve essere di 7 caratteri")]
    [RegularExpression(@"^[A-Z0-9]{7}$", ErrorMessage = "Il Codice SDI deve essere alfanumerico maiuscolo")]
    public string CodiceDestinatarioSdi { get; set; } = "0000000";

    [StringLength(255, ErrorMessage = "La PEC non può superare i 255 caratteri")]
    [EmailAddress(ErrorMessage = "La PEC deve essere un indirizzo email valido")]
    public string? Pec { get; set; }

    [StringLength(255, ErrorMessage = "Il sito web non può superare i 255 caratteri")]
    [Url(ErrorMessage = "Il sito web deve essere un URL valido")]
    public string? SitoWeb { get; set; }

    [Required(ErrorMessage = "Il telefono principale è obbligatorio")]
    [StringLength(30, ErrorMessage = "Il telefono non può superare i 30 caratteri")]
    public string TelefonoPrincipale { get; set; } = string.Empty;

    public bool Attivo { get; set; } = true;

    public DateTime DataCreazione { get; set; }

    public DateTime? DataUltimaModifica { get; set; }

    // === IAuditable Implementation ===
    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public string? CreatedBy { get; set; }

    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public DateTime? Created 
    { 
        get => DataCreazione; 
        set => DataCreazione = value ?? DateTime.UtcNow; 
    }

    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public string? UpdatedBy { get; set; }

    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public DateTime? Updated 
    { 
        get => DataUltimaModifica; 
        set => DataUltimaModifica = value; 
    }

    // Campi di lookup per la grid (non salvati nel DB)
    public string? ReaProvinciaSigla { get; set; }

    /// <summary>
    /// Validazioni custom usando i validatori centralizzati
    /// </summary>
    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        var results = new List<ValidationResult>();

        // Validazione Partita IVA con validatore centralizzato
        var pivaResult = ItalianFiscalValidator.CheckPartitaIva(PartitaIva);
        if (!pivaResult.IsValid)
        {
            results.Add(new ValidationResult(
                pivaResult.ErrorMessage,
                new[] { nameof(PartitaIva) }
            ));
        }

        // Validazione Codice Fiscale (opzionale)
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

        // Validazione PEC (opzionale)
        if (!string.IsNullOrWhiteSpace(Pec))
        {
            var pecResult = EmailValidatorPEC.CheckPec(Pec);
            if (!pecResult.IsValid)
            {
                results.Add(new ValidationResult(
                    pecResult.ErrorMessage,
                    new[] { nameof(Pec) }
                ));
            }
        }

        // Validazione Telefono Principale
        var telResult = PhoneValidator.CheckTelefonoItaly(TelefonoPrincipale);
        if (!telResult.IsValid)
        {
            results.Add(new ValidationResult(
                telResult.ErrorMessage,
                new[] { nameof(TelefonoPrincipale) }
            ));
        }

        // Validazione Codice SDI
        var sdiResult = CodeValidator.CheckCodiceSdi(CodiceDestinatarioSdi);
        if (!sdiResult.IsValid)
        {
            results.Add(new ValidationResult(
                sdiResult.ErrorMessage,
                new[] { nameof(CodiceDestinatarioSdi) }
            ));
        }

        // Validazione Forma Giuridica
        var formaResult = TextValidator.CheckFormaGiuridica(FormaGiuridica);
        if (!formaResult.IsValid)
        {
            results.Add(new ValidationResult(
                formaResult.ErrorMessage,
                new[] { nameof(FormaGiuridica) }
            ));
        }

        // Validazione Capitale Sociale
        if (CapitaleSociale.HasValue)
        {
            var capResult = NumericValidator.CheckCapitaleSociale(CapitaleSociale);
            if (!capResult.IsValid)
            {
                results.Add(new ValidationResult(
                    capResult.ErrorMessage,
                    new[] { nameof(CapitaleSociale) }
                ));
            }
        }

        // Validazione Date Logiche: Data Inizio Attività >= Data Costituzione
        var dateRangeResult = DateValidator.CheckDateRange(
            DataCostituzione,
            DataInizioAttivita,
            "Costituzione",
            "Inizio Attività"
        );

        if (!dateRangeResult.IsValid)
        {
            results.Add(new ValidationResult(
                dateRangeResult.ErrorMessage,
                new[] { nameof(DataInizioAttivita) }
            ));
        }

        // NUOVO: ReaDataIscrizione >= DataCostituzione
        if (ReaDataIscrizione.HasValue && DataCostituzione.HasValue)
        {
            var reaDateResult = DateValidator.CheckDateRange(
                DataCostituzione,
                ReaDataIscrizione,
                "Costituzione",
                "Iscrizione REA"
            );

            if (!reaDateResult.IsValid)
            {
                results.Add(new ValidationResult(
                    reaDateResult.ErrorMessage,
                    new[] { nameof(ReaDataIscrizione) }
                ));
            }
        }

        // Validazione REA condizionale: se uno dei campi è compilato, tutti sono obbligatori
        var hasReaNumero = !string.IsNullOrWhiteSpace(ReaNumero);
        var hasReaProvincia = ReaProvinciaFk.HasValue;
        var hasReaData = ReaDataIscrizione.HasValue;

        // Se almeno uno è compilato, verifica che ci siano tutti
        if (hasReaNumero || hasReaProvincia || hasReaData)
        {
            if (!hasReaNumero)
            {
                results.Add(new ValidationResult(
                    "Il Numero REA è obbligatorio se è presente un dato REA",
                    new[] { nameof(ReaNumero) }
                ));
            }

            if (!hasReaProvincia)
            {
                results.Add(new ValidationResult(
                    "La Provincia REA è obbligatoria se è presente un dato REA",
                    new[] { nameof(ReaProvinciaFk) }
                ));
            }

            if (!hasReaData)
            {
                results.Add(new ValidationResult(
                    "La Data Iscrizione REA è obbligatoria se è presente un dato REA",
                    new[] { nameof(ReaDataIscrizione) }
                ));
            }
        }

        return results;
    }
}
