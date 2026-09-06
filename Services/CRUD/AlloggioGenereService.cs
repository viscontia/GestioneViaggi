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

    /// <summary>
    /// I generi con la spunta su quelli ammessi da questo pernottamento.
    /// ⚠️ Torna TUTTI i generi, non solo quelli già scelti: la scheda deve mostrare le
    /// possibilità, non lo stato. <c>NESSUNA</c> non compare — vale sempre, ed è una
    /// regola, non una configurazione.
    /// </summary>
    public async Task<List<(int Id, string Codice, string Descrizione, bool Ammesso)>>
        GeneriDelPernottamentoAsync(int pernottamentoId)
    {
        var esito = new List<(int, string, string, bool)>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT * FROM fn_ana_tipo_pernottamento_generi_get(@id)", conn);
        cmd.Parameters.AddWithValue("id", pernottamentoId);

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            esito.Add((
                reader.GetInt32(reader.GetOrdinal("genere_id")),
                reader.GetString(reader.GetOrdinal("codice")),
                reader.GetString(reader.GetOrdinal("descrizione")),
                reader.GetBoolean(reader.GetOrdinal("ammesso"))));
        }
        return esito;
    }

    /// <summary>
    /// Imposta i generi ammessi, sostituendo i precedenti.
    /// ⚠️ Un elenco vuoto è legittimo: è il pernottamento «nessuno», dove non c'è niente
    /// da comporre. E il flag <c>con_albergo</c> viene riallineato dal database: non è più
    /// una scelta separata, è una conseguenza.
    /// </summary>
    public async Task ImpostaGeneriDelPernottamentoAsync(
        int pernottamentoId, IEnumerable<int> generi)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_ana_tipo_pernottamento_generi_set(@id, @generi)", conn);
            cmd.Parameters.AddWithValue("id", pernottamentoId);
            cmd.Parameters.AddWithValue("generi", generi.ToArray());
            await cmd.ExecuteNonQueryAsync();
        }
        catch (PostgresException ex) when (ex.SqlState == "23514")
        {
            // ⛔️ Si RIFIUTA, non si chiede. Prima si chiedeva «vuoi procedere lo stesso?»,
            // e un solo clic poteva scoprire 414 assegnazioni già registrate: chi vuole
            // cambiare la configurazione sistema prima quelle, poi la cambia.
            // Il messaggio arriva dal database e dice quante sono e su quali viaggi.
            _logger.LogWarning(ex, "Generi non impostati: {Messaggio}", ex.MessageText);
            throw new InvalidOperationException(ex.MessageText, ex);
        }
    }
}