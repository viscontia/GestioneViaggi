using GestioneViaggi.Models;
using GestioneViaggi.Repositories.Interfaces;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;
using Dapper;
using System.Text.Json;

namespace GestioneViaggi.Repositories;

/// <summary>
/// Repository per operazioni CRUD su ana_clienti con supporto multi-tenant
/// </summary>
public class ClienteRepository(
    IDatabaseService databaseService,
    ILogger<ClienteRepository> logger,
    ISessionManager sessionManager) : IClienteRepository
{
    private readonly IDatabaseService _databaseService = databaseService;
    private readonly ILogger<ClienteRepository> _logger = logger;
    private readonly ISessionManager _sessionManager = sessionManager;

    #region CRUD Base

    public async Task<Cliente?> GetByIdAsync(int clienteId, int aziendaFk)
    {
        try
        {
            // DB-First: Use PostgreSQL function fn_get_cliente_by_id
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT fn_get_cliente_by_id(@clienteId::INT, @aziendaFk::INT)";

            var parameters = new DynamicParameters();
            parameters.Add("clienteId", clienteId);
            parameters.Add("aziendaFk", aziendaFk);

            var jsonResult = await connection.ExecuteScalarAsync<string>(sql, parameters);

            if (string.IsNullOrEmpty(jsonResult) || jsonResult == "null")
            {
                return null;
            }

            var cliente = JsonSerializer.Deserialize<Cliente>(jsonResult, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            return cliente;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero del cliente {ClienteId} per azienda {AziendaFk}", clienteId, aziendaFk);
            throw;
        }
    }

    public async Task<Cliente?> GetDetailAsync(int clienteId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM get_cliente_detail(@clienteId)";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("clienteId", clienteId);

            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                var cliente = MapFromReader(reader);
                cliente.AziendaRagioneSociale = ReadNullableString(reader, "azienda_ragione_sociale");

                if (!reader.IsDBNull(reader.GetOrdinal("comune_nascita_nome")))
                {
                    cliente.ComuneNascita = new Comune
                    {
                        Id = cliente.ComuneNascitaFk,
                        Nome = reader.GetString(reader.GetOrdinal("comune_nascita_nome")),
                        ProvinciaDescrizione = reader.GetString(reader.GetOrdinal("comune_nascita_provincia"))
                    };
                }

                if (!reader.IsDBNull(reader.GetOrdinal("comune_residenza_nome")))
                {
                    cliente.ComuneResidenza = new Comune
                    {
                        Id = cliente.ComuneResidenzaFk,
                        Nome = reader.GetString(reader.GetOrdinal("comune_residenza_nome")),
                        ProvinciaDescrizione = reader.GetString(reader.GetOrdinal("comune_residenza_provincia"))
                    };
                }

                return cliente;
            }

            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero del dettaglio cliente {ClienteId}", clienteId);
            throw;
        }
    }

    public async Task<List<Cliente>> GetAllAsync(int? aziendaFk, int? filterYear = null)
    {
        try
        {
            // DB-First: Use PostgreSQL function fn_get_all_clienti
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT fn_get_all_clienti(@aziendaFk::INT, @filterYear::INT)";

            var parameters = new DynamicParameters();
            parameters.Add("aziendaFk", aziendaFk);
            parameters.Add("filterYear", filterYear);

            var jsonResult = await connection.ExecuteScalarAsync<string>(sql, parameters);

            if (string.IsNullOrEmpty(jsonResult) || jsonResult == "null" || jsonResult == "[]")
            {
                return new List<Cliente>();
            }

            var clienti = JsonSerializer.Deserialize<List<Cliente>>(jsonResult, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            }) ?? new List<Cliente>();

            _logger.LogInformation("Recuperati {Count} clienti per azienda {AziendaFk}", clienti.Count, aziendaFk);
            return clienti;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero di tutti i clienti per azienda {AziendaFk}", aziendaFk);
            throw;
        }
    }

    public async Task<Cliente> InsertAsync(Cliente cliente)
    {
        try
        {
            // DB-First: Use PostgreSQL stored procedure sp_ana_clienti_create
            await using var connection = await _databaseService.GetConnectionAsync();

            var sql = @"SELECT sp_ana_clienti_create(
                @p_cliente_titolo::VARCHAR,
                @p_cliente_cognome::VARCHAR,
                @p_cliente_nome::VARCHAR,
                @p_cliente_sesso::VARCHAR,
                @p_cliente_comune_residenza_fk::INT,
                @p_cliente_indirizzo_residenza::VARCHAR,
                @p_cliente_comune_nascita_fk::INT,
                @p_cliente_data_nascita::DATE,
                @p_cliente_preftelint::VARCHAR,
                @p_cliente_telefono::VARCHAR,
                @p_cliente_email::VARCHAR,
                @p_cliente_codicefiscale::VARCHAR,
                @p_cliente_iban::VARCHAR,
                @p_cliente_foto::BYTEA,
                @p_cliente_carta_identita::BYTEA,
                @p_cliente_tipodoc_identita::VARCHAR,
                @p_cliente_documento_numero::VARCHAR,
                @p_cliente_documento_rilasciato_da::VARCHAR,
                @p_cliente_documento_rilasciato_data::DATE,
                @p_cliente_documento_rilasciato_scadenza::DATE,
                @p_cliente_note::TEXT,
                @p_cliente_foto_mimetype::VARCHAR,
                @p_cliente_foto_filename::VARCHAR,
                @p_cliente_foto_charset::VARCHAR,
                @p_cliente_foto_upd_date::TIMESTAMP,
                @p_cliente_documento_mimetype::VARCHAR,
                @p_cliente_documento_filename::VARCHAR,
                @p_cliente_documento_chartset::VARCHAR,
                @p_cliente_documento_upd_date::TIMESTAMP,
                @p_cliente_intolleranza::VARCHAR,
                @p_azienda_fk::INT
            )";

            var parameters = BuildClienteParameters(cliente);

            var jsonResult = await connection.ExecuteScalarAsync<string>(sql, parameters);

            if (string.IsNullOrEmpty(jsonResult) || jsonResult == "null")
            {
                throw new InvalidOperationException("Failed to create cliente - no result returned");
            }

            var createdCliente = JsonSerializer.Deserialize<Cliente>(jsonResult, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            _logger.LogInformation("Cliente {ClienteId} creato con successo per azienda {AziendaFk}",
                createdCliente?.ClienteId, cliente.AziendaFk);

            return createdCliente ?? throw new InvalidOperationException("Failed to deserialize created cliente");
        }
        catch (PostgresException ex) when (ex.SqlState == "23505")
        {
            _logger.LogWarning(ex, "Violazione constraint univoco durante inserimento cliente");
            throw new InvalidOperationException($"Cliente già esistente: {ex.MessageText}", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'inserimento del cliente");
            throw;
        }
    }

    public async Task<Cliente> UpdateAsync(Cliente cliente)
    {
        try
        {
            // DB-First: Use PostgreSQL stored procedure sp_ana_clienti_update
            await using var connection = await _databaseService.GetConnectionAsync();

            var sql = @"SELECT sp_ana_clienti_update(
                @p_cliente_id::INT,
                @p_cliente_titolo::VARCHAR,
                @p_cliente_cognome::VARCHAR,
                @p_cliente_nome::VARCHAR,
                @p_cliente_sesso::VARCHAR,
                @p_cliente_comune_residenza_fk::INT,
                @p_cliente_indirizzo_residenza::VARCHAR,
                @p_cliente_comune_nascita_fk::INT,
                @p_cliente_data_nascita::DATE,
                @p_cliente_preftelint::VARCHAR,
                @p_cliente_telefono::VARCHAR,
                @p_cliente_email::VARCHAR,
                @p_cliente_codicefiscale::VARCHAR,
                @p_cliente_iban::VARCHAR,
                @p_cliente_foto::BYTEA,
                @p_cliente_carta_identita::BYTEA,
                @p_cliente_tipodoc_identita::VARCHAR,
                @p_cliente_documento_numero::VARCHAR,
                @p_cliente_documento_rilasciato_da::VARCHAR,
                @p_cliente_documento_rilasciato_data::DATE,
                @p_cliente_documento_rilasciato_scadenza::DATE,
                @p_cliente_note::TEXT,
                @p_cliente_foto_mimetype::VARCHAR,
                @p_cliente_foto_filename::VARCHAR,
                @p_cliente_foto_charset::VARCHAR,
                @p_cliente_foto_upd_date::TIMESTAMP,
                @p_cliente_documento_mimetype::VARCHAR,
                @p_cliente_documento_filename::VARCHAR,
                @p_cliente_documento_chartset::VARCHAR,
                @p_cliente_documento_upd_date::TIMESTAMP,
                @p_cliente_intolleranza::VARCHAR,
                @p_azienda_fk::INT
            )";

            var parameters = BuildClienteParameters(cliente);
            parameters.Add("p_cliente_id", cliente.ClienteId);

            var jsonResult = await connection.ExecuteScalarAsync<string>(sql, parameters);

            if (string.IsNullOrEmpty(jsonResult) || jsonResult == "null")
            {
                throw new InvalidOperationException($"Failed to update cliente {cliente.ClienteId} - no result returned");
            }

            var updatedCliente = JsonSerializer.Deserialize<Cliente>(jsonResult, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            _logger.LogInformation("Cliente {ClienteId} aggiornato con successo", cliente.ClienteId);

            return updatedCliente ?? throw new InvalidOperationException("Failed to deserialize updated cliente");
        }
        catch (PostgresException ex) when (ex.SqlState == "23505")
        {
            _logger.LogWarning(ex, "Violazione constraint univoco durante aggiornamento cliente {ClienteId}", cliente.ClienteId);
            throw new InvalidOperationException($"Cliente già esistente: {ex.MessageText}", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del cliente {ClienteId}", cliente.ClienteId);
            throw;
        }
    }

    public async Task<bool> DeleteAsync(int clienteId, int aziendaFk)
    {
        try
        {
            // DB-First: Use PostgreSQL stored procedure sp_ana_clienti_delete
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT sp_ana_clienti_delete(@p_cliente_id::INT, @p_azienda_fk::INT)";

            var parameters = new DynamicParameters();
            parameters.Add("p_cliente_id", clienteId);
            parameters.Add("p_azienda_fk", aziendaFk);

            await connection.ExecuteAsync(sql, parameters);

            _logger.LogInformation("Cliente {ClienteId} eliminato con successo", clienteId);
            return true;
        }
        catch (PostgresException ex)
        {
            _logger.LogWarning(ex, "Errore durante eliminazione cliente {ClienteId}: {Message}", clienteId, ex.MessageText);
            throw new InvalidOperationException($"Impossibile eliminare il cliente: {ex.MessageText}", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione del cliente {ClienteId}", clienteId);
            throw;
        }
    }

    #endregion

    #region Ricerche Specializzate

    public async Task<Cliente?> GetByEmailAsync(string email, int aziendaFk)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT
                    cliente_id,
                    cliente_titolo,
                    cliente_cognome,
                    cliente_nome,
                    cliente_sesso,
                    cliente_comune_residenza_fk,
                    cliente_indirizzo_residenza,
                    cliente_comune_nascita_fk,
                    cliente_data_nascita,
                    cliente_preftelint,
                    cliente_telefono,
                    cliente_email,
                    cliente_codicefiscale,
                    cliente_iban,
                    cliente_foto,
                    cliente_carta_identita,
                    cliente_tipodoc_identita,
                    cliente_documento_numero,
                    cliente_documento_rilasciato_da,
                    cliente_documento_rilasciato_data,
                    cliente_documento_rilasciato_scadenza,
                    cliente_note,
                    cliente_foto_mimetype,
                    cliente_foto_filename,
                    cliente_foto_charset,
                    cliente_foto_upd_date,
                    cliente_documento_mimetype,
                    cliente_documento_filename,
                    cliente_documento_chartset,
                    cliente_documento_upd_date,
                    cliente_intolleranza,
                    azienda_fk,
                    created_by,
                    created,
                    updated_by,
                    updated
                FROM ana_clienti
                WHERE LOWER(cliente_email) = LOWER(@email)
                  AND azienda_fk = @aziendaFk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("email", email);
            command.Parameters.AddWithValue("aziendaFk", aziendaFk);

            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la ricerca del cliente per email {Email}", email);
            throw;
        }
    }

    public async Task<Cliente?> GetByCodiceFiscaleAsync(string codiceFiscale, int aziendaFk)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT
                    cliente_id,
                    cliente_titolo,
                    cliente_cognome,
                    cliente_nome,
                    cliente_sesso,
                    cliente_comune_residenza_fk,
                    cliente_indirizzo_residenza,
                    cliente_comune_nascita_fk,
                    cliente_data_nascita,
                    cliente_preftelint,
                    cliente_telefono,
                    cliente_email,
                    cliente_codicefiscale,
                    cliente_iban,
                    cliente_foto,
                    cliente_carta_identita,
                    cliente_tipodoc_identita,
                    cliente_documento_numero,
                    cliente_documento_rilasciato_da,
                    cliente_documento_rilasciato_data,
                    cliente_documento_rilasciato_scadenza,
                    cliente_note,
                    cliente_foto_mimetype,
                    cliente_foto_filename,
                    cliente_foto_charset,
                    cliente_foto_upd_date,
                    cliente_documento_mimetype,
                    cliente_documento_filename,
                    cliente_documento_chartset,
                    cliente_documento_upd_date,
                    cliente_intolleranza,
                    azienda_fk,
                    created_by,
                    created,
                    updated_by,
                    updated
                FROM ana_clienti
                WHERE UPPER(cliente_codicefiscale) = UPPER(@codiceFiscale)
                  AND azienda_fk = @aziendaFk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("codiceFiscale", codiceFiscale);
            command.Parameters.AddWithValue("aziendaFk", aziendaFk);

            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la ricerca del cliente per codice fiscale {CodiceFiscale}", codiceFiscale);
            throw;
        }
    }

    public async Task<Cliente?> GetByAnagraficaAsync(string cognome, string nome, DateTime dataNascita, string codiceFiscale, int? aziendaFk)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT
                    cliente_id,
                    cliente_titolo,
                    cliente_cognome,
                    cliente_nome,
                    cliente_sesso,
                    cliente_comune_residenza_fk,
                    cliente_indirizzo_residenza,
                    cliente_comune_nascita_fk,
                    cliente_data_nascita,
                    cliente_preftelint,
                    cliente_telefono,
                    cliente_email,
                    cliente_codicefiscale,
                    cliente_iban,
                    cliente_foto,
                    cliente_carta_identita,
                    cliente_tipodoc_identita,
                    cliente_documento_numero,
                    cliente_documento_rilasciato_da,
                    cliente_documento_rilasciato_data,
                    cliente_documento_rilasciato_scadenza,
                    cliente_note,
                    cliente_foto_mimetype,
                    cliente_foto_filename,
                    cliente_foto_charset,
                    cliente_foto_upd_date,
                    cliente_documento_mimetype,
                    cliente_documento_filename,
                    cliente_documento_chartset,
                    cliente_documento_upd_date,
                    cliente_intolleranza,
                    azienda_fk,
                    created_by,
                    created,
                    updated_by,
                    updated
                FROM ana_clienti
                WHERE UPPER(cliente_cognome) = UPPER(@cognome)
                  AND UPPER(cliente_nome) = UPPER(@nome)
                  AND cliente_data_nascita = @dataNascita
                  AND UPPER(cliente_codicefiscale) = UPPER(@codiceFiscale)
                  AND azienda_fk = @aziendaFk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("cognome", cognome);
            command.Parameters.AddWithValue("nome", nome);
            command.Parameters.AddWithValue("dataNascita", dataNascita);
            command.Parameters.AddWithValue("codiceFiscale", codiceFiscale);
            command.Parameters.Add(new NpgsqlParameter("aziendaFk", NpgsqlTypes.NpgsqlDbType.Integer)
            {
                Value = (object?)aziendaFk ?? DBNull.Value
            });

            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la ricerca del cliente per anagrafica");
            throw;
        }
    }

    #endregion

    #region Validazioni di Esistenza

    public async Task<bool> ExistsByEmailAsync(string email, int? aziendaFk, int? excludeClienteId = null)
    {
        try
        {
            // DB-First: Use PostgreSQL function fn_exists_cliente_email
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT fn_exists_cliente_email(@p_email::VARCHAR, @p_exclude_cliente_id::INT, @p_azienda_fk::INT)";

            var parameters = new DynamicParameters();
            parameters.Add("p_email", email);
            parameters.Add("p_exclude_cliente_id", excludeClienteId ?? 0);
            parameters.Add("p_azienda_fk", aziendaFk);

            var result = await connection.ExecuteScalarAsync<bool>(sql, parameters);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la verifica esistenza email {Email}", email);
            throw;
        }
    }

    public async Task<bool> ExistsByCodiceFiscaleAsync(string codiceFiscale, int? aziendaFk, int? excludeClienteId = null)
    {
        try
        {
            // DB-First: Use PostgreSQL function fn_exists_cliente_codice_fiscale
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT fn_exists_cliente_codice_fiscale(@p_codice_fiscale::VARCHAR, @p_exclude_cliente_id::INT, @p_azienda_fk::INT)";

            var parameters = new DynamicParameters();
            parameters.Add("p_codice_fiscale", codiceFiscale);
            parameters.Add("p_exclude_cliente_id", excludeClienteId ?? 0);
            parameters.Add("p_azienda_fk", aziendaFk);

            var result = await connection.ExecuteScalarAsync<bool>(sql, parameters);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la verifica esistenza codice fiscale {CodiceFiscale}", codiceFiscale);
            throw;
        }
    }

    public async Task<bool> ExistsByAnagraficaAsync(string cognome, string nome, DateTime dataNascita, string codiceFiscale, int? aziendaFk, int? excludeClienteId = null)
    {
        try
        {
            // DB-First: Use PostgreSQL function fn_exists_cliente_anagrafica
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT fn_exists_cliente_anagrafica(@p_cognome::VARCHAR, @p_nome::VARCHAR, @p_data_nascita::DATE, @p_codice_fiscale::VARCHAR, @p_exclude_cliente_id::INT, @p_azienda_fk::INT)";

            var parameters = new DynamicParameters();
            parameters.Add("p_cognome", cognome);
            parameters.Add("p_nome", nome);
            parameters.Add("p_data_nascita", dataNascita);
            parameters.Add("p_codice_fiscale", codiceFiscale);
            parameters.Add("p_exclude_cliente_id", excludeClienteId ?? 0);
            parameters.Add("p_azienda_fk", aziendaFk);

            var result = await connection.ExecuteScalarAsync<bool>(sql, parameters);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la verifica esistenza per anagrafica");
            throw;
        }
    }

    #endregion

    #region Verifica Relazioni

    public async Task<bool> HasRelatedBookingsAsync(int clienteId, int aziendaFk)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            // Verifica se esistono iscrizioni per questo cliente
            var sql = @"
                SELECT EXISTS(
                    SELECT 1
                    FROM mov_clienti_viaggi
                    WHERE cliente_id_fk = @clienteId
                )";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("clienteId", clienteId);
            command.Parameters.AddWithValue("aziendaFk", aziendaFk);

            var result = await command.ExecuteScalarAsync();
            return result != null && (bool)result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la verifica delle prenotazioni per cliente {ClienteId}", clienteId);
            throw;
        }
    }

    public async Task<bool> HasRelatedAccommodationsAsync(int clienteId, int aziendaFk)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            // Verifica se esistono alloggi per questo cliente
            var sql = @"
                SELECT EXISTS(
                    SELECT 1
                    FROM mov_clienti_alloggi
                    WHERE (cliente_id1_fk = @clienteId
                       OR cliente_id2_fk = @clienteId
                       OR cliente_id3_fk = @clienteId
                       OR cliente_id4_fk = @clienteId
                       OR cliente_id5_fk = @clienteId
                       OR cliente_id6_fk = @clienteId)
                )";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("clienteId", clienteId);
            command.Parameters.AddWithValue("aziendaFk", aziendaFk);

            var result = await command.ExecuteScalarAsync();
            return result != null && (bool)result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la verifica degli alloggi per cliente {ClienteId}", clienteId);
            throw;
        }
    }

    #endregion

    #region Ricerca Full-Text

    public async Task<List<Cliente>> SearchAsync(string searchTerm, int aziendaFk)
    {
        try
        {
            // DB-First: Use PostgreSQL function fn_search_clienti
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT fn_search_clienti(@p_azienda_fk::INT, @p_search_text::VARCHAR)";

            var parameters = new DynamicParameters();
            parameters.Add("p_azienda_fk", aziendaFk);
            parameters.Add("p_search_text", searchTerm);

            var jsonResult = await connection.ExecuteScalarAsync<string>(sql, parameters);

            if (string.IsNullOrEmpty(jsonResult) || jsonResult == "null" || jsonResult == "[]")
            {
                return new List<Cliente>();
            }

            var clienti = JsonSerializer.Deserialize<List<Cliente>>(jsonResult, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            }) ?? new List<Cliente>();

            return clienti;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la ricerca clienti con termine {SearchTerm}", searchTerm);
            throw;
        }
    }

    #endregion

    #region Conteggi

    public async Task<int> CountAsync(int aziendaFk)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT COUNT(*)
                FROM ana_clienti
                WHERE azienda_fk = @aziendaFk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaFk", aziendaFk);

            var result = await command.ExecuteScalarAsync();
            return result != null ? Convert.ToInt32(result) : 0;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il conteggio dei clienti per azienda {AziendaFk}", aziendaFk);
            throw;
        }
    }

    #endregion


    #region Travel Stats

    public async Task<List<int>> GetTravelYearsAsync(int clienteId)
    {
        var years = new List<int>();
        await using var conn = await _databaseService.GetConnectionAsync();

        await using var cmd = new NpgsqlCommand("SELECT * FROM get_exist_travel_customer_by_year(@p_cliente_id)", conn);
        cmd.Parameters.AddWithValue("p_cliente_id", clienteId);

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            if (!reader.IsDBNull(0))
            {
                years.Add(reader.GetInt32(0));
            }
        }

        return years;
    }

    public async Task<IEnumerable<ClienteTravelHistory>> GetTravelHistoryAsync(int clienteId, int aziendaFk)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM get_client_travel_history(@clienteId, @aziendaFk)";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("clienteId", clienteId);
            command.Parameters.AddWithValue("aziendaFk", aziendaFk);

            await using var reader = await command.ExecuteReaderAsync();
            var result = new List<ClienteTravelHistory>();

            while (await reader.ReadAsync())
            {
                result.Add(new ClienteTravelHistory
                {
                    DataViaggioId = reader.GetInt32(reader.GetOrdinal("data_viaggio_id")),
                    Titolo = reader.GetString(reader.GetOrdinal("titolo")),
                    Tipo = ReadNullableString(reader, "tipo") ?? string.Empty,
                    DataInizio = reader.GetDateTime(reader.GetOrdinal("data_inizio")),
                    DataFine = reader.GetDateTime(reader.GetOrdinal("data_fine")),
                    Km = reader.GetInt32(reader.GetOrdinal("km")),
                    Giorni = reader.GetInt32(reader.GetOrdinal("giorni")),
                    Notti = reader.GetInt32(reader.GetOrdinal("notti")),
                    StatusCode = reader.GetInt32(reader.GetOrdinal("status_code")),
                    StatusDesc = reader.GetString(reader.GetOrdinal("status_desc")),
                    Ruolo = ReadNullableString(reader, "ruolo") ?? string.Empty,
                    Trattamento = ReadNullableString(reader, "trattamento") ?? string.Empty,
                    Pernottamento = ReadNullableString(reader, "pernottamento") ?? string.Empty,
                    CostoPilota = reader.GetInt32(reader.GetOrdinal("costo_pilota")),
                    CostoPasseggero = reader.GetInt32(reader.GetOrdinal("costo_passeggero"))
                });
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dello storico viaggi per cliente {ClienteId}", clienteId);
            throw;
        }
    }

    public async Task<IEnumerable<TravelPassenger>> GetTravelPassengersAsync(int dataViaggioId, int excludeClienteId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM get_travel_passengers(@dataViaggioId, @excludeClienteId)";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("dataViaggioId", dataViaggioId);
            command.Parameters.AddWithValue("excludeClienteId", excludeClienteId);

            await using var reader = await command.ExecuteReaderAsync();
            var result = new List<TravelPassenger>();

            while (await reader.ReadAsync())
            {
                result.Add(new TravelPassenger
                {
                    Nominativo = reader.GetString(reader.GetOrdinal("nominativo")),
                    Ruolo = ReadNullableString(reader, "ruolo") ?? string.Empty
                });
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero passeggeri per viaggio {DataViaggioId}", dataViaggioId);
            throw;
        }
    }

    public async Task<List<string>> GetAllParticipantsTravelAsync(int dataViaggioId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT nominativo FROM get_all_participants_travel(@dataViaggioId)";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("dataViaggioId", dataViaggioId);

            await using var reader = await command.ExecuteReaderAsync();
            var result = new List<string>();

            while (await reader.ReadAsync())
            {
                result.Add(reader.GetString(0));
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei partecipanti globali per viaggio {DataViaggioId}", dataViaggioId);
            throw;
        }
    }

    #endregion

    #region Helper Methods

    private static Cliente MapFromReader(NpgsqlDataReader reader)
    {
        return new Cliente
        {
            ClienteId = reader.GetInt32(reader.GetOrdinal("cliente_id")),
            Titolo = reader.IsDBNull(reader.GetOrdinal("cliente_titolo")) ? null : reader.GetString(reader.GetOrdinal("cliente_titolo")),
            Cognome = reader.GetString(reader.GetOrdinal("cliente_cognome")),
            Nome = reader.GetString(reader.GetOrdinal("cliente_nome")),
            Sesso = reader.GetChar(reader.GetOrdinal("cliente_sesso")),
            ComuneResidenzaFk = reader.GetInt32(reader.GetOrdinal("cliente_comune_residenza_fk")),
            IndirizzoResidenza = reader.IsDBNull(reader.GetOrdinal("cliente_indirizzo_residenza")) ? null : reader.GetString(reader.GetOrdinal("cliente_indirizzo_residenza")),
            ComuneNascitaFk = reader.GetInt32(reader.GetOrdinal("cliente_comune_nascita_fk")),
            DataNascita = reader.IsDBNull(reader.GetOrdinal("cliente_data_nascita")) ? null : reader.GetDateTime(reader.GetOrdinal("cliente_data_nascita")),
            PrefTelInt = reader.IsDBNull(reader.GetOrdinal("cliente_preftelint")) ? null : reader.GetString(reader.GetOrdinal("cliente_preftelint")),
            Telefono = reader.IsDBNull(reader.GetOrdinal("cliente_telefono")) ? null : reader.GetString(reader.GetOrdinal("cliente_telefono")),
            Email = reader.IsDBNull(reader.GetOrdinal("cliente_email")) ? null : reader.GetString(reader.GetOrdinal("cliente_email")),
            CodiceFiscale = reader.IsDBNull(reader.GetOrdinal("cliente_codicefiscale")) ? null : reader.GetString(reader.GetOrdinal("cliente_codicefiscale")),
            Iban = reader.IsDBNull(reader.GetOrdinal("cliente_iban")) ? null : reader.GetString(reader.GetOrdinal("cliente_iban")),
            Foto = reader.IsDBNull(reader.GetOrdinal("cliente_foto")) ? null : (byte[])reader["cliente_foto"],
            CartaIdentita = reader.IsDBNull(reader.GetOrdinal("cliente_carta_identita")) ? null : (byte[])reader["cliente_carta_identita"],
            TipoDocIdentita = reader.IsDBNull(reader.GetOrdinal("cliente_tipodoc_identita")) ? null : reader.GetString(reader.GetOrdinal("cliente_tipodoc_identita")),
            DocumentoNumero = reader.IsDBNull(reader.GetOrdinal("cliente_documento_numero")) ? null : reader.GetString(reader.GetOrdinal("cliente_documento_numero")),
            DocumentoRilasciatoDa = reader.IsDBNull(reader.GetOrdinal("cliente_documento_rilasciato_da")) ? null : reader.GetString(reader.GetOrdinal("cliente_documento_rilasciato_da")),
            DocumentoRilasciatoData = reader.IsDBNull(reader.GetOrdinal("cliente_documento_rilasciato_data")) ? null : reader.GetDateTime(reader.GetOrdinal("cliente_documento_rilasciato_data")),
            DocumentoRilasciatoScadenza = reader.IsDBNull(reader.GetOrdinal("cliente_documento_rilasciato_scadenza")) ? null : reader.GetDateTime(reader.GetOrdinal("cliente_documento_rilasciato_scadenza")),
            Note = reader.IsDBNull(reader.GetOrdinal("cliente_note")) ? null : reader.GetString(reader.GetOrdinal("cliente_note")),
            FotoMimeType = reader.IsDBNull(reader.GetOrdinal("cliente_foto_mimetype")) ? null : reader.GetString(reader.GetOrdinal("cliente_foto_mimetype")),
            FotoFilename = reader.IsDBNull(reader.GetOrdinal("cliente_foto_filename")) ? null : reader.GetString(reader.GetOrdinal("cliente_foto_filename")),
            FotoCharset = reader.IsDBNull(reader.GetOrdinal("cliente_foto_charset")) ? null : reader.GetString(reader.GetOrdinal("cliente_foto_charset")),
            FotoUpdDate = reader.IsDBNull(reader.GetOrdinal("cliente_foto_upd_date")) ? null : reader.GetDateTime(reader.GetOrdinal("cliente_foto_upd_date")),
            DocumentoMimeType = reader.IsDBNull(reader.GetOrdinal("cliente_documento_mimetype")) ? null : reader.GetString(reader.GetOrdinal("cliente_documento_mimetype")),
            DocumentoFilename = reader.IsDBNull(reader.GetOrdinal("cliente_documento_filename")) ? null : reader.GetString(reader.GetOrdinal("cliente_documento_filename")),
            DocumentoCharset = reader.IsDBNull(reader.GetOrdinal("cliente_documento_chartset")) ? null : reader.GetString(reader.GetOrdinal("cliente_documento_chartset")),
            DocumentoUpdDate = reader.IsDBNull(reader.GetOrdinal("cliente_documento_upd_date")) ? null : reader.GetDateTime(reader.GetOrdinal("cliente_documento_upd_date")),
            Intolleranza = reader.IsDBNull(reader.GetOrdinal("cliente_intolleranza")) ? null : reader.GetString(reader.GetOrdinal("cliente_intolleranza")),
            AziendaFk = reader.GetInt32(reader.GetOrdinal("azienda_fk")),
            CreatedBy = reader.IsDBNull(reader.GetOrdinal("created_by")) ? null : reader.GetString(reader.GetOrdinal("created_by")),
            Created = reader.IsDBNull(reader.GetOrdinal("created")) ? null : reader.GetDateTime(reader.GetOrdinal("created")),
            UpdatedBy = reader.IsDBNull(reader.GetOrdinal("updated_by")) ? null : reader.GetString(reader.GetOrdinal("updated_by")),
            Updated = reader.IsDBNull(reader.GetOrdinal("updated")) ? null : reader.GetDateTime(reader.GetOrdinal("updated"))
        };
    }

    private static string? ReadNullableString(NpgsqlDataReader reader, string columnName)
    {
        int ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }

    private static void AddInsertUpdateParameters(NpgsqlCommand command, Cliente cliente)
    {
        command.Parameters.AddWithValue("titolo", (object?)cliente.Titolo ?? DBNull.Value);
        command.Parameters.AddWithValue("cognome", cliente.Cognome);
        command.Parameters.AddWithValue("nome", cliente.Nome);
        command.Parameters.AddWithValue("sesso", cliente.Sesso);
        command.Parameters.AddWithValue("comuneResidenzaFk", cliente.ComuneResidenzaFk);
        command.Parameters.AddWithValue("indirizzoResidenza", (object?)cliente.IndirizzoResidenza ?? DBNull.Value);
        command.Parameters.AddWithValue("comuneNascitaFk", cliente.ComuneNascitaFk);
        command.Parameters.AddWithValue("dataNascita", (object?)cliente.DataNascita ?? DBNull.Value);
        command.Parameters.AddWithValue("prefTelInt", (object?)cliente.PrefTelInt ?? DBNull.Value);
        command.Parameters.AddWithValue("telefono", (object?)cliente.Telefono ?? DBNull.Value);
        command.Parameters.AddWithValue("email", (object?)cliente.Email ?? DBNull.Value);
        command.Parameters.AddWithValue("codiceFiscale", (object?)cliente.CodiceFiscale ?? DBNull.Value);
        command.Parameters.AddWithValue("iban", (object?)cliente.Iban ?? DBNull.Value);
        command.Parameters.AddWithValue("foto", (object?)cliente.Foto ?? DBNull.Value);
        command.Parameters.AddWithValue("cartaIdentita", (object?)cliente.CartaIdentita ?? DBNull.Value);
        command.Parameters.AddWithValue("tipoDocIdentita", (object?)cliente.TipoDocIdentita ?? DBNull.Value);
        command.Parameters.AddWithValue("documentoNumero", (object?)cliente.DocumentoNumero ?? DBNull.Value);
        command.Parameters.AddWithValue("documentoRilasciatoDa", (object?)cliente.DocumentoRilasciatoDa ?? DBNull.Value);
        command.Parameters.AddWithValue("documentoRilasciatoData", (object?)cliente.DocumentoRilasciatoData ?? DBNull.Value);
        command.Parameters.AddWithValue("documentoRilasciatoScadenza", (object?)cliente.DocumentoRilasciatoScadenza ?? DBNull.Value);
        command.Parameters.AddWithValue("note", (object?)cliente.Note ?? DBNull.Value);
        command.Parameters.AddWithValue("fotoMimeType", (object?)cliente.FotoMimeType ?? DBNull.Value);
        command.Parameters.AddWithValue("fotoFilename", (object?)cliente.FotoFilename ?? DBNull.Value);
        command.Parameters.AddWithValue("fotoCharset", (object?)cliente.FotoCharset ?? DBNull.Value);
        command.Parameters.AddWithValue("fotoUpdDate", (object?)cliente.FotoUpdDate ?? DBNull.Value);
        command.Parameters.AddWithValue("documentoMimeType", (object?)cliente.DocumentoMimeType ?? DBNull.Value);
        command.Parameters.AddWithValue("documentoFilename", (object?)cliente.DocumentoFilename ?? DBNull.Value);
        command.Parameters.AddWithValue("documentoCharset", (object?)cliente.DocumentoCharset ?? DBNull.Value);
        command.Parameters.AddWithValue("documentoUpdDate", (object?)cliente.DocumentoUpdDate ?? DBNull.Value);
        command.Parameters.AddWithValue("intolleranza", (object?)cliente.Intolleranza ?? DBNull.Value);
        command.Parameters.AddWithValue("aziendaFk", cliente.AziendaFk);
    }

    /// <summary>
    /// DB-First: Build DynamicParameters for stored procedure calls
    /// </summary>
    private static DynamicParameters BuildClienteParameters(Cliente cliente)
    {
        var parameters = new DynamicParameters();
        parameters.Add("p_cliente_titolo", cliente.Titolo);
        parameters.Add("p_cliente_cognome", cliente.Cognome);
        parameters.Add("p_cliente_nome", cliente.Nome);
        parameters.Add("p_cliente_sesso", cliente.Sesso);
        parameters.Add("p_cliente_comune_residenza_fk", cliente.ComuneResidenzaFk);
        parameters.Add("p_cliente_indirizzo_residenza", cliente.IndirizzoResidenza);
        parameters.Add("p_cliente_comune_nascita_fk", cliente.ComuneNascitaFk);
        parameters.Add("p_cliente_data_nascita", cliente.DataNascita);
        parameters.Add("p_cliente_preftelint", cliente.PrefTelInt);
        parameters.Add("p_cliente_telefono", cliente.Telefono);
        parameters.Add("p_cliente_email", cliente.Email);
        parameters.Add("p_cliente_codicefiscale", cliente.CodiceFiscale);
        parameters.Add("p_cliente_iban", cliente.Iban);
        parameters.Add("p_cliente_foto", cliente.Foto);
        parameters.Add("p_cliente_carta_identita", cliente.CartaIdentita);
        parameters.Add("p_cliente_tipodoc_identita", cliente.TipoDocIdentita);
        parameters.Add("p_cliente_documento_numero", cliente.DocumentoNumero);
        parameters.Add("p_cliente_documento_rilasciato_da", cliente.DocumentoRilasciatoDa);
        parameters.Add("p_cliente_documento_rilasciato_data", cliente.DocumentoRilasciatoData);
        parameters.Add("p_cliente_documento_rilasciato_scadenza", cliente.DocumentoRilasciatoScadenza);
        parameters.Add("p_cliente_note", cliente.Note);
        parameters.Add("p_cliente_foto_mimetype", cliente.FotoMimeType);
        parameters.Add("p_cliente_foto_filename", cliente.FotoFilename);
        parameters.Add("p_cliente_foto_charset", cliente.FotoCharset);
        parameters.Add("p_cliente_foto_upd_date", cliente.FotoUpdDate);
        parameters.Add("p_cliente_documento_mimetype", cliente.DocumentoMimeType);
        parameters.Add("p_cliente_documento_filename", cliente.DocumentoFilename);
        parameters.Add("p_cliente_documento_chartset", cliente.DocumentoCharset);
        parameters.Add("p_cliente_documento_upd_date", cliente.DocumentoUpdDate);
        parameters.Add("p_cliente_intolleranza", cliente.Intolleranza);
        parameters.Add("p_azienda_fk", cliente.AziendaFk);
        return parameters;
    }

    #endregion
}
