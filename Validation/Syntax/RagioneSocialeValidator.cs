using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

public static class RagioneSocialeValidator
{
    private const int MaxLength = 255;

    public static ValidationResult CheckRagioneSociale(string? ragioneSociale)
    {
        if (string.IsNullOrWhiteSpace(ragioneSociale))
            return ValidationResult.Failure(ValidationMessages.RagioneSocialeEmpty, "CHK_RS_001");

        var trimmed = ragioneSociale.Trim();

        if (trimmed.Length == 0)
            return ValidationResult.Failure(ValidationMessages.RagioneSocialeEmpty, "CHK_RS_002");

        if (trimmed.Length > MaxLength)
            return ValidationResult.Failure(ValidationMessages.RagioneSocialeTooLong, "CHK_RS_003");

        return ValidationResult.Success();
    }
}
