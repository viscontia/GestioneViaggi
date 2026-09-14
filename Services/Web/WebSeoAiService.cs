using System.Text.Json;
using GestioneViaggi.Services.Shared.Ai;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Web;

/// <summary>Testi della scheda da cui si ricavano i meta: è quello che l'operatore ha davanti, non ciò che è su DB.</summary>
public sealed record SeoSorgente(
    string? Titolo, string? Sottotitolo, string? Descrizione, string? DurataTesto, string? LuoghiVisitati);

/// <summary>Proposta per i due campi SEO. Nessuno dei due viene scritto senza conferma dell'operatore.</summary>
public sealed record SeoSuggerimento(string? MetaTitle, string? MetaDescription);

/// <summary>
/// Suggerimento assistito dei meta SEO (meta title / meta description) via Claude.
/// </summary>
/// <remarks>
/// Affianca — non sostituisce — i suggerimenti meccanici del Blocco 5 (titolo troncato a 60,
/// descrizione troncata a 155): quelli restano il ripiego quando la chiave Claude non c'è, perché
/// un campo vuoto è peggio di un campo approssimativo.
/// <para>
/// Genera <b>solo l'italiano</b>. Le altre lingue arrivano dalla pipeline di traduzione, dove
/// passano per la revisione: generare qui cinque lingue scavalcherebbe il controllo che impedisce
/// di pubblicare testi che nessuno ha letto.
/// </para>
/// </remarks>
public sealed class WebSeoAiService
{
    /// <summary>Limiti oltre i quali Google tronca. Sono gli stessi dichiarati nella UI del tab.</summary>
    public const int MaxTitle = 60;
    public const int MaxDescription = 155;

    /// <summary>Basta per due stringhe brevi: un tetto basso è anche una protezione sul costo.</summary>
    private const int MaxTokensRisposta = 400;

    private readonly ClaudeTranslationClient _claude;
    private readonly WebTraduzioneOrchestratorService _orchestrator;
    private readonly WebAiConsumoService _consumi;
    private readonly ClaudeOptions _opt;
    private readonly ILogger<WebSeoAiService> _logger;

    public WebSeoAiService(
        ClaudeTranslationClient claude, WebTraduzioneOrchestratorService orchestrator,
        WebAiConsumoService consumi, ClaudeOptions opt, ILogger<WebSeoAiService> logger)
    {
        _claude = claude; _orchestrator = orchestrator; _consumi = consumi; _opt = opt; _logger = logger;
    }

    /// <summary>true se la master key dei segreti c'è: senza, la chiave Claude non è nemmeno leggibile.</summary>
    public bool SecretKeyConfigurata => _orchestrator.SecretKeyConfigurata;

    /// <summary>Chiave Claude dell'azienda configurata? Lettura non distruttiva, per accendere o spegnere il pulsante.</summary>
    public async Task<bool> ChiaveDisponibileAsync(int aziendaId)
    {
        try { return !string.IsNullOrWhiteSpace(await _orchestrator.GetClaudeKeyAsync(aziendaId)); }
        catch (Exception ex)
        {
            // È una lettura chiamata in OnInitializedAsync: se lancia, congela il tab (overview §6).
            _logger.LogWarning(ex, "Chiave Claude non verificabile per azienda {Az}", aziendaId);
            return false;
        }
    }

    /// <summary>
    /// Propone meta title e meta description a partire dai testi della scheda.
    /// </summary>
    /// <remarks>
    /// Se la risposta sfora i limiti si richiede <b>una sola volta</b>, dicendo al modello di quanto
    /// ha sforato. Un secondo tentativo è economico; insistere oltre costerebbe più della resa: se
    /// anche il ritentativo sfora, si tronca sull'ultima parola intera — meglio un testo tagliato
    /// bene di un testo che Google taglia a metà parola.
    /// </remarks>
    public async Task<SeoSuggerimento> SuggerisciAsync(int aziendaId, SeoSorgente sorgente, CancellationToken ct = default)
    {
        var chiave = await _orchestrator.GetClaudeKeyAsync(aziendaId);
        if (string.IsNullOrWhiteSpace(chiave))
            throw new InvalidOperationException(
                "Chiave Claude non configurata per l'azienda: impostala in Anagrafica Azienda → Traduzioni.");

        var materiale = ComponiMateriale(sorgente);
        if (string.IsNullOrWhiteSpace(materiale))
            throw new InvalidOperationException(
                "Non c'è abbastanza testo nella scheda: compila almeno la descrizione o il sottotitolo.");

        var esito = await _claude.ChiamaAsync(chiave!, PromptSistema, materiale, MaxTokensRisposta, ct);
        var (title, descr) = Leggi(esito.Testo);
        var input = esito.InputTokens; var output = esito.OutputTokens;

        if (Sfora(title, MaxTitle) || Sfora(descr, MaxDescription))
        {
            var correzione =
                $"{materiale}\n\n--- CORREZIONE ---\n" +
                $"La proposta precedente sforava i limiti (title {Lunghezza(title)} caratteri, " +
                $"description {Lunghezza(descr)}). Riscrivile più corte: " +
                $"title al massimo {MaxTitle} caratteri, description al massimo {MaxDescription}. " +
                "Conta i caratteri prima di rispondere.";

            try
            {
                var secondo = await _claude.ChiamaAsync(chiave!, PromptSistema, correzione, MaxTokensRisposta, ct);
                input += secondo.InputTokens; output += secondo.OutputTokens;
                var (t2, d2) = Leggi(secondo.Testo);
                if (!string.IsNullOrWhiteSpace(t2)) title = t2;
                if (!string.IsNullOrWhiteSpace(d2)) descr = d2;
            }
            catch (Exception ex)
            {
                // Il primo risultato c'è già: un ritentativo fallito non deve far perdere anche quello.
                _logger.LogWarning(ex, "Ritentativo SEO non riuscito per azienda {Az}: tengo la prima proposta", aziendaId);
            }
        }

        await _consumi.RegistraAsync(aziendaId, _opt.Model, "SEO (meta title + description)",
            input, output, _opt.StimaCosto(input, output), _opt.Valuta);

        return new SeoSuggerimento(Tronca(title, MaxTitle), Tronca(descr, MaxDescription));
    }

    // ---- Prompt ---------------------------------------------------------------

    /// <remarks>
    /// Il vincolo che conta è il divieto di inventare: una description che si inventa «posti
    /// limitati» o una difficoltà che il tour non ha finisce in vetrina sui risultati di ricerca,
    /// dove nessuno la rilegge prima del cliente.
    /// </remarks>
    private static readonly string PromptSistema =
        "Sei un esperto SEO per un tour operator di viaggi offroad. Scrivi in ITALIANO i due meta " +
        "tag di una pagina di viaggio, partendo SOLO dai testi che ti vengono forniti.\n" +
        $"- meta title: al massimo {MaxTitle} caratteri, con le parole più importanti all'inizio.\n" +
        $"- meta description: al massimo {MaxDescription} caratteri, invitante, una frase compiuta " +
        "che finisce con un punto.\n" +
        "REGOLE TASSATIVE:\n" +
        "- NON inventare nulla che non sia nei testi forniti: niente prezzi, date, numero di posti, " +
        "difficoltà, durate o servizi che non leggi.\n" +
        "- NON usare superlativi vuoti («indimenticabile», «unico nel suo genere») né MAIUSCOLE urlate.\n" +
        "- NON scrivere il nome dell'azienda: lo aggiunge il sito.\n" +
        "- Rispetta i nomi propri dei luoghi come sono scritti.\n" +
        "Rispondi SOLO con questo JSON, senza commenti né blocchi di codice:\n" +
        "{\"title\": \"...\", \"description\": \"...\"}";

    private static string ComponiMateriale(SeoSorgente s)
    {
        var sb = new System.Text.StringBuilder();
        void Add(string etichetta, string? valore)
        {
            if (!string.IsNullOrWhiteSpace(valore)) sb.Append(etichetta).Append(": ").AppendLine(valore!.Trim());
        }
        Add("Titolo del viaggio", s.Titolo);
        Add("Sottotitolo", s.Sottotitolo);
        Add("Durata", s.DurataTesto);
        Add("Luoghi visitati", s.LuoghiVisitati);
        Add("Descrizione", s.Descrizione);
        return sb.ToString().Trim();
    }

    // ---- Lettura della risposta ----------------------------------------------

    /// <summary>
    /// Estrae i due campi dal JSON. Il modello a volte incornicia la risposta in un blocco di
    /// codice o ci premette una riga di cortesia, nonostante le istruzioni: si cerca il primo
    /// oggetto JSON invece di dare per buona l'intera risposta.
    /// </summary>
    private (string? Title, string? Descr) Leggi(string risposta)
    {
        var inizio = risposta.IndexOf('{');
        var fine = risposta.LastIndexOf('}');
        if (inizio < 0 || fine <= inizio)
        {
            _logger.LogWarning("Risposta SEO senza JSON riconoscibile: {Risposta}", Estratto(risposta));
            throw new InvalidOperationException("La risposta del servizio non è utilizzabile. Riprova.");
        }

        try
        {
            using var doc = JsonDocument.Parse(risposta[inizio..(fine + 1)]);
            var t = doc.RootElement.TryGetProperty("title", out var et) ? et.GetString() : null;
            var d = doc.RootElement.TryGetProperty("description", out var ed) ? ed.GetString() : null;
            return (Pulisci(t), Pulisci(d));
        }
        catch (JsonException ex)
        {
            _logger.LogWarning(ex, "JSON SEO non interpretabile: {Risposta}", Estratto(risposta));
            throw new InvalidOperationException("La risposta del servizio non è utilizzabile. Riprova.");
        }
    }

    private static string Estratto(string s) => s.Length <= 300 ? s : s[..300] + "…";

    /// <summary>Toglie le virgolette che il modello a volte aggiunge attorno al testo.</summary>
    private static string? Pulisci(string? s)
    {
        if (string.IsNullOrWhiteSpace(s)) return null;
        var v = s.Trim().Trim('"', '«', '»').Trim();
        return v.Length == 0 ? null : v;
    }

    private static int Lunghezza(string? s) => s?.Length ?? 0;
    private static bool Sfora(string? s, int max) => (s?.Length ?? 0) > max;

    /// <summary>Taglia sull'ultimo confine di parola: un testo mozzato a metà parola è peggio di uno corto.</summary>
    private static string? Tronca(string? testo, int max)
    {
        if (string.IsNullOrWhiteSpace(testo)) return null;
        var v = testo.Trim();
        if (v.Length <= max) return v;

        var tagliato = v[..max];
        var ultimoSpazio = tagliato.LastIndexOf(' ');
        if (ultimoSpazio > 0) tagliato = tagliato[..ultimoSpazio];
        return tagliato.TrimEnd(' ', ',', ';', ':', '-', '–', '—');
    }
}
