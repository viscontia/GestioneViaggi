namespace GestioneViaggi.Models.Web;

/// <summary>Un social riconosciuto: codice tecnico, nome per l'utente, colore del marchio.</summary>
public sealed record SocialInfo(string Codice, string Etichetta, string Colore);

/// <summary>
/// Unica definizione dei social riconosciuti dalla newsletter.
/// </summary>
/// <remarks>
/// <para>Prima queste informazioni erano sparse in cinque punti — il <c>CHECK</c> del database, il
/// modello, la tendina del dialogo, la colonna dell'elenco e il renderer — e i colori di marca
/// erano scritti due volte. Aggiungere un social avrebbe richiesto di ricordarseli tutti, e
/// dimenticarne uno non avrebbe dato errore: sarebbe semplicemente sparito da una schermata.</para>
/// <para>Classe <b>pura</b>, senza dipendenze: la usa anche <c>NewsletterHtmlRenderer</c>, che
/// deve restare compilabile fuori dall'applicazione per poter essere verificato.</para>
/// <para>⚠️ L'unico posto che resta da allineare a mano è il vincolo
/// <c>chk_web_indirizzi_social</c> sul database (script <c>519</c>): il database non può leggere
/// questa classe. Aggiungendo un social va aggiornato anche quello.</para>
/// </remarks>
public static class SocialCatalogo
{
    /// <summary>Colore dei pulsanti non-social: l'accento del template.</summary>
    public const string ColoreDefault = "#2171A5";

    public static IReadOnlyList<SocialInfo> Tutti { get; } = new[]
    {
        new SocialInfo("facebook",  "Facebook",  "#1877F2"),
        new SocialInfo("instagram", "Instagram", "#C13584"),
        new SocialInfo("tiktok",    "TikTok",    "#010101"),
        new SocialInfo("youtube",   "YouTube",   "#FF0000"),
    };

    public static SocialInfo? Trova(string? codice) =>
        string.IsNullOrWhiteSpace(codice)
            ? null
            : Tutti.FirstOrDefault(s => string.Equals(s.Codice, codice, StringComparison.OrdinalIgnoreCase));

    /// <summary>Colore del marchio, o l'accento del template se non è un social riconosciuto.</summary>
    public static string Colore(string? codice) => Trova(codice)?.Colore ?? ColoreDefault;

    /// <summary>Nome leggibile. Restituisce il codice grezzo se sconosciuto, mai stringa vuota.</summary>
    public static string Etichetta(string? codice) => Trova(codice)?.Etichetta ?? codice ?? "";

    public static bool Riconosciuto(string? codice) => Trova(codice) != null;
}

/// <summary>
/// Regole di impaginazione della newsletter condivise fra chi <b>rende</b> e chi <b>valida</b>.
/// </summary>
/// <remarks>
/// Stavano in due copie, una nel renderer e una nel validatore. Due copie di una regola sono due
/// regole: basta cambiarne una perché il programma accetti qualcosa che poi non sa disegnare.
/// </remarks>
public static class NewsletterLayout
{
    /// <summary>
    /// Quante caselle ha una fila di pulsanti: sinistra, centro, destra. Non è un limite
    /// arbitrario — sono le posizioni che un pulsante può dichiarare.
    /// </summary>
    public const int MaxPulsantiInFila = 3;

    /// <summary>Larghezza utile del corpo, dentro i 600px del riquadro meno i margini.</summary>
    public const int LarghezzaUtile = 536;

    /// <summary>
    /// Le posizioni orizzontali, in un posto solo. <paramref name="Casella"/> e' l'indice della
    /// colonna nella fila di pulsanti: sinistra 0, centro 1, destra 2.
    /// </summary>
    public sealed record Posizione(string Codice, string Etichetta, string Css, int Casella);

    /// <summary>
    /// Catalogo delle posizioni, nell'ordine in cui vanno mostrate. I <c>Codice</c> sono quelli
    /// ammessi dal CHECK su <c>web_newsletter_blocchi.layout</c> e <c>layout_pulsante</c>:
    /// aggiungerne uno qui senza aggiornare il vincolo produce righe rifiutate dal database.
    /// </summary>
    public static IReadOnlyList<Posizione> Posizioni { get; } = new[]
    {
        new Posizione("sinistra", "A sinistra", "left",   0),
        new Posizione("centro",   "Al centro",  "center", 1),
        new Posizione("destra",   "A destra",   "right",  2),
    };

    /// <summary>
    /// Allineamento CSS di un codice di posizione. Quello che non e' una posizione — <c>pieno</c>,
    /// vuoto, valori sconosciuti — prende <paramref name="cssDiRiserva"/>, che non e' lo stesso
    /// dappertutto: un blocco nasce a sinistra, il pie' di pagina nasce centrato.
    /// </summary>
    public static string Css(string? codice, string cssDiRiserva = "left") =>
        Posizioni.FirstOrDefault(p => p.Codice == codice)?.Css ?? cssDiRiserva;

    /// <summary>Colonna della fila di pulsanti, oppure -1 se la posizione non e' dichiarata.</summary>
    public static int Casella(string? codice) =>
        Posizioni.FirstOrDefault(p => p.Codice == codice)?.Casella ?? -1;
}

/// <summary>
/// I colori del modello grafico della newsletter, in un posto solo.
/// </summary>
/// <remarks>
/// Erano costanti private del renderer: l'utente non poteva sceglierli e nessun'altra parte del
/// programma sapeva quali fossero. Restano i valori predefiniti — un blocco che non dichiara un
/// colore ha esattamente l'aspetto di prima — ma ora sono anche la tavolozza offerta nelle form.
/// </remarks>
public static class NewsletterColori
{
    /// <summary>Testo corrente.</summary>
    public const string Testo = "#333333";

    /// <summary>Testo secondario: sottotitoli, pie' di pagina.</summary>
    public const string Tenue = "#888888";

    /// <summary>Titoli. E' lo stesso blu del pulsante non social.</summary>
    public const string Accento = SocialCatalogo.ColoreDefault;

    /// <summary>
    /// Colori proposti nella scelta. Non e' un vincolo: si puo' comunque prendere qualsiasi
    /// colore dal selettore. Sono i valori che stanno bene sul fondo bianco della newsletter,
    /// messi davanti per non costringere a cercarli ogni volta.
    /// </summary>
    public static IReadOnlyList<ColoreProposto> Tavolozza { get; } = new[]
    {
        new ColoreProposto(Accento, "Blu del modello"),
        new ColoreProposto(Testo,   "Grigio scuro"),
        new ColoreProposto(Tenue,   "Grigio tenue"),
        new ColoreProposto("#000000", "Nero"),
        new ColoreProposto("#C0392B", "Rosso"),
        new ColoreProposto("#D35400", "Arancione"),
        new ColoreProposto("#1E8449", "Verde"),
        new ColoreProposto("#6C3483", "Viola"),
    };

    /// <summary>
    /// Riporta un colore alla forma <c>#RRGGBB</c>, o null se non e' un colore valido.
    /// Il vincolo sul database accetta solo quella forma: un valore diverso verrebbe rifiutato
    /// al salvataggio, e in una mail non darebbe errore ma testo nero senza spiegazione.
    /// </summary>
    public static string? Normalizza(string? colore)
    {
        if (string.IsNullOrWhiteSpace(colore)) return null;

        var c = colore.Trim();
        if (!c.StartsWith('#')) c = "#" + c;

        // Un selettore puo' restituire #RRGGBBAA: la trasparenza in una mail non si usa.
        if (c.Length == 9) c = c[..7];

        return System.Text.RegularExpressions.Regex.IsMatch(c, "^#[0-9A-Fa-f]{6}$")
            ? c.ToUpperInvariant()
            : null;
    }
}

/// <summary>Un colore della tavolozza: il valore e il nome con cui viene proposto.</summary>
public sealed record ColoreProposto(string Hex, string Nome);

/// <summary>
/// I testi che mette il <b>programma</b>, nelle lingue in cui si spedisce.
/// </summary>
/// <remarks>
/// Non sono traduzioni: sono <b>localizzazioni</b>. La differenza non è terminologica —
/// una traduzione è un dato, si archivia, si revisiona e può diventare obsoleta quando
/// l'originale cambia; questi testi non hanno un originale che qualcuno ha scritto, li produce
/// il codice e cambiano solo se cambiamo il codice. Metterli in <c>web_traduzioni</c>
/// significherebbe dare a un utente il compito di rileggerli a ogni newsletter.
/// <para>La frase di disiscrizione è quella che conta di più: è un obbligo di legge, e finora
/// partiva <b>in italiano verso tutti</b>. Un destinatario tedesco poteva non capire come
/// cancellarsi — che è esattamente la cosa che deve poter fare senza sforzo.</para>
/// </remarks>
public static class NewsletterTesti
{
    /// <summary>Lingue in cui si spedisce. La prima è l'originale.</summary>
    public static IReadOnlyList<string> Lingue { get; } = new[] { "IT", "EN", "DE", "ES", "FR" };

    private static string Scegli(string? lingua, string it, string en, string de, string es, string fr) =>
        (lingua ?? "").Trim().ToUpperInvariant() switch
        {
            "EN" => en,
            "DE" => de,
            "ES" => es,
            "FR" => fr,
            _    => it   // IT e qualunque lingua non prevista: meglio l'originale di un vuoto
        };

    /// <summary>Frase che introduce il collegamento di disiscrizione.</summary>
    public static string DomandaDisiscrizione(string? lingua) => Scegli(lingua,
        "Non desideri più ricevere la nostra newsletter?",
        "No longer wish to receive our newsletter?",
        "Sie möchten unseren Newsletter nicht mehr erhalten?",
        "¿Ya no deseas recibir nuestra newsletter?",
        "Vous ne souhaitez plus recevoir notre newsletter ?");

    /// <summary>Testo del collegamento di disiscrizione.</summary>
    public static string Disiscriviti(string? lingua) => Scegli(lingua,
        "Disiscriviti", "Unsubscribe", "Abmelden", "Cancelar la suscripción", "Se désabonner");

    /// <summary>Etichetta di riserva del pulsante di un riquadro tour.</summary>
    public static string PulsanteTour(string? lingua) => Scegli(lingua,
        "Vai alla pagina del Tour", "View the tour page", "Zur Tour-Seite",
        "Ver la página del tour", "Voir la page du circuit");

    /// <summary>Etichetta di riserva di un pulsante senza testo.</summary>
    public static string PulsanteGenerico(string? lingua) => Scegli(lingua,
        "Scopri di più", "Learn more", "Mehr erfahren", "Saber más", "En savoir plus");
}

