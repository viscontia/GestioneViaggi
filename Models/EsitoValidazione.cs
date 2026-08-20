namespace GestioneViaggi.Models;

/// <summary>
/// Una segnalazione restituita dalle funzioni di validazione del database
/// (<c>fn_ana_clienti_valida</c>, <c>fn_mov_clienti_viaggi_valida</c>).
///
/// La <see cref="Gravita"/> non la decide il client: arriva dal database, ed è il
/// motivo per cui gestionale e sito si comportano allo stesso modo davanti allo
/// stesso dato. Scriverla qui, in C#, significherebbe riscriverla anche in Python.
/// </summary>
public class EsitoValidazione
{
    /// <summary>OK · AVVISO · CONFERMA · ERRORE</summary>
    public string Gravita { get; set; } = "OK";

    /// <summary>Codice dell'esito, es. INVERTITI, PILOTA_SENZA_EMAIL, OMONIMO.</summary>
    public string Esito { get; set; } = string.Empty;

    /// <summary>Il testo da mostrare, già in italiano.</summary>
    public string Messaggio { get; set; } = string.Empty;

    /// <summary>
    /// Il soggetto della segnalazione, quando ne ha uno: per <c>PILOTA_SENZA_EMAIL</c>
    /// è il <c>cliente_id</c> su cui aprire la richiesta dell'email.
    /// </summary>
    public int? Riferimento { get; set; }

    public bool Blocca => Gravita == "ERRORE";
    public bool RichiedeConferma => Gravita == "CONFERMA";
}
