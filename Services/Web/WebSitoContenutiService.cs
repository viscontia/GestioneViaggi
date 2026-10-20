using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// La scheda «Sito web» dell'azienda e le garanzie del tour operator (script 692).
/// Solo funzioni fn_*; ogni salvataggio avvisa da sé la coda di rigenerazione del sito (trigger).
/// </summary>
/// <remarks>
/// Disegno: Sito Web SFT/Documenti/Analisi/2026-10-19-Tappa_4_Contorno_Disegno.md.
/// Quando un testo italiano cambia, le sue traduzioni diventano obsolete (come per i testi dei tour):
/// il sito mostra l'italiano finché non si ritraduce.
/// </remarks>
public sealed class WebSitoContenutiService
{
    private readonly IDatabaseService _db;
    private readonly WebTraduzioniService _traduzioni;
    private readonly ILogger<WebSitoContenutiService> _logger;

    public WebSitoContenutiService(IDatabaseService db, WebTraduzioniService traduzioni, ILogger<WebSitoContenutiService> logger)
    {
        _db = db; _traduzioni = traduzioni; _logger = logger;
    }

    /// <summary>I contenuti dell'azienda; vuoti (non null) se la riga non c'è ancora.</summary>
    public async Task<WebSitoContenuti> GetAsync(int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_sito_contenuti_get(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return new WebSitoContenuti { AziendaId = aziendaId };
        return new WebSitoContenuti
        {
            AziendaId = aziendaId,
            FotoHomeFk = r["foto_home_fk"] as long?,
            Motto = r["motto"] as string,
            FraseHome = r["frase_home"] as string,
            EmailMessaggiFk = r["email_messaggi_fk"] as int?,
            EvidenzaTitolo = r["evidenza_titolo"] as string,
            UpdatedBy = r["updated_by"] as string,
            Updated = r["updated"] as DateTime?,
        };
    }

    /// <summary>
    /// Salva la sotto-scheda Home. I testi italiani cambiati rendono obsolete le loro traduzioni.
    /// Restituisce quanti campi tradotti sono diventati da ritradurre.
    /// </summary>
    public async Task<int> SaveAsync(WebSitoContenuti c, string utente)
    {
        var prima = await GetAsync(c.AziendaId);

        await using (var conn = await _db.GetConnectionAsync())
        await using (var cmd = new NpgsqlCommand(
            "SELECT fn_web_sito_contenuti_save(@Az::integer, @Foto::bigint, @Motto::varchar, @Frase::varchar, " +
            "@Email::integer, @Titolo::varchar, @Utente::varchar)", conn))
        {
            cmd.Parameters.AddWithValue("Az", c.AziendaId);
            cmd.Parameters.AddWithValue("Foto", (object?)c.FotoHomeFk ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Motto", (object?)c.Motto ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Frase", (object?)c.FraseHome ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Email", (object?)c.EmailMessaggiFk ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Titolo", (object?)c.EvidenzaTitolo ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Utente", utente);
            await cmd.ExecuteNonQueryAsync();
        }

        // Il confronto si fa sui valori puliti, come li salva il database (spazi ai bordi, vuoto = NULL):
        // aggiungere uno spazio non deve buttare via una traduzione rivista.
        var dopo = await GetAsync(c.AziendaId);
        var obsolete = 0;
        var vecchi = prima.CampiTraducibili().ToDictionary(x => x.Campo, x => x.Valore);
        foreach (var (campo, _, valore) in dopo.CampiTraducibili())
        {
            if (string.Equals(vecchi[campo], valore, StringComparison.Ordinal)) continue;
            obsolete += await _traduzioni.MarkObsoleteAsync(c.AziendaId, WebSitoContenuti.Entita, c.AziendaId, campo);
        }
        if (obsolete > 0)
            _logger.LogInformation("Scheda «Sito web» {Az}: {N} traduzioni diventate obsolete", c.AziendaId, obsolete);
        return obsolete;
    }

    /// <summary>I contenuti dei tour in evidenza, nell'ordine.</summary>
    public async Task<List<long>> ListEvidenzaAsync(int aziendaId)
    {
        var list = new List<long>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT web_tour_contenuti_id FROM fn_web_sito_evidenza_list(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(r.GetInt64(0));
        return list;
    }

    /// <summary>Sostituisce l'elenco dei tour in evidenza (al massimo 3: lo controlla il database).</summary>
    public async Task SaveEvidenzaAsync(int aziendaId, IReadOnlyList<long> contenuti, string utente)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT fn_web_sito_evidenza_save(@Az::integer, @Ids::bigint[], @Utente::varchar)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("Ids", contenuti.ToArray());
        cmd.Parameters.AddWithValue("Utente", utente);
        await cmd.ExecuteNonQueryAsync();
    }

    /// <summary>
    /// I tour che si possono scegliere per «In evidenza»: quelli che il sito mostra adesso. Si usa la stessa
    /// funzione del sito (fn_web_tour_pubblicati), così «pubblicato» ha una definizione sola.
    /// </summary>
    public async Task<List<TourPubblicatoScelta>> ListTourPubblicatiAsync(int aziendaId)
    {
        var list = new List<TourPubblicatoScelta>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT contenuto_id, titolo, data_inizio FROM fn_web_tour_pubblicati(@Az::integer, 'IT')", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            list.Add(new TourPubblicatoScelta(
                r.GetInt64(0),
                r.IsDBNull(1) ? "(senza titolo)" : r.GetString(1),
                r.IsDBNull(2) ? null : DateOnly.FromDateTime(r.GetDateTime(2))));
        return list;
    }

    public async Task<GaranzieAzienda> GetGaranzieAsync(int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT * FROM fn_ana_aziende_garanzie_get(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return new GaranzieAzienda(null, null, null, null);
        return new GaranzieAzienda(
            r["polizza_rc_compagnia"] as string, r["polizza_rc_numero"] as string,
            r["fondo_garanzia_ente"] as string, r["fondo_garanzia_estremi"] as string);
    }

    /// <summary>Salva polizza RC e fondo di garanzia (testi vuoti → NULL, lo fa il database).</summary>
    public async Task SaveGaranzieAsync(int aziendaId, GaranzieAzienda g)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT fn_ana_aziende_garanzie_save(@Az::integer, @C::varchar, @N::varchar, @E::varchar, @S::varchar)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("C", (object?)g.PolizzaRcCompagnia ?? DBNull.Value);
        cmd.Parameters.AddWithValue("N", (object?)g.PolizzaRcNumero ?? DBNull.Value);
        cmd.Parameters.AddWithValue("E", (object?)g.FondoGaranziaEnte ?? DBNull.Value);
        cmd.Parameters.AddWithValue("S", (object?)g.FondoGaranziaEstremi ?? DBNull.Value);
        await cmd.ExecuteNonQueryAsync();
    }

    /// <summary>I testi della sotto-scheda Home da tradurre (solo quelli compilati).</summary>
    public static List<TranslatableItem> ElementiDaTradurre(WebSitoContenuti c) =>
        c.CampiTraducibili()
         .Where(x => !string.IsNullOrWhiteSpace(x.Valore))
         .Select(x => new TranslatableItem(WebSitoContenuti.Entita, c.AziendaId, x.Campo, x.Etichetta, x.Valore!))
         .ToList();
}
