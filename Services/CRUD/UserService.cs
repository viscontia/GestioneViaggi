using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;
using System.Text.Json;

namespace GestioneViaggi.Services.CRUD;

public interface IUserService
{
    Task<List<UserInfo>> GetUsersAsync();
    Task CreateUserAsync(UserInfo user, string password);
    /// <summary>
    /// Update user details. Pass null or empty for password to keep it unchanged.
    /// </summary>
    Task UpdateUserAsync(UserInfo user, string? password = null);
    Task DeleteUserAsync(Guid userId);
}

public class UserService : IUserService
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<UserService> _logger;

    public UserService(IDatabaseService databaseService, ILogger<UserService> logger)
    {
        _databaseService = databaseService;
        _logger = logger;
    }

    public async Task<List<UserInfo>> GetUsersAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM fn_app_list_users()";

            var result = new List<UserInfo>();
            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                result.Add(new UserInfo
                {
                    UserId = reader.GetGuid(reader.GetOrdinal("user_id")),
                    Email = reader.GetString(reader.GetOrdinal("email")),
                    Nome = reader.GetString(reader.GetOrdinal("nome")),
                    Cognome = reader.GetString(reader.GetOrdinal("cognome")),
                    RoleCode = reader.GetString(reader.GetOrdinal("role_code")),
                    RoleName = reader.GetString(reader.GetOrdinal("role_name")),
                    AziendaId = reader.IsDBNull(reader.GetOrdinal("azienda_id")) ? null : reader.GetInt32(reader.GetOrdinal("azienda_id")),
                    RagioneSocialeAzienda = reader.IsDBNull(reader.GetOrdinal("ragione_sociale")) ? null : reader.GetString(reader.GetOrdinal("ragione_sociale")),
                    IsActive = reader.GetBoolean(reader.GetOrdinal("is_active")),
                    LastLoginAt = reader.IsDBNull(reader.GetOrdinal("last_login_at")) ? null : reader.GetDateTime(reader.GetOrdinal("last_login_at")),
                    DataNascita = reader.IsDBNull(reader.GetOrdinal("data_nascita")) ? null : reader.GetDateTime(reader.GetOrdinal("data_nascita")),
                    ValutaDefaultId = reader.IsDBNull(reader.GetOrdinal("valuta_default_id")) ? null : reader.GetInt32(reader.GetOrdinal("valuta_default_id"))
                });
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting users");
            throw;
        }
    }

    private async Task ExecuteCommandAsync(string sql, params (string Name, object? Value)[] parameters)
    {
        await using var connection = await _databaseService.GetConnectionAsync();
        await using var command = new NpgsqlCommand(sql, connection);

        foreach (var p in parameters)
        {
            command.Parameters.AddWithValue(p.Name, p.Value ?? DBNull.Value);
        }

        await command.ExecuteNonQueryAsync();
    }

    public async Task CreateUserAsync(UserInfo user, string password)
    {
        try
        {
            await ExecuteCommandAsync("CALL sp_app_create_user(@p_email, @p_password, @p_nome, @p_cognome, @p_role_code, @p_azienda_id::integer, @p_data_nascita::date, @p_valuta_default_id::integer)",
                ("p_email", user.Email),
                ("p_password", password),
                ("p_nome", user.Nome),
                ("p_cognome", user.Cognome),
                ("p_role_code", user.RoleCode ?? string.Empty),
                ("p_azienda_id", (object?)user.AziendaId ?? DBNull.Value),
                ("p_data_nascita", (object?)user.DataNascita ?? DBNull.Value),
                ("p_valuta_default_id", (object?)user.ValutaDefaultId ?? DBNull.Value)
            );
        }
        catch (PostgresException ex) when (ex.Message.Contains("USER_ALREADY_EXISTS"))
        {
            throw new InvalidOperationException("Un utente con questa email esiste già.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating user");
            throw;
        }
    }

    public async Task UpdateUserAsync(UserInfo user, string? password = null)
    {
        try
        {
            await ExecuteCommandAsync("CALL sp_app_update_user(@p_user_id, @p_email, @p_password, @p_nome, @p_cognome, @p_role_code, @p_azienda_id::integer, @p_is_active, @p_data_nascita::date, @p_valuta_default_id::integer)",
               ("p_user_id", user.UserId),
               ("p_email", user.Email),
               ("p_password", (object?)password ?? DBNull.Value),
               ("p_nome", user.Nome),
               ("p_cognome", user.Cognome),
               ("p_role_code", user.RoleCode ?? string.Empty),
               ("p_azienda_id", (object?)user.AziendaId ?? DBNull.Value),
               ("p_is_active", user.IsActive),
               ("p_data_nascita", (object?)user.DataNascita ?? DBNull.Value),
               ("p_valuta_default_id", (object?)user.ValutaDefaultId ?? DBNull.Value)
           );
        }
        catch (PostgresException ex) when (ex.Message.Contains("EMAIL_ALREADY_EXISTS"))
        {
            throw new InvalidOperationException("Questa email è già associata ad un altro utente.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating user");
            throw;
        }
    }

    public async Task DeleteUserAsync(Guid userId)
    {
        try
        {
            await ExecuteCommandAsync("CALL sp_app_delete_user(@p_user_id)",
                ("p_user_id", userId)
            );
        }
        catch (PostgresException ex)
        {
            _logger.LogError(ex, "PG Error deleting user: {Code} - {Message}", ex.SqlState, ex.Message);

            if (ex.Message.Contains("USER_HAS_OPERATIONAL_DATA"))
            {
                throw new InvalidOperationException("Impossibile eliminare l'utente: risulta autore o revisore di Dati Operativi (Loghi, Viaggi, Clienti).\n\nSi consiglia di DISABILITARE l'utente invece di cancellarlo, per preservare lo storico.");
            }

            if (ex.Message.Contains("USER_HAS_DEPENDENCIES") || ex.SqlState == "23503")
            {
                throw new InvalidOperationException("Impossibile eliminare l'utente: ci sono dati collegati che impediscono la cancellazione.");
            }

            throw new InvalidOperationException($"Errore Database: {ex.Message}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting user");
            throw;
        }
    }
}
