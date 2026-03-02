using Npgsql;
using GestioneViaggi.Models;

namespace GestioneViaggi.Services.Database;

public interface IDatabaseConnectionManager
{
    Task<NpgsqlConnection> GetConnectionAsync();
    Task InitializePoolAsync();
    Task DisposePoolAsync();
    bool IsConnectionAvailable { get; }
    string Host { get; }
    DbEnvironment Environment { get; }
}
