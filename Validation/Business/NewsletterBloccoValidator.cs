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

            "info" when TestoVuoto(b.CorpoHtml) && Vuoto(b.Titolo)
                => "Il riquadro informativo è vuoto: serve almeno un titolo o un testo.",

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
    /// Problemi sulle FILE di pulsanti: una fila ha tre caselle e ogni pulsante ne dichiara una,
    /// quindi non si puo' andare oltre tre ne' occupare due volte la stessa casella.
    /// </summary>
    /// <remarks>
    /// Il controllo guarda l'INSIEME e non il singolo blocco: un pulsante e' valido da solo e
    /// diventa un problema per via dei vicini. Per questo non sta in <see cref="Valida"/>.
    /// </remarks>
    public static List<string> ValidaFilePulsanti(IEnumerable<WebNewsletterBlocco> blocchi)
    {
        var problemi = new List<string>();
        var ordinati = blocchi.OrderBy(b => b.Ordine).ToList();

        var i = 0;
        while (i < ordinati.Count)
        {
            if (ordinati[i].Tipo != "pulsante" || ordinati[i].Colonne != 2) { i++; continue; }

            var fila = new List<WebNewsletterBlocco>();
            while (i < ordinati.Count && ordinati[i].Tipo == "pulsante" && ordinati[i].Colonne == 2)
            {
                fila.Add(ordinati[i]);
                i++;
            }

            if (fila.Count < 2) continue;   // un pulsante solo non forma una fila

            var nomi = string.Join(", ", fila.Select(b => $"«{b.LinkEtichetta ?? "senza testo"}»"));

            if (fila.Count > NewsletterLayout.MaxPulsantiInFila)
            {
                problemi.Add($"Fila di {fila.Count} pulsanti ({nomi}): il massimo è {NewsletterLayout.MaxPulsantiInFila}, " +
                             "una fila ha tre posizioni (sinistra, centro, destra). Togli l'affiancamento a qualcuno.");
            }

            var doppie = fila.GroupBy(b => b.Layout).Where(g => g.Count() > 1).ToList();
            foreach (var g in doppie)
            {
                var quali = string.Join(" e ", g.Select(b => $"«{b.LinkEtichetta ?? "senza testo"}»"));
                problemi.Add($"Nella stessa fila {quali} occupano entrambi la posizione «{Posizione(g.Key)}»: " +
                             "ogni posizione può ospitare un solo pulsante.");
            }
        }

        return problemi;
    }

    private static string Posizione(string? layout) => layout switch
    {
        "sinistra" => "sinistra",
        "centro"   => "centro",
        "destra"   => "destra",
        _          => layout ?? "non dichiarata"
    };

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

        problemi.AddRange(ValidaFilePulsanti(blocchi));
        return problemi;
    }
}
