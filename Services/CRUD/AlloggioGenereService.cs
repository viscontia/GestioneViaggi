using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// I generi di sistemazione. Tutta la SQL sta in funzioni di database
/// (<c>SqlScripts/601</c>): è la regola del progetto, e serve perché le stesse regole le
/// usa anche il sito di iscrizione.
/// </summary>
public class AlloggioGenereService
{
    private readonly IDatabaseService _db;
    private readonly ILogger<AlloggioGenereService> _logger;

    public AlloggioGenereService(IDatabaseService db, ILogger<AlloggioGenereService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<List<AlloggioGenere>> GetAllAsync(bool soloAttivi = false)
    {
        var esito = new List<AlloggioGenere>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT * FROM fn_ana_alloggio_generi_get_all(@soloAttivi)", conn);
        cmd.Parameters.AddWithValue("soloAttivi", soloAttivi);

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            esito.Add(new AlloggioGenere
            {
                Id          = reader.GetInt32(reader.GetOrdinal("genere_id")),
                Codice      = reader.GetString(reader.GetOrdinal("codice")),
                Descrizione = reader.GetString(reader.GetOrdinal("descrizione")),
                Ordine      = reader.GetInt16(reader.GetOrdinal("ordine")),
                Attivo      = reader.GetBoolean(reader.GetOrdinal("attivo"))
            });
        }
        return esito;
    }

    public async Task<int> SalvaAsync(AlloggioGenere g)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_ana_alloggio_generi_upsert(@id, @codice, @descrizione, @ordine, @attivo)", conn);
            cmd.Parameters.AddWithValue("id", g.Id);
            cmd.Parameters.AddWithValue("codice", g.Codice);
            cmd.Parameters.AddWithValue("descrizione", g.Descrizione);
            cmd.Parameters.AddWithValue("ordine", g.Ordine);
            cmd.Parameters.AddWithValue("attivo", g.Attivo);
            return Convert.ToInt32(await cmd.ExecuteScalarAsync());
        }
        catch (PostgresException ex)
        {
            // Il messaggio lo scrive il database, che è anche l'unico posto dove la
            // regola vive: va mostrato com'è, non tradotto a metà.
            _logger.LogWarning(ex, "Genere non salvato: {Messaggio}", ex.MessageText);
            throw new InvalidOperationException(ex.MessageText, ex);
        }
    }

    public async Task EliminaAsync(int id)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_ana_alloggio_generi_delete(@id)", conn);
            cmd.Parameters.AddWithValue("id", id);
            await cmd.ExecuteNonQueryAsync();
        }
        catch (PostgresException ex)
        {
            _logger.LogWarning(ex, "Genere non eliminato: {Messaggio}", ex.MessageText);
            throw new InvalidOperationException(ex.MessageText, ex);
        }
    }
}
