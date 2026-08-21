using GestioneViaggi.Validation.Models;
using System.Text.RegularExpressions;

namespace GestioneViaggi.Validation.Fiscal;

/// <summary>
/// Controllo di <b>forma</b> del codice fiscale italiano: lunghezza, alfabeto ammesso,
/// carattere di controllo, plausibilità dei componenti della data — omocodia inclusa,
/// perché senza decodificarla il carattere di controllo risulterebbe sbagliato.
///
/// <para><b>Qui non si calcola più il codice atteso.</b> Il confronto con l'anagrafica
/// (e il riconoscimento di cognome e nome invertiti) vive nel database:
/// <c>fn_cf_calcola</c>, <c>fn_cf_verifica</c>, <c>fn_cf_verifica_cliente</c>. È lì che
/// stanno i codici catastali dei comuni, ed è lì che lo raggiunge anche il sito di
/// iscrizione — che prima ne aveva una propria copia in Python.</para>
///
/// <para>Quello che resta serve a una cosa sola: dire subito, mentre si digita, che
/// quella stringa non può essere un codice fiscale. Non sostituisce la verifica a
/// valle, la anticipa.</para>
/// </summary>
public static partial class CodiceFiscaleValidator
{
    // Pattern regex per validazione formato base
    [GeneratedRegex(@"^[A-Z]{6}[0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{3}[A-Z]$")]
    private static partial Regex CodiceFiscalePattern();

    // Lettere ammesse per omocodia (sostituti cifre 0-9)
    private static readonly char[] OmocodiaLetters = ['L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'U', 'V'];

    // Mapping cifra → lettera omocodia
    private static readonly Dictionary<char, char> DigitToOmocodiaMap = new()
    {
        { '0', 'L' }, { '1', 'M' }, { '2', 'N' }, { '3', 'P' }, { '4', 'Q' },
        { '5', 'R' }, { '6', 'S' }, { '7', 'T' }, { '8', 'U' }, { '9', 'V' }
    };

    // Mapping inverso lettera omocodia → cifra
    private static readonly Dictionary<char, char> OmocodiaToDigitMap = new()
    {
        { 'L', '0' }, { 'M', '1' }, { 'N', '2' }, { 'P', '3' }, { 'Q', '4' },
        { 'R', '5' }, { 'S', '6' }, { 'T', '7' }, { 'U', '8' }, { 'V', '9' }
    };

    // Tabella conversione caratteri per posizioni DISPARI (odd) nel check digit
    private static readonly Dictionary<char, int> OddPositionValues = new()
    {
        // Lettere
        { 'A', 1 }, { 'B', 0 }, { 'C', 5 }, { 'D', 7 }, { 'E', 9 }, { 'F', 13 }, { 'G', 15 },
        { 'H', 17 }, { 'I', 19 }, { 'J', 21 }, { 'K', 2 }, { 'L', 4 }, { 'M', 18 }, { 'N', 20 },
        { 'O', 11 }, { 'P', 3 }, { 'Q', 6 }, { 'R', 8 }, { 'S', 12 }, { 'T', 14 }, { 'U', 16 },
        { 'V', 10 }, { 'W', 22 }, { 'X', 25 }, { 'Y', 24 }, { 'Z', 23 },
        // Cifre
        { '0', 1 }, { '1', 0 }, { '2', 5 }, { '3', 7 }, { '4', 9 }, { '5', 13 }, { '6', 15 },
        { '7', 17 }, { '8', 19 }, { '9', 21 }
    };

    // Tabella conversione caratteri per posizioni PARI (even) nel check digit
    private static readonly Dictionary<char, int> EvenPositionValues = new()
    {
        // Lettere
        { 'A', 0 }, { 'B', 1 }, { 'C', 2 }, { 'D', 3 }, { 'E', 4 }, { 'F', 5 }, { 'G', 6 },
        { 'H', 7 }, { 'I', 8 }, { 'J', 9 }, { 'K', 10 }, { 'L', 11 }, { 'M', 12 }, { 'N', 13 },
        { 'O', 14 }, { 'P', 15 }, { 'Q', 16 }, { 'R', 17 }, { 'S', 18 }, { 'T', 19 }, { 'U', 20 },
        { 'V', 21 }, { 'W', 22 }, { 'X', 23 }, { 'Y', 24 }, { 'Z', 25 },
        // Cifre
        { '0', 0 }, { '1', 1 }, { '2', 2 }, { '3', 3 }, { '4', 4 }, { '5', 5 }, { '6', 6 },
        { '7', 7 }, { '8', 8 }, { '9', 9 }
    };

    // Mapping codice mese (posizione 9 del CF)
    private static readonly Dictionary<int, char> MonthCodeMap = new()
    {
        { 1, 'A' }, { 2, 'B' }, { 3, 'C' }, { 4, 'D' }, { 5, 'E' }, { 6, 'H' },
        { 7, 'L' }, { 8, 'M' }, { 9, 'P' }, { 10, 'R' }, { 11, 'S' }, { 12, 'T' }
    };

    // Mapping inverso codice mese → numero mese
    private static readonly Dictionary<char, int> MonthCodeToNumberMap = new()
    {
        { 'A', 1 }, { 'B', 2 }, { 'C', 3 }, { 'D', 4 }, { 'E', 5 }, { 'H', 6 },
        { 'L', 7 }, { 'M', 8 }, { 'P', 9 }, { 'R', 10 }, { 'S', 11 }, { 'T', 12 }
    };

    // Posizioni sostituibili per omocodia (0-indexed)
    private static readonly int[] OmocodiaPositions = [6, 7, 9, 10, 12, 13, 14];

    /// <summary>
    /// Valida il formato e la correttezza di un codice fiscale italiano.
    /// Esegue validazione multi-fase: formato, check digit, componenti data.
    /// </summary>
    /// <param name="codiceFiscale">Codice fiscale da validare</param>
    /// <returns>ValidationResult con esito e messaggio</returns>
    public static ValidationResult ValidateCodiceFiscale(string codiceFiscale)
    {
        // Normalizzazione: trim e uppercase
        codiceFiscale = codiceFiscale?.Trim().ToUpperInvariant() ?? string.Empty;

        // Fase 1: Validazione formato base
        if (string.IsNullOrWhiteSpace(codiceFiscale))
        {
            return ValidationResult.Failure("Il codice fiscale è obbligatorio", "empty");
        }

        if (codiceFiscale.Length != 16)
        {
            return ValidationResult.Failure($"Il codice fiscale deve essere di 16 caratteri (forniti: {codiceFiscale.Length})", "invalid_length");
        }

        if (!CodiceFiscalePattern().IsMatch(codiceFiscale))
        {
            return ValidationResult.Failure("Formato codice fiscale non valido", "invalid_format");
        }

        // Fase 2: Validazione check digit
        var checkDigitResult = ValidateCheckDigit(codiceFiscale);
        if (!checkDigitResult.IsValid)
        {
            return checkDigitResult;
        }

        // Fase 3: Validazione componenti data
        var dateComponentsResult = ValidateDateComponents(codiceFiscale);
        if (!dateComponentsResult.IsValid)
        {
            return dateComponentsResult;
        }

        return ValidationResult.Success("Codice fiscale formalmente valido");
    }

    /// <summary>
    /// Valida il check digit (carattere di controllo, 16° carattere).
    /// </summary>
    private static ValidationResult ValidateCheckDigit(string codiceFiscale)
    {
        try
        {
            var calculatedCheckDigit = CalculateCheckDigit(codiceFiscale[..15]);
            var providedCheckDigit = codiceFiscale[15];

            if (calculatedCheckDigit != providedCheckDigit)
            {
                return ValidationResult.Failure(
                    $"Check digit non valido (atteso: {calculatedCheckDigit}, fornito: {providedCheckDigit})",
                    "invalid_check_digit"
                );
            }

            return ValidationResult.Success();
        }
        catch (Exception ex)
        {
            return ValidationResult.Failure($"Errore nel calcolo check digit: {ex.Message}", "check_digit_error");
        }
    }

    /// <summary>
    /// Calcola il check digit per i primi 15 caratteri del codice fiscale.
    /// </summary>
    private static char CalculateCheckDigit(string first15Chars)
    {
        var sum = 0;

        for (int i = 0; i < 15; i++)
        {
            var c = first15Chars[i];
            // Posizioni dispari (0-indexed): 0, 2, 4, 6, 8, 10, 12, 14
            // Posizioni pari (0-indexed): 1, 3, 5, 7, 9, 11, 13
            if (i % 2 == 0)
            {
                // Posizione dispari (in termini umani: 1°, 3°, 5°...)
                sum += OddPositionValues[c];
            }
            else
            {
                // Posizione pari (in termini umani: 2°, 4°, 6°...)
                sum += EvenPositionValues[c];
            }
        }

        var remainder = sum % 26;
        return (char)('A' + remainder);
    }

    /// <summary>
    /// Valida i componenti data (mese, giorno, anno) nel codice fiscale.
    /// </summary>
    private static ValidationResult ValidateDateComponents(string codiceFiscale)
    {
        try
        {
            // Estrazione e validazione mese (posizione 8, 0-indexed)
            var monthChar = codiceFiscale[8];
            if (!MonthCodeToNumberMap.TryGetValue(monthChar, out var month))
            {
                return ValidationResult.Failure($"Codice mese non valido: {monthChar}", "invalid_month_code");
            }

            // Estrazione giorno e sesso (posizioni 9-10, 0-indexed)
            var dayString = codiceFiscale.Substring(9, 2);
            // Decodifica omocodia se presente
            dayString = DecodeOmocodiaString(dayString);

            if (!int.TryParse(dayString, out var dayValue))
            {
                return ValidationResult.Failure($"Valore giorno non valido: {dayString}", "invalid_day_value");
            }

            int day;
            if (dayValue >= 1 && dayValue <= 31)
            {
                day = dayValue;
            }
            else if (dayValue >= 41 && dayValue <= 71)
            {
                day = dayValue - 40;
            }
            else
            {
                return ValidationResult.Failure($"Valore giorno fuori range: {dayValue} (deve essere 1-31 per maschi o 41-71 per femmine)", "day_out_of_range");
            }

            // Estrazione anno (posizioni 6-7, 0-indexed)
            var yearString = codiceFiscale.Substring(6, 2);
            // Decodifica omocodia se presente
            yearString = DecodeOmocodiaString(yearString);

            if (!int.TryParse(yearString, out var yearTwoDigits))
            {
                return ValidationResult.Failure($"Valore anno non valido: {yearString}", "invalid_year_value");
            }

            // Disambiguazione anno (regola: YY <= anno corrente → 20YY, altrimenti 19YY)
            var currentYear = DateTime.Now.Year;
            var currentYearTwoDigits = currentYear % 100;
            var year = yearTwoDigits <= currentYearTwoDigits ? 2000 + yearTwoDigits : 1900 + yearTwoDigits;

            // Validazione data completa
            try
            {
                var date = new DateTime(year, month, day);

                // Controllo che la data non sia futura
                if (date > DateTime.Now)
                {
                    return ValidationResult.Failure($"La data di nascita nel CF ({date:dd/MM/yyyy}) è nel futuro", "future_date");
                }

                // Controllo che la data non sia troppo vecchia (es. > 120 anni)
                if (date < DateTime.Now.AddYears(-120))
                {
                    return ValidationResult.Failure($"La data di nascita nel CF ({date:dd/MM/yyyy}) è troppo vecchia", "date_too_old");
                }
            }
            catch (ArgumentOutOfRangeException)
            {
                return ValidationResult.Failure($"Data non valida: {day}/{month}/{year} (es. 31 febbraio)", "invalid_date");
            }

            return ValidationResult.Success();
        }
        catch (Exception ex)
        {
            return ValidationResult.Failure($"Errore nella validazione componenti data: {ex.Message}", "date_components_error");
        }
    }

    /// <summary>
    /// Decodifica una stringa che potrebbe contenere lettere omocodia in cifre.
    /// </summary>
    private static string DecodeOmocodiaString(string input)
    {
        var result = new char[input.Length];
        for (int i = 0; i < input.Length; i++)
        {
            if (OmocodiaToDigitMap.TryGetValue(input[i], out var digit))
            {
                result[i] = digit;
            }
            else
            {
                result[i] = input[i];
            }
        }
        return new string(result);
    }

}
