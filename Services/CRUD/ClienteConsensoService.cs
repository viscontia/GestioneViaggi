using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>Stato del consenso marketing di un cliente, con data e provenienza dell'ultimo cambio.</summary>
public sealed record ClienteConsenso(bool Consenso, DateTime? Data, string? Fonte);

/// <summary>
/// Get/set del consenso marketing del cliente (ana_clienti.consenso_marketing + _data + _fonte),
/// gestito come side-field nella scheda cliente per non toccare la grande ClienteRepository
/// (stesso schema di <see cref="ClienteLinguaService"/>, Blocco 11-B).
/// È il flag che filtra i destinatari in fn_web_destinatari_newsletter.
/// </summary>
public sealed class ClienteConsensoService
{
    private readonly IDatabaseService _db;
    private readonly ILogger<ClienteConsensoService> _logger;

    public ClienteConsensoService(IDatabaseService db, ILogger<ClienteConsensoService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<ClienteConsenso> GetAsync(int clienteId)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT consenso, data, fonte FROM fn_ana_clienti_get_consenso(@Id::integer)", conn);
            cmd.Parameters.AddWithValue("Id", clienteId);
            await using var r = await cmd.ExecuteReaderAsync();
            if (await r.ReadAsync())
            {
                return new ClienteConsenso(
                    !r.IsDBNull(0) && r.GetBoolean(0),
                    r.IsDBNull(1) ? null : r.GetDateTime(1),
                    r.IsDBNull(2) ? null : r.GetString(2));
            }
            return new ClienteConsenso(false, null, null);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore lettura consenso marketing cliente {Id}", clienteId);
            return new ClienteConsenso(false, null, null);
        }
    }

    /// <summary>
    /// Scrive il consenso. Se lo stato non cambia la function non tocca data/fonte, così un
    /// semplice risalvataggio della scheda non riscrive la data del consenso.
    /// </summary>
    public async Task<bool> SetAsync(int clienteId, bool consenso, string fonte = "gestionale")
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_ana_clienti_set_consenso(@Id::integer, @C::boolean, @F::varchar)", conn);
            cmd.Parameters.AddWithValue("Id", clienteId);
            cmd.Parameters.AddWithValue("C", consenso);
            cmd.Parameters.AddWithValue("F", fonte);
            await cmd.ExecuteScalarAsync();
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore salvataggio consenso marketing cliente {Id}", clienteId);
            return false;
        }
    }
}
