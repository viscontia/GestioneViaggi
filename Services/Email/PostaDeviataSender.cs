using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Email;

/// <summary>
/// Posta di prova: ogni mail va all'indirizzo di collaudo, non ai destinatari veri.
///
/// ⛔️ Serve dal 2026-09-26, quando il database locale è tornato a contenere le email
/// VERE dei clienti (per provare davvero): senza, il gestionale di sviluppo avrebbe
/// mandato ai clienti newsletter, comunicazioni e «puoi completare l'iscrizione» di
/// prova. Lo stesso fa il sito Flask con MAIL_DIROTTA_A. Si accende solo con
/// «Posta:DeviaA» in appsettings.Development.json, cioè solo nella versione di
/// sviluppo: quella distribuita ai clienti non ce l'ha.
/// L'oggetto dice a chi sarebbe andata: «[PROVA → mario@esempio.it] …».
/// </summary>
public sealed class PostaDeviataSender : IEmailSender
{
    private readonly IEmailSender _vero;
    private readonly string _deviaA;
    private readonly ILogger _logger;

    public PostaDeviataSender(IEmailSender vero, string deviaA, ILogger logger)
    {
        _vero = vero;
        _deviaA = deviaA;
        _logger = logger;
    }

    public Task<bool> SendPasswordResetEmailAsync(string toEmail, string userName, string resetCode)
    {
        _logger.LogWarning("[POSTA DEVIATA] reset password per {Originale} → {DeviaA}", toEmail, _deviaA);
        return _vero.SendPasswordResetEmailAsync(_deviaA, userName, resetCode);
    }

    public Task<bool> SendHtmlEmailAsync(IEnumerable<string> toEmails, string subject, string htmlBody, string? fromName = null, string? ccEmail = null)
    {
        var originali = string.Join(", ", toEmails);
        _logger.LogWarning("[POSTA DEVIATA] {Originali} → {DeviaA}", originali, _deviaA);
        // Il cc sparisce: anche lui andrebbe a una persona vera.
        return _vero.SendHtmlEmailAsync(new[] { _deviaA }, $"[PROVA → {originali}] {subject}", htmlBody, fromName, null);
    }
}
