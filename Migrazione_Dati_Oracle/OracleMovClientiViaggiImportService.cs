using System.Data;
using ExcelDataReader;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

using GestioneViaggi.Services.Session;

namespace GestioneViaggi.Migrazione_Dati_Oracle;

public class OracleMovClientiViaggiImportService
{
    private readonly IDatabaseService _databaseService;
    private readonly ITenantContext _tenantContext;
    private readonly ILogger<OracleMovClientiViaggiImportService> _logger;

    public OracleMovClientiViaggiImportService(IDatabaseService databaseService, ITenantContext tenantContext, ILogger<OracleMovClientiViaggiImportService> logger)
    {
        _databaseService = databaseService;
        _tenantContext = tenantContext;
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

            // No Sequence setval needed for this table (Composite PK)

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

    public async Task<ImportResult> ImportFromExcelAsync(string filePath, string tableName = "mov_clienti_viaggi", bool dryRun = false)
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

                        await UpsertMovimentoAsync(connection, row, transaction);

                        await new NpgsqlCommand("RELEASE SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();
                        processedCount++;
                    }
                    catch (PostgresException ex) when (ex.SqlState == "23505") // Unique violation
                    {
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string cliente = row["CLIENTE_ID_FK"]?.ToString() ?? "N/A";
                        string viaggio = row["VIAGGIO_ID_FK"]?.ToString() ?? "N/A";
                        string data_viaggio = row["DATA_VIAGGIO_ID_FK"]?.ToString() ?? "N/A";

                        string errorMsg = $"DUPLICATO: Movimento [C:{cliente}, V:{viaggio}, D:{data_viaggio}] - Violazione vincolo unicità.";
                        result.DuplicateDetails.Add(errorMsg);
                        _logger.LogWarning(errorMsg);
                    }
                    catch (Exception ex)
                    {
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string cliente = row["CLIENTE_ID_FK"]?.ToString() ?? "N/A";
                        string errorMsg = $"ERRORE RIGA [C: {cliente}]: {ex.Message}";
                        result.Errors.Add(errorMsg);
                        _logger.LogError(ex, errorMsg);
                    }
                }
                result.RecordsWritten = processedCount;

                // ENABLE TRIGGERS back
                await new NpgsqlCommand($"ALTER TABLE {tableName} ENABLE TRIGGER ALL", connection, transaction).ExecuteNonQueryAsync();

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
            _logger.LogError(ex, "Errore durante l'importazione Excel Movimenti");
            throw;
        }

        return result;
    }

    private async Task UpsertMovimentoAsync(NpgsqlConnection connection, DataRow row, NpgsqlTransaction transaction)
    {
        // 1. Map Data
        int viaggioId = Convert.ToInt32(row["VIAGGIO_ID_FK"]);
        int dataViaggioId = Convert.ToInt32(row["DATA_VIAGGIO_ID_FK"]);
        int clienteId = Convert.ToInt32(row["CLIENTE_ID_FK"]);

        string oracleUser = row["CREATED_BY"]?.ToString() ?? "UNKNOWN";
        string currentUser = (await _tenantContext.GetCurrentUserAsync())?.Username ?? "IMPORT_ORACLE";
        string createdBy = !string.IsNullOrWhiteSpace(oracleUser) ? oracleUser : currentUser;

        var sql = @"
            INSERT INTO mov_clienti_viaggi (
                viaggio_id_fk, data_viaggio_id_fk, cliente_id_fk,
                tipo_partecipante_id_fk, ana_mezzi_id_fk, mezzo_modello_id_fk,
                mov_cliente_viaggio_scontoval_totale, mov_cliente_viaggio_targa_mezzo,
                mov_cliente_viaggio_cane_sino, mov_cliente_viaggio_note,
                created_by, created, updated_by, updated,
                cliente_pilota_id_fk
            ) VALUES (
                @viaggioId, @dataViaggioId, @clienteId,
                @tipoPartecipante, @mezzoId, @modelloId,
                @scontoVal, @targa,
                @cane, @note,
                @createdBy, @created, @updatedBy, @updated,
                @clientePilotaId
            )
            ON CONFLICT (viaggio_id_fk, data_viaggio_id_fk, cliente_id_fk) DO UPDATE SET
                tipo_partecipante_id_fk = EXCLUDED.tipo_partecipante_id_fk,
                ana_mezzi_id_fk = EXCLUDED.ana_mezzi_id_fk,
                mezzo_modello_id_fk = EXCLUDED.mezzo_modello_id_fk,
                mov_cliente_viaggio_scontoval_totale = EXCLUDED.mov_cliente_viaggio_scontoval_totale,
                mov_cliente_viaggio_targa_mezzo = EXCLUDED.mov_cliente_viaggio_targa_mezzo,
                mov_cliente_viaggio_cane_sino = EXCLUDED.mov_cliente_viaggio_cane_sino,
                mov_cliente_viaggio_note = EXCLUDED.mov_cliente_viaggio_note,
                created_by = EXCLUDED.created_by,
                created = EXCLUDED.created,
                updated_by = EXCLUDED.updated_by,
                updated = EXCLUDED.updated,
                cliente_pilota_id_fk = EXCLUDED.cliente_pilota_id_fk;
        ";

        await using var cmd = new NpgsqlCommand(sql, connection, transaction);

        // PK
        cmd.Parameters.AddWithValue("viaggioId", viaggioId);
        cmd.Parameters.AddWithValue("dataViaggioId", dataViaggioId);
        cmd.Parameters.AddWithValue("clienteId", clienteId);

        // Fields
        cmd.Parameters.AddWithValue("tipoPartecipante", (object?)GetInt(row, "TIPO_PARTECIPANTE_ID_FK") ?? 1); // Default 1 if null due to NOT NULL constraint
        cmd.Parameters.AddWithValue("mezzoId", (object?)GetInt(row, "ANA_MEZZI_ID_FK") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("modelloId", (object?)GetInt(row, "MEZZO_MODELLO_ID_FK") ?? DBNull.Value);

        // Numeric handling
        decimal? sconto = GetDecimal(row, "MOV_CLIENTE_VIAGGIO_SCONTOVAL_TOTALE");
        cmd.Parameters.AddWithValue("scontoVal", (object?)sconto ?? DBNull.Value);

        cmd.Parameters.AddWithValue("targa", (object?)GetString(row, "MOV_CLIENTE_VIAGGIO_TARGA_MEZZO") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("cane", (object?)GetString(row, "MOV_CLIENTE_VIAGGIO_CANE_SINO") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("note", (object?)GetString(row, "MOV_CLIENTE_VIAGGIO_NOTE") ?? DBNull.Value);

        // Audit
        cmd.Parameters.AddWithValue("createdBy", createdBy);
        cmd.Parameters.AddWithValue("created", GetDate(row, "CREATED") ?? DateTime.UtcNow);
        cmd.Parameters.AddWithValue("updatedBy", (object?)GetString(row, "UPDATED_BY") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("updated", (object?)GetDate(row, "UPDATED") ?? DBNull.Value);

        cmd.Parameters.AddWithValue("clientePilotaId", (object?)GetInt(row, "CLIENTE_PILOTA_ID_FK") ?? DBNull.Value);

        await cmd.ExecuteNonQueryAsync();
    }

    private string? GetString(DataRow row, string col) => row.Table.Columns.Contains(col) && row[col] != DBNull.Value ? row[col].ToString() : null;

    private int? GetInt(DataRow row, string col) => row.Table.Columns.Contains(col) && row[col] != DBNull.Value && int.TryParse(row[col].ToString(), out int v) ? v : null;

    private decimal? GetDecimal(DataRow row, string col)
    {
        if (!row.Table.Columns.Contains(col) || row[col] == DBNull.Value) return null;
        if (decimal.TryParse(row[col].ToString(), out decimal d)) return d;
        return null;
    }

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
