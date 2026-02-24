namespace GestioneViaggi.Services.Email;

public interface IEmailSender
{
    Task<bool> SendPasswordResetEmailAsync(string toEmail, string userName, string resetCode);
}
