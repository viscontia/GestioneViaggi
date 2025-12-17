using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace GestioneViaggi.Services.Session;

public class FileStorageProvider : ISecureStorageProvider
{
    private readonly ILogger<FileStorageProvider> _logger;
    private readonly string _storagePath;
    private readonly Dictionary<string, string> _cache = new();

    public FileStorageProvider(ILogger<FileStorageProvider> logger)
    {
        _logger = logger;
        _storagePath = Path.Combine(FileSystem.AppDataDirectory, "session-data.json");
        _logger.LogInformation("FileStorageProvider initialized with path: {Path}", _storagePath);
        LoadFromDisk();
    }

    public async Task SetAsync(string key, string value)
    {
        try
        {
            _cache[key] = value;
            await SaveToDiskAsync();
            _logger.LogDebug("Stored to file: {Key}", key);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error storing value for key: {Key}", key);
            throw;
        }
    }

    public Task<string?> GetAsync(string key)
    {
        try
        {
            var success = _cache.TryGetValue(key, out var value);
            _logger.LogDebug("Retrieved from file: {Key} = {Found}", key, success);
            return Task.FromResult(value);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving value for key: {Key}", key);
            return Task.FromResult<string?>(null);
        }
    }

    public void Remove(string key)
    {
        try
        {
            _cache.Remove(key);
            SaveToDiskAsync().GetAwaiter().GetResult();
            _logger.LogDebug("Removed from file: {Key}", key);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing key: {Key}", key);
        }
    }

    private void LoadFromDisk()
    {
        try
        {
            if (File.Exists(_storagePath))
            {
                var json = File.ReadAllText(_storagePath);
                var data = JsonSerializer.Deserialize<Dictionary<string, string>>(json);
                if (data != null)
                {
                    _cache.Clear();
                    foreach (var kvp in data)
                    {
                        _cache[kvp.Key] = kvp.Value;
                    }
                    _logger.LogInformation("Loaded {Count} items from file storage", _cache.Count);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error loading from file storage");
            _cache.Clear();
        }
    }

    private async Task SaveToDiskAsync()
    {
        try
        {
            var json = JsonSerializer.Serialize(_cache, new JsonSerializerOptions { WriteIndented = false });
            await File.WriteAllTextAsync(_storagePath, json);
            _logger.LogDebug("Data persisted to disk");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving to file storage");
            throw;
        }
    }
}
