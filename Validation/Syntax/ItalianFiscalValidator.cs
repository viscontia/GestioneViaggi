using System.Text.RegularExpressions;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

public static partial class ItalianFiscalValidator
{
    [GeneratedRegex(@"^[0-9]{11}$", RegexOptions.Compiled)]
    private static partial Regex PartitaIvaRegex();

    [GeneratedRegex(@"^[A-Z0-9]{11,16}$", RegexOptions.Compiled)]
    private static partial Regex CodiceFiscaleRegex();

    public static ValidationResult CheckPartitaIva(string? partitaIva)
    {
        if (string.IsNullOrWhiteSpace(partitaIva))
            return ValidationResult.Failure(ValidationMessages.PartitaIvaInvalid, "CHK_PIVA_001");

        if (!PartitaIvaRegex().IsMatch(partitaIva))
            return ValidationResult.Failure(ValidationMessages.PartitaIvaInvalid, "CHK_PIVA_002");

        return ValidationResult.Success();
    }

    public static ValidationResult CheckCodiceFiscale(string? codiceFiscale)
    {
        if (string.IsNullOrWhiteSpace(codiceFiscale))
            return ValidationResult.Success();

        var upperCf = codiceFiscale.ToUpperInvariant();

        if (!CodiceFiscaleRegex().IsMatch(upperCf))
            return ValidationResult.Failure(ValidationMessages.CodiceFiscaleInvalid, "CHK_CF_001");

        return ValidationResult.Success();
    }
}
