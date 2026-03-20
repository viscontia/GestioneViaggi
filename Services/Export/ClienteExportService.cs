using Npgsql;
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
        await using var cmd = new NpgsqlCommand(sql, (NpgsqlConnection)connection);
        cmd.Parameters.AddWithValue("AziendaId", aziendaId ?? (object)DBNull.Value);
        
        var result = new List<ClienteExportDTO>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            char? sesso = null;
            if (!reader.IsDBNull(reader.GetOrdinal("sesso")))
            {
                var sStr = reader.GetString(reader.GetOrdinal("sesso"));
                if (!string.IsNullOrEmpty(sStr)) sesso = sStr[0];
            }

            result.Add(new ClienteExportDTO
            {
                Cognome = reader.IsDBNull(reader.GetOrdinal("cognome")) ? null : reader.GetString(reader.GetOrdinal("cognome")),
                Nome = reader.IsDBNull(reader.GetOrdinal("nome")) ? null : reader.GetString(reader.GetOrdinal("nome")),
                Titolo = reader.IsDBNull(reader.GetOrdinal("titolo")) ? null : reader.GetString(reader.GetOrdinal("titolo")),
                Sesso = sesso,
                DataNascita = reader.IsDBNull(reader.GetOrdinal("data_nascita")) ? null : reader.GetDateTime(reader.GetOrdinal("data_nascita")),
                ComuneNascita = reader.IsDBNull(reader.GetOrdinal("comune_nascita")) ? null : reader.GetString(reader.GetOrdinal("comune_nascita")),
                ProvinciaNascita = reader.IsDBNull(reader.GetOrdinal("provincia_nascita")) ? null : reader.GetString(reader.GetOrdinal("provincia_nascita")),
                IndirizzoResidenza = reader.IsDBNull(reader.GetOrdinal("indirizzo_residenza")) ? null : reader.GetString(reader.GetOrdinal("indirizzo_residenza")),
                ComuneResidenza = reader.IsDBNull(reader.GetOrdinal("comune_residenza")) ? null : reader.GetString(reader.GetOrdinal("comune_residenza")),
                ProvinciaResidenza = reader.IsDBNull(reader.GetOrdinal("provincia_residenza")) ? null : reader.GetString(reader.GetOrdinal("provincia_residenza")),
                PrefissoTelefono = reader.IsDBNull(reader.GetOrdinal("prefisso_telefono")) ? null : reader.GetString(reader.GetOrdinal("prefisso_telefono")),
                Telefono = reader.IsDBNull(reader.GetOrdinal("telefono")) ? null : reader.GetString(reader.GetOrdinal("telefono")),
                Email = reader.IsDBNull(reader.GetOrdinal("email")) ? null : reader.GetString(reader.GetOrdinal("email")),
                CodiceFiscale = reader.IsDBNull(reader.GetOrdinal("codice_fiscale")) ? null : reader.GetString(reader.GetOrdinal("codice_fiscale")),
                Iban = reader.IsDBNull(reader.GetOrdinal("iban")) ? null : reader.GetString(reader.GetOrdinal("iban")),
                TipoDocumento = reader.IsDBNull(reader.GetOrdinal("tipo_documento")) ? null : reader.GetString(reader.GetOrdinal("tipo_documento")),
                NumeroDocumento = reader.IsDBNull(reader.GetOrdinal("numero_documento")) ? null : reader.GetString(reader.GetOrdinal("numero_documento")),
                DocumentoRilasciatoDa = reader.IsDBNull(reader.GetOrdinal("documento_rilasciato_da")) ? null : reader.GetString(reader.GetOrdinal("documento_rilasciato_da")),
                DocumentoDataRilascio = reader.IsDBNull(reader.GetOrdinal("documento_data_rilascio")) ? null : reader.GetDateTime(reader.GetOrdinal("documento_data_rilascio")),
                DocumentoDataScadenza = reader.IsDBNull(reader.GetOrdinal("documento_data_scadenza")) ? null : reader.GetDateTime(reader.GetOrdinal("documento_data_scadenza")),
                Intolleranza = reader.IsDBNull(reader.GetOrdinal("intolleranza")) ? null : reader.GetString(reader.GetOrdinal("intolleranza")),
                Note = reader.IsDBNull(reader.GetOrdinal("note")) ? null : reader.GetString(reader.GetOrdinal("note")),
                Azienda = reader.IsDBNull(reader.GetOrdinal("azienda")) ? null : reader.GetString(reader.GetOrdinal("azienda")),
            });
        }

        _logger.LogInformation("Export clienti: {Count} record estratti per azienda {AziendaId}", result.Count, aziendaId);
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
