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
    /// Pattern generico VAT Number: 1-3 lettere (codice paese) + 2-18 caratteri alfanumerici.
    /// </summary>
    [GeneratedRegex(@"^[A-Z]{1,3}[A-Z0-9]{2,20}$", RegexOptions.Compiled)]
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

    // Svizzera (non EU ma comune): CHE + 9 cifre + MVA/MWST/IVA (supporta separatori come CHE-123.456.789 MWST)
    [GeneratedRegex(@"^CHE[- ]?(\d{9}|\d{3}\.\d{3}\.\d{3})[- ]?(MVA|MWST|IVA|TVA)$", RegexOptions.Compiled | RegexOptions.IgnoreCase)]
    private static partial Regex VatSwitzerlandRegex();

    // Norvegia (non EU ma comune): NO + 9 cifre + MVA
    [GeneratedRegex(@"^NO\d{9}MVA$", RegexOptions.Compiled)]
    private static partial Regex VatNorwayRegex();

    // Albania: NIPT standard (L + 8 cifre + L) oppure con prefisso AL
    [GeneratedRegex(@"^[A-Z]\d{8}[A-Z]$", RegexOptions.Compiled)]
    private static partial Regex VatAlbaniaNiptRegex();

    [GeneratedRegex(@"^AL[A-Z]\d{8}[A-Z]$", RegexOptions.Compiled)]
    private static partial Regex VatAlbaniaWithPrefixRegex();

    // Islanda: IS + 5-6 cifre
    [GeneratedRegex(@"^IS\d{5,6}$", RegexOptions.Compiled)]
    private static partial Regex VatIcelandRegex();

    // Liechtenstein: LI + 5 cifre
    [GeneratedRegex(@"^LI\d{5}$", RegexOptions.Compiled)]
    private static partial Regex VatLiechtensteinRegex();

    // Montenegro: ME + 8 cifre
    [GeneratedRegex(@"^ME\d{8}$", RegexOptions.Compiled)]
    private static partial Regex VatMontenegroRegex();

    // Macedonia del Nord: MK + 13 cifre
    [GeneratedRegex(@"^MK\d{13}$", RegexOptions.Compiled)]
    private static partial Regex VatNorthMacedoniaRegex();

    // Serbia: RS + 9 cifre
    [GeneratedRegex(@"^RS\d{9}$", RegexOptions.Compiled)]
    private static partial Regex VatSerbiaRegex();

    // Turchia: TR + 10 cifre
    [GeneratedRegex(@"^TR\d{10}$", RegexOptions.Compiled)]
    private static partial Regex VatTurkeyRegex();

    // Ucraina: UA + 8-12 cifre
    [GeneratedRegex(@"^UA\d{8,12}$", RegexOptions.Compiled)]
    private static partial Regex VatUkraineRegex();

    // Sudafrica: ZA + 10 cifre
    [GeneratedRegex(@"^ZA\d{10}$", RegexOptions.Compiled)]
    private static partial Regex VatSouthAfricaRegex();

    // Marocco: MA + 8 cifre
    [GeneratedRegex(@"^MA\d{8}$", RegexOptions.Compiled)]
    private static partial Regex VatMoroccoRegex();

    // Tunisia: TN + 7 cifre + 1 lettera
    [GeneratedRegex(@"^TN\d{7}[A-Z]$", RegexOptions.Compiled)]
    private static partial Regex VatTunisiaRegex();

    // Algeria: DZ + 15 o 20 cifre
    [GeneratedRegex(@"^DZ\d{15}(\d{5})?$", RegexOptions.Compiled)]
    private static partial Regex VatAlgeriaRegex();

    // Libia: LY + 6 cifre
    [GeneratedRegex(@"^LY\d{6}$", RegexOptions.Compiled)]
    private static partial Regex VatLibyaRegex();

    // Egitto: EG + 9 cifre
    [GeneratedRegex(@"^EG\d{9}$", RegexOptions.Compiled)]
    private static partial Regex VatEgyptRegex();

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
        { "CHE", VatSwitzerlandRegex },
        { "NO", VatNorwayRegex },
        { "AL", VatAlbaniaWithPrefixRegex },
        { "IS", VatIcelandRegex },
        { "LI", VatLiechtensteinRegex },
        { "ME", VatMontenegroRegex },
        { "MK", VatNorthMacedoniaRegex },
        { "RS", VatSerbiaRegex },
        { "TR", VatTurkeyRegex },
        { "UA", VatUkraineRegex },
        { "ZA", VatSouthAfricaRegex },
        { "MA", VatMoroccoRegex },
        { "TN", VatTunisiaRegex },
        { "DZ", VatAlgeriaRegex },
        { "LY", VatLibyaRegex },
        { "EG", VatEgyptRegex }
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

        // Caso Speciale: Albania (NIPT) può non avere prefisso ed è unico (Lettera + 8 cifre + Lettera)
        if (VatAlbaniaNiptRegex().IsMatch(upperVat) || VatAlbaniaWithPrefixRegex().IsMatch(upperVat))
            return ValidationResult.Success();

        // Fase 1: Validazione pattern generico
        if (!VatNumberGenericRegex().IsMatch(upperVat))
            return ValidationResult.Failure(
                "VAT Number non valido: deve iniziare con 2-3 lettere (codice paese) seguite da caratteri alfanumerici (es: IT12345678901, FR12...)",
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
    /// Estrae il codice paese da un VAT Number.
    /// Gestisce codici a 2 lettere (standard EU) e 3 lettere (es: Svizzera CHE).
    /// </summary>
    /// <param name="vatNumber">VAT Number (es: FR123..., CHE123...).</param>
    /// <returns>Codice paese maiuscolo, oppure null se non valido.</returns>
    public static string? ExtractCountryCode(string? vatNumber)
    {
        if (string.IsNullOrWhiteSpace(vatNumber) || vatNumber.Length < 3)
        {
             if (!string.IsNullOrWhiteSpace(vatNumber) && vatNumber.Length >= 2)
                return vatNumber.Substring(0, 2).ToUpperInvariant();
             return null;
        }

        var upper = vatNumber.ToUpperInvariant();
        if (upper.StartsWith("CHE"))
            return "CHE";

        return upper.Substring(0, 2);
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
