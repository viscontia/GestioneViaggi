using System;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

public static class WebsiteValidator
{
    public static ValidationResult CheckWebsite(string? website)
    {
        if (string.IsNullOrWhiteSpace(website))
            return ValidationResult.Success();

        var trimmed = website.Trim();

        if (!Uri.TryCreate(trimmed, UriKind.Absolute, out Uri? uriResult))
            return ValidationResult.Failure(ValidationMessages.WebsiteInvalid, "CHK_WEB_001");

        if (uriResult.Scheme != Uri.UriSchemeHttp && uriResult.Scheme != Uri.UriSchemeHttps)
            return ValidationResult.Failure(ValidationMessages.WebsiteInvalid, "CHK_WEB_002");

        return ValidationResult.Success();
    }
}
