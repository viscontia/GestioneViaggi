using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>Un campo di una proposta: il valore in archivio accanto a quello proposto.</summary>
public sealed record PropostaCampo(long PropostaId, DateTime CreataIl, string EmailProponente,
                                   string Campo, string Etichetta, string? InArchivio, string? Proposto);

/// <summary>Chi approvare avvisare: l'email da cui è arrivata la proposta, e il nome in scheda.</summary>
public sealed record PropostaApprovata(string Email, string Cognome, string Nome);

/// <summary>
/// Le correzioni di documento e recapiti proposte dal cliente sul sito (L12-bis,
/// SqlScripts/669-670). Non toccano la scheda finché qui non si approvano; l'approvazione
/// passa da fn_ana_clienti_update, con la stessa validazione della scheda cliente.
/// </summary>
public sealed class ClienteProposteWebService
{
    private readonly IDatabaseService _db;
    private readonly ILogger<ClienteProposteWebService> _logger;

    public ClienteProposteWebService(IDatabaseService db, ILogger<ClienteProposteWebService> logger)
    {
        _db = db;
        _logger = logger;
    }

    /// <summary>La proposta in attesa per il cliente, un elemento per campo (vuota se non c'è).</summary>
    public async Task<List<PropostaCampo>> GetInAttesaAsync(int clienteId, int aziendaId)
    {
        var righe = new List<PropostaCampo>();
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT proposta_id, creata_il, email_proponente, campo, etichetta, in_archivio, proposto " +
                "FROM fn_web_proposta_del_cliente(@Id::integer, @Az::integer)", conn);
            cmd.Parameters.AddWithValue("Id", clienteId);
            cmd.Parameters.AddWithValue("Az", aziendaId);
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
            {
                righe.Add(new PropostaCampo(r.GetInt64(0), r.GetDateTime(1), r.GetString(2), r.GetString(3),
                    r.GetString(4), r.IsDBNull(5) ? null : r.GetString(5), r.IsDBNull(6) ? null : r.GetString(6)));
            }
        }
        catch (Exception ex)
        {
            // Senza risposta il riquadro non compare: la scheda si apre comunque.
            _logger.LogError(ex, "Errore lettura proposta dal sito, cliente {Id}", clienteId);
        }
        return righe;
    }

    /// <summary>
    /// Approva: la scheda cambia. Se la validazione rifiuta i dati solleva
    /// <see cref="PostgresException"/> con il messaggio da mostrare, e niente cambia.
    /// </summary>
    public async Task<PropostaApprovata?> ApprovaAsync(long propostaId, int aziendaId, string utente)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT email, cognome, nome FROM fn_web_proposta_approva(@Id::bigint, @Az::integer, @U::varchar)", conn);
        cmd.Parameters.AddWithValue("Id", propostaId);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("U", utente);
        await using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync()
            ? new PropostaApprovata(r.GetString(0), r.IsDBNull(1) ? "" : r.GetString(1), r.IsDBNull(2) ? "" : r.GetString(2))
            : null;
    }

    public async Task<bool> ScartaAsync(long propostaId, int aziendaId, string utente)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT fn_web_proposta_scarta(@Id::bigint, @Az::integer, @U::varchar)", conn);
        cmd.Parameters.AddWithValue("Id", propostaId);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("U", utente);
        return await cmd.ExecuteScalarAsync() is true;
    }
}
