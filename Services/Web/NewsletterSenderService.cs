using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Email;
using GestioneViaggi.Services.Shared;
using GestioneViaggi.Services.Shared.Ai;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>Destinatario risolto (da fn_web_destinatari_newsletter).</summary>
public sealed record NewsletterRecipient(string Email, string? Nome, string? Cognome, string Lingua);

/// <summary>Esito invio campagna.</summary>
public sealed record NewsletterSendResult(int Totale, int Inviate, int Errori, bool TradottoIncompleto);

/// <summary>
/// Motore invio newsletter (Blocco 11, per-azienda): risolve i destinatari (clienti+iscritti−soppressioni),
/// traduce oggetto+corpo per-lingua via Claude, invia via SMTP/ESP dell'azienda, logga la consegna
/// per-destinatario e registra la campagna. Link di disiscrizione firmato HMAC.
/// </summary>
public sealed class NewsletterSenderService
{
    private readonly IDatabaseService _db;
    private readonly EmailSenderFactory _emailFactory;
    private readonly ClaudeTranslationClient _claude;
    private readonly WebTraduzioneOrchestratorService _orchestrator;
    private readonly WebNewsletterInviiService _inviiService;
    private readonly WebNewsletterInviiDestinatariService _destinatariService;
    private readonly ILogger<NewsletterSenderService> _logger;

    public NewsletterSenderService(
        IDatabaseService db, EmailSenderFactory emailFactory, ClaudeTranslationClient claude,
        WebTraduzioneOrchestratorService orchestrator, WebNewsletterInviiService inviiService,
        WebNewsletterInviiDestinatariService destinatariService, ILogger<NewsletterSenderService> logger)
    {
        _db = db; _emailFactory = emailFactory; _claude = claude; _orchestrator = orchestrator;
        _inviiService = inviiService; _destinatariService = destinatariService; _logger = logger;
    }

    public async Task<int> CountRecipientsAsync(int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT count(*) FROM fn_web_destinatari_newsletter(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        return Convert.ToInt32(await cmd.ExecuteScalarAsync());
    }

    public async Task<List<NewsletterRecipient>> GetRecipientsAsync(int aziendaId)
    {
        var list = new List<NewsletterRecipient>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT email, nome, cognome, lingua FROM fn_web_destinatari_newsletter(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            var email = r.GetString(0);
            var nome = r.IsDBNull(1) ? null : r.GetString(1);
            var cognome = r.IsDBNull(2) ? null : r.GetString(2);
            var lingua = (r.IsDBNull(3) ? "IT" : r.GetString(3)).Trim().ToUpperInvariant();
            if (string.IsNullOrEmpty(lingua)) lingua = "IT";
            list.Add(new NewsletterRecipient(email, nome, cognome, lingua));
        }
        return list;
    }

    private async Task<(string Nome, string? Sito, string? Token)> GetAziendaConfigAsync(int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT ragione_sociale, sito_web, token_iscrizione FROM ana_aziende WHERE azienda_id=@Id", conn);
        cmd.Parameters.AddWithValue("Id", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        if (await r.ReadAsync())
            return (r.GetString(0), r.IsDBNull(1) ? null : r.GetString(1), r.IsDBNull(2) ? null : r.GetString(2));
        return ("", null, null);
    }

    /// <summary>Traduce (oggetto, corpo) per ogni lingua richiesta ≠ IT. Senza chiave Claude → tutti IT.</summary>
    private async Task<(Dictionary<string, (string Oggetto, string Corpo)> Bodies, bool Incompleto)> BuildBodiesAsync(
        int aziendaId, string oggetto, string corpo, IReadOnlyCollection<string> lingue)
    {
        var bodies = new Dictionary<string, (string, string)>(StringComparer.OrdinalIgnoreCase) { ["IT"] = (oggetto, corpo) };
        var target = lingue.Where(l => !string.Equals(l, "IT", StringComparison.OrdinalIgnoreCase)).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        if (target.Count == 0) return (bodies, false);

        var key = await _orchestrator.GetClaudeKeyAsync(aziendaId);
        if (string.IsNullOrWhiteSpace(key)) return (bodies, true); // niente chiave → fallback IT (incompleto)

        var incompleto = false;
        foreach (var l in target)
        {
            try
            {
                var o = await _claude.TranslateAsync(key, oggetto, l);
                var c = await _claude.TranslateAsync(key, corpo, l);
                bodies[l] = (o, c);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Traduzione newsletter {Lang} fallita, uso IT", l);
                incompleto = true;
            }
        }
        return (bodies, incompleto);
    }

    private static string WrapBody(string corpo, string azienda, string unsubUrl) => $@"<div style=""font-family:Arial,Helvetica,sans-serif;font-size:14px;color:#222;line-height:1.5;"">
{corpo}
<hr style=""margin-top:24px;border:none;border-top:1px solid #ddd;"" />
<p style=""font-size:12px;color:#888;"">{System.Net.WebUtility.HtmlEncode(azienda)} — <a href=""{unsubUrl}"" style=""color:#888;"">Disiscriviti</a></p>
</div>";

    /// <summary>Invia la campagna a tutti i destinatari (multilingua) e registra invio + log.</summary>
    public async Task<NewsletterSendResult> SendCampaignAsync(int aziendaId, string oggetto, string corpoHtml)
    {
        var recipients = await GetRecipientsAsync(aziendaId);
        if (recipients.Count == 0)
            throw new InvalidOperationException("Nessun destinatario (verifica consensi clienti / iscritti / soppressioni).");

        var cfg = await GetAziendaConfigAsync(aziendaId);
        var (bodies, incompleto) = await BuildBodiesAsync(aziendaId, oggetto, corpoHtml, recipients.Select(r => r.Lingua).ToList());
        var sender = await _emailFactory.GetSenderAsync(null, aziendaId);
        var canale = sender is SmtpEmailSender ? "smtp" : "resend";

        var invio = await _inviiService.CreateAsync(new WebNewsletterInvio
        {
            AziendaId = aziendaId, Oggetto = oggetto, CorpoHtml = corpoHtml, Stato = "in_invio", Canale = canale
        });

        int ok = 0, err = 0;
        foreach (var rec in recipients)
        {
            var lang = bodies.ContainsKey(rec.Lingua) ? rec.Lingua : "IT";
            var (subj, corpo) = bodies[lang];
            var unsub = NewsletterUnsubscribe.BuildUrl(cfg.Sito, rec.Email, cfg.Token);
            var html = WrapBody(corpo, cfg.Nome, unsub);

            bool sent;
            try { sent = await sender.SendHtmlEmailAsync(new[] { rec.Email }, subj, html, cfg.Nome); }
            catch (Exception ex) { _logger.LogError(ex, "Invio newsletter fallito a {Email}", rec.Email); sent = false; }
            if (sent) ok++; else err++;

            try
            {
                await _destinatariService.CreateAsync(new WebNewsletterInvioDestinatario
                {
                    AziendaId = aziendaId, InvioIdFk = invio.WebNewsletterInvioId, Email = rec.Email,
                    Lingua = lang, StatoConsegna = sent ? "inviato" : "errore", Data = DateTime.UtcNow
                });
            }
            catch (Exception ex) { _logger.LogWarning(ex, "Log destinatario {Email} fallito", rec.Email); }
        }

        invio.Stato = "inviato";
        invio.NumeroDestinatari = recipients.Count;
        invio.DataInvio = DateTime.UtcNow;
        await _inviiService.UpdateAsync(invio);

        return new NewsletterSendResult(recipients.Count, ok, err, incompleto);
    }

    /// <summary>Invio di prova a un solo indirizzo (in IT, senza registrare la campagna).</summary>
    public async Task<bool> SendTestAsync(int aziendaId, string oggetto, string corpoHtml, string testEmail)
    {
        var cfg = await GetAziendaConfigAsync(aziendaId);
        var sender = await _emailFactory.GetSenderAsync(null, aziendaId);
        var unsub = NewsletterUnsubscribe.BuildUrl(cfg.Sito, testEmail, cfg.Token);
        var html = WrapBody(corpoHtml, cfg.Nome, unsub);
        return await sender.SendHtmlEmailAsync(new[] { testEmail }, "[TEST] " + oggetto, html, cfg.Nome);
    }
}
