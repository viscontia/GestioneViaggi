using GestioneViaggi.Models.DTOs;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

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
            await using var conn = await _dbService.GetConnectionAsync();
            string sql = @"
                SELECT
                    data_viaggio_id,
                    viaggio_id_fk,
                    data_viaggio_data_inizio,
                    data_viaggio_data_fine,
                    data_viaggio_effettuato_sino
                FROM ana_date_viaggi
                WHERE viaggio_id_fk = @ViaggioId
                ORDER BY data_viaggio_data_inizio DESC";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("ViaggioId", viaggioId);

            var result = new List<DataViaggioDTO>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(MapReaderToDataViaggioDTO(reader));
            }
            return result;
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
            await using var conn = await _dbService.GetConnectionAsync();
            string sql = @"
                SELECT
                    data_viaggio_id,
                    viaggio_id_fk,
                    data_viaggio_data_inizio,
                    data_viaggio_data_fine,
                    data_viaggio_effettuato_sino,
                    has_transactions
                FROM fn_get_date_viaggi_with_transactions(@ViaggioId)";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("ViaggioId", viaggioId);

            var result = new List<DataViaggioDTO>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(MapReaderToDataViaggioDTO(reader));
            }
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero date viaggio con stats per viaggio {ViaggioId}", viaggioId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "data di viaggio");
        }
    }

    #region Mapping Helpers (AOT compatibili - no Reflection.Emit)

    /// <summary>
    /// Helper per verificare se una colonna esiste nel reader (compatibilità AOT - no exception)
    /// </summary>
    private static bool HasColumn(NpgsqlDataReader reader, string columnName)
    {
        for (int i = 0; i < reader.FieldCount; i++)
        {
            if (reader.GetName(i).Equals(columnName, StringComparison.OrdinalIgnoreCase))
                return true;
        }
        return false;
    }

    /// <summary>
    /// Mappa un NpgsqlDataReader a DataViaggioDTO (AOT compatibile)
    /// </summary>
    private static DataViaggioDTO MapReaderToDataViaggioDTO(NpgsqlDataReader reader)
    {
        var dto = new DataViaggioDTO
        {
            DataViaggioId = reader.GetInt32(reader.GetOrdinal("data_viaggio_id")),
            ViaggioIdFk = reader.GetInt32(reader.GetOrdinal("viaggio_id_fk")),
            DataInizio = reader.GetDateTime(reader.GetOrdinal("data_viaggio_data_inizio")),
            DataFine = reader.GetDateTime(reader.GetOrdinal("data_viaggio_data_fine"))
        };

        // Campo nullable
        var effettuatoOrdinal = reader.GetOrdinal("data_viaggio_effettuato_sino");
        dto.Effettuato = reader.IsDBNull(effettuatoOrdinal) ? null : reader.GetString(effettuatoOrdinal);

        // Campo opzionale (solo da fn_get_date_viaggi_with_transactions)
        if (HasColumn(reader, "has_transactions"))
        {
            var hasTransOrdinal = reader.GetOrdinal("has_transactions");
            dto.HasTransactions = !reader.IsDBNull(hasTransOrdinal) && reader.GetBoolean(hasTransOrdinal);
        }

        return dto;
    }

    #endregion
}
