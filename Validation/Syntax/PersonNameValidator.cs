using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

public static class PersonNameValidator
{
    private const int MaxLength = 100;

    public static ValidationResult CheckNome(string? nome)
    {
        if (string.IsNullOrWhiteSpace(nome))
            return ValidationResult.Success();

        if (nome.Trim().Length > MaxLength)
            return ValidationResult.Failure(ValidationMessages.NomeTooLong, "CHK_NAME_001");

        return ValidationResult.Success();
    }

    public static ValidationResult CheckCognome(string? cognome)
    {
        if (string.IsNullOrWhiteSpace(cognome))
            return ValidationResult.Success();

        if (cognome.Trim().Length > MaxLength)
            return ValidationResult.Failure(ValidationMessages.CognomeTooLong, "CHK_SURN_001");

        return ValidationResult.Success();
    }

    public static ValidationResult CheckRuolo(string? ruolo)
    {
        if (string.IsNullOrWhiteSpace(ruolo))
            return ValidationResult.Success();

        if (ruolo.Trim().Length > MaxLength)
            return ValidationResult.Failure(ValidationMessages.RuoloTooLong, "CHK_ROLE_001");

        return ValidationResult.Success();
    }
}
