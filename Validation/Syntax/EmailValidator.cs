using System.Text.RegularExpressions;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

public static partial class EmailValidator
{
    [GeneratedRegex(@"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$", RegexOptions.Compiled | RegexOptions.IgnoreCase)]
    private static partial Regex EmailRegex();

    public static ValidationResult CheckEmail(string? email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return ValidationResult.Success();

        if (!EmailRegex().IsMatch(email))
            return ValidationResult.Failure("Indirizzo email non valido.", "CHK_EMAIL_001");

        return ValidationResult.Success();
    }

    public static ValidationResult CheckPecFormat(string? pec)
    {
        if (string.IsNullOrWhiteSpace(pec))
            return ValidationResult.Success();

        if (!EmailRegex().IsMatch(pec))
            return ValidationResult.Failure(ValidationMessages.PecInvalid, "CHK_PEC_001");

        return ValidationResult.Success();
    }
}
