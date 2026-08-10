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
}
