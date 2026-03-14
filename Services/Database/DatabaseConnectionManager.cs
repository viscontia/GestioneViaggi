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
            // - Prod (Supabase/PgBouncer): pool minimo con multiplexing (dalla connection string)
            if (_environment == DbEnvironment.Test)
            {
                builder.ConnectionStringBuilder.Pooling = true;
                builder.ConnectionStringBuilder.MinPoolSize = 1;
                builder.ConnectionStringBuilder.MaxPoolSize = 20;
            }
            else
            {
                // Per PgBouncer: pooling minimo lato Npgsql, multiplexing gestisce la concorrenza
                builder.ConnectionStringBuilder.Pooling = true;
                builder.ConnectionStringBuilder.MinPoolSize = 0;
                builder.ConnectionStringBuilder.MaxPoolSize = 5;
            }

            builder.ConnectionStringBuilder.Timeout = 30;

            _dataSource = builder.Build();

            await using var testConnection = await _dataSource.OpenConnectionAsync();
            await testConnection.CloseAsync();

            _initialized = true;
            _logger.LogInformation("Database connection pool initialized successfully");
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
}
