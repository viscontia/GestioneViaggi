using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

public static class TextValidator
{
    public static ValidationResult CheckNotEmptyTrimmed(string? value, string errorMessage)
    {
        if (string.IsNullOrWhiteSpace(value))
            return ValidationResult.Failure(errorMessage, "CHK_TXT_001");

        if (string.IsNullOrEmpty(value.Trim()))
            return ValidationResult.Failure(errorMessage, "CHK_TXT_002");

        return ValidationResult.Success();
    }

    public static ValidationResult CheckFormaGiuridica(string? formaGiuridica)
    {
        return CheckNotEmptyTrimmed(formaGiuridica, ValidationMessages.FormaGiuridicaEmpty);
    }
}
