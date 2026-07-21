using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Service DB-First per preferenze utente generiche "nascoste" (key-value), tabella sys_utente_preferenze.
/// Nessuna UI di gestione: usato per salvare/ripristinare preferenze UI per-utente (es. slider dimensione miniature).
/// </summary>
public class UserPreferenzeService
{
    private readonly IDatabaseService _databaseService;
    private readonly ITenantContext _tenantContext;
    private readonly ILogger<UserPreferenzeService> _logger;

    public UserPreferenzeService(
        IDatabaseService databaseService,
        ITenantContext tenantContext,
        ILogger<UserPreferenzeService> logger)
    {
        _databaseService = databaseService;
        _tenantContext = tenantContext;
        _logger = logger;
    }

    /// <summary>
    /// Legge una preferenza dell'utente corrente. Ritorna null se non impostata o se non c'è un utente in sessione.
    /// </summary>
    public async Task<string?> GetAsync(string chiave)
    {
        try
        {
            var user = await _tenantContext.GetCurrentUserAsync();
            if (user == null)
            {
                return null;
            }

            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_sys_utente_pref_get(@UtenteId, @Chiave)", conn);
            cmd.Parameters.AddWithValue("UtenteId", user.UserId);
            cmd.Parameters.AddWithValue("Chiave", chiave);

            var result = await cmd.ExecuteScalarAsync();
            return result == null || result == DBNull.Value ? null : (string)result;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Errore durante la lettura della preferenza utente {Chiave}", chiave);
            return null;
        }
    }

    /// <summary>
    /// Salva (upsert) una preferenza dell'utente corrente. No-op se non c'è un utente in sessione.
    /// </summary>
    public async Task SetAsync(string chiave, string valore)
    {
        try
        {
            var user = await _tenantContext.GetCurrentUserAsync();
            if (user == null)
            {
                return;
            }

            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_sys_utente_pref_set(@UtenteId, @Chiave, @Valore)", conn);
            cmd.Parameters.AddWithValue("UtenteId", user.UserId);
            cmd.Parameters.AddWithValue("Chiave", chiave);
            cmd.Parameters.AddWithValue("Valore", valore);

            await cmd.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Errore durante il salvataggio della preferenza utente {Chiave}", chiave);
        }
    }
}
