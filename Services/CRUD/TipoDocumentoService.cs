using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// I tipi di documento ammessi, letti da <c>fn_ana_tipo_documento_get_all</c>.
///
/// Prima erano scritti a mano nel markup della scheda cliente — e in una forma diversa
/// da quella del sito e da quella dei dati: il gestionale salvava «Passaporto» per
/// esteso, i dati contenevano `PAS`, e il codice più diffuso (`CID`, 144 clienti) non
/// era in nessuno dei due elenchi. Aprendo quei clienti il campo appariva vuoto.
/// Ora la fonte è una sola (SqlScripts/585).
///
/// L'elenco è di tre voci e non cambia durante una sessione: si legge una volta.
/// </summary>
public class TipoDocumentoService
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<TipoDocumentoService> _logger;
    private List<(string Codice, string Descrizione)>? _cache;

    public TipoDocumentoService(IDatabaseService databaseService, ILogger<TipoDocumentoService> logger)
    {
        _databaseService = databaseService;
        _logger = logger;
    }

    public async Task<List<(string Codice, string Descrizione)>> GetAllAsync()
    {
        if (_cache is not null) return _cache;

        var esito = new List<(string, string)>();
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand("SELECT * FROM fn_ana_tipo_documento_get_all()", connection);
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
                esito.Add((reader.GetString(0), reader.GetString(1)));
            _cache = esito;
        }
        catch (Exception ex)
        {
            // Senza elenco la scheda resta leggibile: mostra il codice che c'è già.
            _logger.LogError(ex, "Tipi documento non letti");
        }
        return esito;
    }
}
