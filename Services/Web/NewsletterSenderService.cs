using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Email;
using GestioneViaggi.Services.Shared;
using GestioneViaggi.Services.Shared.Ai;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>Destinatario risolto (da fn_web_destinatari_newsletter). Telefono solo per i clienti.</summary>
public sealed record NewsletterRecipient(string Email, string? Nome, string? Cognome, string Lingua, string? Telefono = null);

/// <summary>Esito invio campagna.</summary>
public sealed record NewsletterSendResult(int Totale, int Inviate, int Errori, bool TradottoIncompleto);

/// <summary>
/// Esito dei controlli preliminari sul branding dell'azienda, letti PRIMA di spedire.
/// <paramref name="SitoMancante"/> e' bloccante: senza <c>sito_web</c> il link di disiscrizione
/// diventa <c>https://www.example.com/unsubscribe?…</c>, cioe' si spedisce a tutti un
/// "Disiscriviti" che non porta da nessuna parte. <paramref name="LogoMancante"/> e' solo un
/// avviso: la mail parte lo stesso, ma senza intestazione.
/// </summary>
public sealed record NewsletterPreflight(bool SitoMancante, bool LogoMancante);

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
    private readonly AziendaLogoService _logoService;
    private readonly WebAiConsumoService _consumi;
    private readonly Services.Shared.Ai.ClaudeOptions _claudeOptions;
    private readonly ILogger<NewsletterSenderService> _logger;

    public NewsletterSenderService(
        IDatabaseService db, EmailSenderFactory emailFactory, ClaudeTranslationClient claude,
        WebTraduzioneOrchestratorService orchestrator, WebNewsletterInviiService inviiService,
        WebNewsletterInviiDestinatariService destinatariService, AziendaLogoService logoService,
        WebAiConsumoService consumi, Services.Shared.Ai.ClaudeOptions claudeOptions,
        ILogger<NewsletterSenderService> logger)
    {
        _db = db; _emailFactory = emailFactory; _claude = claude; _orchestrator = orchestrator;
        _inviiService = inviiService; _destinatariService = destinatariService;
        _logoService = logoService; _consumi = consumi; _claudeOptions = claudeOptions; _logger = logger;
    }

    /// <param name="invioId">
    /// Newsletter di cui applicare i filtri sui destinatari (script 529). Null = tutti quelli che
    /// ne hanno diritto, cioè il comportamento di sempre.
    /// </param>
    public async Task<int> CountRecipientsAsync(int aziendaId, long? invioId = null)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT count(*) FROM fn_web_destinatari_newsletter(@Az::integer, @Invio::bigint)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("Invio", (object?)invioId ?? DBNull.Value);
        return Convert.ToInt32(await cmd.ExecuteScalarAsync());
    }

    /// <inheritdoc cref="CountRecipientsAsync"/>
    public async Task<List<NewsletterRecipient>> GetRecipientsAsync(int aziendaId, long? invioId = null)
    {
        var list = new List<NewsletterRecipient>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT email, nome, cognome, lingua, telefono FROM fn_web_destinatari_newsletter(@Az::integer, @Invio::bigint)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("Invio", (object?)invioId ?? DBNull.Value);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            var email = r.GetString(0);
            var nome = r.IsDBNull(1) ? null : r.GetString(1);
            var cognome = r.IsDBNull(2) ? null : r.GetString(2);
            var lingua = (r.IsDBNull(3) ? "IT" : r.GetString(3)).Trim().ToUpperInvariant();
            if (string.IsNullOrEmpty(lingua)) lingua = "IT";
            var telefono = r.IsDBNull(4) ? null : r.GetString(4);
            list.Add(new NewsletterRecipient(email, nome, cognome, lingua, telefono));
        }
        return list;
    }

    /// <summary>Dati azienda + logo per il template email brandizzato (caricati una volta per campagna).</summary>
    private sealed record NlBranding(string Nome, string? Sito, string? Token, string? Telefono, string? LogoBase64, string? LogoMime);

    private async Task<NlBranding> GetBrandingAsync(int aziendaId)
    {
        string nome = ""; string? sito = null, token = null, tel = null;
        await using (var conn = await _db.GetConnectionAsync())
        await using (var cmd = new NpgsqlCommand("SELECT ragione_sociale, sito_web, token_iscrizione, telefono_principale FROM ana_aziende WHERE azienda_id=@Id", conn))
        {
            cmd.Parameters.AddWithValue("Id", aziendaId);
            await using var r = await cmd.ExecuteReaderAsync();
            if (await r.ReadAsync())
            {
                nome = r.GetString(0);
                sito = r.IsDBNull(1) ? null : r.GetString(1);
                token = r.IsDBNull(2) ? null : r.GetString(2);
                tel = r.IsDBNull(3) ? null : r.GetString(3);
            }
        }

        // Logo aziendale (non-critical: se assente si prosegue senza)
        string? logoBase64 = null, logoMime = null;
        try
        {
            var logos = await _logoService.GetByAziendaIdAsync(aziendaId);
            var logo = logos.Where(l => l.IsActive && l.IsDefault).OrderBy(l => l.Priority).FirstOrDefault()
                    ?? logos.Where(l => l.IsActive).OrderBy(l => l.Priority).FirstOrDefault();
            if (logo != null)
            {
                var bin = await _logoService.GetBinaryDataAsync(logo.Id);
                if (bin != null && bin.Length > 0) { logoBase64 = Convert.ToBase64String(bin); logoMime = logo.MimeType; }
            }
        }
        catch (Exception ex) { _logger.LogWarning(ex, "Logo azienda {Az} non disponibile per newsletter", aziendaId); }

        return new NlBranding(nome, sito, token, tel, logoBase64, logoMime);
    }

    /// <summary>
    /// Controlli preliminari sul branding, da chiamare PRIMA di comporre l'invio: la UI blocca sul
    /// sito mancante e chiede conferma sul logo mancante. Qui nessuna decisione, solo i fatti.
    /// </summary>
    public async Task<NewsletterPreflight> GetPreflightAsync(int aziendaId)
    {
        var b = await GetBrandingAsync(aziendaId);
        return new NewsletterPreflight(
            SitoMancante: string.IsNullOrWhiteSpace(b.Sito),
            LogoMancante: string.IsNullOrWhiteSpace(b.LogoBase64));
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
                bodies[l] = (o.Testo, c.Testo);

                // Anche le traduzioni della newsletter consumano credito: vanno nello stesso registro,
                // altrimenti il totale mostrato all'utente sarebbe più basso della spesa reale.
                foreach (var u in new[] { o, c })
                    await _consumi.RegistraAsync(aziendaId, _claudeOptions.Model, $"Newsletter ({l})",
                        u.InputTokens, u.OutputTokens,
                        _claudeOptions.StimaCosto(u.InputTokens, u.OutputTokens), _claudeOptions.Valuta);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Traduzione newsletter {Lang} fallita, uso IT", l);
                incompleto = true;
            }
        }
        return (bodies, incompleto);
    }

    /// <summary>Footer di disiscrizione, aggiunto in coda al corpo dentro il template brandizzato.</summary>
    private static string UnsubFooter(string unsubUrl) =>
        $@"<hr style=""margin-top:24px;border:none;border-top:1px solid #ddd;"" /><p style=""font-size:12px;color:#888;"">Non desideri più ricevere la nostra newsletter? <a href=""{unsubUrl}"" style=""color:#888;"">Disiscriviti</a></p>";

    /// <summary>Genera l'email brandizzata (template aziendale con logo) includendo il footer di disiscrizione.</summary>
    private static string BuildHtml(NlBranding b, string corpo, string unsubUrl) =>
        CompanyEmailTemplate.GetHtmlBody(b.LogoBase64, b.LogoMime, b.Nome, null, null,
            corpo + UnsubFooter(unsubUrl), DateTime.Now, b.Sito, b.Telefono);

    /// <summary>Invia la campagna a tutti i destinatari (multilingua) e registra invio + log.</summary>
    public async Task<NewsletterSendResult> SendCampaignAsync(
        int aziendaId, string oggetto, string corpoHtml, IProgress<(int Fatti, int Totale)>? progress = null)
    {
        var recipients = await GetRecipientsAsync(aziendaId);
        if (recipients.Count == 0)
            throw new InvalidOperationException("Nessun destinatario (verifica consensi clienti / iscritti / soppressioni).");

        var branding = await GetBrandingAsync(aziendaId);

        // Guardia autoritativa: senza sito_web il link di disiscrizione punta a example.com.
        // La UI avvisa prima, ma il blocco deve stare anche qui: una newsletter con un
        // "Disiscriviti" rotto non si puo' richiamare indietro.
        if (string.IsNullOrWhiteSpace(branding.Sito))
            throw new InvalidOperationException(
                "L'azienda non ha un sito web configurato: il link di disiscrizione sarebbe rotto. " +
                "Compila 'Sito web' in Anagrafica Aziende prima di inviare.");
        var (bodies, incompleto) = await BuildBodiesAsync(aziendaId, oggetto, corpoHtml, recipients.Select(r => r.Lingua).ToList());
        var sender = await _emailFactory.GetSenderAsync(null, aziendaId);
        var canale = sender is SmtpEmailSender ? "smtp" : "resend";

        var invio = await _inviiService.CreateAsync(new WebNewsletterInvio
        {
            AziendaId = aziendaId, Oggetto = oggetto, CorpoHtml = corpoHtml, Stato = "in_invio", Canale = canale
        });

        int ok = 0, err = 0;
        progress?.Report((0, recipients.Count));
        foreach (var rec in recipients)
        {
            var lang = bodies.ContainsKey(rec.Lingua) ? rec.Lingua : "IT";
            var (subj, corpo) = bodies[lang];
            var unsub = NewsletterUnsubscribe.BuildUrl(branding.Sito, rec.Email, branding.Token);
            var html = BuildHtml(branding, corpo, unsub);

            bool sent;
            try { sent = await sender.SendHtmlEmailAsync(new[] { rec.Email }, subj, html, branding.Nome); }
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

            progress?.Report((ok + err, recipients.Count));
        }

        // "inviata" (femminile): e' il valore ammesso da chk_web_newsletter_invii_stato
        // ('bozza','in_invio','inviata'). Con "inviato" l'UPDATE finale falliva sempre (23514),
        // lasciando la campagna in 'in_invio' con data_invio e numero_destinatari NULL.
        invio.Stato = "inviata";
        invio.NumeroDestinatari = recipients.Count;
        invio.DataInvio = DateTime.UtcNow;
        await _inviiService.UpdateAsync(invio);

        return new NewsletterSendResult(recipients.Count, ok, err, incompleto);
    }

    /// <summary>
    /// Invia una newsletter <b>a blocchi</b>: l'HTML e' composto dai blocchi salvati e ricomposto
    /// per ogni destinatario, perche' il link di disiscrizione e' firmato sul suo indirizzo.
    /// </summary>
    /// <remarks>
    /// ⚠️ In questa fase l'invio e' <b>monolingua (IT)</b>: la traduzione per campo dei blocchi e'
    /// la Fase 4. Il vecchio percorso traduceva l'intero blob HTML, cosa che con i blocchi non ha
    /// piu' senso — la struttura non deve passare dentro Claude.
    /// </remarks>
    public async Task<NewsletterSendResult> SendCampaignBlocchiAsync(
        int aziendaId, long invioId, string oggetto,
        NewsletterRenderService render,
        IProgress<(int Fatti, int Totale)>? progress = null)
    {
        // Con l'invioId i destinatari sono quelli filtrati per QUESTA newsletter: se qui passasse
        // null, la selezione fatta dall'utente verrebbe ignorata proprio al momento della spedizione.
        var recipients = await GetRecipientsAsync(aziendaId, invioId);
        if (recipients.Count == 0)
            throw new InvalidOperationException("Nessun destinatario (verifica consensi clienti / iscritti / soppressioni).");

        // Congela gli indirizzi presi dalla rubrica PRIMA di comporre: da qui in avanti la
        // newsletter e' un documento storico e non deve piu' cambiare se qualcuno corregge un
        // indirizzo. Dopo il congelamento la risoluzione al rendering diventa un non-evento.
        await render.CongelaIndirizziAsync(invioId, aziendaId);

        var ctx = await render.PreparaAsync(invioId, aziendaId);

        if (string.IsNullOrWhiteSpace(ctx.Azienda.SitoWeb))
            throw new InvalidOperationException(
                "L'azienda non ha un sito web configurato: il link di disiscrizione sarebbe rotto. " +
                "Compila 'Sito web' in Anagrafica Aziende prima di inviare.");

        var sender = await _emailFactory.GetSenderAsync(null, aziendaId);
        var canale = sender is SmtpEmailSender ? "smtp" : "resend";

        var invio = await _inviiService.GetByIdAsync(invioId, aziendaId)
                    ?? throw new InvalidOperationException("Newsletter non trovata.");
        invio.Stato = "in_invio";
        invio.Canale = canale;
        await _inviiService.UpdateAsync(invio);

        int ok = 0, err = 0;
        progress?.Report((0, recipients.Count));

        foreach (var rec in recipients)
        {
            // La lingua del destinatario governa per ora i soli testi del programma — in
            // particolare la frase di disiscrizione, che e' un obbligo di legge e finora partiva
            // in italiano verso tutti.
            var html = NewsletterRenderService.Render(ctx, rec.Email, rec.Lingua);

            bool sent;
            try { sent = await sender.SendHtmlEmailAsync(new[] { rec.Email }, oggetto, html, ctx.Azienda.RagioneSociale); }
            catch (Exception ex) { _logger.LogError(ex, "Invio newsletter fallito a {Email}", rec.Email); sent = false; }
            if (sent) ok++; else err++;

            try
            {
                await _destinatariService.CreateAsync(new WebNewsletterInvioDestinatario
                {
                    AziendaId = aziendaId, InvioIdFk = invioId, Email = rec.Email,
                    // Resta "IT" di proposito: il registro dice in che lingua e' la NEWSLETTER, e
                    // i contenuti sono ancora italiani. Diventera' rec.Lingua con la traduzione
                    // per campo — scriverlo adesso sarebbe una dichiarazione falsa.
                    Lingua = "IT", StatoConsegna = sent ? "inviato" : "errore", Data = DateTime.UtcNow
                });
            }
            catch (Exception ex) { _logger.LogWarning(ex, "Log destinatario {Email} fallito", rec.Email); }

            progress?.Report((ok + err, recipients.Count));
        }

        // corpo_html conserva l'istantanea di cio' che e' partito (con un indirizzo generico nel
        // link di disiscrizione: le firme per-destinatario non hanno senso nello storico).
        invio.Stato = "inviata";
        invio.CorpoHtml = NewsletterRenderService.Render(ctx, "archivio@storico");
        invio.NumeroDestinatari = recipients.Count;
        invio.DataInvio = DateTime.UtcNow;
        await _inviiService.UpdateAsync(invio);

        return new NewsletterSendResult(recipients.Count, ok, err, TradottoIncompleto: false);
    }

    /// <summary>Invio di prova di una newsletter a blocchi: il rendering REALE a un solo indirizzo.</summary>
    /// <remarks>
    /// Niente prefisso <c>[TEST]</c> e nessuna versione ridotta: serve proprio a vedere cosa
    /// arrivera' ai destinatari. Non registra la campagna nello storico.
    /// </remarks>
    public async Task<bool> SendProvaBlocchiAsync(
        int aziendaId, long invioId, string oggetto, string emailProva, NewsletterRenderService render)
    {
        var ctx = await render.PreparaAsync(invioId, aziendaId);

        if (string.IsNullOrWhiteSpace(ctx.Azienda.SitoWeb))
            throw new InvalidOperationException(
                "L'azienda non ha un sito web configurato: il link di disiscrizione sarebbe rotto. " +
                "Compila 'Sito web' in Anagrafica Aziende prima di inviare.");

        var html = NewsletterRenderService.Render(ctx, emailProva);
        var sender = await _emailFactory.GetSenderAsync(null, aziendaId);
        return await sender.SendHtmlEmailAsync(new[] { emailProva }, oggetto, html, ctx.Azienda.RagioneSociale);
    }

    /// <summary>Invio di prova a un solo indirizzo (in IT, senza registrare la campagna).</summary>
    public async Task<bool> SendTestAsync(int aziendaId, string oggetto, string corpoHtml, string testEmail)
    {
        var branding = await GetBrandingAsync(aziendaId);
        if (string.IsNullOrWhiteSpace(branding.Sito))
            throw new InvalidOperationException(
                "L'azienda non ha un sito web configurato: il link di disiscrizione sarebbe rotto. " +
                "Compila 'Sito web' in Anagrafica Aziende prima di inviare.");

        var sender = await _emailFactory.GetSenderAsync(null, aziendaId);
        var unsub = NewsletterUnsubscribe.BuildUrl(branding.Sito, testEmail, branding.Token);
        var html = BuildHtml(branding, corpoHtml, unsub);
        return await sender.SendHtmlEmailAsync(new[] { testEmail }, "[TEST] " + oggetto, html, branding.Nome);
    }
}
