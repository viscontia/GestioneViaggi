using System.Text.RegularExpressions;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

public static partial class CodeValidator
{
    [GeneratedRegex(@"^[A-Z0-9]{7}$", RegexOptions.Compiled)]
    private static partial Regex CodiceSdiRegex();

    /// <summary>
    /// Valida il Codice Destinatario SDI (Sistema di Interscambio).
    /// </summary>
    /// <param name="codiceSdi">Codice SDI da validare (7 caratteri alfanumerici).</param>
    /// <param name="allowSpecialValues">
    /// Se true, accetta i valori speciali:
    /// - "0000000" (default per fornitori italiani - cassetto fiscale)
    /// - "XXXXXXX" (fisso per fornitori esteri)
    /// </param>
    /// <returns>ValidationResult con esito validazione.</returns>
    public static ValidationResult CheckCodiceSdi(string? codiceSdi, bool allowSpecialValues = false)
    {
        if (string.IsNullOrWhiteSpace(codiceSdi))
            return ValidationResult.Failure(ValidationMessages.CodiceSdiInvalid, "CHK_SDI_001");

        var upperCode = codiceSdi.ToUpperInvariant();

        // Valori speciali consentiti (se richiesto)
        if (allowSpecialValues && (upperCode == "0000000" || upperCode == "XXXXXXX"))
            return ValidationResult.Success();

        if (!CodiceSdiRegex().IsMatch(upperCode))
            return ValidationResult.Failure(ValidationMessages.CodiceSdiInvalid, "CHK_SDI_002");

        return ValidationResult.Success();
    }
}
