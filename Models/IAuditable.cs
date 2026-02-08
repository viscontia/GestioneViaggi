namespace GestioneViaggi.Models;

/// <summary>
/// Interfaccia per entità che supportano l'audit trail standard (created_by, created, updated_by, updated).
/// </summary>
public interface IAuditable
{
    string? CreatedBy { get; set; }
    DateTime? Created { get; set; }
    string? UpdatedBy { get; set; }
    DateTime? Updated { get; set; }
}
