using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Email;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Avviso di superamento della soglia di spesa Claude: banner in app (deciso dai componenti) ed
/// email all'azienda. L'email parte <b>una sola volta per periodo</b> — la decisione sta nel DB
/// (<c>fn_web_ai_soglia_da_avvisare</c>, che controlla e marca nella stessa istruzione), non qui:
/// così due traduzioni ravvicinate non possono generare due messaggi.
/// </summary>
public sealed class WebAiAlertService
{
    private readonly IDatabaseService _db;
    private readonly WebAiConsumoService _consumi;
    private readonly EmailSenderFactory _emailFactory;
    private readonly ILogger<WebAiAlertService> _logger;

    public WebAiAlertService(IDatabaseService db, WebAiConsumoService consumi,
        EmailSenderFactory emailFactory, ILogger<WebAiAlertService> logger)
    {
        _db = db;
        _consumi = consumi;
        _emailFactory = emailFactory;
        _logger = logger;
    }

    /// <summary>
    /// Da chiamare al termine di un blocco di traduzioni. Non lancia mai: un avviso non recapitato
    /// non deve far sembrare fallita una traduzione riuscita e già pagata.
    /// </summary>
    public async Task VerificaEAvvisaAsync(int aziendaId)
    {
        try
        {
            var (daAvvisare, speso, soglia) = await _consumi.VerificaSogliaAsync(aziendaId);
            if (!daAvvisare || soglia is null) return;

            var destinatario = await GetEmailPrincipaleAsync(aziendaId);
            if (string.IsNullOrWhiteSpace(destinatario))
            {
                _logger.LogWarning("Soglia consumi AI superata per azienda {AziendaId} ma nessuna email principale configurata.", aziendaId);
                return;
            }

            var perc = soglia.Value > 0 ? speso / soglia.Value * 100m : 0m;
            var corpo =
                $"<p>La spesa stimata per le traduzioni automatiche ha raggiunto <b>{perc:N0}%</b> della soglia impostata.</p>" +
                $"<p>Speso: <b>{speso:N2}</b> su una soglia di <b>{soglia.Value:N2}</b>.</p>" +
                "<p>Il conteggio è una stima basata sui consumi registrati dal gestionale " +
                "(l'API non espone il credito residuo della chiave): verifica il saldo reale sulla console Anthropic " +
                "e, se hai ricaricato, riavvia il conteggio dalla scheda Traduzioni dell'azienda.</p>";

            var sender = await _emailFactory.GetSenderAsync(null, aziendaId);
            await sender.SendHtmlEmailAsync(new[] { destinatario! }, "Traduzioni automatiche: soglia di spesa raggiunta", corpo);
            _logger.LogInformation("Avviso soglia consumi AI inviato a {Email} (azienda {AziendaId})", destinatario, aziendaId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Invio avviso soglia consumi AI fallito (azienda {AziendaId})", aziendaId);
        }
    }

    private async Task<string?> GetEmailPrincipaleAsync(int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT fn_ana_aziende_email_principale(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        return (await cmd.ExecuteScalarAsync()) as string;
    }
}
