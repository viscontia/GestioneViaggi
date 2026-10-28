using System.Security.Cryptography;
using System.Text;

namespace GestioneViaggi.Services.Shared;

/// <summary>
/// Link di disiscrizione firmato HMAC (Blocco 11). Uniforme per clienti e iscritti (nessun token
/// per-cliente richiesto). Lo apre il sito pubblico (Tappa 4D): la firma la controlla il database
/// (fn_web_newsletter_disiscrivi, script 707) con lo stesso segreto per azienda
/// (ana_aziende.segreto_disiscrizione, separato da token_iscrizione che serve a Flask) e aggiunge una
/// soppressione. Il link porta alla pagina nella lingua del destinatario.
/// </summary>
public static class NewsletterUnsubscribe
{
    public static string Sign(string email, string secret)
    {
        using var h = new HMACSHA256(Encoding.UTF8.GetBytes(secret ?? string.Empty));
        var hash = h.ComputeHash(Encoding.UTF8.GetBytes((email ?? string.Empty).Trim().ToLowerInvariant()));
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    /// <summary><c>{baseUrl}/{lingua}/newsletter/disiscrizione?email=&lt;e&gt;&amp;firma=&lt;hmac(email, secret)&gt;</c></summary>
    public static string BuildUrl(string? baseUrl, string email, string? secret, string? lingua = "IT")
    {
        var b = string.IsNullOrWhiteSpace(baseUrl) ? "https://www.example.com" : baseUrl!.Trim().TrimEnd('/');
        var l = lingua?.Trim().ToLowerInvariant() is "en" or "de" or "fr" or "es" ? lingua.Trim().ToLowerInvariant() : "it";
        var firma = Sign(email, secret ?? string.Empty);
        return $"{b}/{l}/newsletter/disiscrizione?email={Uri.EscapeDataString(email)}&firma={firma}";
    }

    /// <summary>
    /// Intestazioni per disiscriversi con un clic dal programma di posta (RFC 8058; Gmail e Yahoo le
    /// chiedono a chi spedisce in quantità): il programma fa un POST allo stesso indirizzo.
    /// </summary>
    public static IReadOnlyDictionary<string, string> Intestazioni(string url) => new Dictionary<string, string>
    {
        ["List-Unsubscribe"] = $"<{url}>",
        ["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click",
    };
}
