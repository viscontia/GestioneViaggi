using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Get/set della lingua preferita del cliente (ana_clienti.cliente_lingua), gestita come
/// side-field nella scheda cliente per non toccare la grande ClienteRepository (Blocco 11).
/// Il default è scritto dal backfill geo (465); l'operatore la sovrascrive qui.
/// </summary>
public sealed class ClienteLinguaService
{
    private readonly IDatabaseService _db;
    private readonly ILogger<ClienteLinguaService> _logger;

    public ClienteLinguaService(IDatabaseService db, ILogger<ClienteLinguaService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<string?> GetAsync(int clienteId)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_ana_clienti_get_lingua(@Id::integer)", conn);
            cmd.Parameters.AddWithValue("Id", clienteId);
            return (await cmd.ExecuteScalarAsync()) as string;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore lettura lingua cliente {Id}", clienteId);
            return null;
        }
    }

    public async Task<bool> SetAsync(int clienteId, string? lingua)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_ana_clienti_set_lingua(@Id::integer, @L::varchar)", conn);
            cmd.Parameters.AddWithValue("Id", clienteId);
            cmd.Parameters.AddWithValue("L", (object?)lingua ?? DBNull.Value);
            return Convert.ToInt32(await cmd.ExecuteScalarAsync()) > 0;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore salvataggio lingua cliente {Id}", clienteId);
            return false;
        }
    }
}
