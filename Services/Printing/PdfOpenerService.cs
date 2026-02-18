using MudBlazor;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Storage;

namespace GestioneViaggi.Services.Printing;

public interface IPdfOpenerService
{
    Task<bool> OpenPdfAsync(string filePath, string title = "Stampa Completata");
}

public class PdfOpenerService : IPdfOpenerService
{
    private readonly IDialogService _dialogService;

    public PdfOpenerService(IDialogService dialogService)
    {
        _dialogService = dialogService;
    }

    public async Task<bool> OpenPdfAsync(string filePath, string title = "Stampa Completata")
    {
        var fileName = Path.GetFileName(filePath);
        
        bool? confirm = await _dialogService.ShowMessageBox(
            title,
            $"Il file è stato salvato in Downloads:\n{fileName}\n\nVuoi aprirlo?",
            yesText: "Sì, Apri", cancelText: "No");

        if (confirm == true)
        {
            try
            {
#if MACCATALYST
                var psi = new System.Diagnostics.ProcessStartInfo
                {
                    FileName = "open",
                    Arguments = $"\"{filePath}\"",
                    UseShellExecute = true
                };
                System.Diagnostics.Process.Start(psi);
#else
                await Launcher.Default.OpenAsync(new OpenFileRequest
                {
                    Title = title,
                    File = new ReadOnlyFile(filePath)
                });
#endif
                return true;
            }
            catch (Exception)
            {
                // Log or rethrow if needed, but for now just return false indicating failure to open
                return false;
            }
        }

        return false;
    }
}
