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

    /// <summary>
    /// Prezzo per MILIONE di token, usato per stimare il costo di ogni traduzione.
    /// ⚠️ Sono valori di configurazione, non un dato letto dall'API: vanno allineati al listino
    /// Anthropic del modello in uso (sezione "Claude" in appsettings) e cambiati se il listino cambia.
    /// Il costo viene congelato sulla riga di consumo al momento della chiamata, quindi lo storico
    /// resta corretto anche dopo un aggiornamento dei prezzi.
    /// </summary>
    public decimal PrezzoInputPerMilione { get; set; } = 1.00m;
    public decimal PrezzoOutputPerMilione { get; set; } = 5.00m;
    /// <summary>Valuta dei prezzi sopra. Anthropic fattura in USD.</summary>
    public string Valuta { get; set; } = "USD";

    /// <summary>Costo stimato di una chiamata, con i prezzi attualmente configurati.</summary>
    public decimal StimaCosto(int inputTokens, int outputTokens)
        => inputTokens / 1_000_000m * PrezzoInputPerMilione
         + outputTokens / 1_000_000m * PrezzoOutputPerMilione;
}

/// <summary>
/// Esito di una traduzione: testo + token consumati. I token arrivano nel blocco "usage" della
/// risposta Messages, quindi contarli non costa una chiamata in più.
/// </summary>
public sealed record ClaudeTranslation(string Testo, int InputTokens, int OutputTokens);

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

    /// <summary>
    /// Traduce il testo dall'italiano alla lingua target (codice a 2 lettere). Preserva l'HTML.
    /// Ritorna anche i token consumati, per il registro spese.
    /// </summary>
    public async Task<ClaudeTranslation> TranslateAsync(string apiKey, string sourceText, string targetLangCode, CancellationToken ct = default)
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

        // "usage" è sempre presente nelle risposte Messages, ma se un domani cambiasse formato non
        // deve far fallire la traduzione: senza conteggio si registra 0, non si perde il testo.
        var input = 0; var output = 0;
        if (doc.RootElement.TryGetProperty("usage", out var usage))
        {
            if (usage.TryGetProperty("input_tokens", out var i)) input = i.GetInt32();
            if (usage.TryGetProperty("output_tokens", out var o)) output = o.GetInt32();
        }

        return new ClaudeTranslation(text?.Trim() ?? string.Empty, input, output);
    }
}
