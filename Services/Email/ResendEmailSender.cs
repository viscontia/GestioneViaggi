using System.Net.Http.Json;
using System.Text.Json.Serialization;
using GestioneViaggi.Services.CRUD;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Email;

public class ResendEmailSender : IEmailSender
{
    private readonly HttpClient _httpClient;
    private readonly ApiConfigService _apiConfigService;
    private readonly ILogger<ResendEmailSender> _logger;

    private const string RESEND_API_URL = "https://api.resend.com/emails";
    private const string RESEND_SERVICE_CODE = "RESEND";

    private string? _cachedApiKey;
    private string? _cachedFromEmail;
    private bool _configLoaded;

    public ResendEmailSender(
        HttpClient httpClient,
        ApiConfigService apiConfigService,
        ILogger<ResendEmailSender> logger)
    {
        _httpClient = httpClient;
        _httpClient.Timeout = TimeSpan.FromSeconds(30);
        _apiConfigService = apiConfigService;
        _logger = logger;
    }

    private async Task EnsureConfigLoadedAsync()
    {
        if (_configLoaded) return;

        _cachedApiKey = await _apiConfigService.GetConfigValueAsync(RESEND_SERVICE_CODE, "API_KEY");
        _cachedFromEmail = await _apiConfigService.GetConfigValueAsync(RESEND_SERVICE_CODE, "FROM_EMAIL");
        _configLoaded = true;

        if (string.IsNullOrEmpty(_cachedApiKey))
            _logger.LogWarning("API key Resend non trovata in ana_api_config (RESEND/API_KEY)");
        if (string.IsNullOrEmpty(_cachedFromEmail))
            _logger.LogWarning("From email Resend non trovata in ana_api_config (RESEND/FROM_EMAIL)");
    }

    public async Task<bool> SendPasswordResetEmailAsync(string toEmail, string userName, string resetCode)
    {
        await EnsureConfigLoadedAsync();

        if (string.IsNullOrEmpty(_cachedApiKey) || string.IsNullOrEmpty(_cachedFromEmail))
        {
            _logger.LogError("Configurazione Resend incompleta. Impossibile inviare email di reset.");
            return false;
        }

        try
        {
            var subject = PasswordResetEmailTemplate.GetSubject();
            var htmlBody = PasswordResetEmailTemplate.GetHtmlBody(userName, resetCode);

            var request = new HttpRequestMessage(HttpMethod.Post, RESEND_API_URL);
            request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _cachedApiKey);
            request.Content = JsonContent.Create(new ResendEmailRequest
            {
                From = _cachedFromEmail,
                To = [toEmail],
                Subject = subject,
                Html = htmlBody
            });

            var response = await _httpClient.SendAsync(request);

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Email di reset password inviata via Resend a {Email}", toEmail);
                return true;
            }

            var errorContent = await response.Content.ReadAsStringAsync();
            _logger.LogError("Errore Resend API ({StatusCode}): {Error}", response.StatusCode, errorContent);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'invio email via Resend a {Email}", toEmail);
            return false;
        }
    }

    public async Task<bool> SendHtmlEmailAsync(IEnumerable<string> toEmails, string subject, string htmlBody, string? fromName = null, string? ccEmail = null)
    {
        await EnsureConfigLoadedAsync();

        if (string.IsNullOrEmpty(_cachedApiKey))
            throw new InvalidOperationException("API key Resend non configurata (RESEND/API_KEY in ana_api_config).");

        if (string.IsNullOrEmpty(_cachedFromEmail))
            throw new InvalidOperationException("From email Resend non configurata (RESEND/FROM_EMAIL in ana_api_config).");

        var fromAddress = _cachedFromEmail;
        if (!string.IsNullOrEmpty(fromName))
        {
            fromAddress = $"{fromName} <{_cachedFromEmail}>";
        }

        var recipients = toEmails.ToArray();

        var request = new HttpRequestMessage(HttpMethod.Post, RESEND_API_URL);
        request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _cachedApiKey);
        request.Content = JsonContent.Create(new ResendEmailRequest
        {
            From = fromAddress,
            To = recipients.Length == 1
                ? recipients               // Un solo destinatario → usa To diretto
                : [fromAddress],            // Più destinatari → To al mittente, BCC per privacy
            Cc = !string.IsNullOrWhiteSpace(ccEmail) ? [ccEmail] : [],
            Bcc = recipients.Length == 1
                ? []                        // Un solo destinatario → non serve BCC
                : recipients,
            Subject = subject,
            Html = htmlBody
        });

        var response = await _httpClient.SendAsync(request);

        if (response.IsSuccessStatusCode)
        {
            _logger.LogInformation("Email HTML inviata via Resend a {Count} destinatari", toEmails.Count());
            return true;
        }

        var errorContent = await response.Content.ReadAsStringAsync();
        _logger.LogError("Errore Resend API ({StatusCode}): {Error}", response.StatusCode, errorContent);
        throw new InvalidOperationException($"Resend API errore {(int)response.StatusCode}: {errorContent}");
    }

    private class ResendEmailRequest
    {
        [JsonPropertyName("from")]
        public string From { get; set; } = string.Empty;

        [JsonPropertyName("to")]
        public string[] To { get; set; } = [];

        [JsonPropertyName("cc")]
        public string[] Cc { get; set; } = [];

        [JsonPropertyName("bcc")]
        public string[] Bcc { get; set; } = [];

        [JsonPropertyName("subject")]
        public string Subject { get; set; } = string.Empty;

        [JsonPropertyName("html")]
        public string Html { get; set; } = string.Empty;
    }
}
