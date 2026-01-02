using GestioneViaggi.Validation.Models;
using System.Text.RegularExpressions;

namespace GestioneViaggi.Validation.Business;

/// <summary>
/// Validatore per i dati del cliente (anagrafica).
/// Implementa le validazioni business-level per i campi del cliente.
///
/// Traduzione C# della logica di validazione Python dal progetto Iscrizione-Viaggi-Offroad.
/// Nota: Le validazioni qui implementate sono quelle NON gestite dal database
/// (NOT NULL, FK, UNIQUE constraints sono gestiti dal DB).
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
    /// Valida il titolo (es. Sig., Dott., ecc.).
    /// </summary>
    /// <param name="titolo">Titolo da validare</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidateTitolo(string? titolo)
    {
        if (string.IsNullOrWhiteSpace(titolo))
        {
            return ValidationResult.Failure("Seleziona un titolo", "titolo_required");
        }

        var trimmedTitolo = titolo.Trim();

        if (trimmedTitolo.Length > 10)
        {
            return ValidationResult.Failure("Il titolo non può superare 10 caratteri", "titolo_too_long");
        }

        return ValidationResult.Success("Titolo valido");
    }

    /// <summary>
    /// Valida il sesso.
    /// </summary>
    /// <param name="sesso">Sesso da validare (M/F)</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidateSesso(char? sesso)
    {
        if (!sesso.HasValue)
        {
            return ValidationResult.Failure("Seleziona il sesso", "sesso_required");
        }

        var sessoUpper = char.ToUpperInvariant(sesso.Value);

        if (sessoUpper != 'M' && sessoUpper != 'F')
        {
            return ValidationResult.Failure("Il sesso deve essere M (Maschio) o F (Femmina)", "sesso_invalid");
        }

        return ValidationResult.Success("Sesso valido");
    }

    /// <summary>
    /// Valida l'indirizzo di residenza.
    /// </summary>
    /// <param name="indirizzo">Indirizzo da validare</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidateIndirizzoResidenza(string? indirizzo)
    {
        if (string.IsNullOrWhiteSpace(indirizzo))
        {
            return ValidationResult.Failure("L'indirizzo di residenza è obbligatorio", "indirizzo_required");
        }

        var trimmedIndirizzo = indirizzo.Trim();

        if (trimmedIndirizzo.Length < 5)
        {
            return ValidationResult.Failure("L'indirizzo deve contenere almeno 5 caratteri", "indirizzo_too_short");
        }

        if (trimmedIndirizzo.Length > 100)
        {
            return ValidationResult.Failure("L'indirizzo non può superare 100 caratteri", "indirizzo_too_long");
        }

        return ValidationResult.Success("Indirizzo valido");
    }

    /// <summary>
    /// Valida la data di nascita.
    /// </summary>
    /// <param name="dataNascita">Data di nascita da validare</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidateDataNascita(DateTime? dataNascita)
    {
        if (!dataNascita.HasValue)
        {
            return ValidationResult.Failure("Inserisci una data di nascita valida", "data_nascita_required");
        }

        var minBirthDate = DateTime.Now.AddYears(-90);
        var maxBirthDate = DateTime.Now.AddDays(-1); // Ieri

        if (dataNascita.Value < minBirthDate)
        {
            return ValidationResult.Failure(
                $"La data di nascita deve essere compresa tra {minBirthDate:dd/MM/yyyy} e {maxBirthDate:dd/MM/yyyy}",
                "data_nascita_too_old"
            );
        }

        if (dataNascita.Value > maxBirthDate)
        {
            return ValidationResult.Failure(
                $"La data di nascita deve essere compresa tra {minBirthDate:dd/MM/yyyy} e {maxBirthDate:dd/MM/yyyy}",
                "data_nascita_future"
            );
        }

        return ValidationResult.Success("Data di nascita valida");
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
    /// Valida il tipo di documento.
    /// </summary>
    /// <param name="tipoDocumento">Tipo documento da validare</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidateTipoDocumento(string? tipoDocumento)
    {
        if (string.IsNullOrWhiteSpace(tipoDocumento))
        {
            return ValidationResult.Failure("Seleziona il tipo di documento", "tipo_documento_required");
        }

        var trimmedTipo = tipoDocumento.Trim();

        if (trimmedTipo.Length > 10)
        {
            return ValidationResult.Failure("Il tipo documento non può superare 10 caratteri", "tipo_documento_too_long");
        }

        return ValidationResult.Success("Tipo documento valido");
    }

    /// <summary>
    /// Valida il numero del documento.
    /// </summary>
    /// <param name="numeroDocumento">Numero documento da validare</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidateNumeroDocumento(string? numeroDocumento)
    {
        if (string.IsNullOrWhiteSpace(numeroDocumento))
        {
            return ValidationResult.Failure("Il numero documento è obbligatorio (min 3 caratteri)", "numero_documento_required");
        }

        var trimmedNumero = numeroDocumento.Trim();

        if (trimmedNumero.Length < 3)
        {
            return ValidationResult.Failure("Il numero documento deve contenere almeno 3 caratteri", "numero_documento_too_short");
        }

        if (trimmedNumero.Length > 50)
        {
            return ValidationResult.Failure("Il numero documento non può superare 50 caratteri", "numero_documento_too_long");
        }

        return ValidationResult.Success("Numero documento valido");
    }

    /// <summary>
    /// Valida l'ente di rilascio del documento.
    /// </summary>
    /// <param name="rilasciatoDa">Ente rilascio da validare</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidateDocumentoRilasciatoDa(string? rilasciatoDa)
    {
        if (string.IsNullOrWhiteSpace(rilasciatoDa))
        {
            return ValidationResult.Failure("Ente rilascio obbligatorio (min 3 caratteri)", "rilasciato_da_required");
        }

        var trimmedRilasciatoDa = rilasciatoDa.Trim();

        if (trimmedRilasciatoDa.Length < 3)
        {
            return ValidationResult.Failure("L'ente di rilascio deve contenere almeno 3 caratteri", "rilasciato_da_too_short");
        }

        if (trimmedRilasciatoDa.Length > 100)
        {
            return ValidationResult.Failure("L'ente di rilascio non può superare 100 caratteri", "rilasciato_da_too_long");
        }

        return ValidationResult.Success("Ente rilascio valido");
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

    /// <summary>
    /// Valida che l'email del passeggero sia diversa dall'email del pilota.
    /// </summary>
    /// <param name="emailPasseggero">Email passeggero</param>
    /// <param name="emailPilota">Email pilota</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidatePassengerEmailDifferentFromPilot(string? emailPasseggero, string? emailPilota)
    {
        if (string.IsNullOrWhiteSpace(emailPasseggero))
        {
            return ValidationResult.Failure("Email passeggero obbligatoria", "email_passeggero_required");
        }

        if (string.IsNullOrWhiteSpace(emailPilota))
        {
            // Non possiamo validare se non abbiamo l'email del pilota
            return ValidationResult.Success("Email pilota non fornita, skip validazione unicità");
        }

        if (string.Equals(emailPasseggero.Trim(), emailPilota.Trim(), StringComparison.OrdinalIgnoreCase))
        {
            return ValidationResult.Failure("L'email del passeggero non può essere uguale a quella del pilota", "email_same_as_pilot");
        }

        return ValidationResult.Success("Email passeggero diversa dal pilota");
    }

    /// <summary>
    /// Valida che l'email del passeggero sia unica tra tutti i passeggeri.
    /// </summary>
    /// <param name="emailPasseggero">Email passeggero da validare</param>
    /// <param name="altreEmailPasseggeri">Lista delle altre email passeggeri già inserite</param>
    /// <returns>ValidationResult con esito validazione</returns>
    public static ValidationResult ValidatePassengerEmailUnique(string? emailPasseggero, IEnumerable<string> altreEmailPasseggeri)
    {
        if (string.IsNullOrWhiteSpace(emailPasseggero))
        {
            return ValidationResult.Failure("Email passeggero obbligatoria", "email_passeggero_required");
        }

        var trimmedEmail = emailPasseggero.Trim();

        foreach (var altraEmail in altreEmailPasseggeri)
        {
            if (string.Equals(trimmedEmail, altraEmail?.Trim(), StringComparison.OrdinalIgnoreCase))
            {
                return ValidationResult.Failure("Questa email è già stata utilizzata per un altro passeggero", "email_passeggero_duplicate");
            }
        }

        return ValidationResult.Success("Email passeggero unica");
    }
}
