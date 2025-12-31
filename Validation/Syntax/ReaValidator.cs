using System.Text.RegularExpressions;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

public static partial class ReaValidator
{
    private const int MaxLength = 20;

    [GeneratedRegex(@"^[A-Z0-9\-\/]+$", RegexOptions.Compiled)]
    private static partial Regex ReaNumeroRegex();

    public static ValidationResult CheckNumeroRea(string? numeroRea)
    {
        if (string.IsNullOrWhiteSpace(numeroRea))
            return ValidationResult.Success();

        var trimmed = numeroRea.Trim();

        if (trimmed.Length > MaxLength)
            return ValidationResult.Failure(ValidationMessages.ReaInvalid, "CHK_REA_001");

        var upperRea = trimmed.ToUpperInvariant();

        if (!ReaNumeroRegex().IsMatch(upperRea))
            return ValidationResult.Failure(ValidationMessages.ReaInvalid, "CHK_REA_002");

        return ValidationResult.Success();
    }
}
