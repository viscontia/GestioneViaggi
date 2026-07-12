using Npgsql;
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
    private readonly GestioneViaggi.Services.Security.ISecretKeyProvider _secretKey;

    public EmailSenderFactory(
        IDatabaseService databaseService,
        ResendEmailSender resendSender,
        ILogger<SmtpEmailSender> smtpLogger,
        ILogger<EmailSenderFactory> logger,
        GestioneViaggi.Services.Security.ISecretKeyProvider secretKey)
    {
        _databaseService = databaseService;
        _resendSender = resendSender;
        _smtpLogger = smtpLogger;
        _logger = logger;
        _secretKey = secretKey;
    }

    public async Task<IEmailSender> GetSenderAsync(string? roleCode, int? aziendaId)
    {
        // 1. Se l'azienda ha SMTP configurato, usalo (vale per tutti i ruoli, incluso SuperAdmin)
        if (aziendaId.HasValue)
        {
            var hasSmtp = await HasActiveSmtpConfigAsync(aziendaId.Value);
            if (hasSmtp)
            {
                _logger.LogInformation("Azienda {AziendaId} ha SMTP configurato: uso SMTP aziendale", aziendaId.Value);
                return new SmtpEmailSender(_databaseService, _smtpLogger, aziendaId.Value, _secretKey.GetMasterKey());
            }
        }

        // 2. Fallback → Resend
        _logger.LogInformation("Nessun SMTP aziendale disponibile: fallback a Resend");
        return _resendSender;
    }

    private async Task<bool> HasActiveSmtpConfigAsync(int aziendaId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_get_smtp_config_for_email(@AziendaId, @Master)", (NpgsqlConnection)connection);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);
            cmd.Parameters.AddWithValue("Master", _secretKey.GetMasterKey());
            var result = await cmd.ExecuteScalarAsync() as string;
            return !string.IsNullOrEmpty(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore verifica SMTP per azienda {AziendaId}", aziendaId);
            return false;
        }
    }
}
