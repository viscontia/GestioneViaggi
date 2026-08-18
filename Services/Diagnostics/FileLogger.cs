using Microsoft.Extensions.Logging;
using System.Collections.Concurrent;
using System.Text;

namespace GestioneViaggi.Services.Diagnostics;

/// <summary>
/// Registro degli errori su file.
/// </summary>
/// <remarks>
/// Nasce da un difetto che non si riusciva a diagnosticare: l'applicazione si chiudeva da sola e
/// l'unica traccia — <c>AddDebug()</c> — finisce nell'output del debugger, che sulla macchina di
/// chi usa il programma non esiste. Senza un file, un guasto che capita al cliente non e'
/// raccontabile: resta "si e' chiuso".
/// <para>Scrive solo da <see cref="LogLevel.Warning"/> in su: il registro deve restare leggibile
/// e piccolo. Un file al giorno, e i piu' vecchi di trenta giorni si cancellano da soli.</para>
/// <para>Le scritture passano da una coda servita da un solo thread: piu' componenti possono
/// registrare nello stesso istante, e un file scritto da tutti insieme diventa illeggibile.</para>
/// </remarks>
public sealed class FileLoggerProvider : ILoggerProvider
{
    private readonly string _cartella;
    private readonly BlockingCollection<string> _coda = new(1000);
    private readonly Thread _scrittore;
    private volatile bool _chiuso;

    public FileLoggerProvider(string cartella)
    {
        _cartella = cartella;
        Directory.CreateDirectory(_cartella);
        PulisciVecchi();

        _scrittore = new Thread(Scrivi) { IsBackground = true, Name = "log-su-file" };
        _scrittore.Start();
    }

    /// <summary>Percorso del registro di oggi. E' quello da allegare a una segnalazione.</summary>
    public string FileDiOggi => Path.Combine(_cartella, $"gestioneviaggi-{DateTime.Now:yyyy-MM-dd}.log");

    public ILogger CreateLogger(string categoryName) => new Logger(this, categoryName);

    private void Accoda(string riga)
    {
        // Se la coda e' piena si perde la riga invece di rallentare l'applicazione: un registro
        // non deve mai diventare il collo di bottiglia di cio' che sta registrando.
        if (!_chiuso) _coda.TryAdd(riga);
    }

    private void Scrivi()
    {
        foreach (var riga in _coda.GetConsumingEnumerable())
        {
            try { File.AppendAllText(FileDiOggi, riga, Encoding.UTF8); }
            catch { /* disco pieno o file bloccato: non c'e' niente di sensato da fare qui */ }
        }
    }

    private void PulisciVecchi()
    {
        try
        {
            var limite = DateTime.Now.AddDays(-30);
            foreach (var f in Directory.GetFiles(_cartella, "gestioneviaggi-*.log"))
                if (File.GetLastWriteTime(f) < limite) File.Delete(f);
        }
        catch { /* la pulizia non deve impedire l'avvio */ }
    }

    public void Dispose()
    {
        _chiuso = true;
        _coda.CompleteAdding();
        try { _scrittore.Join(TimeSpan.FromSeconds(2)); } catch { }
        _coda.Dispose();
    }

    private sealed class Logger : ILogger
    {
        private readonly FileLoggerProvider _p;
        private readonly string _categoria;

        public Logger(FileLoggerProvider p, string categoria) { _p = p; _categoria = categoria; }

        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;

        // Sotto Warning non si scrive: il registro serve a capire cosa e' andato storto, non a
        // seguire il funzionamento normale.
        public bool IsEnabled(LogLevel logLevel) => logLevel >= LogLevel.Warning;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception,
                                Func<TState, Exception?, string> formatter)
        {
            if (!IsEnabled(logLevel)) return;

            var sb = new StringBuilder();
            sb.Append(DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff"))
              .Append(" [").Append(logLevel).Append("] ")
              .Append(_categoria).Append(" — ")
              .AppendLine(formatter(state, exception));

            // La pila delle chiamate e' il motivo per cui questo file esiste: senza, un errore
            // dice cosa e' successo ma non dove.
            if (exception != null) sb.AppendLine(exception.ToString());

            _p.Accoda(sb.ToString());
        }
    }
}
