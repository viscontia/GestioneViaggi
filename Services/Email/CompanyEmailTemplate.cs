namespace GestioneViaggi.Services.Email;

/// <summary>
/// Template HTML generico per email aziendali.
/// Supporta contesto viaggio opzionale (nome viaggio, range date).
/// </summary>
public static class CompanyEmailTemplate
{
    public static string GetHtmlBody(
        string? logoBase64,
        string? logoMimeType,
        string companyName,
        string? tripName,
        string? dateRange,
        string userHtmlContent,
        DateTime sendDateTime,
        string? companyWebsite = null,
        string? companyPhone = null)
    {
        var logoHtml = "";
        if (!string.IsNullOrEmpty(logoBase64) && !string.IsNullOrEmpty(logoMimeType))
        {
            logoHtml = $@"
                    <tr>
                        <td style=""padding:24px 32px 8px 32px;"">
                            <img src=""data:{logoMimeType};base64,{logoBase64}""
                                 alt=""{System.Net.WebUtility.HtmlEncode(companyName)}""
                                 style=""max-width:200px;height:auto;display:block;"" />
                        </td>
                    </tr>";
        }

        var encodedCompany = System.Net.WebUtility.HtmlEncode(companyName);
        var formattedSendDate = sendDateTime.ToString("dd/MM/yyyy 'alle ore' HH:mm");

        // Sezioni viaggio: renderizzate solo se fornite
        var tripNameHtml = "";
        if (!string.IsNullOrWhiteSpace(tripName))
        {
            var encodedTrip = System.Net.WebUtility.HtmlEncode(tripName);
            tripNameHtml = $@"
                    <!-- Nome Viaggio -->
                    <tr>
                        <td style=""padding:8px 32px 4px 32px;"">
                            <h2 style=""margin:0;font-size:20px;color:#2171A5;font-weight:400;font-style:italic;font-family:Georgia,'Times New Roman',serif;"">
                                {encodedTrip}
                            </h2>
                        </td>
                    </tr>";
        }

        var dateRangeHtml = "";
        if (!string.IsNullOrWhiteSpace(dateRange))
        {
            var encodedDateRange = System.Net.WebUtility.HtmlEncode(dateRange);
            dateRangeHtml = $@"
                    <!-- Range Date -->
                    <tr>
                        <td style=""padding:4px 32px 16px 32px;"">
                            <p style=""margin:0;font-size:14px;color:#2E8B8B;font-weight:500;"">
                                {encodedDateRange}
                            </p>
                        </td>
                    </tr>";
        }

        var footerContactLine = "";
        if (!string.IsNullOrEmpty(companyWebsite) || !string.IsNullOrEmpty(companyPhone))
        {
            var parts = new List<string>();
            if (!string.IsNullOrEmpty(companyPhone))
                parts.Add($"Tel: {System.Net.WebUtility.HtmlEncode(companyPhone)}");
            if (!string.IsNullOrEmpty(companyWebsite))
                parts.Add($"<a href=\"{System.Net.WebUtility.HtmlEncode(companyWebsite)}\" style=\"color:#6b7280;\">{System.Net.WebUtility.HtmlEncode(companyWebsite)}</a>");
            footerContactLine = $"<p style=\"color:#9ca3af;font-size:11px;margin:4px 0 0;text-align:center;\">{string.Join(" | ", parts)}</p>";
        }

        return $@"
<!DOCTYPE html>
<html lang=""it"">
<head>
    <meta charset=""UTF-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
</head>
<body style=""margin:0;padding:0;background-color:#f0f0f0;font-family:'Segoe UI',Roboto,Arial,sans-serif;"">
    <table width=""100%"" cellpadding=""0"" cellspacing=""0"" style=""background-color:#f0f0f0;padding:40px 0;"">
        <tr>
            <td align=""center"">
                <table width=""600"" cellpadding=""0"" cellspacing=""0"" style=""background-color:#ffffff;border-radius:8px;overflow:hidden;border:1px solid #e0e0e0;"">

                    <!-- HEADER: Logo su riga dedicata + Nome Azienda -->
                    {logoHtml}
                    <tr>
                        <td style=""padding:{(string.IsNullOrEmpty(logoHtml) ? "24px" : "8px")} 32px 16px 32px;"">
                            <h1 style=""margin:0;font-size:22px;font-weight:400;font-style:italic;color:#4A90A4;font-family:Georgia,'Times New Roman',serif;"">
                                {encodedCompany}
                            </h1>
                        </td>
                    </tr>

                    <!-- Linea Separatrice Blu -->
                    <tr>
                        <td style=""padding:0 32px;"">
                            <hr style=""border:none;border-top:2px solid #4A90A4;margin:0;"" />
                        </td>
                    </tr>

                    <!-- Data e Ora Invio -->
                    <tr>
                        <td style=""padding:16px 32px 8px 32px;"">
                            <p style=""margin:0;font-size:13px;color:#2171A5;font-weight:bold;"">
                                Data e Ora Invio: {formattedSendDate}
                            </p>
                        </td>
                    </tr>

                    {tripNameHtml}
                    {dateRangeHtml}

                    <!-- Contenuto Utente (Rich Text) -->
                    <tr>
                        <td style=""padding:16px 32px 24px 32px;"">
                            <div style=""font-size:14px;line-height:1.6;color:#333333;"">
                                {userHtmlContent}
                            </div>
                        </td>
                    </tr>

                    <!-- FOOTER -->
                    <tr>
                        <td style=""background-color:#e8e8e8;padding:16px 32px;border-top:1px solid #d0d0d0;"">
                            <p style=""color:#9ca3af;font-size:11px;margin:0;text-align:center;font-style:italic;"">
                                Questa email è stata inviata da {encodedCompany}.
                                Se hai ricevuto questo messaggio per errore, ti preghiamo di ignorarlo.
                            </p>
                            {footerContactLine}
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
