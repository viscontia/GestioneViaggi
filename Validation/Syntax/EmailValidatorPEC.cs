using System.Text.RegularExpressions;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

public static partial class EmailValidatorPEC
{
    // Regex migliorata: 
    // - [a-zA-Z0-9._%+-]+ : Parte locale (prima della @)
    // - @[a-zA-Z0-9.-]+ : Dominio (può avere sottodomini separati da punto)
    // - \.[a-zA-Z]{2,} : TLD (minimo 2 caratteri, qualsiasi estensione)
    [GeneratedRegex(@"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$", RegexOptions.Compiled | RegexOptions.IgnoreCase)]
    private static partial Regex PecRegex();

    public static ValidationResult CheckPec(string? email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return ValidationResult.Success();

        if (!PecRegex().IsMatch(email))
            return ValidationResult.Failure(ValidationMessages.PecInvalid, "ERR_PEC_SYNTAX");

        return ValidationResult.Success();
    }
}
