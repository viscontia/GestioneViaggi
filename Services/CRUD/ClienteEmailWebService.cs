using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// L'email di un cliente agganciata dal sito di iscrizione e non ancora confermata
/// (L12, SqlScripts/668). Finché nessuno la conferma, il cliente non riceve il codice
/// per modificare i suoi dati dal sito: la casella l'ha scritta chi compilava il
/// modulo. Qui la scheda cliente chiede se c'è da confermare, e conferma.
/// </summary>
public sealed class ClienteEmailWebService
{
    private readonly IDatabaseService _db;
    private readonly ILogger<ClienteEmailWebService> _logger;

    public ClienteEmailWebService(IDatabaseService db, ILogger<ClienteEmailWebService> logger)
    {
        _db = db;
        _logger = logger;
    }

    /// <summary>True se l'email attuale della scheda è quella agganciata dal sito.</summary>
    public async Task<bool> DaConfermareAsync(int clienteId, int aziendaId)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_email_da_confermare(@Id::integer, @Az::integer)", conn);
            cmd.Parameters.AddWithValue("Id", clienteId);
            cmd.Parameters.AddWithValue("Az", aziendaId);
            return await cmd.ExecuteScalarAsync() is true;
        }
        catch (Exception ex)
        {
            // Senza risposta non si mostra niente: il bottone non è indispensabile,
            // e un errore qui non deve impedire di aprire la scheda.
            _logger.LogError(ex, "Errore lettura email da confermare, cliente {Id}", clienteId);
            return false;
        }
    }

    /// <summary>Conferma l'email: da qui il codice del sito può partire.</summary>
    public async Task<bool> ConfermaAsync(int clienteId, int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT fn_web_email_conferma(@Id::integer, @Az::integer)", conn);
        cmd.Parameters.AddWithValue("Id", clienteId);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        return await cmd.ExecuteScalarAsync() is true;
    }
}
