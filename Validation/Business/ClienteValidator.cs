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
    /// Valida il cognome.
    /// </summary>
    /// <param name="cognome">Cognome da validare</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidateCognome(string? cognome)
    {
        if (string.IsNullOrWhiteSpace(cognome))
        {
            return ValidationResult.Failure("Il cognome è obbligatorio", "cognome_required");
        }

        var trimmedCognome = cognome.Trim();

        if (trimmedCognome.Length < 2)
        {
            return ValidationResult.Failure("Il cognome deve contenere almeno 2 caratteri", "cognome_too_short");
        }

        if (trimmedCognome.Length > 50)
        {
            return ValidationResult.Failure("Il cognome non può superare 50 caratteri", "cognome_too_long");
        }

        return ValidationResult.Success("Cognome valido");
    }

    /// <summary>
    /// Valida il nome.
    /// </summary>
    /// <param name="nome">Nome da validare</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidateNome(string? nome)
    {
        if (string.IsNullOrWhiteSpace(nome))
        {
            return ValidationResult.Failure("Il nome è obbligatorio", "nome_required");
        }

        var trimmedNome = nome.Trim();

        if (trimmedNome.Length < 2)
        {
            return ValidationResult.Failure("Il nome deve contenere almeno 2 caratteri", "nome_too_short");
        }

        if (trimmedNome.Length > 50)
        {
            return ValidationResult.Failure("Il nome non può superare 50 caratteri", "nome_too_long");
        }

        return ValidationResult.Success("Nome valido");
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
    /// Valida il prefisso telefonico internazionale.
    /// </summary>
    /// <param name="prefisso">Prefisso da validare</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidatePrefissoTelefono(string? prefisso)
    {
        if (string.IsNullOrWhiteSpace(prefisso))
        {
            return ValidationResult.Failure("Seleziona il prefisso internazionale", "prefisso_required");
        }

        var trimmedPrefisso = prefisso.Trim();

        if (trimmedPrefisso.Length > 5)
        {
            return ValidationResult.Failure("Il prefisso non può superare 5 caratteri", "prefisso_too_long");
        }

        return ValidationResult.Success("Prefisso valido");
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

        // Non può essere nel passato
        if (dataScadenza.Value < DateTime.Now.Date)
        {
            return ValidationResult.Failure("Il documento risulta scaduto", "documento_scaduto");
        }

        // Un documento che scade nel 2202 passava: il controllo sopra guarda solo il passato.
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

    /// <summary>
    /// Valida l'IBAN (validazione formato base).
    /// Nota: Implementazione semplificata, per validazione completa usare libreria specializzata.
    /// </summary>
    /// <param name="iban">IBAN da validare</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidateIban(string? iban)
    {
        // IBAN è opzionale
        if (string.IsNullOrWhiteSpace(iban))
        {
            return ValidationResult.Success("IBAN non fornito (opzionale)");
        }

        var trimmedIban = iban.Trim().Replace(" ", "").ToUpperInvariant();

        // Lunghezza minima 15, massima 34 (standard internazionale)
        if (trimmedIban.Length < 15 || trimmedIban.Length > 34)
        {
            return ValidationResult.Failure("Lunghezza IBAN non valida (deve essere tra 15 e 34 caratteri)", "iban_invalid_length");
        }

        // Formato base: prime due lettere (paese), poi numeri e lettere
        if (!char.IsLetter(trimmedIban[0]) || !char.IsLetter(trimmedIban[1]))
        {
            return ValidationResult.Failure("IBAN deve iniziare con due lettere (codice paese)", "iban_invalid_format");
        }

        // Validazione algoritmo MOD-97 per IBAN (implementazione completa opzionale)
        // Per ora: validazione formato base
        if (!Regex.IsMatch(trimmedIban, @"^[A-Z]{2}[0-9A-Z]+$"))
        {
            return ValidationResult.Failure("Formato IBAN non valido", "iban_invalid_format");
        }

        return ValidationResult.Success("IBAN formato valido (validazione completa non implementata)");
    }

}
