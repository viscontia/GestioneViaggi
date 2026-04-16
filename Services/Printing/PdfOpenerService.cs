using GestioneViaggi.Services.Shared;

namespace GestioneViaggi.Services.Printing;

public interface IPdfOpenerService
{
    Task<bool> OpenPdfAsync(string filePath, string title = "Stampa Completata");

    /// <summary>
    /// Ottiene il percorso della cartella per il salvataggio dei PDF.
    /// Usa FileSystem.CacheDirectory su tutte le piattaforme (cartella app isolata).
    /// </summary>
    string GetPdfOutputFolder();

    /// <summary>
    /// Apre la cartella contenente i PDF generati nel file manager del sistema.
    /// </summary>
    void OpenPdfFolder();
}

public class PdfOpenerService : IPdfOpenerService
{
    private readonly IFileOpenerService _fileOpenerService;

    public PdfOpenerService(IFileOpenerService fileOpenerService)
    {
        _fileOpenerService = fileOpenerService;
    }

    public Task<bool> OpenPdfAsync(string filePath, string title = "Stampa Completata")
    {
        return _fileOpenerService.OpenFileAsync(filePath, title);
    }

    public string GetPdfOutputFolder()
    {
        // Usa la cache dell'app su tutte le piattaforme per mantenere i PDF
        // in una cartella dedicata isolata dal filesystem utente.
        return FileSystem.CacheDirectory;
    }

    public void OpenPdfFolder()
    {
        var folderPath = GetPdfOutputFolder();

        try
        {
            #if MACCATALYST
            var psi = new System.Diagnostics.ProcessStartInfo
            {
                FileName = "open",
                Arguments = $"\"{folderPath}\"",
                UseShellExecute = true
            };
            System.Diagnostics.Process.Start(psi);
            #elif WINDOWS
            System.Diagnostics.Process.Start("explorer.exe", folderPath);
            #elif LINUX
            System.Diagnostics.Process.Start("xdg-open", folderPath);
            #else
            // iOS/Android: non supportato direttamente, potrebbe essere implementato con un file picker
            throw new PlatformNotSupportedException("Apertura cartella non supportata su questa piattaforma");
            #endif
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Impossibile aprire la cartella: {folderPath}", ex);
        }
    }
}
