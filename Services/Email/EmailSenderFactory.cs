using Dapper;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Email;

public class EmailSenderFactory
{
    private readonly IDatabaseService _databaseService;
    private readonly ResendEmailSender _resendSender;
    private readonly ILogger<SmtpEmailSender> _smtpLogger;
    private readonly ILogger<EmailSenderFactory> _logger;

    public EmailSenderFactory(
        IDatabaseService databaseService,
        ResendEmailSender resendSender,
        ILogger<SmtpEmailSender> smtpLogger,
        ILogger<EmailSenderFactory> logger)
    {
        _databaseService = databaseService;
        _resendSender = resendSender;
        _smtpLogger = smtpLogger;
        _logger = logger;
    }

    public async Task<IEmailSender> GetSenderAsync(string? roleCode, int? aziendaId)
    {
        // 1. SuperAdmin → Resend
        if (string.Equals(roleCode, "superadmin", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogInformation("Utente SuperAdmin: uso Resend per invio email");
            return _resendSender;
        }

        // 2. Utente con azienda → controlla SMTP aziendale
        if (aziendaId.HasValue)
        {
            var hasSmtp = await HasActiveSmtpConfigAsync(aziendaId.Value);
            if (hasSmtp)
            {
                _logger.LogInformation("Azienda {AziendaId} ha SMTP configurato: uso SMTP aziendale", aziendaId.Value);
                return new SmtpEmailSender(_databaseService, _smtpLogger, aziendaId.Value);
            }

            _logger.LogInformation("Azienda {AziendaId} senza SMTP: fallback a Resend", aziendaId.Value);
        }

        // 3. Default → Resend
        return _resendSender;
    }

    private async Task<bool> HasActiveSmtpConfigAsync(int aziendaId)
    {
        try
        {
            using var connection = await _databaseService.GetConnectionAsync();
            var result = await connection.ExecuteScalarAsync<string>(
                "SELECT fn_get_smtp_config_for_email(@AziendaId)",
                new { AziendaId = aziendaId }
            );
            return !string.IsNullOrEmpty(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore verifica SMTP per azienda {AziendaId}", aziendaId);
            return false;
        }
    }
}
