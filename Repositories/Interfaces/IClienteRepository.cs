using GestioneViaggi.Models;

namespace GestioneViaggi.Repositories.Interfaces;

/// <summary>
/// Repository interface per operazioni su ana_clienti
/// Definisce il contratto per l'accesso ai dati dei clienti
/// </summary>
public interface IClienteRepository
{
    // CRUD Base
    Task<Cliente?> GetByIdAsync(int clienteId, int aziendaFk);
    Task<Cliente?> GetDetailAsync(int clienteId);
    Task<List<Cliente>> GetAllAsync(int? aziendaFk);
    Task<Cliente> InsertAsync(Cliente cliente);
    Task<Cliente> UpdateAsync(Cliente cliente);
    Task<bool> DeleteAsync(int clienteId, int aziendaFk);

    // Ricerche Specializzate
    Task<Cliente?> GetByEmailAsync(string email, int aziendaFk);
    Task<Cliente?> GetByCodiceFiscaleAsync(string codiceFiscale, int aziendaFk);

    /// <summary>
    /// Cerca cliente per anagrafica (cognome + nome + data_nascita + codice_fiscale)
    /// </summary>
    Task<Cliente?> GetByAnagraficaAsync(string cognome, string nome, DateTime dataNascita, string codiceFiscale, int? aziendaFk);

    // Validazioni di Esistenza
    Task<bool> ExistsByEmailAsync(string email, int? aziendaFk, int? excludeClienteId = null);
    Task<bool> ExistsByCodiceFiscaleAsync(string codiceFiscale, int? aziendaFk, int? excludeClienteId = null);
    Task<bool> ExistsByAnagraficaAsync(string cognome, string nome, DateTime dataNascita, string codiceFiscale, int? aziendaFk, int? excludeClienteId = null);

    // Verifica Relazioni
    Task<bool> HasRelatedBookingsAsync(int clienteId, int aziendaFk);
    Task<bool> HasRelatedAccommodationsAsync(int clienteId, int aziendaFk);

    // Ricerca Full-Text
    Task<List<Cliente>> SearchAsync(string searchTerm, int aziendaFk);

    // Conteggi
    Task<int> CountAsync(int aziendaFk);

    // Travel Stats
    Task<List<int>> GetTravelYearsAsync(int clienteId);
    Task<IEnumerable<ClienteTravelHistory>> GetTravelHistoryAsync(int clienteId, int aziendaFk);
    Task<IEnumerable<TravelPassenger>> GetTravelPassengersAsync(int dataViaggioId, int excludeClienteId);
    Task<List<string>> GetAllParticipantsTravelAsync(int dataViaggioId);
}
