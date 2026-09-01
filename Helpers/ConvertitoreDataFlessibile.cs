using System.Globalization;
using MudBlazor;

namespace GestioneViaggi.Helpers;

/// <summary>
/// Legge una data scritta come capita: <c>15031990</c>, <c>15/03/1990</c>, <c>15-3-90</c>.
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
/// la conversione avviene una volta sola, sul testo finito. La comodita' di battere solo le
/// cifre resta, il difetto no.
/// </summary>
public class ConvertitoreDataFlessibile : MudBlazor.Converter<DateTime?, string>
{
    /// <summary>L'istanza da usare nei campi data. Non ha stato: una basta per tutti.</summary>
    public static readonly ConvertitoreDataFlessibile Standard = new();

    /// <summary>Formati accettati quando l'utente scrive i separatori.</summary>
    private static readonly string[] ConSeparatori =
    [
        "dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy", "d/M/yy"
    ];

    /// <summary>Formati accettati quando l'utente scrive solo cifre.</summary>
    private static readonly string[] SoloCifre = ["ddMMyyyy", "ddMMyy"];

    public ConvertitoreDataFlessibile(string formato = "dd/MM/yyyy")
    {
        SetFunc = data => data?.ToString(formato, CultureInfo.InvariantCulture);
        GetFunc = testo => Leggi(testo);
    }

    private static DateTime? Leggi(string? testo)
    {
        testo = testo?.Trim();
        if (string.IsNullOrEmpty(testo)) return null;

        // Punti e trattini sono separatori quanto la barra: chi scrive 15.03.1990 non
        // sta sbagliando, sta usando l'altra convenzione.
        var normalizzato = testo.Replace('.', '/').Replace('-', '/').Replace(' ', '/');

        if (DateTime.TryParseExact(normalizzato, ConSeparatori, CultureInfo.InvariantCulture,
                DateTimeStyles.None, out var conSeparatori))
            return conSeparatori;

        // Solo cifre: 15031990. E' il modo piu' veloce di scrivere una data, ed e'
        // esattamente cio' che la maschera serviva a permettere.
        if (normalizzato.All(char.IsDigit) &&
            DateTime.TryParseExact(normalizzato, SoloCifre, CultureInfo.InvariantCulture,
                DateTimeStyles.None, out var soloCifre))
            return soloCifre;

        // Ultimo tentativo con la cultura corrente, per le forme che non abbiamo previsto.
        // Se fallisce anche questo, il valore resta nullo e sara' la validazione a dirlo:
        // qui non si tira a indovinare su una data.
        return DateTime.TryParse(testo, CultureInfo.CurrentCulture, DateTimeStyles.None, out var libero)
            ? libero
            : null;
    }
}
