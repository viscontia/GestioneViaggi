using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Shared.Ai;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>Campo traducibile (sorgente IT): identità polimorfica + testo.</summary>
public sealed record TranslatableItem(string Entita, long EntitaId, string Campo, string Label, string SourceText);

/// <summary>
/// Orchestratore traduzioni (Blocco 10): raccoglie i campi editoriali IT di un viaggio
/// (contenuti + passi itinerario), li traduce via Claude nelle lingue target e li salva
/// (upsert) in web_traduzioni. Gestisce anche la chiave Claude per-azienda.
/// </summary>
public sealed class WebTraduzioneOrchestratorService
{
    /// <summary>Lingue target (l'italiano è la sorgente).</summary>
    public static readonly string[] Lingue = { "EN", "DE", "FR", "ES" };

    private readonly IDatabaseService _db;
    private readonly ClaudeTranslationClient _claude;
    private readonly WebTraduzioniService _traduzioni;
    private readonly WebTourContenutiService _contenuti;
    private readonly WebTourItinerarioService _itinerario;
    private readonly WebTourItinerarioPassaggiService _passi;
    private readonly ILogger<WebTraduzioneOrchestratorService> _logger;

    public WebTraduzioneOrchestratorService(
        IDatabaseService db, ClaudeTranslationClient claude, WebTraduzioniService traduzioni,
        WebTourContenutiService contenuti, WebTourItinerarioService itinerario, WebTourItinerarioPassaggiService passi,
        ILogger<WebTraduzioneOrchestratorService> logger)
    {
        _db = db; _claude = claude; _traduzioni = traduzioni;
        _contenuti = contenuti; _itinerario = itinerario; _passi = passi; _logger = logger;
    }

    // ---- Chiave Claude per-azienda -------------------------------------------

    public async Task<string?> GetClaudeKeyAsync(int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT fn_ana_aziende_get_claude_key(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        return (await cmd.ExecuteScalarAsync()) as string;
    }

    public async Task<bool> SetClaudeKeyAsync(int aziendaId, string? key)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT fn_ana_aziende_set_claude_key(@Az::integer, @K::text)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("K", (object?)key ?? DBNull.Value);
        return Convert.ToInt32(await cmd.ExecuteScalarAsync()) > 0;
    }

    // ---- Campi traducibili di un viaggio -------------------------------------

    public async Task<List<TranslatableItem>> GetTranslatableItemsAsync(long contenutoId, int aziendaId)
    {
        var items = new List<TranslatableItem>();

        var c = await _contenuti.GetByIdAsync(contenutoId, aziendaId);
        if (c != null)
        {
            void Add(string campo, string label, string? val)
            {
                if (!string.IsNullOrWhiteSpace(val))
                    items.Add(new TranslatableItem("web_tour_contenuti", c.WebTourContenutoId, campo, label, val!));
            }
            Add("sottotitolo", "Sottotitolo", c.Sottotitolo);
            Add("descrizione_html", "Descrizione", c.DescrizioneHtml);
            Add("durata_testo", "Durata", c.DurataTesto);
            Add("luoghi_visitati", "Luoghi visitati", c.LuoghiVisitati);
            Add("info_pernottamento_html", "Pernottamento", c.InfoPernottamentoHtml);
            Add("info_pasti_html", "Pasti", c.InfoPastiHtml);
            Add("info_equipaggiamento_html", "Equipaggiamento", c.InfoEquipaggiamentoHtml);
            Add("altre_info_html", "Altre info", c.AltreInfoHtml);
            Add("meta_title", "Meta title", c.MetaTitle);
            Add("meta_description", "Meta description", c.MetaDescription);
        }

        var giornate = await _itinerario.ListByContenutoAsync(contenutoId, aziendaId);
        foreach (var g in giornate)
        {
            var passi = await _passi.ListByItinerarioAsync(g.WebTourItinerarioId, aziendaId);
            foreach (var p in passi)
                if (!string.IsNullOrWhiteSpace(p.TestoHtml))
                    items.Add(new TranslatableItem("web_tour_itinerario_passaggi", p.WebTourItinerarioPassaggioId,
                        "testo_html", $"Passo (Giorno {g.GiornoNumero})", p.TestoHtml));
        }
        return items;
    }

    // ---- Traduzione -----------------------------------------------------------

    /// <summary>Traduce gli item nelle lingue indicate e li salva (upsert). Ritorna (ok, errori).</summary>
    public async Task<(int Ok, int Errori)> TranslateAsync(
        int aziendaId, IReadOnlyList<TranslatableItem> items, IReadOnlyList<string> lingue, CancellationToken ct = default)
    {
        var key = await GetClaudeKeyAsync(aziendaId);
        if (string.IsNullOrWhiteSpace(key))
            throw new InvalidOperationException("Chiave Claude non configurata per questa azienda.");

        int ok = 0, err = 0;
        foreach (var it in items)
        {
            foreach (var lang in lingue)
            {
                try
                {
                    var tr = await _claude.TranslateAsync(key, it.SourceText, lang, ct);
                    await _traduzioni.UpsertAsync(aziendaId, it.Entita, it.EntitaId, it.Campo, lang, tr);
                    ok++;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Traduzione fallita {Campo}/{Lang}", it.Campo, lang);
                    err++;
                }
            }
        }
        return (ok, err);
    }
}
