namespace GestioneViaggi.Models.Web;

/// <summary>
/// La scheda «Sito web» dell'azienda (tabella web_sito_contenuti, script 692): una riga per azienda.
/// Sotto-scheda Home: foto d'apertura, motto, frase, email che riceve i messaggi del sito, titolo del
/// blocco «In evidenza». Chi siamo e testi legali arriveranno con i pezzi 4B/4C del sito.
/// </summary>
/// <remarks>
/// I testi sono in italiano; le traduzioni stanno in web_traduzioni con
/// entita = <see cref="Entita"/> ed entita_id = azienda (vedi <see cref="CampiTraducibili"/>).
/// </remarks>
public sealed class WebSitoContenuti
{
    /// <summary>Il valore di web_traduzioni.entita per questi testi.</summary>
    public const string Entita = "web_sito_contenuti";

    public const int MaxMotto = 120;
    public const int MaxFraseHome = 300;
    public const int MaxEvidenzaTitolo = 120;

    public int AziendaId { get; set; }

    /// <summary>La foto d'apertura della home (libreria immagini dell'azienda). NULL = nessuna foto.</summary>
    public long? FotoHomeFk { get; set; }

    public string? Motto { get; set; }
    public string? FraseHome { get; set; }

    /// <summary>L'email che riceve i messaggi del modulo Contatti. NULL = l'email principale.</summary>
    public int? EmailMessaggiFk { get; set; }

    /// <summary>Il titolo del blocco «In evidenza» della home (es. «Capodanno fuori traccia»).</summary>
    public string? EvidenzaTitolo { get; set; }

    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }

    /// <summary>I campi che si traducono: (campo in web_traduzioni, etichetta per chi traduce, valore).</summary>
    public IEnumerable<(string Campo, string Etichetta, string? Valore)> CampiTraducibili()
    {
        yield return ("motto", "Home — Motto", Motto);
        yield return ("frase_home", "Home — Frase d'apertura", FraseHome);
        yield return ("evidenza_titolo", "Home — Titolo «In evidenza»", EvidenzaTitolo);
    }

    public WebSitoContenuti Copia() => (WebSitoContenuti)MemberwiseClone();
}

/// <summary>Polizza RC e fondo di garanzia del tour operator (ana_aziende, script 692; Dati generali).</summary>
public sealed record GaranzieAzienda(
    string? PolizzaRcCompagnia, string? PolizzaRcNumero,
    string? FondoGaranziaEnte, string? FondoGaranziaEstremi);

/// <summary>Un tour pubblicato, da scegliere per il blocco «In evidenza».</summary>
public sealed record TourPubblicatoScelta(long ContenutoId, string Titolo, DateOnly? DataInizio)
{
    public string Etichetta => DataInizio is { } d ? $"{Titolo} — {d:dd/MM/yyyy}" : Titolo;
}

/// <summary>
/// Lo stato della scheda «Sito web» mentre il dialogo dell'azienda è aperto: quello salvato e la
/// bozza con le modifiche. Lo tiene il DIALOGO, non la scheda: il dialogo non tiene vive le schede
/// (le ricrea a ogni clic, per non aprire troppe connessioni insieme), e una bozza tenuta dalla
/// scheda si perdeva in silenzio cambiando scheda o premendo «Aggiorna» (prova di Adriano, 2026-10-20).
/// </summary>
public sealed class SitoWebBozza
{
    public int AziendaId { get; set; }
    public bool Caricata { get; set; }
    public WebSitoContenuti Salvato { get; set; } = new();
    public WebSitoContenuti Bozza { get; set; } = new();
    public List<long> EvidenzaSalvata { get; set; } = new();
    public List<long> Evidenza { get; set; } = new();
    public bool Modificata { get; set; }
}

/// <summary>Lo stato di una lingua: quanti testi compilati, quanti tradotti (validi), quanti da rifare.</summary>
public sealed record StatoLinguaTraduzioni(string Lingua, int Traducibili, int Tradotti, int Obsoleti)
{
    public int Mancanti => Traducibili - Tradotti - Obsoleti;
    public bool Completa => Traducibili == 0 || Tradotti == Traducibili;
    public bool DaRifare => Obsoleti > 0;
}

