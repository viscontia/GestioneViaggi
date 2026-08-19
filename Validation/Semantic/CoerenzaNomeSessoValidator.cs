namespace GestioneViaggi.Validation.Semantic;

/// <summary>
/// Avviso (NON bloccante) sulla coerenza fra nome e sesso del cliente.
///
/// Serve a intercettare l'errore tipico da quando il sesso si deriva dal titolo: «SIG.» è la prima
/// voce della tendina, e chi va di fretta ci lascia sopra anche una donna. Siccome quasi tutti i
/// nomi femminili italiani finiscono in -a, il nome tradisce lo scambio.
///
/// Non restituisce un <c>ValidationResult</c> di proposito: non è una validazione, è un sospetto.
/// Un blocco qui sarebbe sbagliato — Andrea e Luca sono nomi maschili e devono poter passare.
/// </summary>
public static class CoerenzaNomeSessoValidator
{
    /// <summary>
    /// Nomi maschili italiani che finiscono in -a. Senza questa lista l'avviso sarebbe inutile:
    /// misurato sui clienti reali, scattava 53 volte su 53 a torto, e 38 di quelle erano Andrea e
    /// Luca. Un avviso che sbaglia sempre insegna solo a ignorarlo.
    /// </summary>
    private static readonly HashSet<string> MaschiliInA = new(StringComparer.OrdinalIgnoreCase)
    {
        "ANDREA", "LUCA", "NICOLA", "ELIA", "MATTIA", "ENEA",
        "ISAIA", "GEREMIA", "ZACCARIA", "BATTISTA", "EVANGELISTA", "COSMA",
        // Composti scritti tutti attaccati: staccati li risolve gia' l'ultimo token.
        "GIANLUCA", "PIERLUCA", "GIANANDREA", "GIANMARIA", "PIERMARIA"
    };

    /// <summary>
    /// Restituisce il testo dell'avviso, oppure <c>null</c> se non c'e' nulla da segnalare.
    /// </summary>
    public static string? Avviso(string? nome, char sesso)
    {
        var pulito = nome?.Trim();
        if (string.IsNullOrEmpty(pulito)) return null;

        var pezzi = pulito.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (pezzi.Length == 0) return null;

        var ultimo = pezzi[^1];
        var finale = char.ToUpperInvariant(ultimo[^1]);

        if (finale == 'A' && sesso == 'M')
        {
            if (MaschiliInA.Contains(ultimo)) return null;

            // "Carlo Maria", "Giovanni Maria": Maria come secondo nome e' uso maschile italiano.
            if (pezzi.Length > 1 && ultimo.Equals("MARIA", StringComparison.OrdinalIgnoreCase)) return null;

            return $"«{pulito}» sembra un nome femminile, ma il titolo scelto imposta il sesso a M. Controlla il titolo.";
        }

        if (finale == 'O' && sesso == 'F')
        {
            return $"«{pulito}» sembra un nome maschile, ma il titolo scelto imposta il sesso a F. Controlla il titolo.";
        }

        return null;
    }
}
