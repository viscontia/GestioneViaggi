using GestioneViaggi.Validation.Models;
using System.Text.RegularExpressions;

namespace GestioneViaggi.Validation.Fiscal;

/// <summary>
/// Validatore per il Codice Fiscale italiano.
/// Implementa l'algoritmo ufficiale completo con:
/// - Validazione formato
/// - Verifica check digit
/// - Validazione componenti data
/// - Calcolo codice fiscale atteso da anagrafica
/// - Gestione omocodia
///
/// Traduzione C# della logica Python da codice_fiscale_utils.py del progetto Iscrizione-Viaggi-Offroad.
/// </summary>
public static partial class CodiceFiscaleValidator
{
    // Pattern regex per validazione formato base
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

    /// <summary>
    /// Calcola il codice fiscale atteso basandosi sui dati anagrafici.
    /// Implementa l'algoritmo ufficiale italiano.
    /// </summary>
    /// <param name="cognome">Cognome</param>
    /// <param name="nome">Nome</param>
    /// <param name="dataNascita">Data di nascita</param>
    /// <param name="sesso">Sesso (M/F)</param>
    /// <param name="codiceComuneCatastale">Codice catastale del comune di nascita (4 caratteri)</param>
    /// <returns>ValidationResult con il codice fiscale calcolato se successo</returns>
    public static ValidationResult<string> CalculateExpectedCodiceFiscale(
        string cognome,
        string nome,
        DateTime dataNascita,
        char sesso,
        string codiceComuneCatastale)
    {
        try
        {
            // Validazione input
            if (string.IsNullOrWhiteSpace(cognome))
                return ValidationResult<string>.Failure("Cognome obbligatorio per calcolo CF", "missing_cognome");

            if (string.IsNullOrWhiteSpace(nome))
                return ValidationResult<string>.Failure("Nome obbligatorio per calcolo CF", "missing_nome");

            if (sesso != 'M' && sesso != 'F')
                return ValidationResult<string>.Failure("Sesso deve essere M o F", "invalid_sesso");

            if (string.IsNullOrWhiteSpace(codiceComuneCatastale) || codiceComuneCatastale.Length != 4)
                return ValidationResult<string>.Failure("Codice comune catastale deve essere di 4 caratteri", "invalid_comune_code");

            // Normalizzazione
            cognome = cognome.Trim().ToUpperInvariant();
            nome = nome.Trim().ToUpperInvariant();
            codiceComuneCatastale = codiceComuneCatastale.Trim().ToUpperInvariant();

            // 1. Codice cognome (3 caratteri)
            var codiceCognome = ExtractCode(cognome, 3);

            // 2. Codice nome (3 caratteri) - regola speciale: se 4+ consonanti, prende 1°, 3°, 4°
            var codiceNome = ExtractNameCode(nome);

            // 3. Codice anno (2 caratteri)
            var codiceAnno = (dataNascita.Year % 100).ToString("D2");

            // 4. Codice mese (1 carattere)
            var codiceMese = MonthCodeMap[dataNascita.Month];

            // 5. Codice giorno (2 caratteri)
            var codiceGiorno = sesso == 'M' ? dataNascita.Day : dataNascita.Day + 40;
            var codiceGiornoString = codiceGiorno.ToString("D2");

            // 6. Codice comune (4 caratteri)
            var codiceComune = codiceComuneCatastale;

            // 7. Check digit
            var first15 = $"{codiceCognome}{codiceNome}{codiceAnno}{codiceMese}{codiceGiornoString}{codiceComune}";
            var checkDigit = CalculateCheckDigit(first15);

            var codiceFiscale = $"{first15}{checkDigit}";

            return ValidationResult<string>.SuccessWithData(codiceFiscale, "Codice fiscale calcolato con successo");
        }
        catch (Exception ex)
        {
            return ValidationResult<string>.Failure($"Errore nel calcolo codice fiscale: {ex.Message}", "calculation_error");
        }
    }

    /// <summary>
    /// Estrae il codice (consonanti + vocali + padding X) da una stringa per cognome.
    /// </summary>
    private static string ExtractCode(string input, int length)
    {
        var consonants = ExtractConsonants(input);
        var vowels = ExtractVowels(input);

        var code = consonants;
        if (code.Length < length)
        {
            code += vowels;
        }

        // Padding con 'X' se necessario
        code = code.PadRight(length, 'X');

        return code[..length];
    }

    /// <summary>
    /// Estrae il codice nome con regola speciale: se ≥4 consonanti, prende 1°, 3°, 4°.
    /// </summary>
    private static string ExtractNameCode(string nome)
    {
        var consonants = ExtractConsonants(nome);

        string code;
        if (consonants.Length >= 4)
        {
            // Regola speciale: prende 1°, 3°, 4° consonante
            code = $"{consonants[0]}{consonants[2]}{consonants[3]}";
        }
        else
        {
            // Regola standard: prime 3 consonanti, poi vocali, poi padding X
            code = ExtractCode(nome, 3);
        }

        return code;
    }

    /// <summary>
    /// Estrae le consonanti da una stringa.
    /// </summary>
    private static string ExtractConsonants(string input)
    {
        return new string([.. input.Where(c => char.IsLetter(c) && !"AEIOU".Contains(c))]);
    }

    /// <summary>
    /// Estrae le vocali da una stringa.
    /// </summary>
    private static string ExtractVowels(string input)
    {
        return new string([.. input.Where(c => "AEIOU".Contains(c))]);
    }

    /// <summary>
    /// Verifica se il codice fiscale fornito è un'omocodia valida del codice fiscale atteso.
    /// </summary>
    /// <param name="cfProvided">Codice fiscale fornito (potenzialmente omocodico)</param>
    /// <param name="cfExpected">Codice fiscale atteso (calcolato da anagrafica)</param>
    /// <returns>ValidationResult che indica se è omocodia valida</returns>
    public static ValidationResult CheckOmocodia(string cfProvided, string cfExpected)
    {
        if (cfProvided.Length != 16 || cfExpected.Length != 16)
        {
            return ValidationResult.Failure("Entrambi i codici fiscali devono essere di 16 caratteri", "invalid_length");
        }

        if (cfProvided == cfExpected)
        {
            return ValidationResult.Success("Codice fiscale coincide esattamente (non è omocodia)");
        }

        try
        {
            // Ricostruisci il CF base (tutte cifre) dal CF omocodico
            var cfBase = new char[15];
            bool hasOmocodia = false;

            for (int i = 0; i < 15; i++)
            {
                if (cfProvided[i] != cfExpected[i])
                {
                    // Differenza trovata
                    // Verifica se la posizione è sostituibile
                    if (!OmocodiaPositions.Contains(i))
                    {
                        return ValidationResult.Failure(
                            $"Differenza in posizione {i + 1} non sostituibile per omocodia",
                            "invalid_omocodia_position"
                        );
                    }

                    // Verifica che sia conversione cifra→lettera valida
                    var expectedChar = cfExpected[i];
                    var providedChar = cfProvided[i];

                    if (!char.IsDigit(expectedChar))
                    {
                        return ValidationResult.Failure(
                            $"Carattere atteso in posizione {i + 1} non è una cifra: {expectedChar}",
                            "expected_not_digit"
                        );
                    }

                    if (!DigitToOmocodiaMap.TryGetValue(expectedChar, out var expectedOmocodiaChar) ||
                        expectedOmocodiaChar != providedChar)
                    {
                        return ValidationResult.Failure(
                            $"Conversione omocodia non valida in posizione {i + 1}: atteso {expectedChar}→{(DigitToOmocodiaMap.TryGetValue(expectedChar, out var c) ? c : '?')}, fornito {providedChar}",
                            "invalid_omocodia_conversion"
                        );
                    }

                    cfBase[i] = expectedChar; // Usa la cifra originale
                    hasOmocodia = true;
                }
                else
                {
                    cfBase[i] = cfExpected[i];
                }
            }

            if (!hasOmocodia)
            {
                return ValidationResult.Failure("Nessuna sostituzione omocodia trovata", "no_omocodia");
            }

            // Ricalcola il check digit per il CF base
            var calculatedCheckDigit = CalculateCheckDigit(new string(cfBase));

            // Verifica il check digit del CF fornito
            if (cfProvided[15] != calculatedCheckDigit)
            {
                return ValidationResult.Failure(
                    $"Check digit non valido per omocodia (atteso: {calculatedCheckDigit}, fornito: {cfProvided[15]})",
                    "invalid_omocodia_check_digit"
                );
            }

            return ValidationResult.Success("Codice fiscale è un'omocodia valida");
        }
        catch (Exception ex)
        {
            return ValidationResult.Failure($"Errore nella verifica omocodia: {ex.Message}", "omocodia_check_error");
        }
    }

    /// <summary>
    /// Valida il codice fiscale confrontandolo con i dati anagrafici forniti.
    /// Gestisce anche omocodia.
    /// </summary>
    /// <param name="cfProvided">Codice fiscale fornito dall'utente</param>
    /// <param name="cognome">Cognome</param>
    /// <param name="nome">Nome</param>
    /// <param name="dataNascita">Data di nascita</param>
    /// <param name="sesso">Sesso (M/F)</param>
    /// <param name="codiceComuneCatastale">Codice catastale del comune di nascita</param>
    /// <returns>ValidationResult che indica se il CF corrisponde all'anagrafica</returns>
    public static ValidationResult ValidateAgainstAnagrafica(
        string cfProvided,
        string cognome,
        string nome,
        DateTime dataNascita,
        char sesso,
        string codiceComuneCatastale)
    {
        // Prima validazione formato base
        var formatResult = ValidateCodiceFiscale(cfProvided);
        if (!formatResult.IsValid)
        {
            return formatResult;
        }

        // Calcola CF atteso
        var expectedResult = CalculateExpectedCodiceFiscale(cognome, nome, dataNascita, sesso, codiceComuneCatastale);
        if (!expectedResult.IsValid)
        {
            return ValidationResult.Failure($"Errore nel calcolo CF atteso: {expectedResult.Message}", "calculation_failed");
        }

        var cfExpected = expectedResult.Data!;

        // Confronto diretto
        if (cfProvided.Equals(cfExpected, StringComparison.OrdinalIgnoreCase))
        {
            return ValidationResult.Success("Codice fiscale valido e corrispondente all'anagrafica");
        }

        // Verifica omocodia
        var omocodiaResult = CheckOmocodia(cfProvided, cfExpected);
        if (omocodiaResult.IsValid)
        {
            return ValidationResult.Success("Codice fiscale valido (omocodia)");
        }

        // Non corrisponde
        return ValidationResult.Failure(
            "Il codice fiscale non corrisponde ai dati anagrafici inseriti",
            "anagrafica_mismatch",
            new Dictionary<string, object>
            {
                { "cf_fornito", cfProvided },
                { "cf_atteso", cfExpected },
                { "omocodia_check", omocodiaResult.Message }
            }
        );
    }
}
