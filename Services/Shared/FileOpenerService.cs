using MudBlazor;

namespace GestioneViaggi.Services.Shared;

public interface IFileOpenerService
{
    Task<bool> OpenFileAsync(string filePath, string title = "File Generato");
}

public class FileOpenerService : IFileOpenerService
{
    private readonly IDialogService _dialogService;

    public FileOpenerService(IDialogService dialogService)
    {
        _dialogService = dialogService;
    }

    public async Task<bool> OpenFileAsync(string filePath, string title = "File Generato")
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
#elif WINDOWS
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                {
                    FileName = filePath,
                    UseShellExecute = true
                });
#else
                await Launcher.Default.OpenAsync(new Microsoft.Maui.Storage.OpenFileRequest
                {
                    Title = title,
                    File = new Microsoft.Maui.Storage.ReadOnlyFile(filePath)
                });
#endif
                return true;
            }
            catch (Exception)
            {
                await _dialogService.ShowMessageBox(
                    "Impossibile aprire il file",
                    "Non è stato possibile aprire il file. Verificare di avere un'applicazione installata in grado di aprire questo tipo di file.\n\n" +
                    $"Il file è comunque disponibile nella cartella Downloads:\n{fileName}",
                    yesText: "OK");
                return false;
            }
        }

        return false;
    }
}
