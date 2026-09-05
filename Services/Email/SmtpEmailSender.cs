using System.Text.Json;
using Npgsql;
using GestioneViaggi.Services.Database;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Logging;
using MimeKit;

namespace GestioneViaggi.Services.Email;

public class SmtpEmailSender : IEmailSender
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<SmtpEmailSender> _logger;
    private readonly int _aziendaId;
    private readonly string _masterKey;

    public SmtpEmailSender(
        IDatabaseService databaseService,
        ILogger<SmtpEmailSender> logger,
        int aziendaId,
        string masterKey)
    {
        _databaseService = databaseService;
        _logger = logger;
        _aziendaId = aziendaId;
        _masterKey = masterKey;
    }

    public async Task<bool> SendPasswordResetEmailAsync(string toEmail, string userName, string resetCode)
    {
        SmtpConfig? config = null;
        try
        {
            // Recupera config SMTP dall'azienda
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT fn_get_smtp_config_for_email(@AziendaId, @Master)";
            await using var cmd = new NpgsqlCommand(sql, (NpgsqlConnection)connection);
            cmd.Parameters.AddWithValue("AziendaId", _aziendaId);
            cmd.Parameters.AddWithValue("Master", _masterKey);
            var configJson = await cmd.ExecuteScalarAsync() as string;

            if (string.IsNullOrEmpty(configJson))
            {
                _logger.LogWarning("Nessuna configurazione SMTP trovata per azienda {AziendaId}", _aziendaId);
                return false;
            }

            config = JsonSerializer.Deserialize<SmtpConfig>(configJson, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            if (config == null)
            {
                _logger.LogError("Impossibile deserializzare configurazione SMTP per azienda {AziendaId}", _aziendaId);
                return false;
            }

            // Costruisci il messaggio
            var message = new MimeMessage();
            message.From.Add(new MailboxAddress(config.FromName, config.FromEmail));
            message.To.Add(new MailboxAddress(userName, toEmail));
            message.Subject = PasswordResetEmailTemplate.GetSubject();

            var bodyBuilder = new BodyBuilder
            {
                HtmlBody = PasswordResetEmailTemplate.GetHtmlBody(userName, resetCode)
            };
            message.Body = bodyBuilder.ToMessageBody();

            // Invia tramite MailKit
            using var client = new SmtpClient();
            client.Timeout = 30_000;
            client.ServerCertificateValidationCallback = CertificatoServerPosta.Validatore(_logger, config.Host);

            var secureSocketOptions = config.SecurityMethod?.ToLower() switch
            {
                "ssl" or "tls" => SecureSocketOptions.SslOnConnect,
                "starttls" => SecureSocketOptions.StartTls,
                "none" => SecureSocketOptions.None,
                _ => SecureSocketOptions.Auto
            };

            await client.ConnectAsync(config.Host, config.Port, secureSocketOptions);
            await client.AuthenticateAsync(config.Username, config.Password);
            await client.SendAsync(message);
            await client.DisconnectAsync(true);

            _logger.LogInformation("Email di reset password inviata via SMTP aziendale (azienda {AziendaId}) a {Email}",
                _aziendaId, toEmail);
            return true;
        }
        catch (Exception ex)
        {
            var motivo = SmtpErrorTranslator.Translate(ex, SmtpPhase.Connect, config?.Host ?? "?", config?.Port ?? 0);
            _logger.LogError(ex, "Errore invio reset password (azienda {AziendaId}) a {Email}: {Motivo}",
                _aziendaId, toEmail, motivo);
            return false;
        }
    }

    public async Task<bool> SendHtmlEmailAsync(IEnumerable<string> toEmails, string subject, string htmlBody, string? fromName = null, string? ccEmail = null)
    {
        SmtpConfig? config = null;
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT fn_get_smtp_config_for_email(@AziendaId, @Master)";
            await using var cmd = new NpgsqlCommand(sql, (NpgsqlConnection)connection);
            cmd.Parameters.AddWithValue("AziendaId", _aziendaId);
            cmd.Parameters.AddWithValue("Master", _masterKey);
            var configJson = await cmd.ExecuteScalarAsync() as string;

            if (string.IsNullOrEmpty(configJson))
            {
                _logger.LogWarning("Nessuna configurazione SMTP trovata per azienda {AziendaId}", _aziendaId);
                throw new InvalidOperationException($"Nessuna configurazione SMTP attiva trovata per questa azienda (ID: {_aziendaId}).");
            }

            config = JsonSerializer.Deserialize<SmtpConfig>(configJson, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            if (config == null)
            {
                _logger.LogError("Impossibile deserializzare configurazione SMTP per azienda {AziendaId}", _aziendaId);
                throw new InvalidOperationException("Configurazione SMTP non valida (deserializzazione fallita).");
            }

            var message = new MimeMessage();
            message.From.Add(new MailboxAddress(fromName ?? config.FromName, config.FromEmail));

            // To visibile obbligatorio (molti server SMTP rifiutano messaggi senza header To)
            message.To.Add(new MailboxAddress(fromName ?? config.FromName, config.FromEmail));

            // BCC per proteggere la privacy dei destinatari
            foreach (var email in toEmails.Where(e => !string.IsNullOrWhiteSpace(e)))
            {
                message.Bcc.Add(MailboxAddress.Parse(email));
            }

            // CC all'utente che ha inviato l'email
            if (!string.IsNullOrWhiteSpace(ccEmail))
            {
                message.Cc.Add(MailboxAddress.Parse(ccEmail));
            }

            message.Subject = subject;

            var bodyBuilder = new BodyBuilder { HtmlBody = htmlBody };
            message.Body = bodyBuilder.ToMessageBody();

            using var client = new SmtpClient();
            client.Timeout = 30_000; // 30 secondi max per connessione/autenticazione/invio
            client.ServerCertificateValidationCallback = CertificatoServerPosta.Validatore(_logger, config.Host);
            var secureSocketOptions = config.SecurityMethod?.ToLower() switch
            {
                "ssl" or "tls" => SecureSocketOptions.SslOnConnect,
                "starttls" => SecureSocketOptions.StartTls,
                "none" => SecureSocketOptions.None,
                _ => SecureSocketOptions.Auto
            };

            _logger.LogInformation(
                "SMTP connessione: host={Host} port={Port} security={Security} user={User} fromEmail={FromEmail}",
                config.Host, config.Port, config.SecurityMethod, config.Username, config.FromEmail);

            await client.ConnectAsync(config.Host, config.Port, secureSocketOptions);
            await client.AuthenticateAsync(config.Username, config.Password);
            await client.SendAsync(message);
            await client.DisconnectAsync(true);

            _logger.LogInformation(
                "Email HTML inviata via SMTP aziendale (azienda {AziendaId}) a {Count} destinatari",
                _aziendaId, toEmails.Count());
            return true;
        }
        catch (InvalidOperationException)
        {
            throw; // messaggi di configurazione già chiari (es. "Nessuna configurazione SMTP attiva")
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore invio email HTML via SMTP aziendale (azienda {AziendaId})", _aziendaId);
            throw new InvalidOperationException(
                SmtpErrorTranslator.Translate(ex, SmtpPhase.Connect, config?.Host ?? "?", config?.Port ?? 0), ex);
        }
    }

    private class SmtpConfig
    {
        public string Host { get; set; } = string.Empty;
        public int Port { get; set; }
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        [System.Text.Json.Serialization.JsonPropertyName("use_tls")]
        public bool UseTls { get; set; }
        [System.Text.Json.Serialization.JsonPropertyName("use_starttls")]
        public bool UseStarttls { get; set; }
        [System.Text.Json.Serialization.JsonPropertyName("security_method")]
        public string? SecurityMethod { get; set; }
        [System.Text.Json.Serialization.JsonPropertyName("from_name")]
        public string FromName { get; set; } = string.Empty;
        [System.Text.Json.Serialization.JsonPropertyName("from_email")]
        public string FromEmail { get; set; } = string.Empty;
    }
}
