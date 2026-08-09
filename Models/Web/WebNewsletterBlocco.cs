namespace GestioneViaggi.Models.Web;

/// <summary>
/// Blocco che compone una newsletter (script 512). Quali campi siano valorizzati dipende dal
/// <see cref="Tipo"/>; i campi traducibili sono Titolo, Sottotitolo, CorpoHtml, ImmagineAlt,
/// LinkEtichetta.
/// </summary>
public sealed class WebNewsletterBlocco
{
    public long WebNewsletterBloccoId { get; set; }
    public long InvioIdFk { get; set; }

    /// <summary>intestazione | testata | testo | tour | immagine | pulsante | separatore | footer. Immutabile dopo la creazione.</summary>
    public string Tipo { get; set; } = "testo";

    public int Ordine { get; set; }

    /// <summary>sinistra | destra | pieno — disposizione del contenuto dentro il blocco.</summary>
    public string Layout { get; set; } = "pieno";

    /// <summary>1 o 2. Su blocchi 'tour' consecutivi, 2 li fa affiancare a coppie.</summary>
    public short Colonne { get; set; } = 1;

    public string? Titolo { get; set; }
    public string? Sottotitolo { get; set; }
    public string? CorpoHtml { get; set; }

    /// <summary>URL pubblico gia' pronto per l'email (JPEG). Vedi NewsletterMediaService.</summary>
    public string? ImmagineUrl { get; set; }
    public string? ImmagineStoragePath { get; set; }
    public string? ImmagineAlt { get; set; }

    public string? LinkUrl { get; set; }
    public string? LinkEtichetta { get; set; }

    /// <summary>Solo per Tipo='tour': l'edizione da cui si ricavano copertina, titolo e link.</summary>
    public int? DataViaggioIdFk { get; set; }

    public int AziendaId { get; set; }
}

/// <summary>Voce del catalogo dei tipi di blocco (fn_web_newsletter_tipi_blocco).</summary>
public sealed record WebNewsletterTipoBlocco(
    string Tipo, string Etichetta, bool Obbligatorio, int? MaxOccorrenze, int OrdineCatalogo);

/// <summary>Riga dell'elenco newsletter (fn_web_newsletter_elenco): bozze, inviate o modelli.</summary>
public sealed record WebNewsletterElencoVoce(
    long Id, string Oggetto, string Stato, DateTime? DataInvio, int? NumeroDestinatari,
    string? Canale, bool IsModello, int NumeroBlocchi, DateTime Created)
{
    public bool IsBozza => Stato == "bozza";
}
