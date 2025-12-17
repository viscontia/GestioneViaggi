using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Database;

public class DatabaseConnectionManager : IDatabaseConnectionManager
{
    private readonly string _connectionString;
    private readonly ILogger<DatabaseConnectionManager> _logger;
    private NpgsqlDataSource? _dataSource;
    private volatile bool _initialized = false;

    public bool IsConnectionAvailable => _dataSource != null && _initialized;

    public DatabaseConnectionManager(IConfiguration configuration, ILogger<DatabaseConnectionManager> logger)
    {
        _connectionString = configuration.GetConnectionString("PostgreSQL")
            ?? throw new InvalidOperationException("Connection string 'PostgreSQL' not found");
        _logger = logger;
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
            
            builder.ConnectionStringBuilder.Pooling = true;
            builder.ConnectionStringBuilder.MinPoolSize = 1;
            builder.ConnectionStringBuilder.MaxPoolSize = 20;
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
