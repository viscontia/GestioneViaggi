using GestioneViaggi.Validation.Models;
using System.Text.RegularExpressions;

namespace GestioneViaggi.Validation.Business;

/// <summary>
/// Controlli di <b>forma</b> sui campi del cliente, usati per dare l'errore mentre si
/// digita. Non sono la sede delle regole: quella è il database
/// (<c>fn_ana_clienti_valida</c> e i vincoli), che vale per chiunque scriva — gestionale,
/// sito di iscrizione, o una query fatta a mano. Qui si <b>anticipa</b>, non si decide.
///
/// <para>Nell'agosto 2026 sono stati eliminati nove metodi che <b>nessuno chiamava</b>.
/// Quattro erano superati (titolo e sesso ora vengono dalla lookup, e il sesso lo impone
/// un trigger). Due dichiaravano l'esatto contrario di ciò che i dati dicono: vietavano al
/// passeggero di avere l'email del pilota, mentre condividere la casella è prassi normale
/// fra coniugi — collegarli avrebbe vietato il caso reale. Gli altri tre pretendevano tipo,
/// numero ed ente di rilascio del documento: misurato su produzione, avrebbero dichiarato
/// impossibili <b>572 clienti su 777</b>. Un obbligo mai applicato non si "ricollega": se lo
/// si vuole davvero, è una decisione, e la sua sede è il database.</para>
/// </summary>
public static class ClienteValidator
{
    // Regex per validazione email (formato base, compatibile con frontend)
    private static readonly Regex EmailPattern = new(
        @"^[^\s@]+@[^\s@]+\.[^\s@]+$",
        RegexOptions.Compiled | RegexOptions.IgnoreCase
    );

    // Regex per validazione telefono (numeri, spazi, +, parentesi, trattini)
    private static readonly Regex TelefonoPattern = new(
        @"^[0-9\s+()-]*$",
        RegexOptions.Compiled
    );

    /// <summary>
    /// Valida il formato dell'email.
    /// </summary>
    /// <param name="email">Email da validare</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidateEmail(string? email)
    {
        if (string.IsNullOrWhiteSpace(email))
        {
            return ValidationResult.Failure("L'email è obbligatoria", "email_required");
        }

        var trimmedEmail = email.Trim();

        if (trimmedEmail.Length > 100)
        {
            return ValidationResult.Failure("L'email non può superare 100 caratteri", "email_too_long");
        }

        if (!EmailPattern.IsMatch(trimmedEmail))
        {
            return ValidationResult.Failure("Formato email non valido", "email_invalid_format");
        }

        return ValidationResult.Success("Email valida");
    }

    /// <summary>
    /// Valida il numero di telefono.
    /// </summary>
    /// <param name="telefono">Telefono da validare</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidateTelefono(string? telefono)
    {
        if (string.IsNullOrWhiteSpace(telefono))
        {
            return ValidationResult.Failure("Il telefono è obbligatorio", "telefono_required");
        }

        var trimmedTelefono = telefono.Trim();

        if (!TelefonoPattern.IsMatch(trimmedTelefono))
        {
            return ValidationResult.Failure("Il telefono non è valido (sono ammessi solo numeri, spazi, +, (), -)", "telefono_invalid_format");
        }

        if (trimmedTelefono.Length > 15)
        {
            return ValidationResult.Failure("Il telefono non può superare 15 caratteri", "telefono_too_long");
        }

        return ValidationResult.Success("Telefono valido");
    }

    /// <summary>
    /// Valida la data di rilascio del documento (con validazioni cross-field).
    /// </summary>
    /// <param name="dataRilascio">Data rilascio da validare</param>
    /// <param name="dataScadenza">Data scadenza (opzionale, per validazione incrociata)</param>
    /// <param name="dataNascita">Data nascita (opzionale, per validazione incrociata)</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidateDocumentoDataRilascio(
        DateTime? dataRilascio,
        DateTime? dataScadenza = null,
        DateTime? dataNascita = null)
    {
        if (!dataRilascio.HasValue)
        {
            return ValidationResult.Failure("La data di rilascio è obbligatoria", "data_rilascio_required");
        }

        // Non può essere troppo nel futuro (max oggi + 1 giorno per tolleranza)
        if (dataRilascio.Value > DateTime.Now.AddDays(1))
        {
            return ValidationResult.Failure("La data di rilascio non può essere nel futuro", "data_rilascio_future");
        }

        // Pavimento assoluto: senza, un anno assurdo nel passato passava ogni volta che la data di
        // nascita non era compilata (l'unico controllo che lo intercettava era il confronto con quella).
        var annoRilascio = Semantic.DateValidator.CheckAnnoPlausibile(
            dataRilascio, "La data di rilascio", Semantic.DateValidator.AnnoMinimoStorico);
        if (!annoRilascio.IsValid)
        {
            return ValidationResult.Failure(annoRilascio.ErrorMessage, "data_rilascio_anno");
        }

        // Deve essere successiva alla data di nascita
        if (dataNascita.HasValue && dataRilascio.Value <= dataNascita.Value)
        {
            return ValidationResult.Failure("La data di rilascio deve essere successiva alla data di nascita", "data_rilascio_before_birth");
        }

        // Deve essere precedente alla data di scadenza
        if (dataScadenza.HasValue && dataRilascio.Value >= dataScadenza.Value)
        {
            return ValidationResult.Failure("La data di rilascio non può essere successiva alla data di scadenza", "data_rilascio_after_scadenza");
        }

        return ValidationResult.Success("Data rilascio valida");
    }

    /// <summary>
    /// Valida la data di scadenza del documento (con validazioni cross-field).
    /// </summary>
    /// <param name="dataScadenza">Data scadenza da validare</param>
    /// <param name="dataRilascio">Data rilascio (opzionale, per validazione incrociata)</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidateDocumentoDataScadenza(
        DateTime? dataScadenza,
        DateTime? dataRilascio = null)
    {
        if (!dataScadenza.HasValue)
        {
            return ValidationResult.Failure("La data di scadenza è obbligatoria", "data_scadenza_required");
        }

        // Il documento scaduto NON si rifiuta: e' un AVVISO, e lo emette
        // fn_ana_clienti_valida (DOCUMENTO_SCADUTO) per gestionale e sito insieme.
        // Qui c'era la copia che lo trasformava in divieto.

        // Un documento che scade nel 2202 non e' scaduto, ma non e' nemmeno una data.
        var annoScadenza = Semantic.DateValidator.CheckAnnoPlausibile(
            dataScadenza, "La data di scadenza", Semantic.DateValidator.AnnoMinimoStorico);
        if (!annoScadenza.IsValid)
        {
            return ValidationResult.Failure(annoScadenza.ErrorMessage, "data_scadenza_anno");
        }

        // Deve essere successiva alla data di rilascio
        if (dataRilascio.HasValue && dataScadenza.Value <= dataRilascio.Value)
        {
            return ValidationResult.Failure("La data di scadenza deve essere successiva alla data di rilascio", "data_scadenza_before_rilascio");
        }

        return ValidationResult.Success("Data scadenza valida");
    }

}
