namespace GestioneViaggi.Models;

using System.ComponentModel.DataAnnotations;

/// <summary>
/// Entità Cliente - rappresenta l'anagrafica clienti (ana_clienti)
/// </summary>
public class Cliente : BaseEntity, IValidatableObject
{
    // Primary Key
    public int ClienteId { get; set; }

    // Dati Anagrafici
    [Required(ErrorMessage = "Il titolo è obbligatorio")]
    public string? Titolo { get; set; }

    [Required(ErrorMessage = "Il cognome è obbligatorio")]
    public string Cognome { get; set; } = string.Empty;

    [Required(ErrorMessage = "Il nome è obbligatorio")]
    public string Nome { get; set; } = string.Empty;

    [Required(ErrorMessage = "Il sesso è obbligatorio")]
    [RegularExpression("[MF]", ErrorMessage = "Selezionare M o F")]
    public char Sesso { get; set; } // 'M' o 'F'

    // Residenza
    public int ComuneResidenzaFk { get; set; }
    public string? IndirizzoResidenza { get; set; }

    // Nascita
    [Required(ErrorMessage = "Il comune di nascita è obbligatorio")]
    [Range(1, int.MaxValue, ErrorMessage = "Il comune di nascita è obbligatorio")]
    public int ComuneNascitaFk { get; set; }
    public DateTime? DataNascita { get; set; }

    // Contatti
    public string? PrefTelInt { get; set; }
    public string? Telefono { get; set; }

    [Required(ErrorMessage = "L'email è obbligatoria")]
    [EmailAddress(ErrorMessage = "Formato email non valido")]
    public string? Email { get; set; }

    // Documenti Identificativi
    public string? CodiceFiscale { get; set; }
    public string? Iban { get; set; }
    [Required(ErrorMessage = "Il tipo di documento è obbligatorio")]
    public string? TipoDocIdentita { get; set; }

    [Required(ErrorMessage = "Il numero del documento è obbligatorio")]
    public string? DocumentoNumero { get; set; }

    [Required(ErrorMessage = "L'ente di rilascio è obbligatorio")]
    public string? DocumentoRilasciatoDa { get; set; }

    [Required(ErrorMessage = "La data di rilascio è obbligatoria")]
    public DateTime? DocumentoRilasciatoData { get; set; }

    [Required(ErrorMessage = "La data di scadenza è obbligatoria")]
    public DateTime? DocumentoRilasciatoScadenza { get; set; }

    // File Binari - Foto
    public byte[]? Foto { get; set; }
    public string? FotoMimeType { get; set; }
    public string? FotoFilename { get; set; }
    public string? FotoCharset { get; set; }
    public DateTime? FotoUpdDate { get; set; }

    // File Binari - Documento
    public byte[]? CartaIdentita { get; set; }
    public string? DocumentoMimeType { get; set; }
    public string? DocumentoFilename { get; set; }
    public string? DocumentoCharset { get; set; }
    public DateTime? DocumentoUpdDate { get; set; }

    // Note e Intolleranze
    public string? Note { get; set; }
    public string? Intolleranza { get; set; }

    // Multi-tenant
    public int AziendaFk { get; set; }

    // Audit Fields
    public string? CreatedBy { get; set; }
    public DateTime? Created { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }

    // Navigation Properties (opzionali - per future implementazioni)
    public Comune? ComuneResidenza { get; set; }
    public Comune? ComuneNascita { get; set; }

    // Proprietà navigazione DTO-like per DataGrid
    public string? AziendaRagioneSociale { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        // Validazione Codice Fiscale: Obbligatorio solo per clienti italiani
        // Si assume italiano se ComuneResidenza è null (default safe) o se ComuneEstero è false
        bool isEstero = ComuneResidenza?.ComuneEstero ?? false;

        if (!isEstero)
        {
            if (string.IsNullOrWhiteSpace(CodiceFiscale))
            {
                yield return new ValidationResult(
                    "Il Codice Fiscale è obbligatorio per i clienti residenti in Italia",
                    new[] { nameof(CodiceFiscale) }
                );
            }
            else if (CodiceFiscale.Length != 16)
            {
                // Nota: La validazione regex/formato potrebbe essere già gestita altrove o qui
                // Per ora ci limitiamo a controllare la presenza come richiesto.
                // Il validator fiscale specifico (CodiceFiscaleValidator) fa controlli più approfonditi.
            }
        }
    }
}
