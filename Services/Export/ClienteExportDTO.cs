namespace GestioneViaggi.Services.Export;

/// <summary>
/// DTO flat per export Excel clienti.
/// Mappato 1:1 con l'output di fn_get_clienti_export.
/// </summary>
public class ClienteExportDTO
{
    public string? Cognome { get; set; }
    public string? Nome { get; set; }
    public string? Titolo { get; set; }
    public char? Sesso { get; set; }
    public DateTime? DataNascita { get; set; }
    public string? ComuneNascita { get; set; }
    public string? ProvinciaNascita { get; set; }
    public string? IndirizzoResidenza { get; set; }
    public string? ComuneResidenza { get; set; }
    public string? ProvinciaResidenza { get; set; }
    public string? PrefissoTelefono { get; set; }
    public string? Telefono { get; set; }
    public string? Email { get; set; }
    public string? CodiceFiscale { get; set; }
    public string? Iban { get; set; }
    public string? TipoDocumento { get; set; }
    public string? NumeroDocumento { get; set; }
    public string? DocumentoRilasciatoDa { get; set; }
    public DateTime? DocumentoDataRilascio { get; set; }
    public DateTime? DocumentoDataScadenza { get; set; }
    public string? Intolleranza { get; set; }
    public string? Note { get; set; }
    public string? Azienda { get; set; }
}
