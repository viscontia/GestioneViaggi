using System.Text.Json;
using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Email;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Authentication;

public class PasswordResetService
{
    private readonly IDatabaseService _databaseService;
    private readonly EmailSenderFactory _emailSenderFactory;
    private readonly ILogger<PasswordResetService> _logger;

    public PasswordResetService(
        IDatabaseService databaseService,
        EmailSenderFactory emailSenderFactory,
        ILogger<PasswordResetService> logger)
    {
        _databaseService = databaseService;
        _emailSenderFactory = emailSenderFactory;
        _logger = logger;
    }

    /// <summary>
    /// Richiede il reset della password. Genera un codice a 6 cifre e invia email.
    /// Per sicurezza anti-enumeration, ritorna sempre un messaggio generico al chiamante.
    /// </summary>
    public async Task<(bool Success, string Message)> RequestResetAsync(string email)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var resultJson = await connection.ExecuteScalarAsync<string>(
                "SELECT fn_app_request_password_reset(@Email::citext)",
                new { Email = email }
            );

            if (string.IsNullOrEmpty(resultJson))
            {
                _logger.LogError("fn_app_request_password_reset ha restituito un risultato vuoto per {Email}", email);
                return (false, "Errore di sistema. Riprova più tardi.");
            }

            var response = JsonSerializer.Deserialize<PasswordResetResponse>(resultJson, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
            });

            if (response == null)
            {
                _logger.LogError("Impossibile deserializzare risposta reset per {Email}", email);
                return (false, "Errore di sistema. Riprova più tardi.");
            }

            // Rate limited
            if (!response.Success && response.ErrorCode == "RATE_LIMITED")
            {
                return (false, response.ErrorMessage ?? "Troppi tentativi. Riprova tra 15 minuti.");
            }

            // Utente non trovato → anti-enumeration: messaggio generico di successo
            if (response.Success && !response.UserFound)
            {
                _logger.LogInformation("Reset richiesto per email non registrata: {Email} (anti-enumeration)", email);
                return (true, "Se l'email è registrata, riceverai un codice di verifica.");
            }

            // Utente trovato → invia email
            if (response.Success && response.UserFound && !string.IsNullOrEmpty(response.ResetCode))
            {
                var sender = await _emailSenderFactory.GetSenderAsync(response.RoleCode, response.AziendaId);
                var emailSent = await sender.SendPasswordResetEmailAsync(
                    response.Email ?? email,
                    response.Nome ?? "Utente",
                    response.ResetCode
                );

                if (!emailSent)
                {
                    _logger.LogError("Invio email di reset fallito per {Email}", email);
                    return (false, "Errore nell'invio dell'email. Riprova più tardi.");
                }

                _logger.LogInformation("Codice di reset inviato con successo a {Email}", email);
                return (true, "Se l'email è registrata, riceverai un codice di verifica.");
            }

            return (false, response.ErrorMessage ?? "Errore di sistema. Riprova più tardi.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante richiesta reset password per {Email}", email);
            return (false, "Errore di sistema. Riprova più tardi.");
        }
    }

    /// <summary>
    /// Valida il codice di reset inserito dall'utente.
    /// </summary>
    public async Task<(bool IsValid, string? UserId, string? Email, string Message)> ValidateCodeAsync(string resetCode)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var result = await connection.ExecuteScalarAsync<string>(
                "SELECT validate_reset_token(@Token)",
                new { Token = resetCode }
            );

            if (string.IsNullOrEmpty(result) || result == "INVALID_OR_EXPIRED")
            {
                return (false, null, null, "Codice non valido o scaduto. Richiedi un nuovo codice.");
            }

            if (result.StartsWith("ERROR:"))
            {
                _logger.LogError("Errore validazione token: {Error}", result);
                return (false, null, null, "Errore di sistema. Riprova più tardi.");
            }

            // Formato: VALID|user_id|email
            if (result.StartsWith("VALID|"))
            {
                var parts = result.Split('|');
                if (parts.Length >= 3)
                {
                    return (true, parts[1], parts[2], "Codice verificato con successo.");
                }
            }

            return (false, null, null, "Errore nella validazione del codice.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante validazione codice di reset");
            return (false, null, null, "Errore di sistema. Riprova più tardi.");
        }
    }

    /// <summary>
    /// Reimposta la password usando il codice di reset e la nuova password.
    /// </summary>
    public async Task<(bool Success, string Message)> ResetPasswordAsync(string resetCode, string newPassword)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            // Usa la versione che accetta password in chiaro (il DB fa l'hashing con bcrypt)
            var result = await connection.ExecuteScalarAsync<string>(
                "SELECT reset_password_with_token(@Token, @NewPassword::text)",
                new { Token = resetCode, NewPassword = newPassword }
            );

            if (result == "SUCCESS")
            {
                _logger.LogInformation("Password reimpostata con successo tramite token");
                return (true, "Password reimpostata con successo. Puoi ora accedere con la nuova password.");
            }

            if (result == "INVALID_OR_EXPIRED_TOKEN")
            {
                return (false, "Codice non valido o scaduto. Richiedi un nuovo codice.");
            }

            _logger.LogError("Errore reset password: {Result}", result);
            return (false, "Errore durante il reset della password. Riprova.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il reset della password");
            return (false, "Errore di sistema. Riprova più tardi.");
        }
    }
}
