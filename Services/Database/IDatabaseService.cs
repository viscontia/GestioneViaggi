using Npgsql;

namespace GestioneViaggi.Services.Database;

public interface IDatabaseService
{
    Task<NpgsqlConnection> GetConnectionAsync();
    Task<T?> ExecuteFunctionAsync<T>(string functionName, params (string Name, object? Value)[] parameters);
}
