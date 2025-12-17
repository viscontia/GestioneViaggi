namespace GestioneViaggi.Models;

/// <summary>
/// Classe base per tutte le entità con ID autogenerato
/// </summary>
public abstract class BaseEntity
{
    /// <summary>
    /// ID univoco dell'entità (non visibile all'utente nelle UI)
    /// </summary>
    public int Id { get; set; }
}
