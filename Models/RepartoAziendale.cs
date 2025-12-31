using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un reparto aziendale (tabella reparti_aziendali)
/// </summary>
public class RepartoAziendale : BaseEntity
{
    [Required(ErrorMessage = "L'azienda è obbligatoria")]
    public int AziendaIdFk { get; set; }

    [Required(ErrorMessage = "Il nome del reparto è obbligatorio")]
    [StringLength(100, ErrorMessage = "Il nome reparto non può superare i 100 caratteri")]
    public string NomeReparto { get; set; } = string.Empty;

    public string? Descrizione { get; set; }

    [StringLength(20, ErrorMessage = "Il telefono reparto non può superare i 20 caratteri")]
    public string? TelefonoReparto { get; set; }

    public int? ManagerContattoIdFk { get; set; }

    public bool IsActive { get; set; } = true;

    // Navigation properties (non mappate direttamente dal DB)
    public string? ManagerNomeCognome { get; set; }

    /// <summary>
    /// Crea una copia dell'entità per evitare modifiche accidentali all'oggetto originale
    /// </summary>
    public RepartoAziendale Clone()
    {
        return new RepartoAziendale
        {
            Id = this.Id,
            AziendaIdFk = this.AziendaIdFk,
            NomeReparto = this.NomeReparto,
            Descrizione = this.Descrizione,
            TelefonoReparto = this.TelefonoReparto,
            ManagerContattoIdFk = this.ManagerContattoIdFk,
            IsActive = this.IsActive,
            ManagerNomeCognome = this.ManagerNomeCognome
        };
    }
}
