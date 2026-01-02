using GestioneViaggi.Models;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Interface per il service layer di gestione clienti
/// Include validazioni business e orchestrazione repository
/// </summary>
public interface IClienteService
{
    // CRUD Operations
    Task<List<Cliente>> GetAllAsync(int? aziendaFk);
    Task<Cliente?> GetByIdAsync(int clienteId, int aziendaFk);
    Task<Cliente> CreateAsync(Cliente cliente);
    Task<Cliente> UpdateAsync(Cliente cliente);
    Task<bool> DeleteAsync(int clienteId, int aziendaFk);

    // Validation Operations
    Task<bool> VerificaClienteEsistenteAsync(string email, int? aziendaFk, int? excludeId = null);
    Task<bool> CheckCodiceFiscaleEsistenzaAsync(string codiceFiscale, int? aziendaFk, int? excludeClienteId = null);
    Task<Cliente?> FindExistingByAnagraficaAsync(string cognome, string nome, DateTime dataNascita, string codiceFiscale, int? aziendaFk);

    // Search Operations
    Task<List<Cliente>> SearchAsync(string searchTerm, int aziendaFk);
    Task<int> CountAsync(int aziendaFk);
}
