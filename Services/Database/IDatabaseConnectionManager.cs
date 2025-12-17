using Npgsql;

namespace GestioneViaggi.Services.Database;

public interface IDatabaseConnectionManager
{
    Task<NpgsqlConnection> GetConnectionAsync();
    Task InitializePoolAsync();
    Task DisposePoolAsync();
    bool IsConnectionAvailable { get; }
}
