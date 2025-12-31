using System.Text.RegularExpressions;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

/// <summary>
/// Validatore per server SMTP
/// </summary>
public static partial class SmtpServerValidator
{
    // Pattern per hostname valido (RFC 1123) - senza underscore
    // Ogni label: inizia/finisce con alfanumerico, può contenere trattini al centro
    [GeneratedRegex(@"^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[a-zA-Z0-9])$", RegexOptions.Compiled)]
    private static partial Regex HostnameRegex();

    // Pattern per IPv6
    [GeneratedRegex(@"^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:))$", RegexOptions.Compiled)]
    private static partial Regex IPv6Regex();

    /// <summary>
    /// Valida un hostname di server SMTP
    /// </summary>
    /// <param name="host">Hostname o indirizzo IP del server SMTP</param>
    /// <returns>Risultato della validazione</returns>
    public static ValidationResult CheckSmtpHost(string? host)
    {
        if (string.IsNullOrWhiteSpace(host))
            return ValidationResult.Failure(ValidationMessages.SmtpHostRequired, "CHK_SMTP_001");

        // 1. Pulizia: rimuovi spazi iniziali e finali
        var trimmed = host.Trim();

        // 2. Errore comune: Email invece di Host
        if (trimmed.Contains('@'))
            return ValidationResult.Failure("Inserisci il nome del server SMTP, non un indirizzo email", "CHK_SMTP_002");

        // 3. Errore comune: Protocollo incluso
        if (trimmed.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
            trimmed.StartsWith("https://", StringComparison.OrdinalIgnoreCase) ||
            trimmed.StartsWith("smtp://", StringComparison.OrdinalIgnoreCase) ||
            trimmed.StartsWith("smtps://", StringComparison.OrdinalIgnoreCase) ||
            trimmed.Contains("://"))
            return ValidationResult.Failure("Non inserire protocolli (http://, smtp://, ecc.). Inserisci solo il nome del server", "CHK_SMTP_003");

        // 4. Gestione porta inclusa nell'host (verrà gestita separatamente)
        // Attenzione: IPv6 contiene ":" quindi dobbiamo controllare prima se è IPv6
        if (trimmed.Contains(':') && !trimmed.StartsWith('['))
        {
            // Verifica se potrebbe essere IPv6 (più di un ":")
            var colonCount = trimmed.Count(c => c == ':');
            if (colonCount == 1)
                return ValidationResult.Failure("La porta va specificata nell'apposito campo, non nel nome del server", "CHK_SMTP_004");
            // Se ha più di un ":", potrebbe essere IPv6, lascia proseguire la validazione
        }

        // 5. Controllo lunghezza massima (RFC 1035: max 255 caratteri)
        if (trimmed.Length > 255)
            return ValidationResult.Failure(ValidationMessages.SmtpHostTooLong, "CHK_SMTP_005");

        // 6. Gestione IP Literal tra parentesi quadre [192.168.1.1] o [2001:db8::1]
        if (trimmed.StartsWith('[') && trimmed.EndsWith(']'))
        {
            var ipContent = trimmed.Substring(1, trimmed.Length - 2);
            if (IsValidIpAddress(ipContent) || IsValidIPv6Address(ipContent))
                return ValidationResult.Success();
            return ValidationResult.Failure("IP literal non valido tra parentesi quadre", "CHK_SMTP_006");
        }

        // 7. Verifica se è un indirizzo IPv4 valido
        if (IsValidIpAddress(trimmed))
            return ValidationResult.Success();

        // 8. Verifica se è un indirizzo IPv6 valido
        if (IsValidIPv6Address(trimmed))
            return ValidationResult.Success();

        // 9. Controllo caratteri non ammessi (solo lettere, numeri, punti e trattini)
        if (!trimmed.All(c => char.IsLetterOrDigit(c) || c == '.' || c == '-'))
            return ValidationResult.Failure("Il nome del server può contenere solo lettere, numeri, punti e trattini", "CHK_SMTP_007");

        // 10. Non può iniziare o finire con punto o trattino
        if (trimmed.StartsWith('.') || trimmed.EndsWith('.') ||
            trimmed.StartsWith('-') || trimmed.EndsWith('-'))
            return ValidationResult.Failure("Il nome del server non può iniziare o finire con punto o trattino", "CHK_SMTP_008");

        // 11. Non possono esserci punti consecutivi
        if (trimmed.Contains(".."))
            return ValidationResult.Failure("Il nome del server non può contenere punti consecutivi", "CHK_SMTP_009");

        // 12. Deve contenere almeno un punto (FQDN richiesto, non hostname locale)
        if (!trimmed.Contains('.'))
            return ValidationResult.Failure("Inserisci un nome dominio completo (es: smtp.gmail.com) o un indirizzo IP", "CHK_SMTP_010");

        // 13. Verifica ogni label (parte tra i punti)
        var labels = trimmed.Split('.');
        foreach (var label in labels)
        {
            // Ogni label non può superare 63 caratteri
            if (label.Length > 63)
                return ValidationResult.Failure("Ogni parte del nome dominio non può superare 63 caratteri", "CHK_SMTP_011");

            // Ogni label deve contenere almeno un carattere
            if (label.Length == 0)
                return ValidationResult.Failure("Nome dominio non valido (label vuota)", "CHK_SMTP_012");
        }

        // 14. Il TLD (ultima parte) non deve essere puramente numerico
        var tld = labels[labels.Length - 1];
        if (tld.All(char.IsDigit))
            return ValidationResult.Failure("Il TLD (ultima parte) non può essere composto solo da numeri", "CHK_SMTP_013");

        // 15. Verifica con regex finale per hostname valido (RFC 1123)
        if (!HostnameRegex().IsMatch(trimmed))
            return ValidationResult.Failure(ValidationMessages.SmtpHostInvalid, "CHK_SMTP_014");

        // 16. Avviso per localhost (warning, ma accettato per testing)
        if (trimmed.Equals("localhost", StringComparison.OrdinalIgnoreCase) ||
            trimmed.Equals("127.0.0.1") ||
            trimmed.Equals("::1"))
        {
            // Per ora accettiamo localhost per scopi di test, ma potremmo volerlo bloccare
            return ValidationResult.Success();
        }

        return ValidationResult.Success();
    }

    /// <summary>
    /// Valida una porta SMTP
    /// </summary>
    /// <param name="port">Numero di porta</param>
    /// <returns>Risultato della validazione</returns>
    public static ValidationResult CheckSmtpPort(int port)
    {
        if (port < 1 || port > 65535)
            return ValidationResult.Failure(ValidationMessages.SmtpPortInvalid, "CHK_SMTP_006");

        // Porta valida
        return ValidationResult.Success();
    }

    /// <summary>
    /// Valida un username SMTP
    /// </summary>
    /// <param name="username">Username per autenticazione</param>
    /// <returns>Risultato della validazione</returns>
    public static ValidationResult CheckSmtpUsername(string? username)
    {
        if (string.IsNullOrWhiteSpace(username))
            return ValidationResult.Failure(ValidationMessages.SmtpUsernameRequired, "CHK_SMTP_007");

        var trimmed = username.Trim();

        if (trimmed.Length > 255)
            return ValidationResult.Failure(ValidationMessages.SmtpUsernameTooLong, "CHK_SMTP_008");

        return ValidationResult.Success();
    }

    /// <summary>
    /// Valida una password SMTP
    /// </summary>
    /// <param name="password">Password per autenticazione</param>
    /// <returns>Risultato della validazione</returns>
    public static ValidationResult CheckSmtpPassword(string? password)
    {
        if (string.IsNullOrWhiteSpace(password))
            return ValidationResult.Failure(ValidationMessages.SmtpPasswordRequired, "CHK_SMTP_009");

        // Lunghezza minima password
        if (password.Length < 3)
            return ValidationResult.Failure(ValidationMessages.SmtpPasswordTooShort, "CHK_SMTP_010");

        return ValidationResult.Success();
    }

    /// <summary>
    /// Verifica se una stringa è un indirizzo IPv4 valido
    /// </summary>
    private static bool IsValidIpAddress(string input)
    {
        var parts = input.Split('.');
        if (parts.Length != 4)
            return false;

        foreach (var part in parts)
        {
            if (!int.TryParse(part, out int octet) || octet < 0 || octet > 255)
                return false;

            // Non permette zeri leading (es: 192.168.001.1 non è valido)
            if (part.Length > 1 && part.StartsWith("0"))
                return false;
        }

        return true;
    }

    /// <summary>
    /// Verifica se una stringa è un indirizzo IPv6 valido
    /// </summary>
    private static bool IsValidIPv6Address(string input)
    {
        // Usa la regex per IPv6
        return IPv6Regex().IsMatch(input);
    }
}
