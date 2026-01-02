using GestioneViaggi.Validation.Models;

namespace GestioneViaggi.Validation.Syntax;

/// <summary>
/// Validatore generico per la lunghezza dei campi.
/// Verifica che una stringa rispetti i limiti di lunghezza minima e massima.
/// Fornisce messaggi di errore dettagliati e formattati.
/// </summary>
public static class FieldLengthValidator
{
    /// <summary>
    /// Valida la lunghezza di un campo con solo limite massimo.
    /// </summary>
    /// <param name="value">Valore del campo da validare</param>
    /// <param name="maxLength">Lunghezza massima consentita</param>
    /// <param name="fieldName">Nome del campo (per messaggio errore personalizzato)</param>
    /// <returns>ValidationResult con esito e messaggio formattato</returns>
    public static ValidationResult ValidateMaxLength(string? value, int maxLength, string? fieldName = null)
    {
        if (string.IsNullOrEmpty(value))
        {
            // Valore nullo o vuoto è sempre valido per questo validatore
            // (la validazione required va fatta separatamente)
            return ValidationResult.Success();
        }

        var actualLength = value.Length;

        if (actualLength <= maxLength)
        {
            return ValidationResult.Success();
        }

        var exceededBy = actualLength - maxLength;
        var fieldDisplayName = string.IsNullOrWhiteSpace(fieldName) ? "Questo campo" : fieldName;

        return ValidationResult.Failure(
            $"{fieldDisplayName} ha una lunghezza massima impostata a {maxLength} caratteri, che è stata superata di {exceededBy} caratteri",
            "max_length_exceeded",
            new Dictionary<string, object>
            {
                { "max_length", maxLength },
                { "actual_length", actualLength },
                { "exceeded_by", exceededBy }
            }
        );
    }

    /// <summary>
    /// Valida la lunghezza di un campo con solo limite minimo.
    /// </summary>
    /// <param name="value">Valore del campo da validare</param>
    /// <param name="minLength">Lunghezza minima richiesta</param>
    /// <param name="fieldName">Nome del campo (per messaggio errore personalizzato)</param>
    /// <returns>ValidationResult con esito e messaggio formattato</returns>
    public static ValidationResult ValidateMinLength(string? value, int minLength, string? fieldName = null)
    {
        if (string.IsNullOrEmpty(value))
        {
            // Valore nullo o vuoto fallisce sempre la validazione minima
            var fieldDisplayName = string.IsNullOrWhiteSpace(fieldName) ? "Questo campo" : fieldName;

            return ValidationResult.Failure(
                $"{fieldDisplayName} deve contenere almeno {minLength} caratteri",
                "min_length_not_met",
                new Dictionary<string, object>
                {
                    { "min_length", minLength },
                    { "actual_length", 0 }
                }
            );
        }

        var actualLength = value.Length;

        if (actualLength >= minLength)
        {
            return ValidationResult.Success();
        }

        var shortBy = minLength - actualLength;
        var displayName = string.IsNullOrWhiteSpace(fieldName) ? "Questo campo" : fieldName;

        return ValidationResult.Failure(
            $"{displayName} deve contenere almeno {minLength} caratteri (mancano {shortBy} caratteri)",
            "min_length_not_met",
            new Dictionary<string, object>
            {
                { "min_length", minLength },
                { "actual_length", actualLength },
                { "short_by", shortBy }
            }
        );
    }

    /// <summary>
    /// Valida la lunghezza di un campo con limiti minimo e massimo.
    /// </summary>
    /// <param name="value">Valore del campo da validare</param>
    /// <param name="minLength">Lunghezza minima richiesta</param>
    /// <param name="maxLength">Lunghezza massima consentita</param>
    /// <param name="fieldName">Nome del campo (per messaggio errore personalizzato)</param>
    /// <returns>ValidationResult con esito e messaggio formattato</returns>
    public static ValidationResult ValidateLength(string? value, int minLength, int maxLength, string? fieldName = null)
    {
        // Prima controlla lunghezza minima
        var minResult = ValidateMinLength(value, minLength, fieldName);
        if (!minResult.IsValid)
        {
            return minResult;
        }

        // Poi controlla lunghezza massima
        var maxResult = ValidateMaxLength(value, maxLength, fieldName);
        if (!maxResult.IsValid)
        {
            return maxResult;
        }

        return ValidationResult.Success();
    }

    /// <summary>
    /// Valida la lunghezza esatta di un campo.
    /// </summary>
    /// <param name="value">Valore del campo da validare</param>
    /// <param name="exactLength">Lunghezza esatta richiesta</param>
    /// <param name="fieldName">Nome del campo (per messaggio errore personalizzato)</param>
    /// <returns>ValidationResult con esito e messaggio formattato</returns>
    public static ValidationResult ValidateExactLength(string? value, int exactLength, string? fieldName = null)
    {
        if (string.IsNullOrEmpty(value))
        {
            var displayName = string.IsNullOrWhiteSpace(fieldName) ? "Questo campo" : fieldName;

            return ValidationResult.Failure(
                $"{displayName} deve essere di esattamente {exactLength} caratteri",
                "exact_length_not_met",
                new Dictionary<string, object>
                {
                    { "exact_length", exactLength },
                    { "actual_length", 0 }
                }
            );
        }

        var actualLength = value.Length;

        if (actualLength == exactLength)
        {
            return ValidationResult.Success();
        }

        var fieldDisplayName = string.IsNullOrWhiteSpace(fieldName) ? "Questo campo" : fieldName;
        var difference = actualLength - exactLength;
        var differenceDescription = difference > 0
            ? $"ha {difference} caratteri in più"
            : $"manca di {Math.Abs(difference)} caratteri";

        return ValidationResult.Failure(
            $"{fieldDisplayName} deve essere di esattamente {exactLength} caratteri ({differenceDescription})",
            "exact_length_not_met",
            new Dictionary<string, object>
            {
                { "exact_length", exactLength },
                { "actual_length", actualLength },
                { "difference", difference }
            }
        );
    }

    /// <summary>
    /// Valida che il campo non sia vuoto o solo spazi bianchi.
    /// </summary>
    /// <param name="value">Valore del campo da validare</param>
    /// <param name="fieldName">Nome del campo (per messaggio errore personalizzato)</param>
    /// <returns>ValidationResult con esito e messaggio</returns>
    public static ValidationResult ValidateNotEmpty(string? value, string? fieldName = null)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            var fieldDisplayName = string.IsNullOrWhiteSpace(fieldName) ? "Questo campo" : fieldName;

            return ValidationResult.Failure(
                $"{fieldDisplayName} è obbligatorio",
                "required",
                new Dictionary<string, object>
                {
                    { "is_null", value == null },
                    { "is_empty", value == string.Empty },
                    { "is_whitespace", !string.IsNullOrEmpty(value) && string.IsNullOrWhiteSpace(value) }
                }
            );
        }

        return ValidationResult.Success();
    }

    /// <summary>
    /// Validazione combinata: campo obbligatorio + lunghezza massima.
    /// Utile per campi required con limite.
    /// </summary>
    /// <param name="value">Valore del campo da validare</param>
    /// <param name="maxLength">Lunghezza massima consentita</param>
    /// <param name="fieldName">Nome del campo (per messaggio errore personalizzato)</param>
    /// <returns>ValidationResult con esito e messaggio</returns>
    public static ValidationResult ValidateRequiredWithMaxLength(string? value, int maxLength, string? fieldName = null)
    {
        // Prima verifica che non sia vuoto
        var notEmptyResult = ValidateNotEmpty(value, fieldName);
        if (!notEmptyResult.IsValid)
        {
            return notEmptyResult;
        }

        // Poi verifica lunghezza massima
        return ValidateMaxLength(value, maxLength, fieldName);
    }

    /// <summary>
    /// Validazione combinata: campo obbligatorio + lunghezza minima e massima.
    /// </summary>
    /// <param name="value">Valore del campo da validare</param>
    /// <param name="minLength">Lunghezza minima richiesta</param>
    /// <param name="maxLength">Lunghezza massima consentita</param>
    /// <param name="fieldName">Nome del campo (per messaggio errore personalizzato)</param>
    /// <returns>ValidationResult con esito e messaggio</returns>
    public static ValidationResult ValidateRequiredWithLength(string? value, int minLength, int maxLength, string? fieldName = null)
    {
        // Prima verifica che non sia vuoto
        var notEmptyResult = ValidateNotEmpty(value, fieldName);
        if (!notEmptyResult.IsValid)
        {
            return notEmptyResult;
        }

        // Poi verifica lunghezze
        return ValidateLength(value, minLength, maxLength, fieldName);
    }
}
