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
