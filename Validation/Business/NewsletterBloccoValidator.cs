using GestioneViaggi.Models.Web;

namespace GestioneViaggi.Validation.Business;

/// <summary>
/// Regole di completezza dei blocchi di una newsletter.
/// </summary>
/// <remarks>
/// Un blocco vuoto non e' un dato incoerente: e' una <b>dimenticanza</b>, e va intercettata in due
/// momenti diversi con la stessa regola — quando si salva il blocco e prima di spedire. Avere la
/// regola in un posto solo evita che i due controlli divergano nel tempo.
/// <para>Intestazione, footer e separatore non hanno contenuto proprio: si compilano dai dati
/// dell'azienda o non ne hanno affatto, quindi non possono essere "vuoti".</para>
/// </remarks>
public static class NewsletterBloccoValidator
{
    /// <summary>Messaggio d'errore se il blocco e' incompleto, altrimenti null.</summary>
    public static string? Valida(WebNewsletterBlocco b)
    {
        static bool Vuoto(string? s) => string.IsNullOrWhiteSpace(s);

        // Un HTML fatto solo di tag vuoti (<p><br></p>) e' vuoto a tutti gli effetti:
        // e' il caso che sfugge piu' facilmente perche' l'editor lo produce da solo.
        static bool TestoVuoto(string? html)
        {
            if (string.IsNullOrWhiteSpace(html)) return true;
            var senzaTag = System.Text.RegularExpressions.Regex.Replace(html, "<.*?>", "");
            return string.IsNullOrWhiteSpace(System.Net.WebUtility.HtmlDecode(senzaTag));
        }

        return b.Tipo switch
        {
            "intestazione" or "footer" or "separatore" => null,

            "testata" when Vuoto(b.ImmagineUrl) && Vuoto(b.Titolo)
                => "La testata è vuota: serve almeno un'immagine o un titolo.",

            "testo" when TestoVuoto(b.CorpoHtml)
                => "Il blocco di testo è vuoto: scrivi qualcosa o eliminalo.",

            "tour" when Vuoto(b.Titolo) && Vuoto(b.ImmagineUrl)
                => "Il riquadro tour è vuoto: scegli un tour, oppure compila almeno titolo e immagine.",

            "immagine" when Vuoto(b.ImmagineUrl)
                => "Il blocco immagine non ha un'immagine.",

            "pulsante" when Vuoto(b.LinkUrl)
                => "Il pulsante non ha un indirizzo di destinazione.",

            _ => null
        };
    }

    /// <summary>
    /// Elenco dei problemi su tutti i blocchi, nell'ordine in cui compaiono nella newsletter.
    /// Usato per bloccare invio e anteprima con un messaggio che dice <i>quale</i> blocco manca.
    /// </summary>
    public static List<string> ValidaTutti(IEnumerable<WebNewsletterBlocco> blocchi)
    {
        var problemi = new List<string>();
        var n = 0;
        foreach (var b in blocchi.OrderBy(x => x.Ordine))
        {
            n++;
            var errore = Valida(b);
            if (errore != null) problemi.Add($"Blocco {n} — {errore}");
        }
        return problemi;
    }
}
