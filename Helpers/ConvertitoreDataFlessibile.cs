using System.Globalization;
using MudBlazor;

namespace GestioneViaggi.Helpers;

/// <summary>
/// Legge una data scritta con le barre: <c>15/03/1990</c> o <c>15/3/90</c>.
///
/// Sostituisce la <c>DateMask</c> dei campi data, che era comoda ma corrompeva i dati.
/// La maschera intercetta ogni tasto in JavaScript, lo rimanda a .NET e poi riposiziona il
/// cursore con un secondo viaggio: su MacCatalyst sono 4-8 chiamate per singolo tasto, e
/// digitando in fretta il carattere successivo entra con il cursore ancora fermo dov'era.
/// Il 2026-08-31 e' costato una partenza reale registrata come <c>8202-01-19</c> invece di
/// <c>2026-08-19</c> — cifre slittate di una posizione e l'ultima caduta fuori — con dodici
/// iscritti attaccati.
///
/// Qui non si intercetta niente: si digita nel campo come in un campo di testo qualunque, e
/// la conversione avviene una volta sola, sul testo finito.
///
/// <b>Perche' i separatori sono obbligatori</b> (deciso il 2026-09-04). Il convertitore
/// sapeva leggere anche <c>15031990</c>, ma MudBlazor in MAUI Hybrid <b>non riscrive il
/// testo</b> di un picker dopo la conversione: si crede un'applicazione Blazor Server, dove
/// quel comportamento e' voluto. E' un difetto noto della libreria (MudBlazor #9090, #11217),
/// corretto solo nella serie 9.x. Il risultato era il peggiore possibile: la data veniva
/// letta e salvata correttamente, ma nel campo restava <c>18042036</c> — il programma
/// accettava in silenzio qualcosa di diverso da cio' che mostrava.
///
/// Chiedendo le barre, il testo digitato e' <b>gia'</b> nella forma definitiva: non c'e'
/// niente da riformattare, e cio' che si vede e' cio' che e' stato capito. Due caratteri in
/// piu' da battere, in cambio di un campo che non mente.
///
/// Il punto e il trattino sono stati tolti per la stessa ragione: <c>18.04.2036</c> sarebbe
/// rimasto visualizzato cosi', e la regola «si vede cio' che si e' capito» vale solo se il
/// campo accetta una forma sola.
/// </summary>
public class ConvertitoreDataFlessibile : MudBlazor.Converter<DateTime?, string>
{
    // Non esiste un'istanza condivisa, ed e' voluto: ce n'era una (`Standard`) usata da
    // tutti i 33 campi, ed e' stata tolta perche' questo convertitore HA STATO. Dichiara
    // alla libreria se l'ultima conversione e' fallita, ed e' cosi' che il campo mostra
    // «data non valida»: condividendola, l'errore di un campo comparirebbe sugli altri.
    //
    // Ogni campo scrive quindi il proprio:
    //     private readonly ConvertitoreDataFlessibile _convScadenza = new();

    /// <summary>
    /// Le uniche forme accettate. Lo zero iniziale e' facoltativo (<c>1/3/1990</c>) e l'anno
    /// si puo' abbreviare (<c>15/03/90</c>): sono comodita' che non cambiano cio' che si legge
    /// nel campo, perche' il separatore c'e' comunque.
    /// </summary>
    private static readonly string[] Accettati =
    [
        "dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy", "d/M/yy"
    ];

    public ConvertitoreDataFlessibile(string formato = "dd/MM/yyyy")
    {
        SetFunc = data => data?.ToString(formato, CultureInfo.InvariantCulture);
        GetFunc = testo => Leggi(testo);
    }

    private DateTime? Leggi(string? testo)
    {
        // L'esito precedente si azzera SEMPRE, per primo. Senza, un errore rimasto acceso
        // fa scartare a MudBlazor anche il valore buono digitato subito dopo: si correggeva
        // «18042036» in «18/04/2036» e il campo continuava a risultare vuoto, con il
        // database che si lamentava di una data mancante che invece era li'.
        GetError = false;

        testo = testo?.Trim();
        if (string.IsNullOrEmpty(testo)) return null;

        // Solo le forme con la barra, e nient'altro. Nessun tentativo «di riserva» con la
        // cultura corrente: accetterebbe scritture che poi il campo non saprebbe mostrare
        // com'e' stato inteso, ed e' esattamente il difetto che si sta chiudendo.
        if (DateTime.TryParseExact(testo, Accettati, CultureInfo.InvariantCulture,
                DateTimeStyles.None, out var data))
            return data;

        // Il fallimento si DICHIARA, non si restituisce come «campo vuoto».
        //
        // E' il pezzo che mancava: tornando null e basta, per MudBlazor quel campo era
        // semplicemente non compilato — indistinguibile da uno lasciato in bianco — e
        // nessun avviso poteva comparire. Chi digitava «18042036» usciva dal campo senza
        // che nulla glielo segnalasse, e lo scopriva al salvataggio.
        //
        // Con UpdateGetError la libreria lo sa, accende ConversionError e mostra da se'
        // il messaggio sotto il campo: e' il meccanismo previsto, e non serve altro.
        UpdateGetError("Data non valida. Scrivila con le barre, per esempio 18/04/2036.");
        return null;
    }
}
