using System.Data;
using ExcelDataReader;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Migrazione_Dati_Oracle;

public class OracleDateViaggiImportService
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<OracleDateViaggiImportService> _logger;

    public OracleDateViaggiImportService(IDatabaseService databaseService, ILogger<OracleDateViaggiImportService> logger)
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
            // Triggers on ana_date_viaggi (audit) respect explicit values, so no need to disable generally.
            // But for consistency and speed, we can disable them if needed. 
            // However, we'll keep them enabled to safeguard logical checks if any.
            // Wait, strict restore might prefer disabled. Let's start safely.

            await new NpgsqlCommand($"TRUNCATE TABLE {tableName} CASCADE", connection, transaction).ExecuteNonQueryAsync();
            await new NpgsqlCommand($"INSERT INTO {tableName} SELECT * FROM {backupTableName}", connection, transaction).ExecuteNonQueryAsync();

            // Sync Sequence if exists (we will create it during import if missing)
            await new NpgsqlCommand("CREATE SEQUENCE IF NOT EXISTS ana_date_viaggi_seq", connection, transaction).ExecuteNonQueryAsync();
            await new NpgsqlCommand($"SELECT setval('public.ana_date_viaggi_seq', (SELECT COALESCE(MAX(data_viaggio_id), 1) FROM public.ana_date_viaggi))", connection, transaction).ExecuteScalarAsync();

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

    public async Task<ImportResult> ImportFromExcelAsync(string filePath, string tableName = "ana_date_viaggi", bool dryRun = false)
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

                // No need to disable triggers as trg_ana_date_viaggi_audit checks for NULLs before overriding.

                int processedCount = 0;
                foreach (DataRow row in infoTable.Rows)
                {
                    try
                    {
                        await new NpgsqlCommand("SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        await UpsertDataViaggioAsync(connection, row, transaction);

                        await new NpgsqlCommand("RELEASE SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();
                        processedCount++;
                    }
                    catch (PostgresException ex) when (ex.SqlState == "23505") // Unique violation
                    {
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string id = row["DATA_VIAGGIO_ID"]?.ToString() ?? "N/A";
                        string errorMsg = $"DUPLICATO: Data Viaggio [ID: {id}] - Violazione vincolo unicità.";
                        result.DuplicateDetails.Add(errorMsg);
                        _logger.LogWarning(errorMsg);
                    }
                    catch (Exception ex)
                    {
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string id = row["DATA_VIAGGIO_ID"]?.ToString() ?? "N/A";
                        string errorMsg = $"ERRORE RIGA [ID {id}]: {ex.Message}";
                        result.Errors.Add(errorMsg);
                        _logger.LogError(ex, errorMsg);
                    }
                }
                result.RecordsWritten = processedCount;

                // Sync Sequence
                await new NpgsqlCommand("CREATE SEQUENCE IF NOT EXISTS ana_date_viaggi_seq", connection, transaction).ExecuteNonQueryAsync();
                await new NpgsqlCommand($"SELECT setval('public.ana_date_viaggi_seq', (SELECT COALESCE(MAX(data_viaggio_id), 1) FROM public.{tableName}))", connection, transaction).ExecuteScalarAsync();

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
            _logger.LogError(ex, "Errore durante l'importazione Excel Data Viaggi");
            throw;
        }

        return result;
    }

    private async Task UpsertDataViaggioAsync(NpgsqlConnection connection, DataRow row, NpgsqlTransaction transaction)
    {
        // 1. Map Data
        int id = Convert.ToInt32(row["DATA_VIAGGIO_ID"]);
        int viaggioId = Convert.ToInt32(row["VIAGGIO_ID_FK"]);

        string oracleUser = row["CREATED_BY"]?.ToString() ?? "UNKNOWN";
        var (aziendaId, createdBy) = MapUserToAzienda(oracleUser);

        // Map nullables
        DateTime? inizio = GetDate(row, "DATA_VIAGGIO_DATA_INIZIO");
        DateTime? fine = GetDate(row, "DATA_VIAGGIO_DATA_FINE");
        // Ensure not null if DB requires it. Checks say 'date' not null usually.
        // Assuming Excel has valid dates. If null, it will throw PG NotNullViolation, caught in loop.

        var sql = @"
            INSERT INTO ana_date_viaggi (
                data_viaggio_id, viaggio_id_fk,
                data_viaggio_data_inizio, data_viaggio_data_fine,
                data_viaggio_effettuato_sino,
                data_viaggio_costo_pilota, data_viaggio_costo_passeggero,
                data_viaggio_costo_passeggero_auto_guida,
                data_viaggio_costo_bambino_0_2, data_viaggio_costo_bambino_2_6, data_viaggio_costo_bambino_6_12,
                data_viaggio_note,
                created_by, created, updated_by, updated,
                azienda_id
            ) VALUES (
                @id, @viaggioId,
                @inizio, @fine,
                @effettuato,
                @costoPilota, @costoPasseggero,
                @costoPassAuto,
                @costoBamb02, @costoBamb26, @costoBamb612,
                @note,
                @createdBy, @created, @updatedBy, @updated,
                @aziendaId
            )
            ON CONFLICT (data_viaggio_id) DO UPDATE SET
                viaggio_id_fk = EXCLUDED.viaggio_id_fk,
                data_viaggio_data_inizio = EXCLUDED.data_viaggio_data_inizio,
                data_viaggio_data_fine = EXCLUDED.data_viaggio_data_fine,
                data_viaggio_effettuato_sino = EXCLUDED.data_viaggio_effettuato_sino,
                data_viaggio_costo_pilota = EXCLUDED.data_viaggio_costo_pilota,
                data_viaggio_costo_passeggero = EXCLUDED.data_viaggio_costo_passeggero,
                data_viaggio_costo_passeggero_auto_guida = EXCLUDED.data_viaggio_costo_passeggero_auto_guida,
                data_viaggio_costo_bambino_0_2 = EXCLUDED.data_viaggio_costo_bambino_0_2,
                data_viaggio_costo_bambino_2_6 = EXCLUDED.data_viaggio_costo_bambino_2_6,
                data_viaggio_costo_bambino_6_12 = EXCLUDED.data_viaggio_costo_bambino_6_12,
                data_viaggio_note = EXCLUDED.data_viaggio_note,
                created_by = EXCLUDED.created_by,
                created = EXCLUDED.created,
                updated_by = EXCLUDED.updated_by,
                updated = EXCLUDED.updated,
                azienda_id = EXCLUDED.azienda_id;
        ";

        await using var cmd = new NpgsqlCommand(sql, connection, transaction);

        cmd.Parameters.AddWithValue("id", id);
        cmd.Parameters.AddWithValue("viaggioId", viaggioId);
        cmd.Parameters.AddWithValue("inizio", (object?)inizio ?? DBNull.Value);
        cmd.Parameters.AddWithValue("fine", (object?)fine ?? DBNull.Value);

        cmd.Parameters.AddWithValue("effettuato", (object?)GetString(row, "DATA_VIAGGIO_EFFETTUATO_SINO") ?? DBNull.Value);

        // Costs imply Integer in schema (data_viaggio_costo_pilota | integer)
        cmd.Parameters.AddWithValue("costoPilota", (object?)GetInt(row, "DATA_VIAGGIO_COSTO_PILOTA") ?? 0);
        cmd.Parameters.AddWithValue("costoPasseggero", (object?)GetInt(row, "DATA_VIAGGIO_COSTO_PASSEGGERO") ?? 0);
        cmd.Parameters.AddWithValue("costoPassAuto", (object?)GetInt(row, "DATA_VIAGGIO_COSTO_PASSEGGERO_AUTO_GUIDA") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("costoBamb02", (object?)GetInt(row, "DATA_VIAGGIO_COSTO_BAMBINO_0_2") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("costoBamb26", (object?)GetInt(row, "DATA_VIAGGIO_COSTO_BAMBINO_2_6") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("costoBamb612", (object?)GetInt(row, "DATA_VIAGGIO_COSTO_BAMBINO_6_12") ?? DBNull.Value);

        cmd.Parameters.AddWithValue("note", (object?)GetString(row, "DATA_VIAGGIO_NOTE") ?? DBNull.Value);

        // Audit
        cmd.Parameters.AddWithValue("createdBy", createdBy);
        cmd.Parameters.AddWithValue("created", GetDate(row, "CREATED") ?? DateTime.UtcNow);
        cmd.Parameters.AddWithValue("updatedBy", (object?)GetString(row, "UPDATED_BY") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("updated", (object?)GetDate(row, "UPDATED") ?? DBNull.Value);

        cmd.Parameters.AddWithValue("aziendaId", aziendaId);

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
        if (val is double dbl) return DateTime.FromOADate(dbl);

        if (DateTime.TryParse(val.ToString(), out DateTime parsed)) return parsed;

        _logger.LogWarning($"Date parse failed for column '{col}'. Value: '{val}'");
        return null;
    }
}
