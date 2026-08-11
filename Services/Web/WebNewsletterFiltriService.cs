using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.Database;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Criteri di selezione dei destinatari di una newsletter (script 529).
/// </summary>
/// <remarks>
/// I criteri <b>restringono</b>: consenso, disiscrizioni e soppressioni restano invalicabili e
/// nessun filtro può farli saltare. Sono inoltre tutti anagrafici, quindi riguardano solo i
/// clienti — gli iscritti dal sito non hanno quei dati.
/// </remarks>
public sealed class WebNewsletterFiltriService
{
    private readonly IDatabaseService _db;

    public WebNewsletterFiltriService(IDatabaseService db) => _db = db;

    public async Task<List<WebNewsletterFiltro>> ListAsync(long invioId, int aziendaId)
    {
        var list = new List<WebNewsletterFiltro>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT id, criterio, descrizione, param_data, param_int FROM fn_web_newsletter_filtri_list(@Invio::bigint, @Az::integer)", conn);
        cmd.Parameters.AddWithValue("Invio", invioId);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            list.Add(new WebNewsletterFiltro(
                r.GetInt64(0), r.GetString(1), r.GetString(2),
                r.IsDBNull(3) ? null : r.GetDateTime(3),
                r.IsDBNull(4) ? null : r.GetInt32(4)));
        }
        return list;
    }

    public async Task<long> AggiungiAsync(int aziendaId, long invioId, string criterio,
                                          DateTime? paramData = null, int? paramInt = null)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_newsletter_filtri_insert(@Az::integer, @Invio::bigint, @Crit::varchar, @Data::date, @Int::integer)", conn);
            cmd.Parameters.AddWithValue("Az", aziendaId);
            cmd.Parameters.AddWithValue("Invio", invioId);
            cmd.Parameters.AddWithValue("Crit", criterio);
            cmd.Parameters.AddWithValue("Data", (object?)paramData ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Int", (object?)paramInt ?? DBNull.Value);
            return Convert.ToInt64(await cmd.ExecuteScalarAsync());
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            throw new InvalidOperationException(pex.MessageText);
        }
    }

    public async Task<bool> EliminaAsync(long id, int aziendaId)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_newsletter_filtri_delete(@Id::bigint, @Az::integer)", conn);
            cmd.Parameters.AddWithValue("Id", id);
            cmd.Parameters.AddWithValue("Az", aziendaId);
            return Convert.ToInt32(await cmd.ExecuteScalarAsync()) > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            throw new InvalidOperationException(pex.MessageText);
        }
    }

    /// <summary>Nazioni in cui risiede almeno un cliente. Italia per prima, poi le estere in ordine.</summary>
    public async Task<List<NazioneClienti>> NazioniAsync(int aziendaId)
    {
        var list = new List<NazioneClienti>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT country_id, nome, estero, clienti FROM fn_web_nazioni_clienti(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            list.Add(new NazioneClienti(r.GetInt32(0), r.GetString(1), r.GetBoolean(2), r.GetInt64(3)));
        return list;
    }

    public async Task<ConteggioDestinatari> ConteggioAsync(int aziendaId, long? invioId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT destinatari, clienti, iscritti, iscritti_esclusi FROM fn_web_newsletter_conteggio(@Az::integer, @Invio::bigint)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("Invio", (object?)invioId ?? DBNull.Value);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return new ConteggioDestinatari(0, 0, 0, 0);
        return new ConteggioDestinatari(r.GetInt64(0), r.GetInt64(1), r.GetInt64(2), r.GetInt64(3));
    }

    /// <summary>Stato dell'interruttore "includi comunque gli iscritti dal sito".</summary>
    public async Task<bool> GetIncludiIscrittiAsync(long invioId, int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT includi_iscritti_web FROM web_newsletter_invii WHERE web_newsletter_invii_id = @Id AND azienda_id = @Az", conn);
        cmd.Parameters.AddWithValue("Id", invioId);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        var v = await cmd.ExecuteScalarAsync();
        return v is bool b && b;
    }

    /// <summary>Includere comunque gli iscritti dal sito quando c'è un filtro attivo.</summary>
    public async Task SetIncludiIscrittiAsync(long invioId, int aziendaId, bool includi)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "UPDATE web_newsletter_invii SET includi_iscritti_web = @V WHERE web_newsletter_invii_id = @Id AND azienda_id = @Az", conn);
        cmd.Parameters.AddWithValue("V", includi);
        cmd.Parameters.AddWithValue("Id", invioId);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await cmd.ExecuteNonQueryAsync();
    }
}
