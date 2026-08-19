using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Email;
using GestioneViaggi.Services.Shared;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>Destinatario risolto (da fn_web_destinatari_newsletter). Telefono solo per i clienti.</summary>
public sealed record NewsletterRecipient(string Email, string? Nome, string? Cognome, string Lingua, string? Telefono = null);

/// <summary>Esito invio campagna.</summary>
public sealed record NewsletterSendResult(int Totale, int Inviate, int Errori);

/// <summary>
/// Esito dei controlli preliminari sul branding dell'azienda, letti PRIMA di spedire.
/// <paramref name="SitoMancante"/> e' bloccante: senza <c>sito_web</c> il link di disiscrizione
/// diventa <c>https://www.example.com/unsubscribe?…</c>, cioe' si spedisce a tutti un
/// "Disiscriviti" che non porta da nessuna parte. <paramref name="LogoMancante"/> e' solo un
/// avviso: la mail parte lo stesso, ma senza intestazione.
/// </summary>
public sealed record NewsletterPreflight(bool SitoMancante, bool LogoMancante);

/// <summary>
/// Motore invio newsletter (per-azienda): risolve i destinatari (clienti+iscritti−soppressioni),
/// compone i blocchi nella lingua di ciascuno, invia via SMTP/ESP dell'azienda, logga la consegna
/// per-destinatario, archivia il corpo di ogni lingua e registra la campagna. Link di disiscrizione
/// firmato HMAC.
/// </summary>
/// <remarks>
/// Le traduzioni <b>non</b> si fanno qui: sono gia' scritte campo per campo in <c>web_traduzioni</c>
/// (le produce il riquadro Lingue) e il rendering le pesca da li'. Il vecchio motore che traduceva
/// l'intero blob HTML al volo e' stato rimosso il 2026-08-19: era senza chiamanti da quando la
/// newsletter e' fatta di blocchi.
/// </remarks>
public sealed class NewsletterSenderService
{
    private readonly IDatabaseService _db;
    private readonly EmailSenderFactory _emailFactory;
    private readonly WebNewsletterInviiService _inviiService;
    private readonly WebNewsletterInviiDestinatariService _destinatariService;
    private readonly AziendaLogoService _logoService;
    private readonly ILogger<NewsletterSenderService> _logger;

    public NewsletterSenderService(
        IDatabaseService db, EmailSenderFactory emailFactory,
        WebNewsletterInviiService inviiService,
        WebNewsletterInviiDestinatariService destinatariService, AziendaLogoService logoService,
        ILogger<NewsletterSenderService> logger)
    {
        _db = db; _emailFactory = emailFactory;
        _inviiService = inviiService; _destinatariService = destinatariService;
        _logoService = logoService; _logger = logger;
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

    /// <summary>Conserva cio' che e' partito in una lingua. Vedi <c>web_newsletter_invii_corpi</c>.</summary>
    private async Task ArchiviaCorpoAsync(int aziendaId, long invioId, string lingua,
                                          string oggetto, string corpo, int destinatari)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT fn_web_newsletter_corpo_archivia(@Invio::bigint, @Az::integer, @Lingua::varchar, @Ogg::varchar, @Corpo::text, @N::integer)", conn);
        cmd.Parameters.AddWithValue("Invio", invioId);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("Lingua", lingua);
        cmd.Parameters.AddWithValue("Ogg", oggetto);
        cmd.Parameters.AddWithValue("Corpo", corpo);
        cmd.Parameters.AddWithValue("N", destinatari);
        await cmd.ExecuteNonQueryAsync();
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

    /// <summary>
    /// Lingue che qualcuno ricevera' davvero e che sono tradotte <b>a meta'</b>, come "DE 5/6".
    /// Vuoto = si spedisce.
    /// </summary>
    /// <remarks>
    /// <para>Regola sola per la UI (che blocca il pulsante) e per il motore (che rifiuta comunque):
    /// una mail per meta' in tedesco e per meta' in italiano arriva a un cliente vero e non si
    /// richiama indietro. Decisione del 2026-08-19: meglio non spedire che spedire mista.</para>
    /// <para><b>Mezza traduzione, non nessuna traduzione.</b> Una lingua a zero (nessuna chiave
    /// Claude, oppure semplicemente non ancora tradotta) non blocca: quella mail parte tutta in
    /// italiano, che e' coerente e si capisce. Il danno e' il miscuglio, non l'italiano.
    /// Senza questa distinzione un'azienda senza chiave Claude non potrebbe spedire affatto.</para>
    /// <para>Conta solo le lingue con destinatari: una traduzione francese a meta' non impedisce
    /// una spedizione dove nessuno e' francese.</para>
    /// </remarks>
    public async Task<IReadOnlyList<string>> LingueIncompleteAsync(
        int aziendaId, long invioId, NewsletterRenderService render)
    {
        var recipients = await GetRecipientsAsync(aziendaId, invioId);
        var lingueUsate = recipients
            .Select(r => (r.Lingua ?? "IT").Trim().ToUpperInvariant())
            .Where(l => l != "IT")
            .ToHashSet();

        if (lingueUsate.Count == 0) return Array.Empty<string>();

        var stato = await render.StatoTraduzioniAsync(invioId, aziendaId);
        return stato
            .Where(s => lingueUsate.Contains(s.Lingua.Trim().ToUpperInvariant())
                        && s.Tradotti > 0 && s.Tradotti < s.Traducibili)
            .Select(s => $"{s.Lingua.Trim()} {s.Tradotti}/{s.Traducibili}")
            .ToList();
    }

    /// <summary>
    /// Invia una newsletter <b>a blocchi</b>: l'HTML e' composto dai blocchi salvati e ricomposto
    /// per ogni destinatario, perche' il link di disiscrizione e' firmato sul suo indirizzo.
    /// </summary>
    /// <remarks>
    /// Ogni destinatario riceve la <b>sua</b> lingua: il rendering usa le traduzioni per campo e
    /// ricade sull'italiano solo dove manca qualcosa. Le lingue tradotte a meta' non arrivano
    /// nemmeno a questo punto — vedi <see cref="LingueIncompleteAsync"/>.
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

        // Guardia autoritativa sulle traduzioni: sta QUI e non solo nella UI, come per il sito web
        // mancante. E sta PRIMA di congelare gli indirizzi e di creare la riga di storico, cosi' un
        // invio rifiutato non lascia traccia ne' effetti.
        var incomplete = await LingueIncompleteAsync(aziendaId, invioId, render);
        if (incomplete.Count > 0)
            throw new InvalidOperationException(
                $"Traduzioni incomplete ({string.Join(", ", incomplete)}): la newsletter partirebbe " +
                "per meta' tradotta e per meta' in italiano. Completa le traduzioni, oppure togli " +
                "dai destinatari le lingue non pronte.");

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
            var html = NewsletterRenderService.Render(ctx, rec.Email, rec.Lingua);

            // L'oggetto segue il corpo: un testo tradotto sotto un oggetto italiano si riconosce
            // come posta indesiderata prima ancora di essere aperto.
            var oggettoLingua = NewsletterRenderService.Oggetto(ctx, oggetto, rec.Lingua);

            bool sent;
            try { sent = await sender.SendHtmlEmailAsync(new[] { rec.Email }, oggettoLingua, html, ctx.Azienda.RagioneSociale); }
            catch (Exception ex) { _logger.LogError(ex, "Invio newsletter fallito a {Email}", rec.Email); sent = false; }
            if (sent) ok++; else err++;

            try
            {
                await _destinatariService.CreateAsync(new WebNewsletterInvioDestinatario
                {
                    AziendaId = aziendaId, InvioIdFk = invioId, Email = rec.Email,
                    // La lingua con cui la mail e' stata composta. Dove una traduzione manca il
                    // singolo campo ricade sull'italiano, quindi il registro dice la lingua
                    // RICHIESTA, non una garanzia di completezza: quella si verifica prima di
                    // spedire, con lo stato delle traduzioni.
                    Lingua = rec.Lingua, StatoConsegna = sent ? "inviato" : "errore", Data = DateTime.UtcNow
                });
            }
            catch (Exception ex) { _logger.LogWarning(ex, "Log destinatario {Email} fallito", rec.Email); }

            progress?.Report((ok + err, recipients.Count));
        }

        // corpo_html conserva l'istantanea di cio' che e' partito (con un indirizzo generico nel
        // link di disiscrizione: le firme per-destinatario non hanno senso nello storico).
        invio.Stato = "inviata";
        // Archivio per lingua: una riga per ogni lingua effettivamente usata. Una newsletter
        // inviata e' la prova documentale di cosa e' stato mandato e a chi — se il registro dei
        // destinatari dice "DE" e l'archivio ha solo l'italiano, la prova non c'e' piu'.
        // Si rende con un indirizzo generico: le firme per-destinatario nel link di disiscrizione
        // non hanno senso nello storico.
        foreach (var gruppo in recipients.GroupBy(r => r.Lingua))
        {
            try
            {
                await ArchiviaCorpoAsync(
                    aziendaId, invioId, gruppo.Key,
                    NewsletterRenderService.Oggetto(ctx, oggetto, gruppo.Key),
                    NewsletterRenderService.Render(ctx, "archivio@storico", gruppo.Key),
                    gruppo.Count());
            }
            catch (Exception ex)
            {
                // L'archivio non deve far fallire un invio gia' avvenuto: le mail sono partite.
                _logger.LogError(ex, "Archivio del corpo {Lingua} non scritto per l'invio {Invio}", gruppo.Key, invioId);
            }
        }

        // Resta anche qui, in italiano: e' cio' che lo Storico mostra da sempre.
        invio.CorpoHtml = NewsletterRenderService.Render(ctx, "archivio@storico");
        invio.NumeroDestinatari = recipients.Count;
        invio.DataInvio = DateTime.UtcNow;
        await _inviiService.UpdateAsync(invio);

        return new NewsletterSendResult(recipients.Count, ok, err);
    }

    /// <summary>Invio di prova di una newsletter a blocchi: il rendering REALE a un solo indirizzo.</summary>
    /// <remarks>
    /// <para>Niente prefisso <c>[TEST]</c> e nessuna versione ridotta: serve proprio a vedere cosa
    /// arrivera' ai destinatari. Non registra la campagna nello storico.</para>
    /// <para>La <paramref name="lingua"/> e' quella che il destinatario vedrebbe: il rendering usa
    /// le traduzioni di quella lingua e l'oggetto tradotto, con lo stesso fallback per campo
    /// dell'invio vero. Prima era sempre italiano, e per vedere una newsletter in tedesco bisognava
    /// spedirla a tutti.</para>
    /// </remarks>
    public async Task<bool> SendProvaBlocchiAsync(
        int aziendaId, long invioId, string oggetto, string emailProva, NewsletterRenderService render,
        string lingua = "IT")
    {
        var ctx = await render.PreparaAsync(invioId, aziendaId);

        if (string.IsNullOrWhiteSpace(ctx.Azienda.SitoWeb))
            throw new InvalidOperationException(
                "L'azienda non ha un sito web configurato: il link di disiscrizione sarebbe rotto. " +
                "Compila 'Sito web' in Anagrafica Aziende prima di inviare.");

        var html = NewsletterRenderService.Render(ctx, emailProva, lingua);
        var oggettoTradotto = NewsletterRenderService.Oggetto(ctx, oggetto, lingua);
        var sender = await _emailFactory.GetSenderAsync(null, aziendaId);
        return await sender.SendHtmlEmailAsync(new[] { emailProva }, oggettoTradotto, html, ctx.Azienda.RagioneSociale);
    }

}
