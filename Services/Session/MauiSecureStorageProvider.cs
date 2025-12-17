using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Session;

public class MauiSecureStorageProvider : ISecureStorageProvider
{
    private readonly ILogger<MauiSecureStorageProvider> _logger;

    public MauiSecureStorageProvider(ILogger<MauiSecureStorageProvider> logger)
    {
        _logger = logger;
    }

    public async Task SetAsync(string key, string value)
    {
        try
        {
            await SecureStorage.SetAsync(key, value);
            _logger.LogDebug("Stored in SecureStorage: {Key}", key);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error storing in SecureStorage: {Key}", key);
            throw;
        }
    }

    public async Task<string?> GetAsync(string key)
    {
        try
        {
            var value = await SecureStorage.GetAsync(key);
            _logger.LogDebug("Retrieved from SecureStorage: {Key} = {Found}", key, !string.IsNullOrEmpty(value));
            return value;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving from SecureStorage: {Key}", key);
            return null;
        }
    }

    public void Remove(string key)
    {
        try
        {
            SecureStorage.Remove(key);
            _logger.LogDebug("Removed from SecureStorage: {Key}", key);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing from SecureStorage: {Key}", key);
        }
    }
}
