using System.Net.Sockets;
using MailKit.Security;
using MailKit.Net.Smtp;

namespace GestioneViaggi.Services.Email;

public enum SmtpPhase { Connect, Authenticate }

/// <summary>
/// Punto UNICO dei messaggi d'errore SMTP (ITA). Mirror di DbErrorTranslator per il dominio rete/posta.
/// Usato da AziendaSmtpService.TestConnectionAsync e da SmtpEmailSender.
/// </summary>
public static class SmtpErrorTranslator
{
    public static string Translate(Exception ex, SmtpPhase phase, string host, int port) => ex switch
    {
        SocketException se when se.SocketErrorCode is SocketError.HostNotFound
                                                    or SocketError.NoData
                                                    or SocketError.TryAgain
            => $"Server di posta non trovato (DNS): controlla il nome host \"{host}\".",
        SocketException se when se.SocketErrorCode == SocketError.ConnectionRefused
            => $"Connessione rifiutata sulla porta {port}: porta chiusa o servizio non attivo su \"{host}\".",
        SocketException
            => $"Rete non raggiungibile verso \"{host}:{port}\": controlla la connessione.",
        SslHandshakeException
            => $"Errore TLS/SSL su \"{host}:{port}\": metodo di sicurezza o certificato non compatibili con la porta.",
        AuthenticationException
            => "Credenziali rifiutate: username o password errati.",
        SmtpCommandException sce
            => $"Errore SMTP dal server: {sce.Message}",
        SmtpProtocolException
            => "Errore di protocollo SMTP nella comunicazione con il server.",
        OperationCanceledException
            => $"Timeout: nessuna risposta da \"{host}:{port}\".",
        _ => "Errore imprevisto durante l'operazione SMTP. Dettaglio tecnico nei log."
    };

    public static string TimeoutMessage(bool hostReachableOnWeb, string host, int port) =>
        hostReachableOnWeb
            ? $"Il server \"{host}\" è raggiungibile ma la porta {port} non risponde: probabile firewall o VPN attiva. " +
              "Disattiva eventuali VPN e riprova (molti server di posta bloccano gli IP VPN/datacenter)."
            : $"Host irraggiungibile (\"{host}\"): controlla la connessione o il nome del server.";

    /// <summary>Probe TCP breve: il server risponde su 443 (o 80)? Usato per diagnosticare i timeout.</summary>
    public static async Task<bool> IsHostReachableOnWebAsync(string host, int timeoutMs = 4000)
    {
        foreach (var p in new[] { 443, 80 })
        {
            try
            {
                using var c = new System.Net.Sockets.TcpClient();
                using var cts = new CancellationTokenSource(timeoutMs);
                await c.ConnectAsync(host, p, cts.Token);
                if (c.Connected) return true;
            }
            catch { /* prova la prossima porta */ }
        }
        return false;
    }
}
