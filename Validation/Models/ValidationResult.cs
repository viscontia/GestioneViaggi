namespace GestioneViaggi.Validation.Models;

/// <summary>
/// Rappresenta il risultato di una validazione.
/// Modello generico riutilizzabile per tutte le operazioni di validazione.
/// </summary>
public class ValidationResult
{
    /// <summary>
    /// Indica se la validazione è riuscita.
    /// </summary>
    public bool IsValid { get; set; }

    /// <summary>
    /// Messaggio descrittivo del risultato della validazione.
    /// In caso di errore, contiene la descrizione del problema.
    /// </summary>
    public string Message { get; set; } = string.Empty;

    /// <summary>
    /// Tipo di errore (opzionale, per categorizzazione).
    /// Es: "duplicate_cf", "invalid_format", "unique_constraint_violation"
    /// </summary>
    public string? ErrorType { get; set; }

    /// <summary>
    /// Dati aggiuntivi contestuali (opzionale).
    /// Es: email del cliente duplicato, valore atteso vs fornito, ecc.
    /// </summary>
    public Dictionary<string, object>? AdditionalData { get; set; }

    /// <summary>
    /// Crea un risultato di validazione con successo.
    /// </summary>
    /// <param name="message">Messaggio di successo (opzionale)</param>
    /// <returns>ValidationResult con IsValid = true</returns>
    public static ValidationResult Success(string message = "Validazione completata con successo")
    {
        return new ValidationResult
        {
            IsValid = true,
            Message = message
        };
    }

    /// <summary>
    /// Crea un risultato di validazione con errore.
    /// </summary>
    /// <param name="message">Messaggio di errore</param>
    /// <param name="errorType">Tipo di errore (opzionale)</param>
    /// <param name="additionalData">Dati aggiuntivi (opzionale)</param>
    /// <returns>ValidationResult con IsValid = false</returns>
    public static ValidationResult Failure(string message, string? errorType = null, Dictionary<string, object>? additionalData = null)
    {
        return new ValidationResult
        {
            IsValid = false,
            Message = message,
            ErrorType = errorType,
            AdditionalData = additionalData
        };
    }
}

/// <summary>
/// Risultato di validazione generico con dato tipizzato.
/// Utile quando la validazione restituisce anche un valore.
/// </summary>
/// <typeparam name="T">Tipo di dato restituito</typeparam>
public class ValidationResult<T> : ValidationResult
{
    /// <summary>
    /// Dato restituito dalla validazione (se presente).
    /// </summary>
    public T? Data { get; set; }

    /// <summary>
    /// Crea un risultato di validazione con successo e dato.
    /// </summary>
    /// <param name="data">Dato da restituire</param>
    /// <param name="message">Messaggio di successo (opzionale)</param>
    /// <returns>ValidationResult&lt;T&gt; con IsValid = true e dato</returns>
    public static ValidationResult<T> SuccessWithData(T data, string message = "Validazione completata con successo")
    {
        return new ValidationResult<T>
        {
            IsValid = true,
            Message = message,
            Data = data
        };
    }

    /// <summary>
    /// Crea un risultato di validazione con errore (senza dato).
    /// </summary>
    /// <param name="message">Messaggio di errore</param>
    /// <param name="errorType">Tipo di errore (opzionale)</param>
    /// <param name="additionalData">Dati aggiuntivi (opzionale)</param>
    /// <returns>ValidationResult&lt;T&gt; con IsValid = false</returns>
    public static new ValidationResult<T> Failure(string message, string? errorType = null, Dictionary<string, object>? additionalData = null)
    {
        return new ValidationResult<T>
        {
            IsValid = false,
            Message = message,
            ErrorType = errorType,
            AdditionalData = additionalData
        };
    }
}
