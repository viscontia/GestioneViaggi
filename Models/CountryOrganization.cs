using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta una regione organizzativa (tabella eba_country_organizations)
/// Esempi: EMEA (Europa, Middle East e Africa), APAC (Asia Pacifico), NA (Nord America)
/// </summary>
public class CountryOrganization : BaseEntity
{
    [Required(ErrorMessage = "Il codice dell'organizzazione è obbligatorio")]
    [StringLength(100, ErrorMessage = "Max 100 caratteri")]
    public string Code { get; set; } = string.Empty;

    [Required(ErrorMessage = "Il nome dell'organizzazione è obbligatorio")]
    [StringLength(255, ErrorMessage = "Max 255 caratteri")]
    public string Name { get; set; } = string.Empty;
}
