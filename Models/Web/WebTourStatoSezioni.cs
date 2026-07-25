namespace GestioneViaggi.Models.Web;

/// <summary>
/// Fatti grezzi sullo stato dei contenuti web di un'edizione, letti in una sola query da
/// <c>fn_web_tour_stato_sezioni</c>. Servono a WebEdizioniManager per accendere il semaforo dei
/// sotto-tab all'apertura, quando i sotto-tab non sono ancora istanziati e non possono notificarlo.
/// Le soglie Vuoto/Parziale/Completo restano in <see cref="WebTabStatoRules"/>.
/// </summary>
public record WebTourStatoSezioni(
    bool HaSlug,
    bool HaSottotitolo,
    bool HaDescrizione,
    int NumeroImmagini,
    bool HaPrincipale,
    int NumeroGiornate,
    int ItemTraducibili,
    int CoppieTradotte);
