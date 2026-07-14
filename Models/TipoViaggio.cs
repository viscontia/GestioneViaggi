using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un tipo di viaggio (tabella ana_tipo_viaggi)
/// </summary>
public class TipoViaggio : BaseEntity
{
    [Required(ErrorMessage = "Il tipo è obbligatorio")]
    [StringLength(6, ErrorMessage = "Max 6 caratteri")]
    public string Tipo { get; set; } = string.Empty;

    [Required(ErrorMessage = "La descrizione è obbligatoria")]
    [StringLength(100, ErrorMessage = "Max 100 caratteri")]
    public string Descrizione { get; set; } = string.Empty;

    /// <summary>FK opzionale alla descrizione web condivisa (web_tipi_viaggio_descrizioni). Blocco 8.</summary>
    public long? DescrizioneWebFk { get; set; }

    /// <summary>Marca il tipo come "esperienza breve / tour giornaliero" (§A.3): guida la sezione condizionale del sito.</summary>
    public bool TipoViaggioBreve { get; set; }
}
