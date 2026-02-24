namespace GestioneViaggi.Services.Email;

public static class PasswordResetEmailTemplate
{
    public static string GetSubject() => "Codice di reset password - Gestione Viaggi";

    public static string GetHtmlBody(string userName, string resetCode)
    {
        return $@"
<!DOCTYPE html>
<html lang=""it"">
<head>
    <meta charset=""UTF-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
</head>
<body style=""margin:0;padding:0;background-color:#f4f4f5;font-family:'Segoe UI',Roboto,Arial,sans-serif;"">
    <table width=""100%"" cellpadding=""0"" cellspacing=""0"" style=""background-color:#f4f4f5;padding:40px 0;"">
        <tr>
            <td align=""center"">
                <table width=""480"" cellpadding=""0"" cellspacing=""0"" style=""background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);"">
                    <!-- Header -->
                    <tr>
                        <td style=""background-color:#111827;padding:28px 32px;text-align:center;"">
                            <h1 style=""color:#ffffff;margin:0;font-size:20px;font-weight:600;"">Gestione Viaggi</h1>
                        </td>
                    </tr>
                    <!-- Body -->
                    <tr>
                        <td style=""padding:32px;"">
                            <p style=""color:#374151;font-size:15px;margin:0 0 16px;"">Ciao <strong>{System.Net.WebUtility.HtmlEncode(userName)}</strong>,</p>
                            <p style=""color:#374151;font-size:15px;margin:0 0 24px;"">Hai richiesto il reset della tua password. Inserisci il seguente codice nell'applicazione:</p>
                            <!-- Code Box -->
                            <div style=""background-color:#f9fafb;border:2px solid #e5e7eb;border-radius:8px;padding:20px;text-align:center;margin:0 0 24px;"">
                                <span style=""font-size:36px;font-weight:700;letter-spacing:8px;color:#111827;font-family:'Courier New',monospace;"">{resetCode}</span>
                            </div>
                            <p style=""color:#6b7280;font-size:13px;margin:0 0 8px;"">Questo codice scade tra <strong>15 minuti</strong>.</p>
                            <p style=""color:#6b7280;font-size:13px;margin:0;"">Se non hai richiesto tu il reset della password, puoi ignorare questa email.</p>
                        </td>
                    </tr>
                    <!-- Footer -->
                    <tr>
                        <td style=""background-color:#f9fafb;padding:20px 32px;border-top:1px solid #e5e7eb;"">
                            <p style=""color:#9ca3af;font-size:12px;margin:0;text-align:center;"">Questa email è stata generata automaticamente. Non rispondere a questo messaggio.</p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>";
    }
}
