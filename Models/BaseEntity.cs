namespace GestioneViaggi.Models;

/// <summary>
/// Classe base per tutte le entità con ID autogenerato
/// </summary>
public abstract class BaseEntity
{
    /// <summary>
    /// ID univoco dell'entità (non visibile all'utente nelle UI)
    /// </summary>
    public virtual int Id { get; set; }

    /// <summary>
    /// Crea una shallow copy dell'entità per evitare modifiche accidentali all'oggetto originale.
    /// Sufficiente per entità semplici senza oggetti nested complessi.
    /// </summary>
    public T Clone<T>() where T : BaseEntity
    {
        return (T)this.MemberwiseClone();
    }
}
