namespace GestioneViaggi.Services;

/// <summary>
/// Logger per debugging in MAUI - scrive su file nella cartella LocalApplicationData
/// </summary>
public static class DebugLogger
{
    private static readonly string LogPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "GestioneViaggi_Debug.txt"
    );

    private static readonly object _lock = new object();

    /// <summary>
    /// Scrive un messaggio nel log con timestamp
    /// </summary>
    public static void Log(string message)
    {
        try
        {
            lock (_lock)
            {
                var timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                var logMessage = $"[{timestamp}] {message}{Environment.NewLine}";
                File.AppendAllText(LogPath, logMessage);
            }
            System.Diagnostics.Debug.WriteLine(message);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[DebugLogger] Errore scrittura log: {ex.Message}");
        }
    }

    /// <summary>
    /// Scrive un messaggio di errore con stack trace
    /// </summary>
    public static void LogError(string message, Exception ex)
    {
        Log($"ERROR: {message}");
        Log($"Exception: {ex.GetType().Name} - {ex.Message}");
        Log($"StackTrace: {ex.StackTrace}");
        if (ex.InnerException != null)
        {
            Log($"InnerException: {ex.InnerException.Message}");
        }
    }

    /// <summary>
    /// Restituisce il percorso del file di log
    /// </summary>
    public static string GetLogPath() => LogPath;

    /// <summary>
    /// Pulisce il file di log (utile prima di un nuovo test)
    /// </summary>
    public static void ClearLog()
    {
        try
        {
            lock (_lock)
            {
                if (File.Exists(LogPath))
                {
                    File.Delete(LogPath);
                }
                Log("=== LOG CLEARED - NEW SESSION ===");
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[DebugLogger] Errore pulizia log: {ex.Message}");
        }
    }

    /// <summary>
    /// Legge il contenuto del log
    /// </summary>
    public static string ReadLog()
    {
        try
        {
            if (File.Exists(LogPath))
            {
                return File.ReadAllText(LogPath);
            }
            return "Log file non trovato";
        }
        catch (Exception ex)
        {
            return $"Errore lettura log: {ex.Message}";
        }
    }
}
