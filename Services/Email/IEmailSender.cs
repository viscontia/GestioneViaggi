namespace GestioneViaggi.Services.Email;

public interface IEmailSender
{
    Task<bool> SendPasswordResetEmailAsync(string toEmail, string userName, string resetCode);

    /// <summary>
    /// Invia un'email HTML generica a uno o più destinatari.
    /// </summary>
    Task<bool> SendHtmlEmailAsync(IEnumerable<string> toEmails, string subject, string htmlBody, string? fromName = null, string? ccEmail = null);
}
