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

    public async Task<Cliente?> GetByIdAsync(int clienteId, int aziendaFk)
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
                    updated,
                    a.ragione_sociale as azienda_ragione_sociale,
                    com_nas.comune_descrizione as com_nas_nome,
                    prov_nas.provincia_sigla as com_nas_provincia,
                    com_res.comune_descrizione as com_res_nome,
                    prov_res.provincia_sigla as com_res_provincia
                FROM ana_clienti c
                LEFT JOIN ana_aziende a ON c.azienda_fk = a.azienda_id
                LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
                LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
                LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
                LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
                WHERE c.cliente_id = @clienteId
                  AND c.azienda_fk = @aziendaFk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("clienteId", clienteId);
            command.Parameters.AddWithValue("aziendaFk", aziendaFk);

            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                var cliente = MapFromReader(reader);
                cliente.AziendaRagioneSociale = ReadNullableString(reader, "azienda_ragione_sociale");

                if (!reader.IsDBNull(reader.GetOrdinal("com_nas_nome")))
                {
                    cliente.ComuneNascita = new Comune
                    {
                        Id = cliente.ComuneNascitaFk,
                        Nome = reader.GetString(reader.GetOrdinal("com_nas_nome")),
                        ProvinciaDescrizione = reader.GetString(reader.GetOrdinal("com_nas_provincia"))
                    };
                }

                if (!reader.IsDBNull(reader.GetOrdinal("com_res_nome")))
                {
                    cliente.ComuneResidenza = new Comune
                    {
                        Id = cliente.ComuneResidenzaFk,
                        Nome = reader.GetString(reader.GetOrdinal("com_res_nome")),
                        ProvinciaDescrizione = reader.GetString(reader.GetOrdinal("com_res_provincia"))
                    };
                }

                return cliente;
            }

            return null;
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
                    updated,
                    a.ragione_sociale as azienda_ragione_sociale,
                    com_nas.comune_descrizione as com_nas_nome,
                    prov_nas.provincia_sigla as com_nas_provincia,
                    com_res.comune_descrizione as com_res_nome,
                    prov_res.provincia_sigla as com_res_provincia,
                    get_count_travel_made(c.cliente_id, c.azienda_fk) as viaggi_fatti,
                    get_count_travel_future(c.cliente_id, c.azienda_fk) as viaggi_da_fare
                FROM ana_clienti c
                LEFT JOIN ana_aziende a ON c.azienda_fk = a.azienda_id
                LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
                LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
                LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
                LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
                WHERE (@aziendaFk::integer IS NULL OR c.azienda_fk = @aziendaFk)
                  AND (@filterYear::integer IS NULL OR EXTRACT(YEAR FROM c.created) = @filterYear)
                ORDER BY a.ragione_sociale, c.cliente_cognome, c.cliente_nome";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaFk", (object?)aziendaFk ?? DBNull.Value);
            command.Parameters.AddWithValue("filterYear", (object?)filterYear ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();

            var clienti = new List<Cliente>();
            while (await reader.ReadAsync())
            {
                var cliente = MapFromReader(reader);
                cliente.AziendaRagioneSociale = ReadNullableString(reader, "azienda_ragione_sociale");
                cliente.ViaggiFatti = reader.IsDBNull(reader.GetOrdinal("viaggi_fatti")) ? 0 : reader.GetInt32(reader.GetOrdinal("viaggi_fatti"));
                cliente.ViaggiDaFare = reader.IsDBNull(reader.GetOrdinal("viaggi_da_fare")) ? 0 : reader.GetInt32(reader.GetOrdinal("viaggi_da_fare"));

                // Map nested objects manually since MapFromReader handles base entity
                if (!reader.IsDBNull(reader.GetOrdinal("com_nas_nome")))
                {
                    cliente.ComuneNascita = new Comune
                    {
                        Id = cliente.ComuneNascitaFk,
                        Nome = reader.GetString(reader.GetOrdinal("com_nas_nome")),
                        ProvinciaDescrizione = reader.GetString(reader.GetOrdinal("com_nas_provincia"))
                    };
                }

                if (!reader.IsDBNull(reader.GetOrdinal("com_res_nome")))
                {
                    cliente.ComuneResidenza = new Comune
                    {
                        Id = cliente.ComuneResidenzaFk,
                        Nome = reader.GetString(reader.GetOrdinal("com_res_nome")),
                        ProvinciaDescrizione = reader.GetString(reader.GetOrdinal("com_res_provincia"))
                    };
                }

                clienti.Add(cliente);
            }

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
            await using var connection = await _databaseService.GetConnectionAsync();


            var sql = @"
                INSERT INTO ana_clienti (
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
                    azienda_fk
                )
                VALUES (
                    @titolo,
                    @cognome,
                    @nome,
                    @sesso,
                    @comuneResidenzaFk,
                    @indirizzoResidenza,
                    @comuneNascitaFk,
                    @dataNascita,
                    @prefTelInt,
                    @telefono,
                    @email,
                    @codiceFiscale,
                    @iban,
                    @foto,
                    @cartaIdentita,
                    @tipoDocIdentita,
                    @documentoNumero,
                    @documentoRilasciatoDa,
                    @documentoRilasciatoData,
                    @documentoRilasciatoScadenza,
                    @note,
                    @fotoMimeType,
                    @fotoFilename,
                    @fotoCharset,
                    @fotoUpdDate,
                    @documentoMimeType,
                    @documentoFilename,
                    @documentoCharset,
                    @documentoUpdDate,
                    @intolleranza,
                    @aziendaFk
                )
                RETURNING
                    cliente_id,
                    created_by,
                    created,
                    updated_by,
                    updated";

            await using var command = new NpgsqlCommand(sql, connection);
            AddInsertUpdateParameters(command, cliente);

            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                cliente.ClienteId = reader.GetInt32(0);
                cliente.CreatedBy = reader.IsDBNull(1) ? null : reader.GetString(1);
                cliente.Created = reader.IsDBNull(2) ? null : reader.GetDateTime(2);
                cliente.UpdatedBy = reader.IsDBNull(3) ? null : reader.GetString(3);
                cliente.Updated = reader.IsDBNull(4) ? null : reader.GetDateTime(4);
            }

            _logger.LogInformation("Cliente {ClienteId} creato con successo per azienda {AziendaFk}", cliente.ClienteId, cliente.AziendaFk);

            // Ritorniamo l'oggetto completo (con join) per aggiornare correttamente la griglia
            return await GetByIdAsync(cliente.ClienteId, cliente.AziendaFk) ?? cliente;
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
            await using var connection = await _databaseService.GetConnectionAsync();


            var sql = @"
                UPDATE ana_clienti
                SET
                    cliente_titolo = @titolo,
                    cliente_cognome = @cognome,
                    cliente_nome = @nome,
                    cliente_sesso = @sesso,
                    cliente_comune_residenza_fk = @comuneResidenzaFk,
                    cliente_indirizzo_residenza = @indirizzoResidenza,
                    cliente_comune_nascita_fk = @comuneNascitaFk,
                    cliente_data_nascita = @dataNascita,
                    cliente_preftelint = @prefTelInt,
                    cliente_telefono = @telefono,
                    cliente_email = @email,
                    cliente_codicefiscale = @codiceFiscale,
                    cliente_iban = @iban,
                    cliente_foto = @foto,
                    cliente_carta_identita = @cartaIdentita,
                    cliente_tipodoc_identita = @tipoDocIdentita,
                    cliente_documento_numero = @documentoNumero,
                    cliente_documento_rilasciato_da = @documentoRilasciatoDa,
                    cliente_documento_rilasciato_data = @documentoRilasciatoData,
                    cliente_documento_rilasciato_scadenza = @documentoRilasciatoScadenza,
                    cliente_note = @note,
                    cliente_foto_mimetype = @fotoMimeType,
                    cliente_foto_filename = @fotoFilename,
                    cliente_foto_charset = @fotoCharset,
                    cliente_foto_upd_date = @fotoUpdDate,
                    cliente_documento_mimetype = @documentoMimeType,
                    cliente_documento_filename = @documentoFilename,
                    cliente_documento_chartset = @documentoCharset,
                    cliente_documento_upd_date = @documentoUpdDate,
                    cliente_intolleranza = @intolleranza
                WHERE cliente_id = @clienteId
                  AND azienda_fk = @aziendaFk
                RETURNING
                    updated_by,
                    updated";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("clienteId", cliente.ClienteId);
            AddInsertUpdateParameters(command, cliente);

            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                cliente.UpdatedBy = reader.IsDBNull(0) ? null : reader.GetString(0);
                cliente.Updated = reader.IsDBNull(1) ? null : reader.GetDateTime(1);
            }

            _logger.LogInformation("Cliente {ClienteId} aggiornato con successo", cliente.ClienteId);

            // Ritorniamo l'oggetto completo (con join) per aggiornare correttamente la griglia
            return await GetByIdAsync(cliente.ClienteId, cliente.AziendaFk) ?? cliente;
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
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                DELETE FROM ana_clienti
                WHERE cliente_id = @clienteId
                  AND azienda_fk = @aziendaFk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("clienteId", clienteId);
            command.Parameters.AddWithValue("aziendaFk", aziendaFk);

            var rowsAffected = await command.ExecuteNonQueryAsync();

            if (rowsAffected > 0)
            {
                _logger.LogInformation("Cliente {ClienteId} eliminato con successo", clienteId);
                return true;
            }

            return false;
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
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT EXISTS(
                    SELECT 1
                    FROM ana_clienti
                    WHERE LOWER(cliente_email) = LOWER(@email)
                      AND azienda_fk = @aziendaFk
                      AND (@excludeClienteId IS NULL OR cliente_id != @excludeClienteId)
                )";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("email", email);
            command.Parameters.Add(new NpgsqlParameter("aziendaFk", NpgsqlTypes.NpgsqlDbType.Integer)
            {
                Value = (object?)aziendaFk ?? DBNull.Value
            });
            command.Parameters.Add(new NpgsqlParameter("excludeClienteId", NpgsqlTypes.NpgsqlDbType.Integer)
            {
                Value = (object?)excludeClienteId ?? DBNull.Value
            });

            var result = await command.ExecuteScalarAsync();
            return result != null && (bool)result;
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
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT EXISTS(
                    SELECT 1
                    FROM ana_clienti
                    WHERE UPPER(cliente_codicefiscale) = UPPER(@codiceFiscale)
                      AND azienda_fk = @aziendaFk
                      AND (@excludeClienteId IS NULL OR cliente_id != @excludeClienteId)
                )";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("codiceFiscale", codiceFiscale);
            command.Parameters.Add(new NpgsqlParameter("aziendaFk", NpgsqlTypes.NpgsqlDbType.Integer)
            {
                Value = (object?)aziendaFk ?? DBNull.Value
            });
            command.Parameters.Add(new NpgsqlParameter("excludeClienteId", NpgsqlTypes.NpgsqlDbType.Integer)
            {
                Value = (object?)excludeClienteId ?? DBNull.Value
            });

            var result = await command.ExecuteScalarAsync();
            return result != null && (bool)result;
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
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT EXISTS(
                    SELECT 1
                    FROM ana_clienti
                    WHERE UPPER(cliente_cognome) = UPPER(@cognome)
                      AND UPPER(cliente_nome) = UPPER(@nome)
                      AND cliente_data_nascita = @dataNascita
                      AND UPPER(cliente_codicefiscale) = UPPER(@codiceFiscale)
                      AND azienda_fk = @aziendaFk
                      AND (@excludeClienteId IS NULL OR cliente_id != @excludeClienteId)
                )";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("cognome", cognome);
            command.Parameters.AddWithValue("nome", nome);
            command.Parameters.AddWithValue("dataNascita", dataNascita);
            command.Parameters.AddWithValue("codiceFiscale", codiceFiscale);
            command.Parameters.Add(new NpgsqlParameter("aziendaFk", NpgsqlTypes.NpgsqlDbType.Integer)
            {
                Value = (object?)aziendaFk ?? DBNull.Value
            });
            command.Parameters.Add(new NpgsqlParameter("excludeClienteId", NpgsqlTypes.NpgsqlDbType.Integer)
            {
                Value = (object?)excludeClienteId ?? DBNull.Value
            });

            var result = await command.ExecuteScalarAsync();
            return result != null && (bool)result;
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
                    updated,
                    a.ragione_sociale as azienda_ragione_sociale,
                    com_nas.comune_descrizione as com_nas_nome,
                    prov_nas.provincia_sigla as com_nas_provincia,
                    com_res.comune_descrizione as com_res_nome,
                    prov_res.provincia_sigla as com_res_provincia
                FROM ana_clienti c
                LEFT JOIN ana_aziende a ON c.azienda_fk = a.azienda_id
                LEFT JOIN ana_geo_comuni com_nas ON c.cliente_comune_nascita_fk = com_nas.comune_id
                LEFT JOIN ana_geo_province prov_nas ON com_nas.comune_provincia_fk = prov_nas.provincia_id
                LEFT JOIN ana_geo_comuni com_res ON c.cliente_comune_residenza_fk = com_res.comune_id
                LEFT JOIN ana_geo_province prov_res ON com_res.comune_provincia_fk = prov_res.provincia_id
                WHERE c.azienda_fk = @aziendaFk
                  AND (
                      LOWER(c.cliente_cognome) LIKE LOWER(@searchPattern) OR
                      LOWER(c.cliente_nome) LIKE LOWER(@searchPattern) OR
                      LOWER(c.cliente_email) LIKE LOWER(@searchPattern) OR
                      LOWER(c.cliente_codicefiscale) LIKE LOWER(@searchPattern)
                  )
                ORDER BY c.cliente_cognome, c.cliente_nome
                LIMIT 100";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaFk", aziendaFk);
            command.Parameters.AddWithValue("searchPattern", $"%{searchTerm}%");

            await using var reader = await command.ExecuteReaderAsync();

            var clienti = new List<Cliente>();
            while (await reader.ReadAsync())
            {
                var cliente = MapFromReader(reader);
                cliente.AziendaRagioneSociale = ReadNullableString(reader, "azienda_ragione_sociale");

                // Map nested objects manually
                if (!reader.IsDBNull(reader.GetOrdinal("com_nas_nome")))
                {
                    cliente.ComuneNascita = new Comune
                    {
                        Id = cliente.ComuneNascitaFk,
                        Nome = reader.GetString(reader.GetOrdinal("com_nas_nome")),
                        ProvinciaDescrizione = reader.GetString(reader.GetOrdinal("com_nas_provincia"))
                    };
                }

                if (!reader.IsDBNull(reader.GetOrdinal("com_res_nome")))
                {
                    cliente.ComuneResidenza = new Comune
                    {
                        Id = cliente.ComuneResidenzaFk,
                        Nome = reader.GetString(reader.GetOrdinal("com_res_nome")),
                        ProvinciaDescrizione = reader.GetString(reader.GetOrdinal("com_res_provincia"))
                    };
                }

                clienti.Add(cliente);
            }

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



    #endregion
}
