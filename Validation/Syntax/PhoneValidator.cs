using System.Text.RegularExpressions;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

public static partial class PhoneValidator
{
    [GeneratedRegex(@"^(\+39\s?)?[0-9\s\-\.]{6,15}$", RegexOptions.Compiled)]
    private static partial Regex TelefonoItalyRegex();

    public static ValidationResult CheckTelefonoItaly(string? telefono)
    {
        if (string.IsNullOrWhiteSpace(telefono))
            return ValidationResult.Failure(ValidationMessages.TelefonoInvalid, "CHK_TEL_001");

        var trimmed = telefono.Trim();
        
        if (string.IsNullOrEmpty(trimmed))
            return ValidationResult.Failure(ValidationMessages.TelefonoInvalid, "CHK_TEL_002");

        if (!TelefonoItalyRegex().IsMatch(trimmed))
            return ValidationResult.Failure(ValidationMessages.TelefonoInvalid, "CHK_TEL_003");

        return ValidationResult.Success();
    }
}
