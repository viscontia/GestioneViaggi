using System.Text.Json;
using System.Text.Json.Serialization;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Helper class for JSON deserialization in printing services.
/// Provides centralized configuration for PostgreSQL JSON responses.
/// </summary>
public static class PrintJsonHelper
{
    /// <summary>
    /// Standard JsonSerializerOptions for all print services.
    /// Handles snake_case to PascalCase conversion and enum serialization.
    /// </summary>
    public static JsonSerializerOptions GetDefaultOptions()
    {
        return new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
            Converters = { new JsonStringEnumConverter() }
        };
    }
}

/// <summary>
/// Base class for company print info with automatic base64 logo conversion.
/// Use this instead of defining CompanyPrintInfo in each DTO file.
/// </summary>
public class CompanyPrintInfoBase
{
    [JsonPropertyName("ragione_sociale")]
    public string RagioneSociale { get; set; } = string.Empty;

    [JsonPropertyName("telefono")]
    public string Telefono { get; set; } = string.Empty;

    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    [JsonPropertyName("sito_web")]
    public string SitoWeb { get; set; } = string.Empty;

    [JsonPropertyName("piva")]
    public string Piva { get; set; } = string.Empty;

    [JsonPropertyName("logo_data")]
    public string? LogoDataBase64 { get; set; }

    /// <summary>
    /// Logo as byte array. Automatically converts from/to base64 string.
    /// This property is not serialized - it's a computed wrapper around LogoDataBase64.
    /// </summary>
    [JsonIgnore]
    public byte[] LogoData
    {
        get
        {
            if (string.IsNullOrEmpty(LogoDataBase64))
                return Array.Empty<byte>();

            try
            {
                return Convert.FromBase64String(LogoDataBase64);
            }
            catch
            {
                return Array.Empty<byte>();
            }
        }
        set
        {
            if (value == null || value.Length == 0)
                LogoDataBase64 = null;
            else
                LogoDataBase64 = Convert.ToBase64String(value);
        }
    }
}
