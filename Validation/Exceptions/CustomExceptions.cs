namespace GestioneViaggi.Validation.Exceptions;

/// <summary>
/// Eccezione sollevata quando viene violato un constraint di unicità nel database.
/// Equivalente della gestione ORA-00001 (Oracle) o 23505 (PostgreSQL).
/// </summary>
public class UniqueConstraintViolationException : Exception
{
    /// <summary>
    /// Email del cliente esistente che causa la violazione.
    /// </summary>
    public string? ExistingEmail { get; set; }

    /// <summary>
    /// Tipo di constraint violato (es: "codice_fiscale", "composite_unique").
    /// </summary>
    public string? ConstraintType { get; set; }

    /// <summary>
    /// Dati aggiuntivi sulla violazione.
    /// </summary>
    public Dictionary<string, object>? AdditionalData { get; set; }

    public UniqueConstraintViolationException() : base()
    {
    }

    public UniqueConstraintViolationException(string message) : base(message)
    {
    }

    public UniqueConstraintViolationException(string message, Exception innerException)
        : base(message, innerException)
    {
    }

    public UniqueConstraintViolationException(string message, string? existingEmail, string? constraintType = null)
        : base(message)
    {
        ExistingEmail = existingEmail;
        ConstraintType = constraintType;
    }
}

/// <summary>
/// Eccezione sollevata quando si tenta di creare una prenotazione duplicata.
/// </summary>
public class DuplicateBookingException : Exception
{
    /// <summary>
    /// Email del cliente che ha già la prenotazione.
    /// </summary>
    public string? CustomerEmail { get; set; }

    /// <summary>
    /// ID del viaggio per cui esiste già la prenotazione.
    /// </summary>
    public int? ViaggioId { get; set; }

    public DuplicateBookingException() : base()
    {
    }

    public DuplicateBookingException(string message) : base(message)
    {
    }

    public DuplicateBookingException(string message, Exception innerException)
        : base(message, innerException)
    {
    }

    public DuplicateBookingException(string message, string? customerEmail, int? viaggioId = null)
        : base(message)
    {
        CustomerEmail = customerEmail;
        ViaggioId = viaggioId;
    }
}

/// <summary>
/// Eccezione sollevata quando la validazione del codice fiscale fallisce.
/// </summary>
public class CodiceFiscaleValidationException : Exception
{
    /// <summary>
    /// Codice fiscale che ha fallito la validazione.
    /// </summary>
    public string? CodiceFiscale { get; set; }

    /// <summary>
    /// Tipo di errore di validazione (es: "invalid_format", "invalid_check_digit", "date_mismatch").
    /// </summary>
    public string? ValidationErrorType { get; set; }

    public CodiceFiscaleValidationException() : base()
    {
    }

    public CodiceFiscaleValidationException(string message) : base(message)
    {
    }

    public CodiceFiscaleValidationException(string message, Exception innerException)
        : base(message, innerException)
    {
    }

    public CodiceFiscaleValidationException(string message, string? codiceFiscale, string? validationErrorType = null)
        : base(message)
    {
        CodiceFiscale = codiceFiscale;
        ValidationErrorType = validationErrorType;
    }
}

/// <summary>
/// Eccezione sollevata quando si tenta di cancellare un cliente che ha relazioni attive.
/// </summary>
public class ClienteHasRelationsException : Exception
{
    /// <summary>
    /// ID del cliente che si tenta di cancellare.
    /// </summary>
    public int ClienteId { get; set; }

    /// <summary>
    /// Tipo di relazione che impedisce la cancellazione (es: "viaggi", "alloggi").
    /// </summary>
    public string? RelationType { get; set; }

    /// <summary>
    /// Numero di relazioni trovate.
    /// </summary>
    public int RelationCount { get; set; }

    public ClienteHasRelationsException() : base()
    {
    }

    public ClienteHasRelationsException(string message) : base(message)
    {
    }

    public ClienteHasRelationsException(string message, Exception innerException)
        : base(message, innerException)
    {
    }

    public ClienteHasRelationsException(string message, int clienteId, string? relationType, int relationCount)
        : base(message)
    {
        ClienteId = clienteId;
        RelationType = relationType;
        RelationCount = relationCount;
    }
}
