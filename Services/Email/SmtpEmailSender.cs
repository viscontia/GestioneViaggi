using System.Text.Json;
using Dapper;
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

    public SmtpEmailSender(
        IDatabaseService databaseService,
        ILogger<SmtpEmailSender> logger,
        int aziendaId)
    {
        _databaseService = databaseService;
        _logger = logger;
        _aziendaId = aziendaId;
    }

    public async Task<bool> SendPasswordResetEmailAsync(string toEmail, string userName, string resetCode)
    {
        try
        {
            // Recupera config SMTP dall'azienda
            await using var connection = await _databaseService.GetConnectionAsync();
            var configJson = await connection.ExecuteScalarAsync<string>(
                "SELECT fn_get_smtp_config_for_email(@AziendaId)",
                new { AziendaId = _aziendaId }
            );

            if (string.IsNullOrEmpty(configJson))
            {
                _logger.LogWarning("Nessuna configurazione SMTP trovata per azienda {AziendaId}", _aziendaId);
                return false;
            }

            var config = JsonSerializer.Deserialize<SmtpConfig>(configJson, new JsonSerializerOptions
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
            _logger.LogError(ex, "Errore invio email via SMTP aziendale (azienda {AziendaId}) a {Email}",
                _aziendaId, toEmail);
            return false;
        }
    }

    public async Task<bool> SendHtmlEmailAsync(IEnumerable<string> toEmails, string subject, string htmlBody, string? fromName = null, string? ccEmail = null)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var configJson = await connection.ExecuteScalarAsync<string>(
                "SELECT fn_get_smtp_config_for_email(@AziendaId)",
                new { AziendaId = _aziendaId }
            );

            if (string.IsNullOrEmpty(configJson))
            {
                _logger.LogWarning("Nessuna configurazione SMTP trovata per azienda {AziendaId}", _aziendaId);
                return false;
            }

            var config = JsonSerializer.Deserialize<SmtpConfig>(configJson, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            if (config == null)
            {
                _logger.LogError("Impossibile deserializzare configurazione SMTP per azienda {AziendaId}", _aziendaId);
                return false;
            }

            var message = new MimeMessage();
            message.From.Add(new MailboxAddress(fromName ?? config.FromName, config.FromEmail));

            // BCC per proteggere la privacy dei destinatari
            foreach (var email in toEmails)
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

            _logger.LogInformation(
                "Email HTML inviata via SMTP aziendale (azienda {AziendaId}) a {Count} destinatari",
                _aziendaId, toEmails.Count());
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore invio email HTML via SMTP aziendale (azienda {AziendaId})", _aziendaId);
            return false;
        }
    }

    private class SmtpConfig
    {
        public string Host { get; set; } = string.Empty;
        public int Port { get; set; }
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public bool UseTls { get; set; }
        public bool UseStarttls { get; set; }
        public string? SecurityMethod { get; set; }
        public string FromName { get; set; } = string.Empty;
        public string FromEmail { get; set; } = string.Empty;
    }
}
