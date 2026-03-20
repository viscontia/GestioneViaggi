using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Npgsql;
using GestioneViaggi.Models;

namespace GestioneViaggi.Services.Database;

public class DatabaseConnectionManager : IDatabaseConnectionManager
{
    private readonly string _connectionString;
    private readonly ILogger<DatabaseConnectionManager> _logger;
    private readonly string _host;
    private readonly DbEnvironment _environment;
    private NpgsqlDataSource? _dataSource;
    private volatile bool _initialized = false;

    public bool IsConnectionAvailable => _dataSource != null && _initialized;

    public string Host => _host;

    public DbEnvironment Environment => _environment;

    public DatabaseConnectionManager(
        IConfiguration configuration,
        ILogger<DatabaseConnectionManager> logger)
    {
        _connectionString = configuration.GetConnectionString("PostgreSQL")
            ?? throw new InvalidOperationException("Connection string 'PostgreSQL' not found");
        _logger = logger;
        
        _host = ExtractHost(_connectionString);
        _environment = DetermineEnvironment(_host);
    }

    private static string ExtractHost(string connectionString)
    {
        var parts = connectionString.Split(';', StringSplitOptions.RemoveEmptyEntries);
        foreach (var part in parts)
        {
            var keyValue = part.Split('=', 2);
            if (keyValue.Length == 2 && keyValue[0].Trim().Equals("Host", StringComparison.OrdinalIgnoreCase))
            {
                return keyValue[1].Trim();
            }
        }
        return string.Empty;
    }

    private static DbEnvironment DetermineEnvironment(string host)
    {
        if (string.IsNullOrEmpty(host))
            return DbEnvironment.Prod;
            
        var lowerHost = host.ToLowerInvariant();
        if (lowerHost == "localhost" || lowerHost == "127.0.0.1")
            return DbEnvironment.Test;
            
        return DbEnvironment.Prod;
    }

    public async Task InitializePoolAsync()
    {
        if (_initialized || _dataSource != null)
        {
            _logger.LogInformation("Connection pool already initialized");
            return;
        }

        try
        {
            var builder = new NpgsqlDataSourceBuilder(_connectionString);

            // Configurazione pooling differenziata per ambiente:
            // - Test (Docker locale): pool più ampio senza multiplexing
            // - Prod (Supabase/PgBouncer): pool standard (Keepalive=30 dalla connection string)
            if (_environment == DbEnvironment.Test)
            {
                // Test (Docker locale): configurazione pool client-side
                builder.ConnectionStringBuilder.Pooling = true;
                builder.ConnectionStringBuilder.MinPoolSize = 1;
                builder.ConnectionStringBuilder.MaxPoolSize = 20;
                builder.ConnectionStringBuilder.ConnectionIdleLifetime = 300; // 5 minutes idle cleanup
                builder.ConnectionStringBuilder.ConnectionPruningInterval = 10; // Check every 10 seconds
                builder.ConnectionStringBuilder.Timeout = 30;
                builder.ConnectionStringBuilder.ConnectionLifetime = 600; // 10 minutes max connection lifetime
            }
            // Per Prod (Supabase/PgBouncer): NON modificare NULLA
            // La connection string contiene già tutte le impostazioni corrette

            _dataSource = builder.Build();

            await using var testConnection = await _dataSource.OpenConnectionAsync();
            await testConnection.CloseAsync();

            _initialized = true;

            // Log pool configuration for monitoring
            var poolConfig = _environment == DbEnvironment.Test
                ? "Test: MinPool=1, MaxPool=20, IdleLifetime=300s"
                : "Prod: Pooling=true (PgBouncer), Keepalive=30s";
            _logger.LogInformation(
                "Database connection pool initialized successfully. Environment: {Environment}, Config: {PoolConfig}",
                _environment,
                poolConfig
            );
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize database connection pool");
            throw;
        }
    }

    public async Task<NpgsqlConnection> GetConnectionAsync()
    {
        if (!IsConnectionAvailable)
        {
            _logger.LogWarning("Connection pool not initialized. Initializing...");
            await InitializePoolAsync();
        }

        try
        {
            var connection = await _dataSource!.OpenConnectionAsync();
            _logger.LogDebug("Database connection acquired from pool");
            return connection;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to acquire database connection");
            throw;
        }
    }

    public async Task DisposePoolAsync()
    {
        try
        {
            if (_dataSource != null)
            {
                await _dataSource.DisposeAsync();
                _dataSource = null;
                _initialized = false;
                _logger.LogInformation("Database connection pool disposed");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error disposing database connection pool");
        }
    }

    /// <summary>
    /// Gets current pool statistics for monitoring and optimization.
    /// Call this periodically to verify MaxPoolSize is adequate.
    /// </summary>
    public PoolStatistics GetPoolStatistics()
    {
        var stats = new PoolStatistics
        {
            Environment = _environment,
            IsInitialized = _initialized,
            Host = _host,
            MaxPoolSize = _environment == DbEnvironment.Test ? 20 : 0, // Prod: no client-side pooling
            MinPoolSize = _environment == DbEnvironment.Test ? 1 : 0,
            IdleLifetimeSeconds = _environment == DbEnvironment.Test ? 300 : 0,
            ConnectionLifetimeSeconds = _environment == DbEnvironment.Test ? 600 : 0
        };

        _logger.LogDebug(
            "Pool Statistics - Env: {Environment}, MaxPool: {MaxPool}, Host: {Host}",
            stats.Environment,
            stats.MaxPoolSize,
            stats.Host
        );

        return stats;
    }
}

/// <summary>
/// Represents current connection pool statistics.
/// Useful for monitoring and determining if MaxPoolSize needs adjustment.
/// </summary>
public record PoolStatistics
{
    public DbEnvironment Environment { get; init; }
    public bool IsInitialized { get; init; }
    public string Host { get; init; } = string.Empty;
    public int MaxPoolSize { get; init; }
    public int MinPoolSize { get; init; }
    public int IdleLifetimeSeconds { get; init; }
    public int ConnectionLifetimeSeconds { get; init; }
}
