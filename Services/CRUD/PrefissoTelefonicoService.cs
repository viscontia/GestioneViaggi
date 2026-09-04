using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// I prefissi telefonici internazionali, letti da <c>fn_ana_tel_pref_int_get_all</c>.
///
/// Prima di questo servizio il prefisso era un campo di <b>testo libero</b> nel
/// gestionale e una tendina di <b>dieci voci europee</b> nel sito, scritte a mano in
/// Python: due fonti diverse per lo stesso dato, e nei dati reali erano già finiti
/// prefissi che il sito non sapeva mostrare (+27, +34) e due varianti di «+39».
/// Ora la fonte è una sola, nel database, dove la raggiungono entrambi (SqlScripts/580).
///
/// L'elenco è di 249 voci e non cambia mai durante una sessione: si legge una volta.
/// </summary>
public class PrefissoTelefonicoService
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<PrefissoTelefonicoService> _logger;
    private List<PrefissoTelefonico>? _cache;

    public PrefissoTelefonicoService(IDatabaseService databaseService,
                                     ILogger<PrefissoTelefonicoService> logger)
    {
        _databaseService = databaseService;
        _logger = logger;
    }

    public async Task<List<PrefissoTelefonico>> GetAllAsync()
    {
        if (_cache is not null) return _cache;

        var esito = new List<PrefissoTelefonico>();
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand("SELECT * FROM fn_ana_tel_pref_int_get_all()", connection);
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                esito.Add(new PrefissoTelefonico
                {
                    Codice = reader.GetString(0),
                    Iso2 = reader.GetString(1),
                    Paese = reader.GetString(2),
                    Descrizione = reader.GetString(3)
                });
            }
            _cache = esito;
        }
        catch (Exception ex)
        {
            // Senza elenco la scheda resta usabile: il campo mostra ciò che c'è già.
            _logger.LogError(ex, "Prefissi telefonici non letti");
        }
        return esito;
    }
}
