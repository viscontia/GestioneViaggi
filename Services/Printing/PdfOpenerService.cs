using GestioneViaggi.Services.Shared;

namespace GestioneViaggi.Services.Printing;

public interface IPdfOpenerService
{
    Task<bool> OpenPdfAsync(string filePath, string title = "Stampa Completata");
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
}
