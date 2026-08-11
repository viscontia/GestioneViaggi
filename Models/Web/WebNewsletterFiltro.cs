namespace GestioneViaggi.Models.Web;

/// <summary>
/// Un criterio di selezione dei destinatari di una newsletter (script 529).
/// </summary>
/// <remarks>
/// La <paramref name="Descrizione"/> è composta dal database al momento in cui il criterio viene
/// aggiunto, e da lì non cambia più: è la frase che si legge nell'archivio di ciò che è stato
/// spedito, e fra un anno la partenza citata potrebbe non esistere più.
/// </remarks>
public sealed record WebNewsletterFiltro(
    long Id, string Criterio, string Descrizione, DateTime? ParamData, int? ParamInt);

/// <summary>
/// Conteggio dei destinatari, spaccato per popolazione.
/// </summary>
/// <param name="IscrittiEsclusi">
/// Iscritti dal sito lasciati fuori dai filtri attivi. Non hanno anagrafica, quindi nessun
/// criterio può valutarli: il numero va mostrato, altrimenti l'esclusione avviene in silenzio.
/// </param>
public sealed record ConteggioDestinatari(long Destinatari, long Clienti, long Iscritti, long IscrittiEsclusi);

/// <summary>Nazione in cui risiede almeno un cliente dell'azienda. Italia per prima.</summary>
public sealed record NazioneClienti(int CountryId, string Nome, bool Estero, long Clienti);
