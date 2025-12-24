using System.Text.RegularExpressions;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

public static partial class CodeValidator
{
    [GeneratedRegex(@"^[A-Z0-9]{7}$", RegexOptions.Compiled)]
    private static partial Regex CodiceSdiRegex();

    public static ValidationResult CheckCodiceSdi(string? codiceSdi)
    {
        if (string.IsNullOrWhiteSpace(codiceSdi))
            return ValidationResult.Failure(ValidationMessages.CodiceSdiInvalid, "CHK_SDI_001");

        var upperCode = codiceSdi.ToUpperInvariant();

        if (!CodiceSdiRegex().IsMatch(upperCode))
            return ValidationResult.Failure(ValidationMessages.CodiceSdiInvalid, "CHK_SDI_002");

        return ValidationResult.Success();
    }
}
