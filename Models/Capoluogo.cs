using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un Capoluogo di Regione (tabella ana_geo_capoluogo)
/// Colonne DB: capoluogo_id, capoluogo_descrizione
/// </summary>
public class Capoluogo : BaseEntity
{
    [Required(ErrorMessage = "La descrizione del capoluogo è obbligatoria")]
    [StringLength(50, ErrorMessage = "La descrizione non può superare i 50 caratteri")]
    public string Descrizione { get; set; } = string.Empty;
}
