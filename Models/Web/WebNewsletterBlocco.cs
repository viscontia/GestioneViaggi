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

    /// <summary>
    /// Voce della rubrica indirizzi da cui viene il collegamento (script 518). NULL = URL scritto
    /// a mano o dedotto dal tour. Finché la newsletter è bozza o modello il rendering risolve da
    /// qui, così correggere un indirizzo in rubrica allinea tutte le bozze; all'invio l'URL viene
    /// congelato in <see cref="LinkUrl"/> e la newsletter inviata non cambia più.
    /// </summary>
    public long? IndirizzoIdFk { get; set; }

    /// <summary>
    /// Social del pulsante e relativa icona, COPIATI dalla rubrica alla scelta (script 519/520):
    /// una newsletter già inviata non deve cambiare aspetto se in rubrica si sostituisce l'icona.
    /// </summary>
    public string? Social { get; set; }
    public string? IconaUrl { get; set; }

    /// <summary>
    /// Allineamento del pulsante, indipendente da quello dell'immagine (script 525).
    /// NULL = segue il layout del blocco.
    /// </summary>
    public string? LayoutPulsante { get; set; }

    /// <summary>Colore del titolo in #RRGGBB (script 526). NULL = colore predefinito.</summary>
    public string? ColoreTitolo { get; set; }

    /// <summary>Colore del sottotitolo in #RRGGBB (script 526). NULL = colore predefinito.</summary>
    public string? ColoreSottotitolo { get; set; }

    public int AziendaId { get; set; }

    /// <summary>
    /// Copia di lavoro del blocco, campo per campo.
    /// </summary>
    /// <remarks>
    /// Esiste perché la copia va fatta <b>tutta</b>. Era scritta a mano elencando i campi, e
    /// quell'elenco non veniva aggiornato: sono rimasti fuori il legame con la rubrica, il social,
    /// l'icona, la posizione del pulsante e i colori. Aprire un blocco in modifica e salvare li
    /// cancellava, senza alcun errore — si notava solo guardando la mail arrivata.
    /// <para><c>MemberwiseClone</c> copia i campi che ci sono, non quelli che qualcuno si è
    /// ricordato di elencare: aggiungendo una colonna non c'è più niente da aggiornare qui.</para>
    /// </remarks>
    public WebNewsletterBlocco Copia() => (WebNewsletterBlocco)MemberwiseClone();
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
