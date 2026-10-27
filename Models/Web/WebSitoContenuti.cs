namespace GestioneViaggi.Models.Web;

/// <summary>
/// La scheda «Sito web» dell'azienda (tabella web_sito_contenuti, script 692): una riga per azienda.
/// Sotto-scheda Home: foto d'apertura, motto, titolo e sottotitolo (script 695), email che riceve i messaggi del sito, titolo del
/// blocco «In evidenza». Testi legali (script 701, pezzo 4B) e Chi siamo (script 703, pezzo 4C).
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
    public const int MaxTitoloHome = 300;
    public const int MaxSottotitoloHome = 300;
    public const int MaxEvidenzaTitolo = 120;

    public int AziendaId { get; set; }

    /// <summary>
    /// La foto d'apertura scelta dalla libreria (1200 px, per le newsletter). Dal 698 resta solo come ripiego
    /// finché non si carica una foto dalla scheda (<see cref="FotoHomeUrl"/>), che la spegne.
    /// </summary>
    public long? FotoHomeFk { get; set; }

    /// <summary>La foto d'apertura caricata dalla scheda (698): 2000 px in WebP. NULL = nessuna.</summary>
    public string? FotoHomeUrl { get; set; }
    public int? FotoHomeLarghezza { get; set; }
    public int? FotoHomeAltezza { get; set; }

    /// <summary>Il video d'apertura (698): versione computer e telefono, misure, durata. NULL = nessun video.</summary>
    public string? VideoHomeUrl { get; set; }
    public string? VideoHomeTelefonoUrl { get; set; }
    public int? VideoHomeLarghezza { get; set; }
    public int? VideoHomeAltezza { get; set; }
    public decimal? VideoHomeDurata { get; set; }

    public string? Motto { get; set; }
    /// <summary>Il titolo dell'apertura, sotto il motto (script 695: era la «frase d'apertura»).</summary>
    public string? TitoloHome { get; set; }

    /// <summary>Il sottotitolo dell'apertura: facoltativo (vuoto = non si mostra).</summary>
    public string? SottotitoloHome { get; set; }

    /// <summary>L'email che riceve i messaggi del modulo Contatti. NULL = l'email principale.</summary>
    public int? EmailMessaggiFk { get; set; }

    /// <summary>Il titolo del blocco «In evidenza» della home (es. «Capodanno fuori traccia»).</summary>
    public string? EvidenzaTitolo { get; set; }

    /// <summary>I testi legali del sito (script 701; sotto-scheda «Testi legali»): HTML dell'editor Quill. NULL = la pagina non c'è.</summary>
    public string? NoteLegali { get; set; }
    public string? Privacy { get; set; }
    public string? Cookie { get; set; }
    public DateTime? NoteLegaliAggiornato { get; set; }
    public DateTime? PrivacyAggiornato { get; set; }
    public DateTime? CookieAggiornato { get; set; }

    /// <summary>
    /// La pagina «Chi siamo» (script 703; sotto-scheda «Chi siamo»): HTML dell'editor Quill. NULL = la pagina non c'è.
    /// Le due foto si caricano dalla scheda come la foto della home: 1 in cima, 2 a metà del testo.
    /// </summary>
    public string? ChiSiamo { get; set; }
    public DateTime? ChiSiamoAggiornato { get; set; }
    public string? ChiSiamoFoto1Url { get; set; }
    public int? ChiSiamoFoto1Larghezza { get; set; }
    public int? ChiSiamoFoto1Altezza { get; set; }
    public string? ChiSiamoFoto2Url { get; set; }
    public int? ChiSiamoFoto2Larghezza { get; set; }
    public int? ChiSiamoFoto2Altezza { get; set; }

    /// <summary>La foto di Chi siamo in posizione 1 o 2 (indirizzo e misure; Url null = nessuna).</summary>
    public (string? Url, int? Larghezza, int? Altezza) FotoChiSiamo(int posizione) => posizione == 1
        ? (ChiSiamoFoto1Url, ChiSiamoFoto1Larghezza, ChiSiamoFoto1Altezza)
        : (ChiSiamoFoto2Url, ChiSiamoFoto2Larghezza, ChiSiamoFoto2Altezza);

    public string? UpdatedBy { get; set; }
    public DateTime? Updated { get; set; }

    /// <summary>Il testo di Chi siamo che si traduce (campo = nome della pagina, come lo legge fn_web_sito_pagina).</summary>
    public IEnumerable<(string Campo, string Etichetta, string? Valore)> CampiChiSiamo()
    {
        yield return ("chi_siamo", "Chi siamo — Testo", ChiSiamo);
    }

    /// <summary>I testi legali che si traducono (campo = nome della pagina, come li legge fn_web_sito_pagina).</summary>
    public IEnumerable<(string Campo, string Etichetta, string? Valore)> CampiTestiLegali()
    {
        yield return ("note_legali", "Testi legali — Note legali", NoteLegali);
        yield return ("privacy", "Testi legali — Privacy", Privacy);
        yield return ("cookie", "Testi legali — Cookie", Cookie);
    }

    /// <summary>Un testo legale è cambiato rispetto a <paramref name="altro"/>?</summary>
    public bool TestiLegaliDiversiDa(WebSitoContenuti altro) =>
        !string.Equals(NoteLegali, altro.NoteLegali, StringComparison.Ordinal)
        || !string.Equals(Privacy, altro.Privacy, StringComparison.Ordinal)
        || !string.Equals(Cookie, altro.Cookie, StringComparison.Ordinal);

    /// <summary>I campi che si traducono: (campo in web_traduzioni, etichetta per chi traduce, valore).</summary>
    public IEnumerable<(string Campo, string Etichetta, string? Valore)> CampiTraducibili()
    {
        yield return ("motto", "Home — Motto", Motto);
        yield return ("titolo_home", "Home — Titolo", TitoloHome);
        yield return ("sottotitolo_home", "Home — Sottotitolo", SottotitoloHome);
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

    /// <summary>Foto e video scelti ma non ancora mandati allo Storage: ci vanno all'«Aggiorna».</summary>
    public FotoHomeNuova? FotoNuova { get; set; }
    public bool FotoTolta { get; set; }

    /// <summary>Le due foto di Chi siamo (indice 0 = posizione 1): scelte o tolte, vanno allo Storage all'«Aggiorna».</summary>
    public FotoHomeNuova?[] FotoChiSiamoNuova { get; } = new FotoHomeNuova?[2];
    public bool[] FotoChiSiamoTolta { get; } = new bool[2];
    public GestioneViaggi.Services.Shared.Storage.WebVideoProcessor.VideoPreparato? VideoNuovo { get; set; }
    public bool VideoTolto { get; set; }

    /// <summary>Foto o video in preparazione (sul computer): finché dura, «Aggiorna» non si può premere.</summary>
    public bool InPreparazione { get; set; }

    /// <summary>Butta via foto e video non ancora caricati (e i file temporanei del video).</summary>
    public void ScartaMedia()
    {
        VideoNuovo?.Cancella();
        VideoNuovo = null; FotoNuova = null; VideoTolto = false; FotoTolta = false;
        Array.Clear(FotoChiSiamoNuova); Array.Clear(FotoChiSiamoTolta);
    }
}

/// <summary>Una foto della scheda pronta per lo Storage (WebP 2000 px) e la sua anteprima: home e Chi siamo.</summary>
public sealed record FotoHomeNuova(byte[] Bytes, int Larghezza, int Altezza, string Mime)
{
    public string Anteprima => $"data:{Mime};base64,{Convert.ToBase64String(Bytes)}";
}

/// <summary>Lo stato di una lingua: quanti testi compilati, quanti tradotti (validi), quanti da rifare.</summary>
public sealed record StatoLinguaTraduzioni(string Lingua, int Traducibili, int Tradotti, int Obsoleti)
{
    public int Mancanti => Traducibili - Tradotti - Obsoleti;
    public bool Completa => Traducibili == 0 || Tradotti == Traducibili;
    public bool DaRifare => Obsoleti > 0;
}

