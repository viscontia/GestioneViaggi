namespace GestioneViaggi.Services.Email;

public interface IEmailSender
{
    Task<bool> SendPasswordResetEmailAsync(string toEmail, string userName, string resetCode);

    /// <summary>
    /// Invia un'email HTML generica a uno o più destinatari. <paramref name="intestazioni"/>: intestazioni in più
    /// (per la newsletter quelle della disiscrizione con un clic).
    /// </summary>
    Task<bool> SendHtmlEmailAsync(IEnumerable<string> toEmails, string subject, string htmlBody, string? fromName = null, string? ccEmail = null,
                                  IReadOnlyDictionary<string, string>? intestazioni = null);
}
