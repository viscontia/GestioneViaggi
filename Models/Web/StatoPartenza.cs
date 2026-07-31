namespace GestioneViaggi.Models.Web;

/// <summary>Come presentare lo stato di una partenza: gravità, etichetta breve e spiegazione estesa.</summary>
public record EsitoStatoPartenza(LivelloStatoPartenza Livello, string Etichetta, string Tooltip);

public enum LivelloStatoPartenza
{
    /// <summary>Flag e calendario coerenti, partenza ancora da fare: situazione normale.</summary>
    Normale,
    /// <summary>Coerente ma conclusa: la scheda web di solito non serve più.</summary>
    Conclusa,
    /// <summary>Flag e calendario in contraddizione: qualcosa da sistemare in anagrafica.</summary>
    Anomalia
}

/// <summary>
/// Stato di una partenza incrociando la spunta "Viaggio Effettuato"
/// (<c>ana_date_viaggi.data_viaggio_effettuato_sino</c>) con la <b>data di fine</b>.
///
/// Il solo flag non basta a dire se la situazione è sensata: le due informazioni possono
/// contraddirsi, ed è proprio la contraddizione che l'operatore deve vedere. I quattro casi:
///
/// <list type="table">
///   <item><term>SI + conclusa</term><description>coerente: viaggio fatto e registrato.</description></item>
///   <item><term>NO + conclusa</term><description><b>anomalia</b>: o il flag non è stato aggiornato, o il viaggio non è stato fatto.</description></item>
///   <item><term>NO + futura</term><description>coerente: partenza in programma.</description></item>
///   <item><term>SI + futura</term><description><b>anomalia</b>: segnata come fatta prima di essere conclusa.</description></item>
/// </list>
/// </summary>
public static class StatoPartenzaRules
{
    public static EsitoStatoPartenza Valuta(bool effettuato, DateTime? dataFine, DateTime oggi)
    {
        // Senza data di fine non si può incrociare nulla: si dice solo cosa riporta il flag.
        if (dataFine is not { } fine)
        {
            return effettuato
                ? new(LivelloStatoPartenza.Conclusa, "Partenza effettuata",
                      "Risulta effettuata (spunta \"Viaggio Effettuato\" nella scheda Date del viaggio). Data di fine non disponibile.")
                : new(LivelloStatoPartenza.Normale, "Partenza da effettuare",
                      "Non risulta ancora effettuata. Data di fine non disponibile.");
        }

        // "Conclusa" = l'ultimo giorno è passato. Il giorno stesso della fine il viaggio è ancora in corso.
        var conclusa = fine.Date < oggi.Date;
        var quando = fine.ToString("dd/MM/yyyy");

        return (effettuato, conclusa) switch
        {
            (true, true) => new(LivelloStatoPartenza.Conclusa,
                "Partenza effettuata",
                $"Coerente: la partenza si è conclusa il {quando} ed è registrata come effettuata. " +
                "Curare la scheda web di una partenza già avvenuta di solito non serve più."),

            (false, true) => new(LivelloStatoPartenza.Anomalia,
                "Conclusa ma non registrata",
                $"Da controllare: la partenza si è conclusa il {quando} ma non è spuntata come effettuata. " +
                "O il viaggio è stato fatto e manca l'aggiornamento del flag, oppure era in programma e non è stato realizzato. " +
                "Si corregge nella scheda Date del viaggio."),

            (false, false) => new(LivelloStatoPartenza.Normale,
                "Partenza da effettuare",
                $"Situazione normale: la partenza è in programma e si conclude il {quando}. " +
                "Il flag \"Viaggio Effettuato\" si spunta a viaggio concluso, nella scheda Date del viaggio."),

            (true, false) => new(LivelloStatoPartenza.Anomalia,
                "Effettuata ma non ancora conclusa",
                $"Da controllare: risulta spuntata come effettuata, ma la partenza si conclude il {quando}, quindi non è ancora terminata. " +
                "Probabile spunta messa per errore o in anticipo, nella scheda Date del viaggio.")
        };
    }
}
