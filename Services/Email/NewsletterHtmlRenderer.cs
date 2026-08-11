using System.Net;
using System.Text;
using GestioneViaggi.Models.Web;

namespace GestioneViaggi.Services.Email;

/// <summary>Un blocco pronto da renderizzare (gia' tradotto nella lingua del destinatario).</summary>
public sealed record NewsletterRenderBlocco(
    string Tipo,
    string Layout = "pieno",
    int Colonne = 1,
    string? Titolo = null,
    string? Sottotitolo = null,
    string? CorpoHtml = null,
    string? ImmagineUrl = null,
    string? ImmagineAlt = null,
    string? LinkUrl = null,
    string? LinkEtichetta = null,
    string? Social = null,
    string? IconaUrl = null);

/// <summary>Dati dell'azienda usati da intestazione e footer.</summary>
public sealed record NewsletterRenderAzienda(
    string RagioneSociale,
    string? LogoUrl = null,
    string? Indirizzo = null,
    string? PartitaIva = null,
    string? Email = null,
    string? Telefono = null,
    string? SitoWeb = null);

/// <summary>
/// Composizione del footer, configurabile per azienda (§6.5 del design).
/// <paramref name="Campi"/> elenca i campi nell'ordine voluto, fra:
/// ragione_sociale, indirizzo, partita_iva, email, telefono, sito_web.
/// </summary>
public sealed record NewsletterFooterConfig(
    IReadOnlyList<string> Campi,
    int Colonne = 1,
    string Allineamento = "centro")
{
    /// <summary>Composizione di default quando l'azienda non ne ha configurata una.</summary>
    public static NewsletterFooterConfig Default { get; } = new(
        new[] { "ragione_sociale", "indirizzo", "partita_iva", "email", "telefono", "sito_web" });
}

/// <summary>
/// Rende una newsletter a blocchi in HTML per email.
/// </summary>
/// <remarks>
/// <para><b>Vincoli non negoziabili, imposti dai client di posta e non da preferenze stilistiche:</b></para>
/// <list type="bullet">
///   <item>layout a <b>tabelle</b>, mai flex o grid: Outlook per Windows usa il motore di Word;</item>
///   <item>stili <b>inline</b>, niente &lt;style&gt; nell'head: molti client lo rimuovono;</item>
///   <item>larghezza fissa <b>600px</b>, che e' la larghezza sicura storica del riquadro di lettura;</item>
///   <item>immagini con attributo <c>width</c> <i>oltre</i> allo stile, <c>display:block</c> e <c>border:0</c>;</item>
///   <item>nessuna URI <c>data:</c> e nessun WebP: Outlook non li renderizza (vedi §2.4 del design).</item>
/// </list>
/// <para>Classe <b>pura</b>: nessuna dipendenza, nessun I/O. Riceve dati gia' risolti (URL delle
/// immagini gia' pubbliche e in JPEG, testi gia' tradotti) e restituisce una stringa. E' cio' che
/// la rende verificabile fuori dall'applicazione.</para>
/// </remarks>
public static class NewsletterHtmlRenderer
{
    private const int Larghezza = 600;
    private const string FontFamily = "Arial, Helvetica, sans-serif";
    private const string ColoreTesto = "#333333";
    private const string ColoreTenue = "#888888";
    private const string ColoreAccento = SocialCatalogo.ColoreDefault;
    private const string ColoreSfondo = "#f4f4f4";

    public static string Render(
        IEnumerable<NewsletterRenderBlocco> blocchi,
        NewsletterRenderAzienda azienda,
        NewsletterFooterConfig? footerConfig,
        string unsubscribeUrl)
    {
        var lista = blocchi?.ToList() ?? new List<NewsletterRenderBlocco>();
        var cfg = footerConfig ?? NewsletterFooterConfig.Default;
        var sb = new StringBuilder();

        sb.Append($@"<!DOCTYPE html PUBLIC ""-//W3C//DTD XHTML 1.0 Transitional//EN"" ""http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"">
<html xmlns=""http://www.w3.org/1999/xhtml"">
<head>
<meta http-equiv=""Content-Type"" content=""text/html; charset=UTF-8"" />
<meta name=""viewport"" content=""width=device-width, initial-scale=1.0"" />
<title>{Esc(azienda.RagioneSociale)}</title>
</head>
<body style=""margin:0;padding:0;background-color:{ColoreSfondo};"">
<table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" border=""0"" style=""background-color:{ColoreSfondo};"">
  <tr>
    <td align=""center"" style=""padding:16px 8px;"">
      <table role=""presentation"" width=""{Larghezza}"" cellpadding=""0"" cellspacing=""0"" border=""0"" style=""width:{Larghezza}px;max-width:{Larghezza}px;background-color:#ffffff;"">");

        // I blocchi 'tour' con colonne=2 consecutivi vanno affiancati a coppie: e' il caso
        // "due tour affiancati invece che impilati" del design (§6.4).
        for (int i = 0; i < lista.Count; i++)
        {
            var b = lista[i];

            if (b.Tipo == "tour" && b.Colonne == 2
                && i + 1 < lista.Count && lista[i + 1].Tipo == "tour" && lista[i + 1].Colonne == 2)
            {
                sb.Append(RenderTourAffiancati(b, lista[i + 1]));
                i++; // consumata anche la seconda
                continue;
            }

            // Pulsanti "in fila": una sequenza di pulsanti marcati come affiancati finisce in
            // UNA riga sola, divisa in celle uguali. Senza, ogni pulsante prende una riga a
            // piena larghezza e l'allineamento li dispone a scaletta invece che in fila.
            if (b.Tipo == "pulsante" && b.Colonne == 2
                && i + 1 < lista.Count && lista[i + 1].Tipo == "pulsante" && lista[i + 1].Colonne == 2)
            {
                var fila = new List<NewsletterRenderBlocco>();
                // Massimo tre per fila: le caselle sono tre (sinistra, centro, destra). Un
                // quarto pulsante non avrebbe una posizione da dichiarare, quindi apre una
                // nuova fila invece di stringere tutti.
                while (i < lista.Count && lista[i].Tipo == "pulsante" && lista[i].Colonne == 2
                       && fila.Count < NewsletterLayout.MaxPulsantiInFila)
                {
                    fila.Add(lista[i]);
                    i++;
                }
                i--; // il for incrementa di nuovo
                sb.Append(RenderPulsantiInFila(fila));
                continue;
            }

            sb.Append(RenderBlocco(b, azienda, cfg, unsubscribeUrl));
        }

        sb.Append(@"
      </table>
    </td>
  </tr>
</table>
</body>
</html>");

        return sb.ToString();
    }

    private static string RenderBlocco(
        NewsletterRenderBlocco b, NewsletterRenderAzienda azienda,
        NewsletterFooterConfig cfg, string unsubscribeUrl) => b.Tipo switch
        {
            "intestazione" => RenderIntestazione(azienda),
            "testata"      => RenderTestata(b),
            "testo"        => RenderTesto(b),
            "info"         => RenderInfo(b),
            "tour"         => RenderTour(b),
            "immagine"     => RenderImmagine(b),
            "pulsante"     => RenderPulsante(b),
            "separatore"   => RenderSeparatore(),
            "footer"       => RenderFooter(azienda, cfg, unsubscribeUrl),
            _              => string.Empty
        };

    private static string RenderIntestazione(NewsletterRenderAzienda a)
    {
        // Logo via URL pubblico: mai data: URI, che Outlook non renderizza.
        var contenuto = string.IsNullOrWhiteSpace(a.LogoUrl)
            ? $@"<div style=""font-family:{FontFamily};font-size:22px;font-weight:bold;color:{ColoreAccento};"">{Esc(a.RagioneSociale)}</div>"
            : $@"<img src=""{Esc(a.LogoUrl)}"" alt=""{Esc(a.RagioneSociale)}"" width=""200"" style=""width:200px;max-width:200px;height:auto;display:block;border:0;outline:none;text-decoration:none;"" />";

        return $@"
        <tr><td align=""center"" style=""padding:24px 32px 12px 32px;"">{contenuto}</td></tr>";
    }

    private static string RenderTestata(NewsletterRenderBlocco b)
    {
        var sb = new StringBuilder();

        // Testo SOPRA l'immagine non si fa: richiederebbe background-image, che in Outlook
        // funziona solo con VML. Immagine, poi titolo sotto: robusto ovunque.
        if (!string.IsNullOrWhiteSpace(b.ImmagineUrl))
        {
            sb.Append($@"
        <tr><td style=""padding:0;"">
          <img src=""{Esc(b.ImmagineUrl)}"" alt=""{Esc(b.ImmagineAlt)}"" width=""{Larghezza}"" style=""width:{Larghezza}px;max-width:100%;height:auto;display:block;border:0;"" />
        </td></tr>");
        }

        if (!string.IsNullOrWhiteSpace(b.Titolo))
        {
            sb.Append($@"
        <tr><td align=""center"" style=""padding:20px 32px 4px 32px;"">
          <h1 style=""margin:0;font-family:{FontFamily};font-size:26px;line-height:32px;color:{ColoreAccento};"">{Esc(b.Titolo)}</h1>
        </td></tr>");
        }

        if (!string.IsNullOrWhiteSpace(b.Sottotitolo))
        {
            sb.Append($@"
        <tr><td align=""center"" style=""padding:0 32px 16px 32px;"">
          <p style=""margin:0;font-family:{FontFamily};font-size:16px;line-height:24px;color:{ColoreTesto};"">{Esc(b.Sottotitolo)}</p>
        </td></tr>");
        }

        return sb.ToString();
    }

    private static string RenderTesto(NewsletterRenderBlocco b)
    {
        if (string.IsNullOrWhiteSpace(b.CorpoHtml)) return string.Empty;
        var align = AllineaDaLayout(b.Layout);

        // CorpoHtml arriva dall'editor: e' HTML gia' formato, non va escapizzato.
        return $@"
        <tr><td align=""{align}"" style=""padding:12px 32px;font-family:{FontFamily};font-size:15px;line-height:22px;color:{ColoreTesto};"">
          {b.CorpoHtml}
        </td></tr>";
    }

    /// <summary>
    /// Riquadro informativo: icona a fianco, titolo e testo di seguito.
    /// </summary>
    /// <remarks>
    /// Ricalcato sulla newsletter reale (CHI PUO' PARTECIPARE, COSTI, ADESIONI). L'immagine e'
    /// un'icona di accompagnamento, non una copertina: colonna stretta e fissa, cosi' il testo
    /// resta il protagonista e i riquadri incolonnati appaiono allineati fra loro.
    /// La colonna dell'icona resta larga uguale anche quando l'immagine manca, altrimenti un
    /// riquadro senza icona sfalserebbe i titoli rispetto agli altri.
    /// </remarks>
    private static string RenderInfo(NewsletterRenderBlocco b)
    {
        const int LarghezzaIcona = 130;

        var testo = new StringBuilder();
        if (!string.IsNullOrWhiteSpace(b.Titolo))
            testo.Append($@"<h3 style=""margin:0 0 8px 0;font-family:{FontFamily};font-size:15px;line-height:20px;color:{ColoreAccento};text-transform:uppercase;"">{Esc(b.Titolo)}</h3>");
        if (!string.IsNullOrWhiteSpace(b.Sottotitolo))
            testo.Append($@"<p style=""margin:0 0 6px 0;font-family:{FontFamily};font-size:13px;color:{ColoreTenue};"">{Esc(b.Sottotitolo)}</p>");
        if (!string.IsNullOrWhiteSpace(b.CorpoHtml))
            testo.Append($@"<div style=""font-family:{FontFamily};font-size:14px;line-height:21px;color:{ColoreTesto};"">{b.CorpoHtml}</div>");

        var icona = string.IsNullOrWhiteSpace(b.ImmagineUrl)
            ? "&nbsp;"
            : $@"<img src=""{Esc(b.ImmagineUrl)}"" alt=""{Esc(b.ImmagineAlt)}"" width=""110"" style=""width:110px;max-width:110px;height:auto;display:block;border:0;"" />";

        var cellaIcona = $@"<td width=""{LarghezzaIcona}"" valign=""top"" align=""center"" style=""width:{LarghezzaIcona}px;padding:0;"">{icona}</td>";
        var cellaTesto = b.Layout == "destra"
            ? $@"<td valign=""top"" style=""padding:0 16px 0 0;"">{testo}</td>"
            : $@"<td valign=""top"" style=""padding:0 0 0 16px;"">{testo}</td>";

        var righe = b.Layout == "destra" ? cellaTesto + cellaIcona : cellaIcona + cellaTesto;

        return $@"
        <tr><td style=""padding:14px 32px;border-bottom:1px solid #ececec;"">
          <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" border=""0"">
            <tr>{righe}</tr>
          </table>
        </td></tr>";
    }

    private static string RenderTour(NewsletterRenderBlocco b)
    {
        var testo = TestoTour(b, 0);

        // layout pieno: immagine sopra, testo sotto
        if (b.Layout == "pieno" || string.IsNullOrWhiteSpace(b.ImmagineUrl))
        {
            var img = string.IsNullOrWhiteSpace(b.ImmagineUrl) ? "" : $@"
              <tr><td style=""padding:0 0 12px 0;""><img src=""{Esc(b.ImmagineUrl)}"" alt=""{Esc(b.ImmagineAlt)}"" width=""536"" style=""width:536px;max-width:100%;height:auto;display:block;border:0;"" /></td></tr>";

            return $@"
        <tr><td style=""padding:16px 32px;"">
          <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" border=""0"">{img}
            <tr><td>{testo}</td></tr>
          </table>
        </td></tr>";
        }

        // layout sinistra/destra: due celle affiancate (Outlook regge le tabelle, non flex)
        var cellaImg = $@"<td width=""240"" valign=""top"" style=""width:240px;padding:0;"">
              <img src=""{Esc(b.ImmagineUrl)}"" alt=""{Esc(b.ImmagineAlt)}"" width=""240"" style=""width:240px;max-width:240px;height:auto;display:block;border:0;"" />
            </td>";
        var cellaTxt = $@"<td valign=""top"" style=""padding:0 0 0 16px;"">{testo}</td>";
        var cellaTxtDx = $@"<td valign=""top"" style=""padding:0 16px 0 0;"">{testo}</td>";

        var righe = b.Layout == "sinistra"
            ? cellaImg + cellaTxt      // immagine a sinistra
            : cellaTxtDx + cellaImg;   // immagine a destra

        return $@"
        <tr><td style=""padding:16px 32px;"">
          <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" border=""0"">
            <tr>{righe}</tr>
          </table>
        </td></tr>";
    }

    private static string RenderTourAffiancati(NewsletterRenderBlocco a, NewsletterRenderBlocco b)
    {
        static string Colonna(NewsletterRenderBlocco t, string padding)
        {
            var img = string.IsNullOrWhiteSpace(t.ImmagineUrl) ? "" : $@"
                <tr><td style=""padding:0 0 10px 0;""><img src=""{Esc(t.ImmagineUrl)}"" alt=""{Esc(t.ImmagineAlt)}"" width=""258"" style=""width:258px;max-width:100%;height:auto;display:block;border:0;"" /></td></tr>";

            return $@"<td width=""268"" valign=""top"" style=""width:268px;{padding}"">
              <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" border=""0"">{img}
                <tr><td>{TestoTour(t, 1)}</td></tr>
              </table>
            </td>";
        }

        return $@"
        <tr><td style=""padding:16px 32px;"">
          <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" border=""0"">
            <tr>
              {Colonna(a, "padding:0 10px 0 0;")}
              {Colonna(b, "padding:0 0 0 10px;")}
            </tr>
          </table>
        </td></tr>";
    }

    /// <summary>Titolo + testo + pulsante di un riquadro tour. <paramref name="livello"/> 1 = versione affiancata (piu' piccola).</summary>
    private static string TestoTour(NewsletterRenderBlocco b, int livello)
    {
        var sb = new StringBuilder();
        var dimTitolo = livello == 0 ? 20 : 17;

        if (!string.IsNullOrWhiteSpace(b.Titolo))
            sb.Append($@"<h2 style=""margin:0 0 6px 0;font-family:{FontFamily};font-size:{dimTitolo}px;line-height:{dimTitolo + 6}px;color:{ColoreAccento};"">{Esc(b.Titolo)}</h2>");

        if (!string.IsNullOrWhiteSpace(b.Sottotitolo))
            sb.Append($@"<p style=""margin:0 0 8px 0;font-family:{FontFamily};font-size:13px;color:{ColoreTenue};"">{Esc(b.Sottotitolo)}</p>");

        if (!string.IsNullOrWhiteSpace(b.CorpoHtml))
            sb.Append($@"<div style=""font-family:{FontFamily};font-size:14px;line-height:21px;color:{ColoreTesto};"">{b.CorpoHtml}</div>");

        if (!string.IsNullOrWhiteSpace(b.LinkUrl))
            sb.Append(BottoneBulletproof(b.LinkUrl!, b.LinkEtichetta ?? "Vai alla pagina del Tour", allineaSinistra: true));

        return sb.ToString();
    }

    private static string RenderImmagine(NewsletterRenderBlocco b)
    {
        if (string.IsNullOrWhiteSpace(b.ImmagineUrl)) return string.Empty;

        var img = $@"<img src=""{Esc(b.ImmagineUrl)}"" alt=""{Esc(b.ImmagineAlt)}"" width=""536"" style=""width:536px;max-width:100%;height:auto;display:block;border:0;"" />";
        if (!string.IsNullOrWhiteSpace(b.LinkUrl))
            img = $@"<a href=""{Esc(b.LinkUrl)}"" target=""_blank"" style=""text-decoration:none;"">{img}</a>";

        return $@"
        <tr><td align=""{AllineaDaLayout(b.Layout)}"" style=""padding:16px 32px;"">{img}</td></tr>";
    }

    private static string RenderPulsante(NewsletterRenderBlocco b)
    {
        if (string.IsNullOrWhiteSpace(b.LinkUrl)) return string.Empty;
        var etichetta = string.IsNullOrWhiteSpace(b.LinkEtichetta) ? "Scopri di piu'" : b.LinkEtichetta!;

        return $@"
        <tr><td align=""{AllineaDaLayout(b.Layout)}"" style=""padding:8px 32px 16px 32px;"">
          {BottoneBulletproof(b.LinkUrl!, etichetta, allineaSinistra: false, b.Social, b.IconaUrl)}
        </td></tr>";
    }

    /// <summary>
    /// Pulsante a tabella e non &lt;a&gt; stilizzato: Outlook ignora padding e background su un
    /// link, e il risultato sarebbe testo blu sottolineato al posto del bottone.
    /// </summary>
    /// <remarks>
    /// Su un pulsante social il colore e' quello del marchio e, se c'e' un'icona, compare a
    /// sinistra del testo. L'icona e' un <c>&lt;img&gt;</c> con URL pubblico: nelle email non
    /// esistono alternative — i font di icone non vengono caricati, l'SVG non e' renderizzato da
    /// Outlook e le URI <c>data:</c> nemmeno. Se l'icona manca resta il solo colore, che gia'
    /// distingue il pulsante.
    /// </remarks>
    private static string BottoneBulletproof(
        string url, string etichetta, bool allineaSinistra,
        string? social = null, string? iconaUrl = null)
    {
        var margine = allineaSinistra ? "margin-top:10px;" : "";
        var colore = SocialCatalogo.Colore(social);

        // vertical-align:middle e non default: senza, l'icona spinge in basso la riga di testo.
        var icona = string.IsNullOrWhiteSpace(iconaUrl) ? "" :
            $@"<img src=""{Esc(iconaUrl)}"" alt="""" width=""18"" height=""18"" style=""width:18px;height:18px;display:inline-block;vertical-align:middle;border:0;margin-right:8px;"" />";

        var testo = $@"<span style=""vertical-align:middle;"">{Esc(etichetta)}</span>";

        return $@"<table role=""presentation"" cellpadding=""0"" cellspacing=""0"" border=""0"" style=""{margine}"">
            <tr><td align=""center"" bgcolor=""{colore}"" style=""background-color:{colore};border-radius:4px;"">
              <a href=""{Esc(url)}"" target=""_blank"" style=""display:inline-block;padding:11px 22px;font-family:{FontFamily};font-size:14px;font-weight:bold;color:#ffffff;text-decoration:none;"">{icona}{testo}</a>
            </td></tr>
          </table>";
    }

    /// <summary>
    /// Piu' pulsanti su una sola riga. La riga e' sempre divisa in <b>tre caselle uguali</b> e
    /// ogni pulsante occupa quella dichiarata nel proprio <c>layout</c>.
    /// </summary>
    /// <remarks>
    /// Nella prima versione l'allineamento del singolo veniva ignorato e i pulsanti si
    /// disponevano nell'ordine dei blocchi: la posizione risultava quindi decisa dall'ordine in
    /// elenco, che in una lista verticale non si legge come "sinistra-centro-destra". Ora la
    /// posizione e' dichiarata.
    /// <para>Le caselle vuote restano vuote di proposito: sinistra + destra senza il centro e' una
    /// disposizione legittima, e riempire il buco spostando i pulsanti tradirebbe la scelta.</para>
    /// </remarks>
    private static string RenderPulsantiInFila(List<NewsletterRenderBlocco> fila)
    {
        // Tre caselle fisse: 0 = sinistra, 1 = centro, 2 = destra.
        var caselle = new NewsletterRenderBlocco?[NewsletterLayout.MaxPulsantiInFila];

        foreach (var b in fila.Take(NewsletterLayout.MaxPulsantiInFila))
        {
            var voluta = b.Layout switch { "sinistra" => 0, "centro" => 1, "destra" => 2, _ => -1 };

            // Casella non dichiarata o gia' occupata: si prende la prima libera, cosi' un
            // pulsante non sparisce mai per un conflitto (che la UI comunque impedisce).
            if (voluta < 0 || caselle[voluta] != null)
                voluta = Array.FindIndex(caselle, c => c == null);

            if (voluta >= 0) caselle[voluta] = b;
        }

        var allineamenti = new[] { "left", "center", "right" };
        var celle = new StringBuilder();

        for (int c = 0; c < NewsletterLayout.MaxPulsantiInFila; c++)
        {
            var b = caselle[c];
            var contenuto = "&nbsp;";
            if (b != null && !string.IsNullOrWhiteSpace(b.LinkUrl))
            {
                var etichetta = string.IsNullOrWhiteSpace(b.LinkEtichetta) ? "Scopri di piu'" : b.LinkEtichetta!;
                contenuto = BottoneBulletproof(b.LinkUrl!, etichetta, allineaSinistra: false, b.Social, b.IconaUrl);
            }

            celle.Append($@"<td width=""33.33%"" align=""{allineamenti[c]}"" valign=""middle"" style=""width:33.33%;padding:0 4px;"">{contenuto}</td>");
        }

        return $@"
        <tr><td style=""padding:8px 32px 16px 32px;"">
          <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" border=""0"">
            <tr>{celle}</tr>
          </table>
        </td></tr>";
    }

    private static string RenderSeparatore() => $@"
        <tr><td style=""padding:8px 32px;""><hr style=""border:none;border-top:1px solid #e0e0e0;margin:0;"" /></td></tr>";

    private static string RenderFooter(NewsletterRenderAzienda a, NewsletterFooterConfig cfg, string unsubscribeUrl)
    {
        var valori = new List<string>();
        foreach (var campo in cfg.Campi)
        {
            var v = campo switch
            {
                "ragione_sociale" => a.RagioneSociale,
                "indirizzo"       => a.Indirizzo,
                "partita_iva"     => string.IsNullOrWhiteSpace(a.PartitaIva) ? null : $"P. IVA {a.PartitaIva}",
                "email"           => a.Email,
                "telefono"        => a.Telefono,
                "sito_web"        => a.SitoWeb,
                _                 => null
            };
            if (!string.IsNullOrWhiteSpace(v)) valori.Add(Esc(v!));
        }

        var align = cfg.Allineamento switch { "sinistra" => "left", "destra" => "right", _ => "center" };
        string corpo;

        if (cfg.Colonne == 2 && valori.Count > 1)
        {
            var meta = (valori.Count + 1) / 2;
            var sx = string.Join("<br />", valori.Take(meta));
            var dx = string.Join("<br />", valori.Skip(meta));
            corpo = $@"<table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" border=""0"">
              <tr>
                <td valign=""top"" align=""{align}"" style=""font-family:{FontFamily};font-size:12px;line-height:18px;color:{ColoreTenue};"">{sx}</td>
                <td valign=""top"" align=""{align}"" style=""font-family:{FontFamily};font-size:12px;line-height:18px;color:{ColoreTenue};"">{dx}</td>
              </tr>
            </table>";
        }
        else
        {
            corpo = $@"<div style=""font-family:{FontFamily};font-size:12px;line-height:18px;color:{ColoreTenue};"">{string.Join("<br />", valori)}</div>";
        }

        // Il link di disiscrizione NON e' configurabile e non e' rimovibile: e' obbligo di legge
        // per la posta commerciale ed e' l'unico meccanismo che rende possibile disiscriversi
        // (§6.5 del design).
        return $@"
        <tr><td style=""padding:20px 32px 8px 32px;""><hr style=""border:none;border-top:1px solid #e0e0e0;margin:0;"" /></td></tr>
        <tr><td align=""{align}"" style=""padding:4px 32px 8px 32px;"">{corpo}</td></tr>
        <tr><td align=""{align}"" style=""padding:0 32px 24px 32px;"">
          <p style=""margin:0;font-family:{FontFamily};font-size:12px;line-height:18px;color:{ColoreTenue};"">
            Non desideri piu' ricevere la nostra newsletter?
            <a href=""{Esc(unsubscribeUrl)}"" target=""_blank"" style=""color:{ColoreTenue};"">Disiscriviti</a>
          </p>
        </td></tr>";
    }

    /// <summary>
    /// Su testo, pulsante e immagine il campo <c>layout</c> significa <b>allineamento</b>
    /// (su tour e' invece la posizione dell'immagine). <c>pieno</c> resta a sinistra: e' il
    /// default storico e su un paragrafo "piena larghezza" equivale a testo allineato a sinistra.
    /// </summary>
    private static string AllineaDaLayout(string? layout) => layout switch
    {
        "sinistra" => "left",
        "destra"   => "right",
        "centro"   => "center",
        _          => "left"
    };

    private static string Esc(string? s) => WebUtility.HtmlEncode(s ?? string.Empty);
}
