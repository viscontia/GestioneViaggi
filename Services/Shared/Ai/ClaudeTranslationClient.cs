using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Shared.Ai;

/// <summary>Opzioni del client Claude (Anthropic). Modello di default: Haiku 4.5 (traduzione economica).</summary>
public sealed class ClaudeOptions
{
    public string Model { get; set; } = "claude-haiku-4-5-20251001";
    public int MaxTokens { get; set; } = 4096;
    public string ApiVersion { get; set; } = "2023-06-01";
}

/// <summary>
/// Client per la traduzione via Claude API (Anthropic Messages, HTTP REST, no SDK).
/// La chiave è PER-AZIENDA (ana_aziende.claude_api_key) e viene passata per-chiamata.
/// Il prompt preserva l'HTML e non traduce i nomi propri.
/// </summary>
public sealed class ClaudeTranslationClient
{
    private const string Endpoint = "https://api.anthropic.com/v1/messages";
    private static readonly Dictionary<string, string> LangNames = new(StringComparer.OrdinalIgnoreCase)
    {
        ["EN"] = "inglese", ["DE"] = "tedesco", ["FR"] = "francese", ["ES"] = "spagnolo"
    };

    private readonly HttpClient _http;
    private readonly ClaudeOptions _opt;
    private readonly ILogger<ClaudeTranslationClient> _logger;

    public ClaudeTranslationClient(HttpClient http, ClaudeOptions opt, ILogger<ClaudeTranslationClient> logger)
    {
        _http = http;
        _opt = opt;
        _logger = logger;
    }

    public static string LanguageName(string code) => LangNames.TryGetValue(code, out var n) ? n : code;

    /// <summary>Traduce il testo dall'italiano alla lingua target (codice a 2 lettere). Preserva l'HTML.</summary>
    public async Task<string> TranslateAsync(string apiKey, string sourceText, string targetLangCode, CancellationToken ct = default)
    {
        var lang = LanguageName(targetLangCode);
        var system =
            $"Sei un traduttore professionale per un sito di tour offroad. Traduci il testo dall'italiano al {lang}. " +
            "Conserva ESATTAMENTE l'HTML (tag, attributi, entità) senza alterarlo. " +
            "NON tradurre i nomi propri: toponimi, nomi di tour, marchi, nomi di persone. " +
            "Rispondi SOLO con la traduzione, senza premesse, virgolette o commenti.";

        var payload = new
        {
            model = _opt.Model,
            max_tokens = _opt.MaxTokens,
            system,
            messages = new[] { new { role = "user", content = sourceText } }
        };

        using var req = new HttpRequestMessage(HttpMethod.Post, Endpoint);
        req.Headers.TryAddWithoutValidation("x-api-key", apiKey);
        req.Headers.TryAddWithoutValidation("anthropic-version", _opt.ApiVersion);
        req.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

        using var resp = await _http.SendAsync(req, ct);
        var body = await resp.Content.ReadAsStringAsync(ct);
        if (!resp.IsSuccessStatusCode)
        {
            _logger.LogError("Claude API {Status}: {Body}", (int)resp.StatusCode, body);
            throw new InvalidOperationException($"Claude API ha restituito {(int)resp.StatusCode}. Verifica la chiave o la quota.");
        }

        using var doc = JsonDocument.Parse(body);
        var text = doc.RootElement.GetProperty("content")[0].GetProperty("text").GetString();
        return text?.Trim() ?? string.Empty;
    }
}
