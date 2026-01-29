using System.Text.RegularExpressions;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

/// <summary>
/// Validatore per VAT Number (Partita IVA) europei.
/// Supporta validazione pattern generico + pattern specifici per paese.
/// </summary>
/// <remarks>
/// Fonti:
/// - EU VAT Number Formats: https://www.avalara.com/vatlive/en/eu-vat-rules/eu-vat-number-registration/eu-vat-number-formats.html
/// - Regex Patterns: https://github.com/mnestorov/regex-patterns
/// - O'Reilly Cookbook: https://www.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/ch04s21.html
/// </remarks>
public static partial class EuropeanVatValidator
{
    // ========== PATTERN GENERICO ==========

    /// <summary>
    /// Pattern generico VAT Number: 2 lettere (codice paese) + 2-18 caratteri alfanumerici.
    /// </summary>
    [GeneratedRegex(@"^[A-Z]{2}[A-Z0-9]{2,18}$", RegexOptions.Compiled)]
    private static partial Regex VatNumberGenericRegex();

    // ========== PATTERN SPECIFICI PER PAESE ==========

    // Austria: ATU + 8 cifre
    [GeneratedRegex(@"^ATU\d{8}$", RegexOptions.Compiled)]
    private static partial Regex VatAustriaRegex();

    // Belgio: BE + 10 cifre
    [GeneratedRegex(@"^BE\d{10}$", RegexOptions.Compiled)]
    private static partial Regex VatBelgiumRegex();

    // Bulgaria: BG + 9-10 cifre
    [GeneratedRegex(@"^BG\d{9,10}$", RegexOptions.Compiled)]
    private static partial Regex VatBulgariaRegex();

    // Croazia: HR + 11 cifre
    [GeneratedRegex(@"^HR\d{11}$", RegexOptions.Compiled)]
    private static partial Regex VatCroatiaRegex();

    // Cipro: CY + 8 cifre + 1 lettera
    [GeneratedRegex(@"^CY\d{8}[A-Z]$", RegexOptions.Compiled)]
    private static partial Regex VatCyprusRegex();

    // Repubblica Ceca: CZ + 8-10 cifre
    [GeneratedRegex(@"^CZ\d{8,10}$", RegexOptions.Compiled)]
    private static partial Regex VatCzechRepublicRegex();

    // Danimarca: DK + 8 cifre
    [GeneratedRegex(@"^DK\d{8}$", RegexOptions.Compiled)]
    private static partial Regex VatDenmarkRegex();

    // Estonia: EE + 9 cifre
    [GeneratedRegex(@"^EE\d{9}$", RegexOptions.Compiled)]
    private static partial Regex VatEstoniaRegex();

    // Finlandia: FI + 8 cifre
    [GeneratedRegex(@"^FI\d{8}$", RegexOptions.Compiled)]
    private static partial Regex VatFinlandRegex();

    // Francia: FR + 2 caratteri (alfanumerici) + 9 cifre
    [GeneratedRegex(@"^FR[A-Z0-9]{2}\d{9}$", RegexOptions.Compiled)]
    private static partial Regex VatFranceRegex();

    // Germania: DE + 9 cifre
    [GeneratedRegex(@"^DE\d{9}$", RegexOptions.Compiled)]
    private static partial Regex VatGermanyRegex();

    // Grecia: EL + 9 cifre
    [GeneratedRegex(@"^EL\d{9}$", RegexOptions.Compiled)]
    private static partial Regex VatGreeceRegex();

    // Ungheria: HU + 8 cifre
    [GeneratedRegex(@"^HU\d{8}$", RegexOptions.Compiled)]
    private static partial Regex VatHungaryRegex();

    // Irlanda: IE + 7 cifre + 1-2 lettere
    [GeneratedRegex(@"^IE\d{7}[A-Z]{1,2}$", RegexOptions.Compiled)]
    private static partial Regex VatIrelandRegex();

    // Italia: IT + 11 cifre (per completezza, anche se abbiamo ItalianFiscalValidator)
    [GeneratedRegex(@"^IT\d{11}$", RegexOptions.Compiled)]
    private static partial Regex VatItalyRegex();

    // Lettonia: LV + 11 cifre
    [GeneratedRegex(@"^LV\d{11}$", RegexOptions.Compiled)]
    private static partial Regex VatLatviaRegex();

    // Lituania: LT + 9-12 cifre
    [GeneratedRegex(@"^LT\d{9,12}$", RegexOptions.Compiled)]
    private static partial Regex VatLithuaniaRegex();

    // Lussemburgo: LU + 8 cifre
    [GeneratedRegex(@"^LU\d{8}$", RegexOptions.Compiled)]
    private static partial Regex VatLuxembourgRegex();

    // Malta: MT + 8 cifre
    [GeneratedRegex(@"^MT\d{8}$", RegexOptions.Compiled)]
    private static partial Regex VatMaltaRegex();

    // Paesi Bassi: NL + 9 cifre + B + 2 cifre
    [GeneratedRegex(@"^NL\d{9}B\d{2}$", RegexOptions.Compiled)]
    private static partial Regex VatNetherlandsRegex();

    // Polonia: PL + 10 cifre
    [GeneratedRegex(@"^PL\d{10}$", RegexOptions.Compiled)]
    private static partial Regex VatPolandRegex();

    // Portogallo: PT + 9 cifre
    [GeneratedRegex(@"^PT\d{9}$", RegexOptions.Compiled)]
    private static partial Regex VatPortugalRegex();

    // Romania: RO + 2-10 cifre
    [GeneratedRegex(@"^RO\d{2,10}$", RegexOptions.Compiled)]
    private static partial Regex VatRomaniaRegex();

    // Slovacchia: SK + 10 cifre
    [GeneratedRegex(@"^SK\d{10}$", RegexOptions.Compiled)]
    private static partial Regex VatSlovakiaRegex();

    // Slovenia: SI + 8 cifre
    [GeneratedRegex(@"^SI\d{8}$", RegexOptions.Compiled)]
    private static partial Regex VatSloveniaRegex();

    // Spagna: ES + 1 carattere + 7 cifre + 1 carattere
    [GeneratedRegex(@"^ES[A-Z0-9]\d{7}[A-Z0-9]$", RegexOptions.Compiled)]
    private static partial Regex VatSpainRegex();

    // Svezia: SE + 10 cifre + 01 (suffisso fisso)
    [GeneratedRegex(@"^SE\d{10}01$", RegexOptions.Compiled)]
    private static partial Regex VatSwedenRegex();

    // Regno Unito: GB + 9 o 12 cifre (post-Brexit, ma ancora usato)
    [GeneratedRegex(@"^GB(\d{9}|\d{12})$", RegexOptions.Compiled)]
    private static partial Regex VatUnitedKingdomRegex();

    // Svizzera (non EU ma comune): CHE + 9 cifre + MVA/MWST/IVA
    [GeneratedRegex(@"^CHE\d{9}(MVA|MWST|IVA)$", RegexOptions.Compiled)]
    private static partial Regex VatSwitzerlandRegex();

    // Norvegia (non EU ma comune): NO + 9 cifre + MVA
    [GeneratedRegex(@"^NO\d{9}MVA$", RegexOptions.Compiled)]
    private static partial Regex VatNorwayRegex();

    // ========== MAPPATURA COUNTRY CODE → REGEX ==========

    /// <summary>
    /// Dizionario pattern specifici per paese.
    /// </summary>
    private static readonly Dictionary<string, Func<Regex>> CountryPatterns = new()
    {
        { "AT", VatAustriaRegex },
        { "BE", VatBelgiumRegex },
        { "BG", VatBulgariaRegex },
        { "HR", VatCroatiaRegex },
        { "CY", VatCyprusRegex },
        { "CZ", VatCzechRepublicRegex },
        { "DK", VatDenmarkRegex },
        { "EE", VatEstoniaRegex },
        { "FI", VatFinlandRegex },
        { "FR", VatFranceRegex },
        { "DE", VatGermanyRegex },
        { "EL", VatGreeceRegex },
        { "HU", VatHungaryRegex },
        { "IE", VatIrelandRegex },
        { "IT", VatItalyRegex },
        { "LV", VatLatviaRegex },
        { "LT", VatLithuaniaRegex },
        { "LU", VatLuxembourgRegex },
        { "MT", VatMaltaRegex },
        { "NL", VatNetherlandsRegex },
        { "PL", VatPolandRegex },
        { "PT", VatPortugalRegex },
        { "RO", VatRomaniaRegex },
        { "SK", VatSlovakiaRegex },
        { "SI", VatSloveniaRegex },
        { "ES", VatSpainRegex },
        { "SE", VatSwedenRegex },
        { "GB", VatUnitedKingdomRegex },
        { "CHE", VatSwitzerlandRegex },  // Svizzera usa 3 lettere
        { "NO", VatNorwayRegex }
    };

    // ========== METODI PUBBLICI ==========

    /// <summary>
    /// Valida un VAT Number europeo.
    /// Esegue validazione in due fasi: pattern generico + pattern specifico paese (se disponibile).
    /// </summary>
    /// <param name="vatNumber">VAT Number da validare (es: FR12345678901, DE123456789).</param>
    /// <returns>ValidationResult con esito validazione.</returns>
    public static ValidationResult CheckVatNumber(string? vatNumber)
    {
        if (string.IsNullOrWhiteSpace(vatNumber))
            return ValidationResult.Failure(
                "VAT Number obbligatorio per fornitori esteri",
                "CHK_VAT_001"
            );

        var upperVat = vatNumber.ToUpperInvariant().Trim();

        // Fase 1: Validazione pattern generico
        if (!VatNumberGenericRegex().IsMatch(upperVat))
            return ValidationResult.Failure(
                "VAT Number non valido: deve iniziare con 2 lettere (codice paese) seguite da 2-18 caratteri alfanumerici (es: FR12345678901, DE123456789)",
                "CHK_VAT_002"
            );

        // Fase 2: Validazione pattern specifico paese (se disponibile)
        var countryCode = ExtractCountryCode(upperVat);
        if (!string.IsNullOrEmpty(countryCode))
        {
            // Gestione speciale Svizzera (3 lettere: CHE)
            if (upperVat.StartsWith("CHE"))
            {
                if (CountryPatterns.TryGetValue("CHE", out var chRegexFunc))
                {
                    if (!chRegexFunc().IsMatch(upperVat))
                        return ValidationResult.Failure(
                            $"VAT Number non valido per la Svizzera. Formato atteso: CHE + 9 cifre + MVA/MWST/IVA (es: CHE123456789MVA)",
                            "CHK_VAT_003"
                        );
                }
            }
            // Validazione standard 2 lettere
            else if (CountryPatterns.TryGetValue(countryCode, out var regexFunc))
            {
                if (!regexFunc().IsMatch(upperVat))
                    return ValidationResult.Failure(
                        $"VAT Number non valido per il paese {countryCode}. Verifica il formato specifico del paese",
                        "CHK_VAT_003"
                    );
            }
        }

        return ValidationResult.Success();
    }

    /// <summary>
    /// Estrae il codice paese da un VAT Number (primi 2 caratteri).
    /// </summary>
    /// <param name="vatNumber">VAT Number (es: FR12345678901).</param>
    /// <returns>Codice paese maiuscolo (es: "FR"), oppure null se non valido.</returns>
    public static string? ExtractCountryCode(string? vatNumber)
    {
        if (string.IsNullOrWhiteSpace(vatNumber) || vatNumber.Length < 2)
            return null;

        return vatNumber.Substring(0, 2).ToUpperInvariant();
    }

    /// <summary>
    /// Verifica se un codice paese ha una validazione specifica disponibile.
    /// </summary>
    /// <param name="countryCode">Codice paese a 2 lettere (es: "FR", "DE").</param>
    /// <returns>True se il paese è supportato con pattern specifico.</returns>
    public static bool IsCountrySupported(string countryCode)
    {
        return CountryPatterns.ContainsKey(countryCode.ToUpperInvariant());
    }

    /// <summary>
    /// Restituisce la lista di tutti i codici paese supportati per validazione specifica.
    /// </summary>
    /// <returns>Lista codici paese (es: ["AT", "BE", "FR", ...]).</returns>
    public static IEnumerable<string> GetSupportedCountryCodes()
    {
        return CountryPatterns.Keys.OrderBy(k => k);
    }
}
