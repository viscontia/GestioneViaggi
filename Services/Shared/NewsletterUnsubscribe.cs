using System.Security.Cryptography;
using System.Text;

namespace GestioneViaggi.Services.Shared;

/// <summary>
/// Link di disiscrizione firmato HMAC (Blocco 11). Uniforme per clienti e iscritti (nessun token
/// per-cliente richiesto). Il click lo gestisce il sito pubblico (Fase 3): verifica la firma con
/// lo stesso segreto per-azienda (ana_aziende.token_iscrizione) e aggiunge una soppressione.
/// </summary>
public static class NewsletterUnsubscribe
{
    public static string Sign(string email, string secret)
    {
        using var h = new HMACSHA256(Encoding.UTF8.GetBytes(secret ?? string.Empty));
        var hash = h.ComputeHash(Encoding.UTF8.GetBytes((email ?? string.Empty).Trim().ToLowerInvariant()));
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    /// <summary><c>{baseUrl}/unsubscribe?email=&lt;e&gt;&amp;sig=&lt;hmac(email, secret)&gt;</c></summary>
    public static string BuildUrl(string? baseUrl, string email, string? secret)
    {
        var b = string.IsNullOrWhiteSpace(baseUrl) ? "https://www.example.com" : baseUrl!.Trim().TrimEnd('/');
        var sig = Sign(email, secret ?? string.Empty);
        return $"{b}/unsubscribe?email={Uri.EscapeDataString(email)}&sig={sig}";
    }
}
