using GestioneViaggi.Models;
using GestioneViaggi.Repositories.Interfaces;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

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

    /// <summary>
    /// Un cliente per id. Chiama <c>fn_get_cliente_by_id</c>, che restituisce JSON con
    /// le chiavi gia' nella forma del model — comuni annidati compresi.
    /// </summary>
    public async Task<Cliente?> GetByIdAsync(int clienteId, int aziendaFk)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand("SELECT fn_get_cliente_by_id(@id, @azienda)", connection);
            command.Parameters.AddWithValue("id", clienteId);
            command.Parameters.AddWithValue("azienda", aziendaFk);

            var json = await command.ExecuteScalarAsync() as string;
            return DaJson<Cliente>(json);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero del cliente {ClienteId}", clienteId);
            throw;
        }
    }

    public async Task<Cliente?> GetDetailAsync(int clienteId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand("SELECT fn_get_cliente_detail(@id)", connection);
            command.Parameters.AddWithValue("id", clienteId);

            return DaJson<Cliente>(await command.ExecuteScalarAsync() as string);
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
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand("SELECT fn_get_all_clienti(@azienda, @anno)", connection);
            command.Parameters.Add(new NpgsqlParameter("azienda", NpgsqlTypes.NpgsqlDbType.Integer) { Value = (object?)aziendaFk ?? DBNull.Value });
            command.Parameters.Add(new NpgsqlParameter("anno", NpgsqlTypes.NpgsqlDbType.Integer) { Value = (object?)filterYear ?? DBNull.Value });

            var json = await command.ExecuteScalarAsync() as string;
            return DaJson<List<Cliente>>(json) ?? new List<Cliente>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei clienti");
            throw;
        }
    }

    /// <summary>
    /// Crea un cliente chiamando <c>fn_ana_clienti_insert</c>. Le regole — duplicati,
    /// omonimi, codice fiscale, date — vivono dentro quella funzione: qui non se ne
    /// riscrive nessuna, perché il sito di iscrizione chiama la stessa e deve
    /// comportarsi allo stesso modo.
    /// </summary>
    /// <summary>
    /// I riscontri di duplicato su un'anagrafica, dal database. E' l'unico posto da
    /// cui passano: codice fiscale, anagrafica completa, omonimia ed email.
    /// </summary>
    public async Task<List<EsitoValidazione>> VerificaDuplicatoAsync(
        int aziendaFk, string? cognome, string? nome, DateTime? dataNascita,
        int? comuneNascitaFk, string? codiceFiscale, int? escludiClienteId, string? email)
    {
        await using var connection = await _databaseService.GetConnectionAsync();
        await using var command = new NpgsqlCommand(
            "SELECT gravita, esito, messaggio, cliente_id FROM fn_ana_clienti_verifica_duplicato(" +
            "@azienda, @cognome, @nome, @nascita, @comune, @cf, @escludi, @email)", connection);
        command.Parameters.AddWithValue("azienda", aziendaFk);
        command.Parameters.AddWithValue("cognome", (object?)cognome ?? DBNull.Value);
        command.Parameters.AddWithValue("nome", (object?)nome ?? DBNull.Value);
        command.Parameters.Add(new NpgsqlParameter("nascita", NpgsqlTypes.NpgsqlDbType.Date) { Value = (object?)dataNascita ?? DBNull.Value });
        command.Parameters.Add(new NpgsqlParameter("comune", NpgsqlTypes.NpgsqlDbType.Integer) { Value = (object?)comuneNascitaFk ?? DBNull.Value });
        command.Parameters.AddWithValue("cf", (object?)codiceFiscale ?? DBNull.Value);
        command.Parameters.Add(new NpgsqlParameter("escludi", NpgsqlTypes.NpgsqlDbType.Integer) { Value = (object?)escludiClienteId ?? DBNull.Value });
        command.Parameters.AddWithValue("email", (object?)email ?? DBNull.Value);

        var esiti = new List<EsitoValidazione>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            esiti.Add(new EsitoValidazione
            {
                Gravita = reader.GetString(0),
                Esito = reader.GetString(1),
                Messaggio = reader.GetString(2),
                Riferimento = reader.IsDBNull(3) ? null : reader.GetInt32(3)
            });
        }
        return esiti;
    }

    /// <summary>
    /// Chiede al database cosa non va, senza scrivere. Serve alla form per sapere
    /// PRIMA di salvare, e poter chiedere conferma dove serve.
    /// </summary>
    public async Task<List<EsitoValidazione>> ValidaAsync(Cliente cliente, int? clienteId = null)
    {
        await using var connection = await _databaseService.GetConnectionAsync();
        await using var command = new NpgsqlCommand(
            "SELECT gravita, esito, messaggio FROM fn_ana_clienti_valida(@dati::jsonb, @id)", connection);
        command.Parameters.AddWithValue("dati", ClienteJson.Serializza(cliente));
        command.Parameters.Add(new NpgsqlParameter("id", NpgsqlTypes.NpgsqlDbType.Integer)
        {
            Value = (object?)clienteId ?? DBNull.Value
        });

        var esiti = new List<EsitoValidazione>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            esiti.Add(new EsitoValidazione
            {
                Gravita = reader.GetString(0),
                Esito = reader.GetString(1),
                Messaggio = reader.GetString(2)
            });
        }
        return esiti;
    }

    public async Task<Cliente> InsertAsync(Cliente cliente, bool conferme = false)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand(
                "SELECT fn_ana_clienti_insert(@dati::jsonb, @conferme)", connection);
            command.Parameters.AddWithValue("dati", ClienteJson.Serializza(cliente));
            command.Parameters.AddWithValue("conferme", conferme);

            cliente.ClienteId = Convert.ToInt32(await command.ExecuteScalarAsync());
            _logger.LogInformation("Cliente {ClienteId} creato per azienda {AziendaFk}", cliente.ClienteId, cliente.AziendaFk);

            // Si rilegge per avere i campi calcolati dal database: sesso derivato dal
            // titolo, audit, e le descrizioni dei comuni che servono alla griglia.
            return await GetByIdAsync(cliente.ClienteId, cliente.AziendaFk) ?? cliente;
        }
        catch (PostgresException ex) when (ex.SqlState == "P0001")
        {
            // Messaggio gia' in italiano: lo compone la funzione di validazione.
            throw new InvalidOperationException(ex.MessageText, ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'inserimento del cliente");
            throw;
        }
    }

    /// <summary>
    /// Aggiorna un cliente con <c>fn_ana_clienti_update</c>. L'aggiornamento è
    /// parziale per costruzione, ma qui si manda l'entità intera: la form la
    /// possiede tutta, e mandare tutto evita di dover sapere cosa è cambiato.
    /// </summary>
    public async Task<Cliente> UpdateAsync(Cliente cliente, bool conferme = false)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand(
                "SELECT fn_ana_clienti_update(@id, @dati::jsonb, @conferme)", connection);
            command.Parameters.AddWithValue("id", cliente.ClienteId);
            command.Parameters.AddWithValue("dati", ClienteJson.Serializza(cliente, includiAzienda: false));
            command.Parameters.AddWithValue("conferme", conferme);

            var righe = Convert.ToInt32(await command.ExecuteScalarAsync());
            if (righe == 0)
                throw new InvalidOperationException($"Cliente {cliente.ClienteId} non trovato.");

            _logger.LogInformation("Cliente {ClienteId} aggiornato", cliente.ClienteId);
            return await GetByIdAsync(cliente.ClienteId, cliente.AziendaFk) ?? cliente;
        }
        catch (PostgresException ex) when (ex.SqlState == "P0001")
        {
            throw new InvalidOperationException(ex.MessageText, ex);
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
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand(
                "SELECT fn_ana_clienti_delete(@id, @azienda)", connection);
            command.Parameters.AddWithValue("id", clienteId);
            command.Parameters.AddWithValue("azienda", aziendaFk);

            var righe = Convert.ToInt32(await command.ExecuteScalarAsync());
            _logger.LogInformation("Cliente {ClienteId} eliminato ({Righe} righe)", clienteId, righe);
            return righe > 0;
        }
        catch (PostgresException ex) when (ex.SqlState == "P0001")
        {
            throw new InvalidOperationException(ex.MessageText, ex);
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
            await using var command = new NpgsqlCommand("SELECT fn_get_cliente_by_email(@email, @azienda)", connection);
            command.Parameters.AddWithValue("email", email ?? string.Empty);
            command.Parameters.AddWithValue("azienda", aziendaFk);

            return DaJson<Cliente>(await command.ExecuteScalarAsync() as string);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero del cliente per email");
            throw;
        }
    }

    public async Task<Cliente?> GetByCodiceFiscaleAsync(string codiceFiscale, int aziendaFk)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand("SELECT fn_get_cliente_by_codice_fiscale(@cf, @azienda)", connection);
            command.Parameters.AddWithValue("cf", codiceFiscale ?? string.Empty);
            command.Parameters.AddWithValue("azienda", aziendaFk);

            return DaJson<Cliente>(await command.ExecuteScalarAsync() as string);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero del cliente per codice fiscale");
            throw;
        }
    }

    #endregion

    #region Validazioni di Esistenza

    /// <summary>
    /// Esiste gia' un cliente con questa email nella stessa azienda? Si appoggia
    /// alla verifica canonica: la regola non si riscrive qui.
    /// ⚠️ L'email ripetuta e' un AVVISO, non un divieto — condividere la casella e'
    /// prassi legittima. Chi chiama non deve trattarla come un blocco.
    /// </summary>
    public async Task<bool> ExistsByEmailAsync(string email, int? aziendaFk, int? excludeClienteId = null)
    {
        var esiti = await VerificaDuplicatoAsync(aziendaFk ?? 0, null, null, null, null, null, excludeClienteId, email);
        return esiti.Any(e => e.Esito == "STESSA_EMAIL");
    }

    public async Task<bool> ExistsByCodiceFiscaleAsync(string codiceFiscale, int? aziendaFk, int? excludeClienteId = null)
    {
        var esiti = await VerificaDuplicatoAsync(aziendaFk ?? 0, null, null, null, null, codiceFiscale, excludeClienteId, null);
        return esiti.Any(e => e.Esito == "STESSO_CF");
    }

    #endregion

    #region Verifica Relazioni

    public async Task<bool> HasRelatedBookingsAsync(int clienteId, int aziendaFk)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand("SELECT fn_cliente_ha_iscrizioni(@id, @azienda)", connection);
            command.Parameters.AddWithValue("id", clienteId);
            command.Parameters.AddWithValue("azienda", aziendaFk);

            return await command.ExecuteScalarAsync() is true;
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
            await using var command = new NpgsqlCommand("SELECT fn_cliente_ha_alloggi(@id, @azienda)", connection);
            command.Parameters.AddWithValue("id", clienteId);
            command.Parameters.AddWithValue("azienda", aziendaFk);

            return await command.ExecuteScalarAsync() is true;
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
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand("SELECT fn_search_clienti(@azienda, @testo)", connection);
            command.Parameters.AddWithValue("azienda", aziendaFk);
            command.Parameters.AddWithValue("testo", searchTerm ?? string.Empty);

            var json = await command.ExecuteScalarAsync() as string;
            return DaJson<List<Cliente>>(json) ?? new List<Cliente>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la ricerca clienti");
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
            await using var command = new NpgsqlCommand("SELECT fn_count_clienti_by_azienda(@azienda)", connection);
            command.Parameters.AddWithValue("azienda", aziendaFk);
            return Convert.ToInt32(await command.ExecuteScalarAsync());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il conteggio dei clienti");
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

    /// <summary>
    /// Le funzioni di lettura restituiscono JSON con le chiavi gia' nella forma del
    /// model: non serve nessuna mappatura a mano, e aggiungere una colonna domani non
    /// obbliga a toccare questo file.
    /// </summary>
    private static T? DaJson<T>(string? json)
    {
        if (string.IsNullOrWhiteSpace(json) || json == "null") return default;
        return System.Text.Json.JsonSerializer.Deserialize<T>(json);
    }

    private static string? ReadNullableString(NpgsqlDataReader reader, string columnName)
    {
        int ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }



    #endregion
}
