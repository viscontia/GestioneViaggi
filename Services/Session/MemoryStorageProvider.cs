using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Session;

public class MemoryStorageProvider : ISecureStorageProvider
{
    private readonly Dictionary<string, string> _storage = new();
    private readonly ILogger<MemoryStorageProvider> _logger;

    public MemoryStorageProvider(ILogger<MemoryStorageProvider> logger)
    {
        _logger = logger;
    }

    public Task SetAsync(string key, string value)
    {
        _storage[key] = value;
        _logger.LogDebug("Stored in memory: {Key}", key);
        return Task.CompletedTask;
    }

    public Task<string?> GetAsync(string key)
    {
        var success = _storage.TryGetValue(key, out var value);
        _logger.LogDebug("Retrieved from memory: {Key} = {Found}", key, success);
        return Task.FromResult(value);
    }

    public void Remove(string key)
    {
        _storage.Remove(key);
        _logger.LogDebug("Removed from memory: {Key}", key);
    }
}
