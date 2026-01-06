using System.Data;
using ExcelDataReader;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Migrazione_Dati_Oracle;

public class OracleMovClientiAlloggiImportService
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<OracleMovClientiAlloggiImportService> _logger;

    public OracleMovClientiAlloggiImportService(IDatabaseService databaseService, ILogger<OracleMovClientiAlloggiImportService> logger)
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
            await new NpgsqlCommand($"TRUNCATE TABLE {tableName} CASCADE", connection, transaction).ExecuteNonQueryAsync();
            await new NpgsqlCommand($"INSERT INTO {tableName} SELECT * FROM {backupTableName}", connection, transaction).ExecuteNonQueryAsync();

            // Sync Sequence
            await new NpgsqlCommand("CREATE SEQUENCE IF NOT EXISTS mov_clienti_alloggi_seq", connection, transaction).ExecuteNonQueryAsync();
            await new NpgsqlCommand($"SELECT setval('public.mov_clienti_alloggi_seq', (SELECT COALESCE(MAX(mov_clienti_alloggio_pk), 1) FROM public.mov_clienti_alloggi))", connection, transaction).ExecuteScalarAsync();

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

    public async Task<ImportResult> ImportFromExcelAsync(string filePath, string tableName = "mov_clienti_alloggi", bool dryRun = false)
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

                // Triggers handle audit fields, so we can leave them enabled or disable for performance/strict historical accuracy.
                // Since we want to preserve historical CREATED (if present), keeping them ON is fine as they respect explicit non-null values.

                int processedCount = 0;
                foreach (DataRow row in infoTable.Rows)
                {
                    try
                    {
                        await new NpgsqlCommand("SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        await UpsertMovimentoAlloggioAsync(connection, row, transaction);

                        await new NpgsqlCommand("RELEASE SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();
                        processedCount++;
                    }
                    catch (PostgresException ex) when (ex.SqlState == "23505") // Unique violation
                    {
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string id = row["MOV_CLIENTI_ALLOGGIO_PK"]?.ToString() ?? "N/A";
                        string errorMsg = $"DUPLICATO: MovAlloggio [ID {id}] - Violazione PK.";
                        result.DuplicateDetails.Add(errorMsg);
                        _logger.LogWarning(errorMsg);
                    }
                    catch (Exception ex)
                    {
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string id = row["MOV_CLIENTI_ALLOGGIO_PK"]?.ToString() ?? "N/A";
                        string errorMsg = $"ERRORE RIGA [ID {id}]: {ex.Message}";
                        result.Errors.Add(errorMsg);
                        _logger.LogError(ex, errorMsg);
                    }
                }
                result.RecordsWritten = processedCount;

                // Create/Sync Sequence if missing
                await new NpgsqlCommand("CREATE SEQUENCE IF NOT EXISTS mov_clienti_alloggi_seq", connection, transaction).ExecuteNonQueryAsync();
                await new NpgsqlCommand($"SELECT setval('public.mov_clienti_alloggi_seq', (SELECT COALESCE(MAX(mov_clienti_alloggio_pk), 1) FROM public.{tableName}))", connection, transaction).ExecuteScalarAsync();

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
            _logger.LogError(ex, "Errore durante l'importazione Excel Movimenti Alloggi");
            throw;
        }

        return result;
    }

    private async Task UpsertMovimentoAlloggioAsync(NpgsqlConnection connection, DataRow row, NpgsqlTransaction transaction)
    {
        // Map Data
        int id = Convert.ToInt32(row["MOV_CLIENTI_ALLOGGIO_PK"]);
        int viaggioId = Convert.ToInt32(row["VIAGGIO_ID_FK"]);
        int dataViaggioId = Convert.ToInt32(row["DATA_VIAGGIO_ID_FK"]);
        int tipoAlloggioId = Convert.ToInt32(row["TIPO_ALLOGGIO_ID_FK"]);

        string oracleUser = row["CREATED_BY"]?.ToString() ?? "UNKNOWN";
        var (createdByUser, _) = MapUser(oracleUser); // Reuse logic if needed, or simple map

        var sql = @"
            INSERT INTO mov_clienti_alloggi (
                mov_clienti_alloggio_pk,
                viaggio_id_fk,
                data_viaggio_id_fk,
                tipo_alloggio_id_fk,
                cliente_id1_fk, cliente_id2_fk, cliente_id3_fk, 
                cliente_id4_fk, cliente_id5_fk, cliente_id6_fk,
                created_by, created, updated_by, updated
            ) VALUES (
                @id,
                @viaggioId,
                @dataViaggioId,
                @tipoAlloggioId,
                @c1, @c2, @c3, @c4, @c5, @c6,
                @createdBy, @created, @updatedBy, @updated
            )
            ON CONFLICT (mov_clienti_alloggio_pk) DO UPDATE SET
                viaggio_id_fk = EXCLUDED.viaggio_id_fk,
                data_viaggio_id_fk = EXCLUDED.data_viaggio_id_fk,
                tipo_alloggio_id_fk = EXCLUDED.tipo_alloggio_id_fk,
                cliente_id1_fk = EXCLUDED.cliente_id1_fk,
                cliente_id2_fk = EXCLUDED.cliente_id2_fk,
                cliente_id3_fk = EXCLUDED.cliente_id3_fk,
                cliente_id4_fk = EXCLUDED.cliente_id4_fk,
                cliente_id5_fk = EXCLUDED.cliente_id5_fk,
                cliente_id6_fk = EXCLUDED.cliente_id6_fk,
                created_by = EXCLUDED.created_by,
                created = EXCLUDED.created,
                updated_by = EXCLUDED.updated_by,
                updated = EXCLUDED.updated;
        ";

        await using var cmd = new NpgsqlCommand(sql, connection, transaction);

        cmd.Parameters.AddWithValue("id", id);
        cmd.Parameters.AddWithValue("viaggioId", viaggioId);
        cmd.Parameters.AddWithValue("dataViaggioId", dataViaggioId);
        cmd.Parameters.AddWithValue("tipoAlloggioId", tipoAlloggioId);

        cmd.Parameters.AddWithValue("c1", (object?)GetInt(row, "CLIENTE_ID1_FK") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("c2", (object?)GetInt(row, "CLIENTE_ID2_FK") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("c3", (object?)GetInt(row, "CLIENTE_ID3_FK") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("c4", (object?)GetInt(row, "CLIENTE_ID4_FK") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("c5", (object?)GetInt(row, "CLIENTE_ID5_FK") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("c6", (object?)GetInt(row, "CLIENTE_ID6_FK") ?? DBNull.Value);

        // Audit
        // Use mapped user or fall back to Oracle user string if valid email/user not found
        cmd.Parameters.AddWithValue("createdBy", createdByUser);

        // Handle potentially null/NaT date
        DateTime? createdDate = GetDate(row, "CREATED");
        cmd.Parameters.AddWithValue("created", (object?)createdDate ?? DateTime.UtcNow);

        cmd.Parameters.AddWithValue("updatedBy", (object?)GetString(row, "UPDATED_BY") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("updated", (object?)GetDate(row, "UPDATED") ?? DBNull.Value);

        await cmd.ExecuteNonQueryAsync();
    }

    private (string Email, int AziendaId) MapUser(string oracleUser)
    {
        return oracleUser.ToUpper() switch
        {
            "ANTONIOT" => ("segreteria@sardegnafuoritraccia.it", 2),
            "VISCONTIA" => ("visconti.adriano@gmail.com", 6),
            _ => (oracleUser, 2) // Default to keeping the oracle string if unknown, or map to default
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

        // If it's a "NaT" string or unparseable, return null
        return null;
    }
}
