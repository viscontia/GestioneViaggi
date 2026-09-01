using GestioneViaggi.Models;
using GestioneViaggi.Repositories;
using GestioneViaggi.Repositories.Interfaces;
using GestioneViaggi.Validation.Business;
using GestioneViaggi.Validation.Fiscal;
using GestioneViaggi.Validation.Syntax;
using GestioneViaggi.Validation.Exceptions;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Service per gestione clienti con validazioni business complete
/// Orchestrazione tra Repository e Validators
/// </summary>
public class ClienteService(IClienteRepository repository, IDatabaseService databaseService, ILogger<ClienteService> logger) : IClienteService
{
    private readonly IClienteRepository _repository = repository;
    private readonly IDatabaseService _databaseService = databaseService;
    private readonly ILogger<ClienteService> _logger = logger;

    #region CRUD Operations

    public async Task<List<Cliente>> GetAllAsync(int? aziendaFk, int? filterYear = null, string? searchText = null)
    {
        try
        {
            return await _repository.GetAllAsync(aziendaFk, filterYear, searchText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero di tutti i clienti per azienda {AziendaFk}", aziendaFk);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "ana_clienti");
        }
    }

    public async Task<Cliente?> GetByIdAsync(int clienteId, int aziendaFk)
    {
        try
        {
            return await _repository.GetByIdAsync(clienteId, aziendaFk);
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
            return await _repository.GetDetailAsync(clienteId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero del dettaglio cliente {ClienteId}", clienteId);
            throw;
        }
    }

    /// <summary>Le segnalazioni del database su questa anagrafica, senza scrivere.</summary>
    public Task<string?> AvvisoNomeSessoAsync(string? nome, char sesso)
        => _repository.AvvisoNomeSessoAsync(nome, sesso);

    public Task<List<EsitoValidazione>> ValidaAsync(Cliente cliente, int? clienteId = null)
        => _repository.ValidaAsync(cliente, clienteId);

    public async Task<Cliente> CreateAsync(Cliente cliente, bool conferme = false)
    {
        try
        {
            // Le validazioni NON stanno piu' qui: le fa fn_ana_clienti_insert, cosi'
            // valgono anche per il sito di iscrizione, che questo C# non lo vede.
            // Resta la normalizzazione, che e' presentazione e non regola.
            NormalizeCliente(cliente);

            return await _repository.InsertAsync(cliente, conferme);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del cliente");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "ana_clienti");
        }
    }

    public async Task<Cliente> UpdateAsync(Cliente cliente, bool conferme = false)
    {
        try
        {
            NormalizeCliente(cliente);

            return await _repository.UpdateAsync(cliente, conferme);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del cliente {ClienteId}", cliente.ClienteId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "ana_clienti");
        }
    }

    public async Task<bool> DeleteAsync(int clienteId, int aziendaFk)
    {
        try
        {
            // Verifica relazioni
            var hasBookings = await _repository.HasRelatedBookingsAsync(clienteId, aziendaFk);
            var hasAccommodations = await _repository.HasRelatedAccommodationsAsync(clienteId, aziendaFk);

            if (hasBookings || hasAccommodations)
            {
                var relations = new List<string>();
                if (hasBookings) relations.Add("viaggi");
                if (hasAccommodations) relations.Add("alloggi");

                throw new ClienteHasRelationsException(
                    $"Impossibile eliminare il cliente: ha relazioni con {string.Join(" e ", relations)}",
                    clienteId,
                    string.Join(", ", relations),
                    relations.Count
                );
            }

            return await _repository.DeleteAsync(clienteId, aziendaFk);
        }
        catch (Exception ex) when (ex is not ClienteHasRelationsException)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione del cliente {ClienteId}", clienteId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "ana_clienti");
        }
    }

    #endregion

    #region Validation Operations

    public async Task<bool> VerificaClienteEsistenteAsync(string email, int? aziendaFk, int? excludeId = null)
    {
        try
        {
            return await _repository.ExistsByEmailAsync(email, aziendaFk, excludeId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la verifica esistenza email {Email}", email);
            throw;
        }
    }

    public async Task<bool> CheckCodiceFiscaleEsistenzaAsync(string codiceFiscale, int? aziendaFk, int? excludeClienteId = null)
    {
        try
        {
            return await _repository.ExistsByCodiceFiscaleAsync(codiceFiscale, aziendaFk, excludeClienteId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la verifica esistenza codice fiscale {CodiceFiscale}", codiceFiscale);
            throw;
        }
    }

    #endregion

    #region Search Operations

    public async Task<List<Cliente>> SearchAsync(string searchTerm, int aziendaFk)
    {
        try
        {
            return await _repository.SearchAsync(searchTerm, aziendaFk);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la ricerca clienti con termine {SearchTerm}", searchTerm);
            throw;
        }
    }

    public async Task<int> CountAsync(int aziendaFk)
    {
        try
        {
            return await _repository.CountAsync(aziendaFk);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il conteggio clienti per azienda {AziendaFk}", aziendaFk);
            throw;
        }
    }

    // Travel Stats
    public async Task<List<int>> GetTravelYearsAsync(int clienteId)
    {
        try
        {
            return await _repository.GetTravelYearsAsync(clienteId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero degli anni viaggi cliente {ClienteId}", clienteId);
            throw;
        }
    }

    public async Task<IEnumerable<ClienteTravelHistory>> GetTravelHistoryAsync(int clienteId, int aziendaFk)
    {
        try
        {
            return await _repository.GetTravelHistoryAsync(clienteId, aziendaFk);
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
            return await _repository.GetTravelPassengersAsync(dataViaggioId, excludeClienteId);
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
            return await _repository.GetAllParticipantsTravelAsync(dataViaggioId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei partecipanti per viaggio {DataViaggioId}", dataViaggioId);
            throw;
        }
    }

    public async Task<GestioneViaggi.Models.DTOs.ClienteInitData> GetClienteInitDataAsync(int? clienteId = null)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            using (var cmd = new NpgsqlCommand("SELECT fn_get_cliente_init_data(@p_cliente_id)", conn))
            {
                cmd.Parameters.AddWithValue("p_cliente_id", (object?)clienteId ?? DBNull.Value);
                var result = await cmd.ExecuteScalarAsync();
                var jsonResult = result?.ToString() ?? "{}";

                return System.Text.Json.JsonSerializer.Deserialize<GestioneViaggi.Models.DTOs.ClienteInitData>(jsonResult, new System.Text.Json.JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                }) ?? new GestioneViaggi.Models.DTOs.ClienteInitData();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore Fat Init Cliente per ID {ClienteId}", clienteId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "ana_clienti");
        }
    }

    #endregion

    #region Private Validation Methods

    /// <summary>
    /// Validazione completa cliente prima di INSERT/UPDATE
    /// </summary>
    // Le validazioni che stavano qui (lunghezze, formati, codice fiscale, unicita')
    // sono scese nel database con SqlScripts/541-552. Non sono state "spostate" per
    // ordine: erano invisibili al sito di iscrizione, che scrive sulla stessa tabella.
    // Ora le fa fn_ana_clienti_valida, e valgono per entrambi.
    //
    // Qui resta la sola normalizzazione, che e' presentazione e non regola.

    /// </summary>
    private static void NormalizeCliente(Cliente cliente)
    {
        // Uppercase per campi testo
        cliente.Cognome = cliente.Cognome?.ToUpperInvariant() ?? string.Empty;
        cliente.Nome = cliente.Nome?.ToUpperInvariant() ?? string.Empty;
        cliente.IndirizzoResidenza = cliente.IndirizzoResidenza?.ToUpperInvariant();

        // Uppercase per codice fiscale
        cliente.CodiceFiscale = cliente.CodiceFiscale?.ToUpperInvariant();

        // Uppercase per IBAN
        cliente.Iban = cliente.Iban?.ToUpperInvariant();

        // Lowercase per email
        cliente.Email = cliente.Email?.ToLowerInvariant();

        // Trim su tutti i campi stringa
        cliente.Cognome = cliente.Cognome?.Trim() ?? string.Empty;
        cliente.Nome = cliente.Nome?.Trim() ?? string.Empty;
        cliente.IndirizzoResidenza = cliente.IndirizzoResidenza?.Trim();
        cliente.PrefTelInt = cliente.PrefTelInt?.Trim();
        cliente.Telefono = cliente.Telefono?.Trim();
        cliente.Email = cliente.Email?.Trim();
        cliente.CodiceFiscale = cliente.CodiceFiscale?.Trim();
        cliente.Iban = cliente.Iban?.Trim();
        // Uppercase per altri campi dati
        cliente.TipoDocIdentita = cliente.TipoDocIdentita?.ToUpperInvariant();
        cliente.DocumentoNumero = cliente.DocumentoNumero?.ToUpperInvariant();
        cliente.DocumentoRilasciatoDa = cliente.DocumentoRilasciatoDa?.ToUpperInvariant();
        cliente.Intolleranza = cliente.Intolleranza?.ToUpperInvariant();

        // Note: lasciamo flessibilità o forziamo upper? Utente dice "NESSUN campo... minuscolo".
        // Forziamo Upper per sicurezza.
        cliente.Note = cliente.Note?.ToUpperInvariant();

        // Trim finali (ridondante se ToUpperInvariant gestisce stringhe, ma utile se null safe logic cambia)
        // La logica sopra gestisce il replace. I Trim sotto sono ora ridondanti per i campi uppercased.
        // Rimuovo i trim dei campi che ho appena uppercasato per pulizia
        cliente.PrefTelInt = cliente.PrefTelInt?.Trim();
        cliente.Telefono = cliente.Telefono?.Trim();
        cliente.Email = cliente.Email?.Trim();
    }

    #endregion
}
