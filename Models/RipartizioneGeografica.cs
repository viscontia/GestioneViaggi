using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta una ripartizione geografica italiana (tabella ana_geo_ita_ripgeo)
/// </summary>
public class RipartizioneGeografica : BaseEntity
{
    [Required(ErrorMessage = "La descrizione della ripartizione geografica è obbligatoria")]
    [StringLength(50, ErrorMessage = "La descrizione non può superare i 50 caratteri")]
    public string Descrizione { get; set; } = string.Empty;
}
