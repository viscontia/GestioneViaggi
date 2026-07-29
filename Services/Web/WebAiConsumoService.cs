using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>Totali di consumo Claude di un'azienda.</summary>
public record WebAiRiepilogo(int Chiamate, long TokenInput, long TokenOutput, decimal Costo, string Valuta, DateTime? UltimaChiamata);

/// <summary>Soglia di spesa configurata per un'azienda (NULL = nessun avviso).</summary>
public record WebAiConfig(decimal? SogliaSpesa, DateTime ConteggioDa, DateTime? AvvisatoIl, DateOnly? PrezziVerificatiIl)
{
    /// <summary>
    /// Ogni quanto ricordare di ricontrollare il listino Anthropic. I prezzi cambiano qualche volta
    /// l'anno: tre mesi bastano ad accorgersene senza diventare un avviso da ignorare.
    /// </summary>
    public const int GiorniValiditaPrezzi = 90;

    /// <summary>
    /// true se la conferma più recente è più vecchia della soglia. Il riferimento è la data più
    /// recente fra quella confermata dall'operatore e quella "di fabbrica"
    /// (<see cref="Services.Shared.Ai.ClaudeOptions.DataVerificaPrezzi"/>): su un'installazione nuova,
    /// dove nessuno ha ancora confermato nulla, il promemoria non deve scattare subito su prezzi
    /// che sono stati verificati al momento del rilascio.
    /// </summary>
    public static bool PrezziDaVerificare(DateOnly? confermaOperatore, DateOnly oggi)
    {
        var codice = Services.Shared.Ai.ClaudeOptions.DataVerificaPrezzi;
        var riferimento = confermaOperatore is { } d && d > codice ? d : codice;
        return riferimento.AddDays(GiorniValiditaPrezzi) <= oggi;
    }

    /// <summary>Data della conferma valida (operatore o rilascio), usata nei messaggi.</summary>
    public static DateOnly DataRiferimentoPrezzi(DateOnly? confermaOperatore)
    {
        var codice = Services.Shared.Ai.ClaudeOptions.DataVerificaPrezzi;
        return confermaOperatore is { } d && d > codice ? d : codice;
    }
}

/// <summary>
/// Registro dei consumi Claude (DB-first, funzioni <c>fn_web_ai_*</c>).
/// L'API Anthropic non espone il credito residuo: qui si contano i token che le risposte riportano
/// già nel blocco <c>usage</c>, quindi il tracciamento non costa chiamate né crediti. Il totale è
/// una <b>stima dei consumi passati da questo gestionale</b>, non il saldo reale della chiave.
/// </summary>
public class WebAiConsumoService
{
    private readonly IDatabaseService _db;
    private readonly ILogger<WebAiConsumoService> _logger;

    public WebAiConsumoService(IDatabaseService db, ILogger<WebAiConsumoService> logger)
    {
        _db = db;
        _logger = logger;
    }

    /// <summary>
    /// Registra una chiamata. Non lancia: un problema nel registro spese non deve far fallire una
    /// traduzione già pagata e riuscita — al massimo si perde una riga di contabilità.
    /// </summary>
    public async Task RegistraAsync(int aziendaId, string modello, string? contesto,
        int inputTokens, int outputTokens, decimal costo, string valuta)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_web_ai_consumo_insert(@Az::integer, @Mod::varchar, @Ctx::varchar, @In::integer, @Out::integer, @Costo::numeric, @Val::varchar)", conn);
            cmd.Parameters.AddWithValue("Az", aziendaId);
            cmd.Parameters.AddWithValue("Mod", modello);
            cmd.Parameters.AddWithValue("Ctx", (object?)contesto ?? DBNull.Value);
            cmd.Parameters.AddWithValue("In", inputTokens);
            cmd.Parameters.AddWithValue("Out", outputTokens);
            cmd.Parameters.AddWithValue("Costo", costo);
            cmd.Parameters.AddWithValue("Val", valuta);
            await cmd.ExecuteScalarAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Registrazione consumo AI fallita (azienda {AziendaId})", aziendaId);
        }
    }

    /// <summary>Totali dal momento indicato (null = da sempre).</summary>
    public async Task<WebAiRiepilogo> RiepilogoAsync(int aziendaId, DateTime? da = null)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_ai_consumo_riepilogo(@Az::integer, @Da::timestamptz)", conn);
            cmd.Parameters.AddWithValue("Az", aziendaId);
            cmd.Parameters.AddWithValue("Da", (object?)da ?? DBNull.Value);

            await using var reader = await cmd.ExecuteReaderAsync();
            if (!await reader.ReadAsync()) return new WebAiRiepilogo(0, 0, 0, 0, "USD", null);

            var ultimaOrd = reader.GetOrdinal("ultima_chiamata");
            return new WebAiRiepilogo(
                reader.GetInt32(reader.GetOrdinal("n_chiamate")),
                reader.GetInt64(reader.GetOrdinal("tot_input")),
                reader.GetInt64(reader.GetOrdinal("tot_output")),
                reader.GetDecimal(reader.GetOrdinal("costo_totale")),
                reader.GetString(reader.GetOrdinal("valuta")),
                reader.IsDBNull(ultimaOrd) ? null : reader.GetDateTime(ultimaOrd));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Riepilogo consumi AI fallito (azienda {AziendaId})", aziendaId);
            return new WebAiRiepilogo(0, 0, 0, 0, "USD", null);
        }
    }

    public async Task<WebAiConfig?> GetConfigAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_ai_config_get(@Az::integer)", conn);
            cmd.Parameters.AddWithValue("Az", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            if (!await reader.ReadAsync()) return null;

            var sogliaOrd = reader.GetOrdinal("soglia_spesa");
            var avvisoOrd = reader.GetOrdinal("avvisato_il");
            var verificaOrd = reader.GetOrdinal("prezzi_verificati_il");
            return new WebAiConfig(
                reader.IsDBNull(sogliaOrd) ? null : reader.GetDecimal(sogliaOrd),
                reader.GetDateTime(reader.GetOrdinal("conteggio_da")),
                reader.IsDBNull(avvisoOrd) ? null : reader.GetDateTime(avvisoOrd),
                reader.IsDBNull(verificaOrd) ? null : DateOnly.FromDateTime(reader.GetDateTime(verificaOrd)));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lettura config AI fallita (azienda {AziendaId})", aziendaId);
            return null;
        }
    }

    /// <summary>Registra che oggi i prezzi sono stati confermati contro il listino Anthropic.</summary>
    public async Task PrezziVerificatiAsync(int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT fn_web_ai_prezzi_verificati(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await cmd.ExecuteScalarAsync();
    }

    /// <summary>Imposta la soglia. <paramref name="riparti"/> azzera il conteggio (nuova ricarica).</summary>
    public async Task SetSogliaAsync(int aziendaId, decimal? soglia, bool riparti = false)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT fn_web_ai_config_set(@Az::integer, @S::numeric, @R::boolean)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("S", (object?)soglia ?? DBNull.Value);
        cmd.Parameters.AddWithValue("R", riparti);
        await cmd.ExecuteScalarAsync();
    }

    /// <summary>
    /// true (una sola volta per periodo) se la spesa ha raggiunto il 90% della soglia.
    /// Controllo e marcatura avvengono nella stessa istruzione DB: due traduzioni ravvicinate non
    /// possono far partire due email.
    /// </summary>
    public async Task<(bool DaAvvisare, decimal Speso, decimal? Soglia)> VerificaSogliaAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_ai_soglia_da_avvisare(@Az::integer)", conn);
            cmd.Parameters.AddWithValue("Az", aziendaId);

            await using var reader = await cmd.ExecuteReaderAsync();
            if (!await reader.ReadAsync()) return (false, 0, null);

            var sogliaOrd = reader.GetOrdinal("soglia");
            return (reader.GetBoolean(reader.GetOrdinal("da_avvisare")),
                    reader.GetDecimal(reader.GetOrdinal("speso")),
                    reader.IsDBNull(sogliaOrd) ? null : reader.GetDecimal(sogliaOrd));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Verifica soglia AI fallita (azienda {AziendaId})", aziendaId);
            return (false, 0, null);
        }
    }
}
