using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Semantic;

/// <summary>
/// Validatore semantico per logica temporale e confronto date.
/// Validazioni context-aware che verificano relazioni tra date.
/// </summary>
public static class DateValidator
{
    /// <summary>
    /// Verifica che la data finale sia successiva o uguale alla data iniziale.
    /// </summary>
    /// <param name="startDate">Data iniziale (es. Costituzione, Partenza)</param>
    /// <param name="endDate">Data finale (es. Inizio Attività, Ritorno)</param>
    /// <param name="startLabel">Etichetta per la data iniziale</param>
    /// <param name="endLabel">Etichetta per la data finale</param>
    /// <returns>ValidationResult con esito e messaggio</returns>
    public static ValidationResult CheckDateRange(
        DateTime? startDate,
        DateTime? endDate,
        string startLabel = "Data iniziale",
        string endLabel = "Data finale")
    {
        // Se una delle due è null, non possiamo fare il confronto semantico di range
        if (!startDate.HasValue || !endDate.HasValue)
            return ValidationResult.Success();

        // Confronto: la data finale deve essere >= data iniziale
        if (endDate.Value.Date < startDate.Value.Date)
        {
            return ValidationResult.Failure(
                $"{endLabel} non può essere precedente a {startLabel}",
                "CHK_DATE_RANGE_001"
            );
        }

        return ValidationResult.Success();
    }

    /// <summary>
    /// Verifica che una data non sia nel futuro.
    /// </summary>
    /// <param name="date">Data da validare</param>
    /// <param name="fieldName">Nome campo (per messaggio errore)</param>
    /// <returns>ValidationResult con esito e messaggio</returns>
    public static ValidationResult CheckNotFuture(DateTime? date, string fieldName = "Data")
    {
        if (!date.HasValue)
            return ValidationResult.Success();

        if (date.Value.Date > DateTime.Today)
        {
            return ValidationResult.Failure(
                $"{fieldName} non può essere futura",
                "CHK_DATE_FUTURE_001"
            );
        }

        return ValidationResult.Success();
    }

    /// <summary>
    /// Verifica che una data non sia nel passato.
    /// </summary>
    /// <param name="date">Data da validare</param>
    /// <param name="fieldName">Nome campo (per messaggio errore)</param>
    /// <returns>ValidationResult con esito e messaggio</returns>
    public static ValidationResult CheckNotPast(DateTime? date, string fieldName = "Data")
    {
        if (!date.HasValue)
            return ValidationResult.Success();

        if (date.Value.Date < DateTime.Today)
        {
            return ValidationResult.Failure(
                $"{fieldName} non può essere passata",
                "CHK_DATE_PAST_001"
            );
        }

        return ValidationResult.Success();
    }

    /// <summary>
    /// Verifica che la data cada in un range specifico.
    /// </summary>
    /// <param name="date">Data da validare</param>
    /// <param name="minDate">Data minima consentita</param>
    /// <param name="maxDate">Data massima consentita</param>
    /// <param name="fieldName">Nome campo (per messaggio errore)</param>
    /// <returns>ValidationResult con esito e messaggio</returns>
    public static ValidationResult CheckDateBetween(
        DateTime? date,
        DateTime minDate,
        DateTime maxDate,
        string fieldName = "Data")
    {
        if (!date.HasValue)
            return ValidationResult.Success();

        if (date.Value < minDate || date.Value > maxDate)
        {
            return ValidationResult.Failure(
                $"{fieldName} deve essere compresa tra {minDate:dd/MM/yyyy} e {maxDate:dd/MM/yyyy}",
                "CHK_DATE_BETWEEN_001"
            );
        }

        return ValidationResult.Success();
    }

    /// <summary>
    /// Verifica che l'età calcolata dalla data di nascita sia maggiore o uguale al minimo.
    /// </summary>
    /// <param name="birthDate">Data di nascita</param>
    /// <param name="minAge">Età minima richiesta</param>
    /// <param name="referenceDate">Data di riferimento (default oggi)</param>
    /// <returns>ValidationResult con esito e messaggio</returns>
    public static ValidationResult CheckMinimumAge(
        DateTime? birthDate,
        int minAge,
        DateTime? referenceDate = null)
    {
        if (!birthDate.HasValue)
            return ValidationResult.Success();

        var reference = referenceDate ?? DateTime.Today;
        var age = reference.Year - birthDate.Value.Year;

        // Aggiusta per compleanno non ancora compiuto nell'anno corrente
        if (reference.Month < birthDate.Value.Month ||
            (reference.Month == birthDate.Value.Month && reference.Day < birthDate.Value.Day))
        {
            age--;
        }

        if (age < minAge)
        {
            return ValidationResult.Failure(
                $"L'età deve essere almeno di {minAge} anni",
                "CHK_DATE_AGE_001"
            );
        }

        return ValidationResult.Success();
    }
}
