using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

/// <summary>
/// Validatore sintattico per coordinate bancarie (IBAN, SWIFT/BIC).
/// Verifica formato e checksum secondo standard internazionali.
/// </summary>
public static class BankingValidator
{
    /// <summary>
    /// Verifica formato IBAN (International Bank Account Number).
    /// Supporta tutti i paesi SEPA con verifica checksum MOD-97.
    /// </summary>
    /// <param name="iban">Codice IBAN da validare</param>
    /// <returns>ValidationResult con esito e messaggio</returns>
    public static ValidationResult CheckIban(string? iban)
    {
        if (string.IsNullOrWhiteSpace(iban))
            return ValidationResult.Failure("L'IBAN non può essere vuoto", "CHK_IBAN_EMPTY");

        // Rimuovi spazi e converti uppercase
        var cleanIban = iban.Replace(" ", "").ToUpper();

        // Lunghezza: min 15, max 34 caratteri
        if (cleanIban.Length < 15 || cleanIban.Length > 34)
        {
            return ValidationResult.Failure(
                "L'IBAN deve essere tra 15 e 34 caratteri",
                "CHK_IBAN_LENGTH");
        }

        // Formato: 2 lettere (paese) + 2 cifre (check) + alfanumerico
        if (!char.IsLetter(cleanIban[0]) || !char.IsLetter(cleanIban[1]))
        {
            return ValidationResult.Failure(
                "L'IBAN deve iniziare con 2 lettere (codice paese)",
                "CHK_IBAN_COUNTRY");
        }

        if (!char.IsDigit(cleanIban[2]) || !char.IsDigit(cleanIban[3]))
        {
            return ValidationResult.Failure(
                "Le posizioni 3-4 dell'IBAN devono essere cifre (check digit)",
                "CHK_IBAN_CHECK_DIGIT");
        }

        // Verifica che contenga solo lettere e cifre
        if (!cleanIban.All(c => char.IsLetterOrDigit(c)))
        {
            return ValidationResult.Failure(
                "L'IBAN può contenere solo lettere e cifre",
                "CHK_IBAN_ALPHANUMERIC");
        }

        // Verifica checksum MOD-97 (algoritmo standard IBAN)
        if (!ValidateIbanChecksum(cleanIban))
        {
            return ValidationResult.Failure(
                "L'IBAN non è valido (checksum non corretto)",
                "CHK_IBAN_CHECKSUM");
        }

        // IBAN Italia: deve essere esattamente 27 caratteri e iniziare con IT
        if (cleanIban.StartsWith("IT") && cleanIban.Length != 27)
        {
            return ValidationResult.Failure(
                "L'IBAN italiano deve essere di 27 caratteri",
                "CHK_IBAN_IT_LENGTH");
        }

        return ValidationResult.Success();
    }

    /// <summary>
    /// Verifica formato SWIFT/BIC (Bank Identifier Code).
    /// Standard ISO 9362: 8 o 11 caratteri alfanumerici.
    /// </summary>
    /// <param name="swift">Codice SWIFT/BIC da validare</param>
    /// <returns>ValidationResult con esito e messaggio</returns>
    public static ValidationResult CheckSwift(string? swift)
    {
        if (string.IsNullOrWhiteSpace(swift))
            return ValidationResult.Success(); // SWIFT è opzionale

        var cleanSwift = swift.Replace(" ", "").ToUpper();

        // Lunghezza: 8 o 11 caratteri
        if (cleanSwift.Length != 8 && cleanSwift.Length != 11)
        {
            return ValidationResult.Failure(
                "Il codice SWIFT/BIC deve essere di 8 o 11 caratteri",
                "CHK_SWIFT_LENGTH");
        }

        // Primi 4 caratteri: Bank Code (lettere)
        if (!cleanSwift.Take(4).All(c => char.IsLetter(c)))
        {
            return ValidationResult.Failure(
                "I primi 4 caratteri del SWIFT devono essere lettere (Bank Code)",
                "CHK_SWIFT_BANK_CODE");
        }

        // Caratteri 5-6: Country Code (lettere)
        if (!cleanSwift.Skip(4).Take(2).All(c => char.IsLetter(c)))
        {
            return ValidationResult.Failure(
                "I caratteri 5-6 del SWIFT devono essere lettere (Country Code)",
                "CHK_SWIFT_COUNTRY");
        }

        // Caratteri 7-8: Location Code (lettere o cifre)
        if (!cleanSwift.Skip(6).Take(2).All(c => char.IsLetterOrDigit(c)))
        {
            return ValidationResult.Failure(
                "I caratteri 7-8 del SWIFT devono essere alfanumerici (Location Code)",
                "CHK_SWIFT_LOCATION");
        }

        // Se 11 caratteri: caratteri 9-11 Branch Code (opzionale, alfanumerico)
        if (cleanSwift.Length == 11)
        {
            if (!cleanSwift.Skip(8).Take(3).All(c => char.IsLetterOrDigit(c)))
            {
                return ValidationResult.Failure(
                    "I caratteri 9-11 del SWIFT devono essere alfanumerici (Branch Code)",
                    "CHK_SWIFT_BRANCH");
            }
        }

        return ValidationResult.Success();
    }

    /// <summary>
    /// Valida il checksum dell'IBAN secondo algoritmo MOD-97 (ISO 13616).
    /// </summary>
    private static bool ValidateIbanChecksum(string iban)
    {
        try
        {
            // Step 1: Sposta i primi 4 caratteri alla fine
            var rearranged = iban.Substring(4) + iban.Substring(0, 4);

            // Step 2: Sostituisci lettere con numeri (A=10, B=11, ..., Z=35)
            var numericString = string.Empty;
            foreach (var c in rearranged)
            {
                if (char.IsDigit(c))
                {
                    numericString += c;
                }
                else if (char.IsLetter(c))
                {
                    // A=10, B=11, ..., Z=35
                    numericString += (c - 'A' + 10).ToString();
                }
            }

            // Step 3: Calcola MOD-97 (numero troppo grande per long, usa algoritmo iterativo)
            var remainder = 0;
            foreach (var digit in numericString)
            {
                remainder = (remainder * 10 + (digit - '0')) % 97;
            }

            // Step 4: Il risultato deve essere 1
            return remainder == 1;
        }
        catch
        {
            return false;
        }
    }
}
