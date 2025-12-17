using GestioneViaggi.Models;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Interfaccia generica per operazioni CRUD
/// </summary>
/// <typeparam name="T">Tipo di entità che eredita da BaseEntity</typeparam>
public interface ICrudService<T> where T : BaseEntity
{
    /// <summary>
    /// Recupera tutte le entità
    /// </summary>
    Task<List<T>> GetAllAsync();

    /// <summary>
    /// Recupera un'entità per ID
    /// </summary>
    Task<T?> GetByIdAsync(int id);

    /// <summary>
    /// Crea una nuova entità
    /// </summary>
    Task<T> CreateAsync(T entity);

    /// <summary>
    /// Aggiorna un'entità esistente
    /// </summary>
    Task<T> UpdateAsync(T entity);

    /// <summary>
    /// Elimina un'entità per ID
    /// </summary>
    Task<bool> DeleteAsync(int id);
}
