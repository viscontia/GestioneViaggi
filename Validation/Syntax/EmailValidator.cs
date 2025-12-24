using System.Text.RegularExpressions;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

public static partial class EmailValidator
{
    [GeneratedRegex(@"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$", RegexOptions.Compiled | RegexOptions.IgnoreCase)]
    private static partial Regex PecRegex();

    public static ValidationResult CheckPecFormat(string? pec)
    {
        if (string.IsNullOrWhiteSpace(pec))
            return ValidationResult.Success();

        if (!PecRegex().IsMatch(pec))
            return ValidationResult.Failure(ValidationMessages.PecInvalid, "CHK_PEC_001");

        return ValidationResult.Success();
    }
}
