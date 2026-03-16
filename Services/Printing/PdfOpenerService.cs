using GestioneViaggi.Services.Shared;

namespace GestioneViaggi.Services.Printing;

public interface IPdfOpenerService
{
    Task<bool> OpenPdfAsync(string filePath, string title = "Stampa Completata");

    /// <summary>
    /// Ottiene il percorso della cartella per il salvataggio dei PDF.
    /// Su macOS sandboxato, crea la cartella Downloads nel container se non esiste,
    /// altrimenti usa la cache dell'app.
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
        // Su macOS/iOS/Android le app sono sandboxate e non possono scrivere
        // liberamente nel filesystem. Usiamo direttamente la cache dell'app.
        #if MACCATALYST || IOS || ANDROID
        return FileSystem.CacheDirectory;
        #else
        // Su Windows/Linux proviamo la cartella Downloads standard
        var targetFolder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            "Downloads"
        );

        // Se non esiste o non possiamo accedervi, usa la cache
        try
        {
            if (!Directory.Exists(targetFolder))
            {
                Directory.CreateDirectory(targetFolder);
            }

            // Test di scrittura per verificare i permessi
            var testFile = Path.Combine(targetFolder, ".write_test");
            File.WriteAllText(testFile, "test");
            File.Delete(testFile);

            return targetFolder;
        }
        catch
        {
            // Fallback: usa la cache dell'app
            return FileSystem.CacheDirectory;
        }
        #endif
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
