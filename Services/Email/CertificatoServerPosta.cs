using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Email;

/// <summary>
/// Decide se fidarsi del certificato del server di posta.
///
/// Prima qui c'era <c>(s, c, h, e) =&gt; true</c>: qualunque certificato andava bene. Un
/// intermediario che si fosse messo in mezzo con un certificato inventato sarebbe stato
/// accettato, e con lui <b>utenza e password della casella</b>. ⚠️ Era l'esatto contrario
/// della vulnerabilità chiusa aggiornando MailKit alla 4.17 (CVE-2026-41319, un attacco
/// dell'uomo in mezzo): finché la validazione è disattivata, la correzione della libreria
/// protegge molto meno.
///
/// <para><b>Perché quel callback c'era.</b> Misurato il 2026-09-05 con MailKit 4.17 sul
/// server reale: .NET costruisce la catena <b>per intero</b> — foglia → YR1 → Root YR →
/// ISRG Root X1, che macOS conosce — e l'unico rilievo è
/// <c>RevocationStatusUnknown: An incomplete certificate revocation check occurred</c>.
/// Cioè il certificato è valido e la catena è attendibile: .NET non riesce soltanto a
/// <i>completare il controllo di revoca</i>, cosa comune da quando Let's Encrypt ha
/// dismesso OCSP. Il sito, in Python, lo stesso server lo valida senza aiuto.</para>
///
/// <para>La regola qui sotto tollera <b>solo</b> quel caso. Nome che non corrisponde,
/// certificato scaduto, catena che non arriva a una radice attendibile, firma non valida:
/// tutto il resto viene rifiutato, come deve essere.</para>
/// </summary>
internal static class CertificatoServerPosta
{
    /// <summary>
    /// Il validatore da assegnare a <c>ServerCertificateValidationCallback</c>.
    /// </summary>
    public static RemoteCertificateValidationCallback Validatore(ILogger logger, string host) =>
        (_, certificato, catena, errori) => Accettabile(logger, host, certificato, catena, errori);

    private static bool Accettabile(ILogger logger, string host,
                                    X509Certificate? certificato, X509Chain? catena,
                                    SslPolicyErrors errori)
    {
        if (errori == SslPolicyErrors.None) return true;

        // Nome che non corrisponde o certificato assente: non si tratta. Sono i due segni
        // di chi si sta spacciando per il server di posta.
        if (errori.HasFlag(SslPolicyErrors.RemoteCertificateNameMismatch) ||
            errori.HasFlag(SslPolicyErrors.RemoteCertificateNotAvailable))
        {
            logger.LogError("Certificato di {Host} rifiutato: {Errori}", host, errori);
            return false;
        }

        if (catena is null)
        {
            logger.LogError("Certificato di {Host} rifiutato: catena non disponibile", host);
            return false;
        }

        // Resta il solo RemoteCertificateChainErrors. Si guarda PERCHE': si tollera
        // l'impossibilita' di verificare la revoca, nient'altro.
        var soloRevoca = catena.ChainStatus.Length > 0 && catena.ChainStatus.All(s =>
            s.Status is X509ChainStatusFlags.RevocationStatusUnknown
                     or X509ChainStatusFlags.OfflineRevocation);

        if (!soloRevoca)
        {
            var dettaglio = string.Join(", ", catena.ChainStatus.Select(s => s.Status));
            logger.LogError("Certificato di {Host} rifiutato: {Dettaglio}", host,
                            dettaglio.Length > 0 ? dettaglio : errori.ToString());
            return false;
        }

        logger.LogWarning(
            "Certificato di {Host} accettato: catena valida, ma il controllo di revoca non " +
            "si e' potuto completare. E' il comportamento atteso da quando Let's Encrypt ha " +
            "dismesso OCSP; se questo messaggio cambia, va guardato.", host);
        return true;
    }
}
