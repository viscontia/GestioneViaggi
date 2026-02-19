using Dapper;
using GestioneViaggi.Models.DTOs;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.CRUD;

public class AnaDateViaggiService
{
    private readonly IDatabaseService _dbService;
    private readonly ILogger<AnaDateViaggiService> _logger;

    public AnaDateViaggiService(IDatabaseService dbService, ILogger<AnaDateViaggiService> logger)
    {
        _dbService = dbService;
        _logger = logger;
    }

    /// <summary>
    /// Recupera le date di viaggio per un determinato viaggio
    /// </summary>
    public async Task<IEnumerable<DataViaggioDTO>> GetByViaggioIdAsync(int viaggioId)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            string sql = @"
                SELECT
                    data_viaggio_id as DataViaggioId,
                    viaggio_id_fk as ViaggioIdFk,
                    data_viaggio_data_inizio as DataInizio,
                    data_viaggio_data_fine as DataFine,
                    data_viaggio_effettuato_sino as Effettuato
                FROM ana_date_viaggi
                WHERE viaggio_id_fk = @ViaggioId
                ORDER BY data_viaggio_data_inizio DESC";

            return await conn.QueryAsync<DataViaggioDTO>(sql, new { ViaggioId = viaggioId });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero date viaggio per viaggio {ViaggioId}", viaggioId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "data di viaggio");
        }
    }

    /// <summary>
    /// Recupera le date di viaggio con statistiche transazionali per un determinato viaggio
    /// </summary>
    public async Task<IEnumerable<DataViaggioDTO>> GetByViaggioIdWithStatsAsync(int viaggioId)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            string sql = @"
                SELECT 
                    data_viaggio_id as DataViaggioId,
                    viaggio_id_fk as ViaggioIdFk,
                    data_viaggio_data_inizio as DataInizio,
                    data_viaggio_data_fine as DataFine,
                    data_viaggio_effettuato_sino as Effettuato,
                    has_transactions as HasTransactions
                FROM fn_get_date_viaggi_with_transactions(@ViaggioId)";

            return await conn.QueryAsync<DataViaggioDTO>(sql, new { ViaggioId = viaggioId });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero date viaggio con stats per viaggio {ViaggioId}", viaggioId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "data di viaggio");
        }
    }
}
