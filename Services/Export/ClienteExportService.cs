using Dapper;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Export;

public interface IClienteExportService
{
    Task<List<ClienteExportDTO>> GetClientiExportAsync(int? aziendaId);

    List<ExcelColumnDefinition<ClienteExportDTO>> GetColumnDefinitions();
}

public class ClienteExportService : IClienteExportService
{
    private readonly IDatabaseService _dbService;
    private readonly ILogger<ClienteExportService> _logger;

    public ClienteExportService(IDatabaseService dbService, ILogger<ClienteExportService> logger)
    {
        _dbService = dbService;
        _logger = logger;
    }

    public async Task<List<ClienteExportDTO>> GetClientiExportAsync(int? aziendaId)
    {
        await using var connection = await _dbService.GetConnectionAsync();

        var sql = "SELECT * FROM fn_get_clienti_export(@AziendaId)";
        var result = await connection.QueryAsync<ClienteExportDTO>(sql, new { AziendaId = aziendaId });

        _logger.LogInformation("Export clienti: {Count} record estratti per azienda {AziendaId}", result.Count(), aziendaId);
        return result.ToList();
    }

    public List<ExcelColumnDefinition<ClienteExportDTO>> GetColumnDefinitions()
    {
        return new List<ExcelColumnDefinition<ClienteExportDTO>>
        {
            new() { Header = "Cognome", ValueSelector = x => x.Cognome },
            new() { Header = "Nome", ValueSelector = x => x.Nome },
            new() { Header = "Titolo", ValueSelector = x => x.Titolo },
            new() { Header = "Sesso", ValueSelector = x => x.Sesso },
            new() { Header = "Data di Nascita", ValueSelector = x => x.DataNascita, NumberFormat = "dd/MM/yyyy" },
            new() { Header = "Comune di Nascita", ValueSelector = x => x.ComuneNascita },
            new() { Header = "Prov. Nascita", ValueSelector = x => x.ProvinciaNascita },
            new() { Header = "Indirizzo Residenza", ValueSelector = x => x.IndirizzoResidenza },
            new() { Header = "Comune di Residenza", ValueSelector = x => x.ComuneResidenza },
            new() { Header = "Prov. Residenza", ValueSelector = x => x.ProvinciaResidenza },
            new() { Header = "Prefisso Tel.", ValueSelector = x => x.PrefissoTelefono },
            new() { Header = "Telefono", ValueSelector = x => x.Telefono },
            new() { Header = "Email", ValueSelector = x => x.Email },
            new() { Header = "Codice Fiscale", ValueSelector = x => x.CodiceFiscale },
            new() { Header = "IBAN", ValueSelector = x => x.Iban },
            new() { Header = "Tipo Documento", ValueSelector = x => x.TipoDocumento },
            new() { Header = "Numero Documento", ValueSelector = x => x.NumeroDocumento },
            new() { Header = "Rilasciato Da", ValueSelector = x => x.DocumentoRilasciatoDa },
            new() { Header = "Data Rilascio", ValueSelector = x => x.DocumentoDataRilascio, NumberFormat = "dd/MM/yyyy" },
            new() { Header = "Data Scadenza", ValueSelector = x => x.DocumentoDataScadenza, NumberFormat = "dd/MM/yyyy" },
            new() { Header = "Intolleranze Alimentari", ValueSelector = x => x.Intolleranza },
            new() { Header = "Note", ValueSelector = x => x.Note },
            new() { Header = "Azienda", ValueSelector = x => x.Azienda },
        };
    }
}
