using System.ComponentModel.DataAnnotations;
using GestioneViaggi.Validation.Syntax;
using GestioneViaggi.Validation.Semantic;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un viaggio (tabella ana_viaggi)
/// </summary>
public class AnaViaggi : BaseEntity, IValidatableObject
{
    // === Foreign Keys (Required) ===

    [Required(ErrorMessage = "La Nazione è obbligatoria")]
    [Range(1, int.MaxValue, ErrorMessage = "Selezionare una Nazione valida")]
    public int NazioneIdFk { get; set; }

    [Required(ErrorMessage = "Il Tipo Viaggio è obbligatorio")]
    [Range(1, int.MaxValue, ErrorMessage = "Selezionare un Tipo Viaggio valido")]
    public int TipoViaggioIdFk { get; set; }

    [Required(ErrorMessage = "Il Tipo Trattamento è obbligatorio")]
    [Range(1, int.MaxValue, ErrorMessage = "Selezionare un Tipo Trattamento valido")]
    public int TipoTrattamentoIdFk { get; set; }

    [Required(ErrorMessage = "Il Tipo Pernottamento è obbligatorio")]
    [Range(1, int.MaxValue, ErrorMessage = "Selezionare un Tipo Pernottamento valido")]
    public int TipoPernottamentoIdFk { get; set; }

    [Required(ErrorMessage = "Il Tipo Avvicinamento è obbligatorio")]
    [Range(1, int.MaxValue, ErrorMessage = "Selezionare un Tipo Avvicinamento valido")]
    public int TipoAvvicinamentoIdFk { get; set; }

    [Required(ErrorMessage = "L'Azienda è obbligatoria")]
    [Range(1, int.MaxValue, ErrorMessage = "Selezionare un'Azienda valida")]
    public int AziendaId { get; set; }

    // === Text Fields ===

    [Required(ErrorMessage = "La descrizione breve è obbligatoria")]
    public string DescrizioneBreve { get; set; } = string.Empty;

    [Required(ErrorMessage = "La descrizione estesa è obbligatoria")]
    public string DescrizioneEstesa { get; set; } = string.Empty;

    public string? Note { get; set; } // Opzionale

    public string? Link { get; set; } // Opzionale

    // === Numeric Fields ===

    [Required(ErrorMessage = "Il numero di giorni è obbligatorio")]
    [Range(1, 365, ErrorMessage = "Numero giorni non valido (1-365)")]
    public int NumeroGiorni { get; set; }

    [Required(ErrorMessage = "Il numero di notti è obbligatorio")]
    [Range(0, 365, ErrorMessage = "Numero notti non valido (0-365)")]
    public int NumeroNotti { get; set; }

    [Required(ErrorMessage = "I Km sono obbligatori")]
    [Range(0, 100000, ErrorMessage = "Km non validi")]
    public int Km { get; set; }

    // === Other Fields ===

    [Required(ErrorMessage = "Il campo Pasti al sacco è obbligatorio")]
    public string PastiAlSacco { get; set; } = "N"; // 'Y' o 'N'

    // === Audit Fields ===
    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }

    // === Navigation Properties / DTO Fields ===
    public string? NazioneNome { get; set; }
    public string? TipoViaggioDescrizione { get; set; }
    public string? TipoAvvicinamentoDescrizione { get; set; }
    public string? TipoTrattamentoDescrizione { get; set; }
    public string? TipoPernottamentoDescrizione { get; set; }
    public string? AziendaRagioneSociale { get; set; }

    // === Validation ===
    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        // Validazione Lunghezza Campi
        var lengthResult = FieldLengthValidator.ValidateMaxLength(DescrizioneBreve, 100, "Descrizione Breve");
        if (!lengthResult.IsValid)
            yield return new ValidationResult(lengthResult.Message, new[] { nameof(DescrizioneBreve) });

        lengthResult = FieldLengthValidator.ValidateMaxLength(DescrizioneEstesa, 2000, "Descrizione Estesa");
        if (!lengthResult.IsValid)
            yield return new ValidationResult(lengthResult.Message, new[] { nameof(DescrizioneEstesa) });

        lengthResult = FieldLengthValidator.ValidateMaxLength(Note, 2000, "Note");
        if (!lengthResult.IsValid)
            yield return new ValidationResult(lengthResult.Message, new[] { nameof(Note) });

        lengthResult = FieldLengthValidator.ValidateMaxLength(Link, 500, "Link");
        if (!lengthResult.IsValid)
            yield return new ValidationResult(lengthResult.Message, new[] { nameof(Link) });

        // Validazione Numerica
        var numericResult = NumericValidator.CheckPositiveDecimal((decimal?)Km);
        if (!numericResult.IsValid)
            yield return new ValidationResult(numericResult.ErrorMessage, new[] { nameof(Km) });

        // Giorni vs Notti consistency check (optional logic)
        if (NumeroNotti > NumeroGiorni)
        {
            yield return new ValidationResult("Il numero di notti non può essere superiore al numero di giorni (controllare)", new[] { nameof(NumeroNotti) });
        }
    }
    // === Transient UI Properties ===
    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public int MatchingDatesCount { get; set; }
}
