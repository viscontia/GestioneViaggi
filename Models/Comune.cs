using System.ComponentModel.DataAnnotations;
using GestioneViaggi.Validation.Semantic;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un comune italiano o estero (tabella ana_geo_comuni)
/// Colonne DB: comune_id, comune, cod_istat, pref_tel, cap, cod_fiscale,
/// num_abitanti, link, comune_estero, comune_provincia_fk, comune_ripgeo_FK, comune_capoluogo_fk
/// </summary>
public class Comune : BaseEntity, IValidatableObject
{
    [Required(ErrorMessage = "Il nome del comune è obbligatorio")]
    [StringLength(100, ErrorMessage = "Il nome del comune non può superare i 100 caratteri")]
    public string Nome { get; set; } = string.Empty;

    [StringLength(6, MinimumLength = 6, ErrorMessage = "Il codice ISTAT deve essere di esattamente 6 cifre")]
    [RegularExpression(@"^\d{6}$", ErrorMessage = "Il codice ISTAT deve contenere solo cifre numeriche")]
    public string? CodIstat { get; set; }

    [StringLength(5, ErrorMessage = "Il prefisso telefonico non può superare i 5 caratteri")]
    public string? PrefTel { get; set; }

    // [StringLength(5, MinimumLength = 5, ErrorMessage = "Il CAP deve essere di esattamente 5 caratteri")]
    // [RegularExpression(@"^\d{5}$", ErrorMessage = "Il CAP deve contenere solo 5 cifre numeriche")]
    [StringLength(12, ErrorMessage = "Il CAP non può superare i 12 caratteri")] // Generic max length for safety
    public string? Cap { get; set; }

    [StringLength(4, ErrorMessage = "Il codice fiscale non può superare i 4 caratteri")]
    public string? CodFiscale { get; set; }

    [Required(ErrorMessage = "Il numero di abitanti è obbligatorio")]
    [Range(10, int.MaxValue, ErrorMessage = "Il numero di abitanti deve essere almeno 10.")]
    public int? NumAbitanti { get; set; }

    [StringLength(200, ErrorMessage = "Il link non può superare i 200 caratteri")]
    [Url(ErrorMessage = "Il link deve essere un URL valido")]
    public string? Link { get; set; }

    public bool ComuneEstero { get; set; } = false;

    [Required(ErrorMessage = "La provincia è obbligatoria")]
    public int? ProvinciaIdFk { get; set; }

    [Required(ErrorMessage = "La ripartizione geografica è obbligatoria")]
    public int? RipGeoIdFk { get; set; }

    [Required(ErrorMessage = "Il capoluogo è obbligatorio")]
    public int? CapoluogoIdFk { get; set; }

    // Campi non salvati nel DB, solo per visualizzazione nella grid
    public string? ProvinciaDescrizione { get; set; }
    public string? ProvinciaSigla { get; set; }
    public string? RipGeoDescrizione { get; set; }
    public string? RegioneDescrizione { get; set; }
    public string? CapoluogoDescrizione { get; set; }

    /// <summary>
    /// Validazioni condizionali basate su ComuneEstero
    /// </summary>
    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        var results = new List<ValidationResult>();

        // FK OBBLIGATORIE
        if (!ProvinciaIdFk.HasValue || ProvinciaIdFk.Value <= 0)
        {
            results.Add(new ValidationResult(
                "La provincia è obbligatoria",
                new[] { nameof(ProvinciaIdFk) }
            ));
        }

        if (!RipGeoIdFk.HasValue || RipGeoIdFk.Value <= 0)
        {
            results.Add(new ValidationResult(
                "La ripartizione geografica è obbligatoria",
                new[] { nameof(RipGeoIdFk) }
            ));
        }

        if (!CapoluogoIdFk.HasValue || CapoluogoIdFk.Value <= 0)
        {
            results.Add(new ValidationResult(
                "Il capoluogo è obbligatorio",
                new[] { nameof(CapoluogoIdFk) }
            ));
        }

        // Se NON è un comune estero, alcuni campi diventano obbligatori
        if (!ComuneEstero)
        {
            if (string.IsNullOrWhiteSpace(CodIstat))
            {
                results.Add(new ValidationResult(
                    "Il codice ISTAT è obbligatorio per i comuni italiani",
                    new[] { nameof(CodIstat) }
                ));
            }

            if (string.IsNullOrWhiteSpace(Cap))
            {
                results.Add(new ValidationResult(
                    "Il CAP è obbligatorio per i comuni italiani",
                    new[] { nameof(Cap) }
                ));
            }
            else
            {
                var capValidation = GeographicValidator.CheckCap(Cap);
                if (!capValidation.IsValid)
                {
                    results.Add(new ValidationResult(
                        capValidation.ErrorMessage,
                        new[] { nameof(Cap) }
                    ));
                }
            }

            if (string.IsNullOrWhiteSpace(CodFiscale))
            {
                results.Add(new ValidationResult(
                    "Il codice catasto (Belfiore) è obbligatorio per i comuni italiani",
                    new[] { nameof(CodFiscale) }
                ));
            }
            else if (!System.Text.RegularExpressions.Regex.IsMatch(CodFiscale, @"^[A-Z][0-9]{3}$"))
            {
                results.Add(new ValidationResult(
                   "Il codice deve essere di 4 caratteri: 1 lettera e 3 numeri (es. H501)",
                   new[] { nameof(CodFiscale) }
               ));
            }

            if (string.IsNullOrWhiteSpace(PrefTel))
            {
                results.Add(new ValidationResult(
                    "Il prefisso telefonico è obbligatorio per i comuni italiani",
                    new[] { nameof(PrefTel) }
                ));
            }
            else if (!System.Text.RegularExpressions.Regex.IsMatch(PrefTel, @"^0\d{1,3}$"))
            {
                results.Add(new ValidationResult(
                    "Il prefisso deve essere di 2-4 cifre e iniziare con 0 (es. 02, 06, 055, 0332)",
                    new[] { nameof(PrefTel) }
                ));
            }
        }
        else
        {
            // Se è un comune estero:
            // 1. CAP è OPZIONALE.
            // 2. Se c'è, controlliamo solo la lunghezza (già gestita dall'attributo generico)
            // Non usiamo GeographicValidator.CheckCap perché impone 5 cifre.
        }

        return results;
    }
}
