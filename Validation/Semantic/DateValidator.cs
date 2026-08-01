using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Semantic;

/// <summary>
/// Validatore semantico per logica temporale e confronto date.
/// Validazioni context-aware che verificano relazioni tra date.
/// </summary>
public static class DateValidator
{
    /// <summary>Primo anno ammesso per una data operativa. Non è una regola commerciale: è un pavimento di plausibilità.</summary>
    public const int AnnoMinimo = 2000;
    /// <summary>Ultimo anno ammesso.</summary>
    public const int AnnoMassimo = 2100;
    /// <summary>Oltre questi anni nel futuro la data è insolita e va confermata (non vietata).</summary>
    public const int AnniAvantiSenzaConferma = 5;

    /// <summary>
    /// Anni indietro che in contabilità sono lavoro ordinario e non vanno confermati: a inizio anno si
    /// chiude legittimamente l'esercizio precedente. Sui viaggi invece si usa 0 (conferma sempre), perché
    /// una partenza non si programma nell'anno scorso.
    /// </summary>
    public const int AnniIndietroContabilita = 1;

    public static DateTime DataMinima => new(AnnoMinimo, 1, 1);
    public static DateTime DataMassima => new(AnnoMassimo, 12, 31);

    /// <summary>
    /// L'anno è plausibile? Controllo ASSOLUTO, che mancava del tutto: tutte le altre verifiche sulle
    /// date sono relative (fine dopo inizio, durata da anagrafica) e restano soddisfatte anche con un
    /// anno assurdo, perché un refuso sposta entrambe le date insieme.
    /// </summary>
    public static ValidationResult CheckAnnoPlausibile(DateTime? date, string fieldName = "Data")
    {
        if (!date.HasValue) return ValidationResult.Success();

        if (date.Value.Year < AnnoMinimo || date.Value.Year > AnnoMassimo)
        {
            return ValidationResult.Failure(
                $"{fieldName}: " + string.Format(ValidationMessages.AnnoNonPlausibile, AnnoMinimo, AnnoMassimo),
                "CHK_DATE_ANNO_001");
        }

        return ValidationResult.Success();
    }

    /// <summary>
    /// Motivo per cui la data è insolita e merita una conferma esplicita, oppure null se è ordinaria.
    /// Non blocca: serve a intercettare i refusi che restano dentro l'intervallo plausibile, dove un
    /// limite largo non arriva (2027 al posto di 2026 sarebbe accettato da qualunque range).
    /// </summary>
    /// <param name="anniIndietroAmmessi">
    /// Quanti anni indietro sono lavoro ordinario e non vanno confermati. <b>0</b> (default) per i viaggi:
    /// una partenza non si programma nell'anno scorso, quindi si chiede conferma sempre. <b>1</b> per la
    /// contabilità, dove a inizio anno si lavora legittimamente sull'esercizio precedente.
    /// </param>
    public static string? MotivoDaConfermare(DateTime? date, DateTime? oggi = null, int anniIndietroAmmessi = 0)
    {
        if (!date.HasValue) return null;

        var riferimento = (oggi ?? DateTime.Today).Date;

        if (date.Value.Year < riferimento.Year - anniIndietroAmmessi)
            return string.Format(ValidationMessages.DataAnnoPassato, date.Value.Year);

        if (date.Value.Date > riferimento.AddYears(AnniAvantiSenzaConferma))
            return string.Format(ValidationMessages.DataTroppoLontana, AnniAvantiSenzaConferma);

        return null;
    }

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
