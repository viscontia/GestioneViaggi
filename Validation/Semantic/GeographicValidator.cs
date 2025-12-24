using System.Text.RegularExpressions;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Semantic;

public static partial class GeographicValidator
{
    [GeneratedRegex(@"^[0-9]{5}$", RegexOptions.Compiled)]
    private static partial Regex CapRegex();

    public static ValidationResult CheckCap(string? cap)
    {
        if (string.IsNullOrWhiteSpace(cap))
            return ValidationResult.Failure(ValidationMessages.CapInvalid, "CHK_CAP_001");

        var trimmed = cap.Trim();

        if (!CapRegex().IsMatch(trimmed))
            return ValidationResult.Failure(ValidationMessages.CapInvalid, "CHK_CAP_002");

        return ValidationResult.Success();
    }
}
