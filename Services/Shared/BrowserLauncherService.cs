using MudBlazor;

namespace GestioneViaggi.Services.Shared;

/// <summary>
/// Service for opening URLs in the system default browser.
/// Cross-platform compatible (Windows, macOS sandbox).
/// </summary>
public interface IBrowserLauncherService
{
    /// <summary>
    /// Opens a URL in the system default browser.
    /// </summary>
    /// <param name="url">The URL to open (must be http/https)</param>
    /// <param name="mode">Browser launch mode (default: SystemPreferred)</param>
    /// <returns>True if browser opened successfully, false otherwise</returns>
    Task<bool> OpenUrlAsync(string url, BrowserLaunchMode mode = BrowserLaunchMode.SystemPreferred);
}

public class BrowserLauncherService : IBrowserLauncherService
{
    private readonly ISnackbar _snackbar;

    public BrowserLauncherService(ISnackbar snackbar)
    {
        _snackbar = snackbar;
    }

    public async Task<bool> OpenUrlAsync(string url, BrowserLaunchMode mode = BrowserLaunchMode.SystemPreferred)
    {
        // Validation: null/empty check
        if (string.IsNullOrWhiteSpace(url))
        {
            return false;
        }

        // Validation: URL format check
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri))
        {
            return false;
        }

        // Security: only http/https schemes allowed
        if (uri.Scheme != "http" && uri.Scheme != "https")
        {
            _snackbar.Add("Solo URL http/https sono supportati", Severity.Warning);
            return false;
        }

        // Open browser using MAUI.Essentials (cross-platform)
        try
        {
            await Browser.Default.OpenAsync(url, mode);
            return true;
        }
        catch (FeatureNotSupportedException)
        {
            _snackbar.Add("Apertura browser non supportata su questa piattaforma", Severity.Error);
            return false;
        }
        catch (Exception ex)
        {
            _snackbar.Add($"Impossibile aprire il browser: {ex.Message}", Severity.Error);
            return false;
        }
    }
}
