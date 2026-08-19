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

    public async Task<List<Cliente>> GetAllAsync(int? aziendaFk, int? filterYear = null)
    {
        try
        {
            return await _repository.GetAllAsync(aziendaFk, filterYear);
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

    public async Task<Cliente> CreateAsync(Cliente cliente)
    {
        try
        {
            // Validazioni pre-insert
            await ValidateClienteAsync(cliente, isUpdate: false);

            // Normalizza dati
            NormalizeCliente(cliente);

            // Insert
            return await _repository.InsertAsync(cliente);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del cliente");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "ana_clienti");
        }
    }

    public async Task<Cliente> UpdateAsync(Cliente cliente)
    {
        try
        {
            // Validazioni pre-update
            await ValidateClienteAsync(cliente, isUpdate: true);

            // Normalizza dati
            NormalizeCliente(cliente);

            // Update
            return await _repository.UpdateAsync(cliente);
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

    public async Task<Cliente?> FindExistingByAnagraficaAsync(string cognome, string nome, DateTime dataNascita, string codiceFiscale, int? aziendaFk)
    {
        try
        {
            return await _repository.GetByAnagraficaAsync(cognome, nome, dataNascita, codiceFiscale, aziendaFk);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la ricerca cliente per anagrafica");
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
    private async Task ValidateClienteAsync(Cliente cliente, bool isUpdate)
    {
        // 1. Validazioni Sintattiche (Lunghezza Campi)
        ValidateFieldLengths(cliente);

        // 2. Validazioni Semantiche (Email, Telefono, Date)
        ValidateSemanticFields(cliente);

        // 3. Validazione Codice Fiscale (se presente)
        if (!string.IsNullOrWhiteSpace(cliente.CodiceFiscale))
        {
            ValidateCodiceFiscale(cliente);
        }

        // 4. Validazioni Business (Unicità)
        await ValidateBusinessRules(cliente, isUpdate);
    }

    /// <summary>
    /// Validazione lunghezze campi
    /// </summary>
    private static void ValidateFieldLengths(Cliente cliente)
    {
        var validations = new List<(string Field, string? Value, int MaxLength)>
        {
            ("Cognome", cliente.Cognome, 50),
            ("Nome", cliente.Nome, 50),
            ("IndirizzoResidenza", cliente.IndirizzoResidenza, 100),
            ("PrefTelInt", cliente.PrefTelInt, 5),
            ("Telefono", cliente.Telefono, 15),
            ("Email", cliente.Email, 100),
            ("CodiceFiscale", cliente.CodiceFiscale, 16),
            ("Iban", cliente.Iban, 34),
            ("TipoDocIdentita", cliente.TipoDocIdentita, 10),
            ("DocumentoNumero", cliente.DocumentoNumero, 50),
            ("DocumentoRilasciatoDa", cliente.DocumentoRilasciatoDa, 100)
        };

        foreach (var (field, value, maxLength) in validations)
        {
            var result = FieldLengthValidator.ValidateMaxLength(value, maxLength, field);
            if (!result.IsValid)
            {
                throw new ArgumentException(result.Message, field);
            }
        }
    }

    /// <summary>
    /// Validazione semantica email, telefono, date
    /// </summary>
    private static void ValidateSemanticFields(Cliente cliente)
    {
        // Email
        if (!string.IsNullOrWhiteSpace(cliente.Email))
        {
            var emailResult = ClienteValidator.ValidateEmail(cliente.Email);
            if (!emailResult.IsValid)
            {
                throw new ArgumentException(emailResult.Message, nameof(cliente));
            }
        }

        // Telefono
        if (!string.IsNullOrWhiteSpace(cliente.Telefono))
        {
            var phoneResult = ClienteValidator.ValidateTelefono(cliente.Telefono);
            if (!phoneResult.IsValid)
            {
                throw new ArgumentException(phoneResult.Message, nameof(cliente));
            }
        }

        // Prefisso Telefono
        if (!string.IsNullOrWhiteSpace(cliente.PrefTelInt))
        {
            var prefResult = ClienteValidator.ValidatePrefissoTelefono(cliente.PrefTelInt);
            if (!prefResult.IsValid)
            {
                throw new ArgumentException(prefResult.Message, nameof(cliente));
            }
        }

        // Data Nascita
        if (cliente.DataNascita.HasValue)
        {
            var dataNascitaResult = ClienteValidator.ValidateDataNascita(cliente.DataNascita.Value);
            if (!dataNascitaResult.IsValid)
            {
                throw new ArgumentException(dataNascitaResult.Message, nameof(cliente));
            }
        }

        // Date Documento - validazione manuale (metodo non esistente in ClienteValidator)
        if (cliente.DocumentoRilasciatoData.HasValue && cliente.DocumentoRilasciatoScadenza.HasValue)
        {
            if (cliente.DocumentoRilasciatoScadenza.Value <= cliente.DocumentoRilasciatoData.Value)
            {
                throw new ArgumentException(
                    "La data di scadenza del documento deve essere successiva alla data di rilascio",
                    nameof(cliente)
                );
            }
        }

        // IBAN - validazione basica (validatore completo potrebbe non esistere)
        if (!string.IsNullOrWhiteSpace(cliente.Iban))
        {
            var trimmedIban = cliente.Iban.Trim().Replace(" ", "");
            if (trimmedIban.Length < 15 || trimmedIban.Length > 34)
            {
                throw new ArgumentException(
                    "IBAN non valido: deve essere tra 15 e 34 caratteri",
                    nameof(cliente)
                );
            }
        }
    }

    /// <summary>
    /// Validazione Codice Fiscale con algoritmo completo
    /// </summary>
    private void ValidateCodiceFiscale(Cliente cliente)
    {
        // Validazione formato e check digit
        var cfResult = CodiceFiscaleValidator.ValidateCodiceFiscale(cliente.CodiceFiscale!);
        if (!cfResult.IsValid)
        {
            throw new CodiceFiscaleValidationException(
                cfResult.Message,
                cliente.CodiceFiscale!,
                cfResult.ErrorType ?? "invalid_format"
            );
        }

        // Validazione contro anagrafica (se data nascita presente)
        if (cliente.DataNascita.HasValue)
        {
            // TODO: Validazione anagrafica richiede codice catastale del comune
            // Per ora usiamo solo la validazione base del formato
            _logger.LogDebug(
                "Codice fiscale {CF} - validazione anagrafica completa da implementare con codice catastale comune",
                cliente.CodiceFiscale
            );
        }
    }

    /// <summary>
    /// Validazioni business rules (unicità email, codice fiscale, anagrafica)
    /// </summary>
    private async Task ValidateBusinessRules(Cliente cliente, bool isUpdate)
    {
        int? excludeId = isUpdate ? cliente.ClienteId : null;

        // Verifica unicità email (se presente)
        if (!string.IsNullOrWhiteSpace(cliente.Email))
        {
            var emailExists = await _repository.ExistsByEmailAsync(cliente.Email, cliente.AziendaFk, excludeId);
            if (emailExists)
            {
                throw new UniqueConstraintViolationException(
                    $"Email già utilizzata da un altro cliente: {cliente.Email}",
                    cliente.Email,
                    "cliente_email"
                );
            }
        }

        // Verifica unicità codice fiscale (se presente)
        if (!string.IsNullOrWhiteSpace(cliente.CodiceFiscale))
        {
            var cfExists = await _repository.ExistsByCodiceFiscaleAsync(cliente.CodiceFiscale, cliente.AziendaFk, excludeId);
            if (cfExists)
            {
                throw new UniqueConstraintViolationException(
                    $"Codice fiscale già utilizzato da un altro cliente: {cliente.CodiceFiscale}",
                    null,
                    "cliente_codicefiscale"
                );
            }
        }

        // Verifica unicità anagrafica (cognome + nome + data nascita + CF)
        if (cliente.DataNascita.HasValue && !string.IsNullOrWhiteSpace(cliente.CodiceFiscale))
        {
            var anagraficaExists = await _repository.ExistsByAnagraficaAsync(
                cliente.Cognome,
                cliente.Nome,
                cliente.DataNascita.Value,
                cliente.CodiceFiscale,
                cliente.AziendaFk,
                excludeId
            );

            if (anagraficaExists)
            {
                throw new DuplicateBookingException(
                    "Cliente già esistente con stessa anagrafica (cognome, nome, data nascita, codice fiscale)",
                    cliente.Email
                );
            }
        }
    }

    /// <summary>
    /// Normalizza i dati del cliente prima del salvataggio
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
