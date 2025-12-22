using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta una marca veicolo (tabella ana_mezzi)
/// </summary>
public class MarcaVeicolo : BaseEntity
{
    [Required(ErrorMessage = "La descrizione è obbligatoria")]
    [StringLength(100, ErrorMessage = "Max 100 caratteri")]
    public string Descrizione { get; set; } = string.Empty;
}
