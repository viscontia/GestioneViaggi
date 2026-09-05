using GestioneViaggi.Models;
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
    /// Una partenza sola, riga intera, riletta dal database.
    ///
    /// ⚠️ Serve la RIGA INTERA e non il <see cref="DataViaggioDTO"/> di riepilogo:
    /// quello ha sei campi mentre l'entità ne ha diciannove, e riaprire la scheda
    /// con il DTO azzererebbe costi e note.
    /// DB Function: fn_ana_date_viaggi_get_by_id (SqlScripts/596)
    /// </summary>
    public async Task<AnaDataViaggio?> GetByIdAsync(int dataViaggioId)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT * FROM fn_ana_date_viaggi_get_by_id(@id)", conn);
            cmd.Parameters.AddWithValue("id", dataViaggioId);

            await using var reader = await cmd.ExecuteReaderAsync();
            if (!await reader.ReadAsync()) return null;

            object? Leggi(string c) { var i = reader.GetOrdinal(c); return reader.IsDBNull(i) ? null : reader.GetValue(i); }

            return new AnaDataViaggio
            {
                Id           = (int)reader.GetValue(reader.GetOrdinal("data_viaggio_id")),
                ViaggioIdFk  = (int)reader.GetValue(reader.GetOrdinal("viaggio_id_fk")),
                DataInizio   = (DateTime?)Leggi("data_viaggio_data_inizio"),
                DataFine     = (DateTime?)Leggi("data_viaggio_data_fine"),
                EffettuatoSino = (string?)Leggi("data_viaggio_effettuato_sino") ?? "N",
                CostoPilota  = (decimal?)Leggi("data_viaggio_costo_pilota"),
                CostoPasseggero = (decimal?)Leggi("data_viaggio_costo_passeggero"),
                CostoPasseggeroAutoGuida = (decimal?)Leggi("data_viaggio_costo_passeggero_auto_guida"),
                CostoBambino02 = (decimal?)Leggi("data_viaggio_costo_bambino_0_2"),
                CostoBambino26 = (decimal?)Leggi("data_viaggio_costo_bambino_2_6"),
                CostoBambino612 = (decimal?)Leggi("data_viaggio_costo_bambino_6_12"),
                Note         = (string?)Leggi("data_viaggio_note"),
                AziendaId    = (int?)Leggi("azienda_id") ?? 0,
                CreatedBy    = (string?)Leggi("created_by"),
                Created      = (DateTime?)Leggi("created"),
                UpdatedBy    = (string?)Leggi("updated_by"),
                Updated      = (DateTime?)Leggi("updated")
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Rilettura della partenza {Id} non riuscita", dataViaggioId);
            throw;
        }
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
