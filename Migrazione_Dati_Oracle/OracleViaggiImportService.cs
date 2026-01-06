using System.Data;
using ExcelDataReader;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Migrazione_Dati_Oracle;

public class OracleViaggiImportService
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<OracleViaggiImportService> _logger;

    public OracleViaggiImportService(IDatabaseService databaseService, ILogger<OracleViaggiImportService> logger)
    {
        _databaseService = databaseService;
        _logger = logger;

        System.Text.Encoding.RegisterProvider(System.Text.CodePagesEncodingProvider.Instance);
    }

    public async Task BackupTableAsync(string tableName)
    {
        await using var connection = await _databaseService.GetConnectionAsync();
        var backupTableName = $"{tableName}_BAK";

        await using var cmdDrop = new NpgsqlCommand($"DROP TABLE IF EXISTS {backupTableName}", connection);
        await cmdDrop.ExecuteNonQueryAsync();

        await using var cmdBackup = new NpgsqlCommand($"CREATE TABLE {backupTableName} AS SELECT * FROM {tableName}", connection);
        await cmdBackup.ExecuteNonQueryAsync();

        _logger.LogInformation("Backup created: {BackupTable}", backupTableName);
    }

    public async Task RestoreTableAsync(string tableName)
    {
        var backupTableName = $"{tableName}_BAK";
        await using var connection = await _databaseService.GetConnectionAsync();

        await using var transaction = await connection.BeginTransactionAsync();
        try
        {
            await new NpgsqlCommand($"ALTER TABLE {tableName} DISABLE TRIGGER ALL", connection, transaction).ExecuteNonQueryAsync();
            await new NpgsqlCommand($"TRUNCATE TABLE {tableName} CASCADE", connection, transaction).ExecuteNonQueryAsync();
            await new NpgsqlCommand($"INSERT INTO {tableName} SELECT * FROM {backupTableName}", connection, transaction).ExecuteNonQueryAsync();
            await new NpgsqlCommand($"ALTER TABLE {tableName} ENABLE TRIGGER ALL", connection, transaction).ExecuteNonQueryAsync();
            await new NpgsqlCommand($"SELECT setval('public.ana_viaggi_seq', (SELECT MAX(viaggio_id) FROM public.ana_viaggi))", connection, transaction).ExecuteScalarAsync();

            await transaction.CommitAsync();
            _logger.LogInformation("Restore completed from {BackupTable}", backupTableName);
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync();
            _logger.LogError(ex, "Failed to restore table {TableName}", tableName);
            throw;
        }
    }

    public async Task<ImportResult> ImportFromExcelAsync(string filePath, string tableName = "ana_viaggi", bool dryRun = false)
    {
        if (!File.Exists(filePath))
        {
            throw new FileNotFoundException("File Excel non trovato", filePath);
        }

        var result = new ImportResult();

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var transaction = await connection.BeginTransactionAsync();

            try
            {
                result.DbCountBefore = Convert.ToInt32(await new NpgsqlCommand($"SELECT COUNT(*) FROM {tableName}", connection, transaction).ExecuteScalarAsync());

                await using var stream = File.Open(filePath, FileMode.Open, FileAccess.Read);
                using var reader = ExcelReaderFactory.CreateReader(stream);

                var dataSet = reader.AsDataSet(new ExcelDataSetConfiguration()
                {
                    ConfigureDataTable = (_) => new ExcelDataTableConfiguration() { UseHeaderRow = true }
                });

                var infoTable = dataSet.Tables[0];
                result.RecordsRead = infoTable.Rows.Count;

                // DISABLE TRIGGERS to allow inserting historical created/created_by
                await new NpgsqlCommand($"ALTER TABLE {tableName} DISABLE TRIGGER ALL", connection, transaction).ExecuteNonQueryAsync();

                int processedCount = 0;
                foreach (DataRow row in infoTable.Rows)
                {
                    try
                    {
                        await new NpgsqlCommand("SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        await UpsertViaggioAsync(connection, row, transaction);

                        await new NpgsqlCommand("RELEASE SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();
                        processedCount++;
                    }
                    catch (PostgresException ex) when (ex.SqlState == "23505") // Unique violation
                    {
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string id = row["VIAGGIO_ID"]?.ToString() ?? "N/A";
                        string desc = row["VIAGGIO_DESCRIZIONE_BREVE"]?.ToString() ?? "N/A";

                        string errorMsg = $"DUPLICATO: Viaggio '{desc}' [ID: {id}] - Violazione vincolo unicità.";
                        result.DuplicateDetails.Add(errorMsg);
                        _logger.LogWarning(errorMsg);
                    }
                    catch (Exception ex)
                    {
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string id = row["VIAGGIO_ID"]?.ToString() ?? "N/A";
                        string errorMsg = $"ERRORE RIGA [ID {id}]: {ex.Message}";
                        result.Errors.Add(errorMsg);
                        _logger.LogError(ex, errorMsg);
                    }
                }
                result.RecordsWritten = processedCount;

                // ENABLE TRIGGERS back
                await new NpgsqlCommand($"ALTER TABLE {tableName} ENABLE TRIGGER ALL", connection, transaction).ExecuteNonQueryAsync();

                using var cmdSeq = new NpgsqlCommand("SELECT setval('public.ana_viaggi_seq', (SELECT MAX(viaggio_id) FROM public.ana_viaggi))", connection, transaction);
                await cmdSeq.ExecuteScalarAsync();

                result.DbCountAfter = Convert.ToInt32(await new NpgsqlCommand($"SELECT COUNT(*) FROM {tableName}", connection, transaction).ExecuteScalarAsync());

                if (dryRun)
                {
                    await transaction.RollbackAsync();
                    _logger.LogInformation("Simulazione completata. Rollback effettuato.");
                }
                else
                {
                    await transaction.CommitAsync();
                    _logger.LogInformation("Importazione completata con successo. Commit effettuato.");
                }
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'importazione Excel Viaggi");
            throw;
        }

        return result;
    }

    private async Task UpsertViaggioAsync(NpgsqlConnection connection, DataRow row, NpgsqlTransaction transaction)
    {
        // 1. Map Data
        int viaggioId = Convert.ToInt32(row["VIAGGIO_ID"]);
        string oracleUser = row["CREATED_BY"]?.ToString() ?? "UNKNOWN";
        var (aziendaId, createdBy) = MapUserToAzienda(oracleUser);

        var sql = @"
            INSERT INTO ana_viaggi (
                viaggio_id, viaggio_descrizione_breve, viaggio_descrizione_estesa,
                viaggio_numero_giorni, viaggio_numero_notti, viaggio_pasti_al_sacco,
                viaggio_num_km, viaggio_tipo_avvicinamento, viaggio_note,
                viaggio_tipo_viaggio_fk, viaggio_tipo_trattamento_fk,
                viaggio_nazione_fk, viaggio_tipo_pernottamento_fk,
                azienda_id,
                created_by, created, updated_by, updated,
                viaggio_link
            ) VALUES (
                @id, @descBreve, @descEstesa,
                @numGiorni, @numNotti, @pastiAlSacco,
                @numKm, @tipoAvvicinamento, @note,
                @tipoViaggio, @tipoTrattamento,
                @nazione, @tipoPernottamento,
                @azienda,
                @createdBy, @created, NULL, NULL,
                @link
            )
            ON CONFLICT (viaggio_id) DO UPDATE SET
                viaggio_descrizione_breve = EXCLUDED.viaggio_descrizione_breve,
                viaggio_descrizione_estesa = EXCLUDED.viaggio_descrizione_estesa,
                viaggio_numero_giorni = EXCLUDED.viaggio_numero_giorni,
                viaggio_numero_notti = EXCLUDED.viaggio_numero_notti,
                viaggio_pasti_al_sacco = EXCLUDED.viaggio_pasti_al_sacco,
                viaggio_num_km = EXCLUDED.viaggio_num_km,
                viaggio_tipo_avvicinamento = EXCLUDED.viaggio_tipo_avvicinamento,
                viaggio_note = EXCLUDED.viaggio_note,
                viaggio_tipo_viaggio_fk = EXCLUDED.viaggio_tipo_viaggio_fk,
                viaggio_tipo_trattamento_fk = EXCLUDED.viaggio_tipo_trattamento_fk,
                viaggio_nazione_fk = EXCLUDED.viaggio_nazione_fk,
                viaggio_tipo_pernottamento_fk = EXCLUDED.viaggio_tipo_pernottamento_fk,
                azienda_id = EXCLUDED.azienda_id,
                created_by = EXCLUDED.created_by,
                created = EXCLUDED.created,
                viaggio_link = EXCLUDED.viaggio_link;
        ";

        await using var cmd = new NpgsqlCommand(sql, connection, transaction);
        cmd.Parameters.AddWithValue("id", viaggioId);
        cmd.Parameters.AddWithValue("descBreve", GetString(row, "VIAGGIO_DESCRIZIONE_BREVE") ?? "N/A");
        cmd.Parameters.AddWithValue("descEstesa", (object?)GetString(row, "VIAGGIO_DESCRIZIONE_ESTESA") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("numGiorni", (object?)GetInt(row, "VIAGGIO_NUMERO_GIORNI") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("numNotti", (object?)GetInt(row, "VIAGGIO_NUMERO_NOTTI") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("pastiAlSacco", (object?)GetString(row, "VIAGGIO_PASTI_AL_SACCO") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("numKm", (object?)GetInt(row, "VIAGGIO_NUM_KM") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("tipoAvvicinamento", (object?)GetString(row, "VIAGGIO_TIPO_AVVICINAMENTO") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("note", (object?)GetString(row, "VIAGGIO_NOTE") ?? DBNull.Value);

        // FKs - defaulting to NULL if not found, ideally user should map lookups
        cmd.Parameters.AddWithValue("tipoViaggio", (object?)GetInt(row, "VIAGGIO_TIPO_VIAGGIO_FK") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("tipoTrattamento", (object?)GetInt(row, "VIAGGIO_TIPO_TRATTAMENTO_FK") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("nazione", (object?)GetInt(row, "VIAGGIO_NAZIONE_FK") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("tipoPernottamento", (object?)GetInt(row, "VIAGGIO_TIPO_PERNOTTAMENTO_FK") ?? DBNull.Value);

        cmd.Parameters.AddWithValue("azienda", aziendaId);
        cmd.Parameters.AddWithValue("createdBy", createdBy);
        cmd.Parameters.AddWithValue("created", GetDate(row, "CREATED") ?? DateTime.UtcNow);
        cmd.Parameters.AddWithValue("link", (object?)GetString(row, "VIAGGIO_LINK") ?? DBNull.Value);

        await cmd.ExecuteNonQueryAsync();
    }

    private (int AziendaId, string CreatedBy) MapUserToAzienda(string oracleUser)
    {
        return oracleUser.ToUpper() switch
        {
            "ANTONIOT" => (2, "segreteria@sardegnafuoritraccia.it"),
            "VISCONTIA" => (6, "visconti.adriano@gmail.com"),
            _ => (2, "unknown@import.com")
        };
    }

    private string? GetString(DataRow row, string col) => row.Table.Columns.Contains(col) && row[col] != DBNull.Value ? row[col].ToString() : null;
    private int? GetInt(DataRow row, string col) => row.Table.Columns.Contains(col) && row[col] != DBNull.Value && int.TryParse(row[col].ToString(), out int v) ? v : null;

    private DateTime? GetDate(DataRow row, string col)
    {
        if (!row.Table.Columns.Contains(col) || row[col] == DBNull.Value) return null;

        var val = row[col];
        if (val is DateTime d) return d;
        if (val is double dbl) return DateTime.FromOADate(dbl); // Handle Excel serial dates if any

        if (DateTime.TryParse(val.ToString(), out DateTime parsed)) return parsed;

        _logger.LogWarning($"Date parse failed for column '{col}'. Value: '{val}'");
        return null;
    }
}
