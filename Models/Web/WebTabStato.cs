namespace GestioneViaggi.Models.Web;

/// <summary>
/// Stato di completamento di un sotto-tab dei Contenuti Web (Contenuti/Itinerario/Galleria/Mappa/Traduzioni).
/// Calcolato da ogni sotto-tab e usato da WebEdizioniManager per colorare l'icona del tab (semaforo)
/// e dal gating di pubblicazione (§Fase 3): tutti i sotto-tab devono essere <see cref="Completo"/>.
/// </summary>
public enum WebTabStato
{
    /// <summary>Nulla inserito.</summary>
    Vuoto,
    /// <summary>Iniziato ma mancano i campi/dati obbligatori.</summary>
    Parziale,
    /// <summary>Tutti i campi/dati obbligatori sono presenti.</summary>
    Completo
}

/// <summary>
/// Soglie di completamento dei sotto-tab, in un solo posto: le usano sia i sotto-tab (aggiornamento
/// dal vivo mentre si edita) sia WebEdizioniManager (semaforo all'apertura, dai fatti letti con
/// <c>fn_web_tour_stato_sezioni</c>). Cambiare una regola qui la cambia in entrambi i percorsi.
/// </summary>
public static class WebTabStatoRules
{
    /// <summary>Completo se slug + sottotitolo + descrizione sono tutti presenti; Vuoto se tutti assenti; altrimenti Parziale.</summary>
    public static WebTabStato Contenuti(bool haSlug, bool haSottotitolo, bool haDescrizione)
    {
        if (haSlug && haSottotitolo && haDescrizione) return WebTabStato.Completo;
        if (!haSlug && !haSottotitolo && !haDescrizione) return WebTabStato.Vuoto;
        return WebTabStato.Parziale;
    }

    /// <summary>Vuoto se nessuna immagine; Parziale se immagini senza copertina; Completo se >=1 immagine + copertina.</summary>
    public static WebTabStato Galleria(int numeroImmagini, bool haPrincipale)
        => numeroImmagini == 0 ? WebTabStato.Vuoto
         : haPrincipale ? WebTabStato.Completo
         : WebTabStato.Parziale;

    /// <summary>Vuoto se nessuna giornata; Parziale se descritte meno giornate della durata del viaggio; altrimenti Completo.</summary>
    public static WebTabStato Itinerario(int numeroGiornate, int numeroGiorni)
        => numeroGiornate == 0 ? WebTabStato.Vuoto
         : numeroGiorni > 0 && numeroGiornate < numeroGiorni ? WebTabStato.Parziale
         : WebTabStato.Completo;

    /// <summary>La mappa è opzionale: non blocca mai il gating di pubblicazione.</summary>
    public static WebTabStato Mappa() => WebTabStato.Completo;

    /// <summary>
    /// Completo solo quando <b>tutte</b> le coppie campo×lingua sono state <b>revisionate</b> (e non
    /// sono obsolete): le traduzioni automatiche finiscono sul sito nella lingua del cliente, quindi
    /// nessuno deve poter pubblicare testi che nessuno ha approvato. Vuoto se non c'è ancora nulla,
    /// Parziale in mezzo — compreso il caso "tutto tradotto ma non ancora approvato".
    /// Nessun campo da tradurre → Completo (vacuamente vero, non blocca la pubblicazione).
    /// </summary>
    public static WebTabStato Traduzioni(int coppieAttese, int coppieTradotte, int coppieRevisionate)
        => coppieAttese == 0 ? WebTabStato.Completo
         : coppieRevisionate >= coppieAttese ? WebTabStato.Completo
         : coppieTradotte == 0 ? WebTabStato.Vuoto
         : WebTabStato.Parziale;
}

public static class WebTabStatoExtensions
{
    /// <summary>Mappa lo stato al colore semaforo: Vuoto=Warning (giallo), Parziale=Error (rosso), Completo=Success (verde).</summary>
    public static MudBlazor.Color ToColor(this WebTabStato stato) => stato switch
    {
        WebTabStato.Completo => MudBlazor.Color.Success,
        WebTabStato.Parziale => MudBlazor.Color.Error,
        _ => MudBlazor.Color.Warning
    };
}
