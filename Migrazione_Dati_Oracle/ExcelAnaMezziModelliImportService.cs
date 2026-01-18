using System.Data;
using ExcelDataReader;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Migrazione_Dati_Oracle;

public class ExcelAnaMezziModelliImportService
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<ExcelAnaMezziModelliImportService> _logger;

    public ExcelAnaMezziModelliImportService(IDatabaseService databaseService, ILogger<ExcelAnaMezziModelliImportService> logger)
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

            // Sincronizzazione Sequence
            await new NpgsqlCommand("CREATE SEQUENCE IF NOT EXISTS ana_mezzi_modelli_seq", connection, transaction).ExecuteNonQueryAsync();
            await new NpgsqlCommand($"SELECT setval('public.ana_mezzi_modelli_seq', (SELECT COALESCE(MAX(mezzo_modello_id), 1) FROM public.ana_mezzi_modelli))", connection, transaction).ExecuteScalarAsync();

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

    public async Task<ImportResult> ImportFromExcelAsync(string filePath, string tableName = "ana_mezzi_modelli", bool dryRun = false)
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

                // Il trigger ana_mezzi_modelli_trg1 assegna automaticamente la PK, 
                // ma l'INSERT esplicito con valore PK sovrascrive il DEFAULT
                // Quindi non serve disabilitare il trigger

                int processedCount = 0;
                foreach (DataRow row in infoTable.Rows)
                {
                    try
                    {
                        await new NpgsqlCommand("SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        await UpsertMezzoModelloAsync(connection, row, transaction);

                        await new NpgsqlCommand("RELEASE SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();
                        processedCount++;
                    }
                    catch (PostgresException ex) when (ex.SqlState == "23505") // Unique violation
                    {
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string id = row["MEZZO_MODELLO_ID"]?.ToString() ?? "N/A";
                        string errorMsg = $"DUPLICATO: MezzoModello [ID {id}] - Violazione PK.";
                        result.DuplicateDetails.Add(errorMsg);
                        _logger.LogWarning(errorMsg);
                    }
                    catch (PostgresException ex) when (ex.SqlState == "23503") // Foreign key violation
                    {
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string id = row["MEZZO_MODELLO_ID"]?.ToString() ?? "N/A";
                        string errorMsg = $"FK VIOLATION: MezzoModello [ID {id}] - {ex.Message}";
                        result.Errors.Add(errorMsg);
                        _logger.LogWarning(errorMsg);
                    }
                    catch (Exception ex)
                    {
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string id = row["MEZZO_MODELLO_ID"]?.ToString() ?? "N/A";
                        string errorMsg = $"ERRORE RIGA [ID {id}]: {ex.Message}";
                        result.Errors.Add(errorMsg);
                        _logger.LogError(ex, errorMsg);
                    }
                }
                result.RecordsWritten = processedCount;

                // Creazione/Sincronizzazione Sequence
                await new NpgsqlCommand("CREATE SEQUENCE IF NOT EXISTS ana_mezzi_modelli_seq", connection, transaction).ExecuteNonQueryAsync();
                await new NpgsqlCommand($"SELECT setval('public.ana_mezzi_modelli_seq', (SELECT COALESCE(MAX(mezzo_modello_id), 1) FROM public.{tableName}))", connection, transaction).ExecuteScalarAsync();

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
            _logger.LogError(ex, "Errore durante l'importazione Excel AnaMezziModelli");
            throw;
        }

        return result;
    }

    private async Task UpsertMezzoModelloAsync(NpgsqlConnection connection, DataRow row, NpgsqlTransaction transaction)
    {
        // Mappatura campi da Excel
        int id = Convert.ToInt32(row["MEZZO_MODELLO_ID"]);
        string descrizione = row["MEZZO_MODELLO_DESCRIZIONE"]?.ToString() ?? throw new InvalidDataException("MEZZO_MODELLO_DESCRIZIONE obbligatorio");
        int mezzoFk = Convert.ToInt32(row["MEZZO_MODELLO_MEZZO_FK"]);
        int? tipoFk = GetInt(row, "MEZZO_MODELLO_TIPO_FK");

        var sql = @"
            INSERT INTO ana_mezzi_modelli (
                mezzo_modello_id,
                mezzo_modello_descrizione,
                mezzo_modello_mezzo_fk,
                mezzo_modello_tipo_fk
            ) VALUES (
                @id,
                @descrizione,
                @mezzoFk,
                @tipoFk
            )
            ON CONFLICT (mezzo_modello_id) DO UPDATE SET
                mezzo_modello_descrizione = EXCLUDED.mezzo_modello_descrizione,
                mezzo_modello_mezzo_fk = EXCLUDED.mezzo_modello_mezzo_fk,
                mezzo_modello_tipo_fk = EXCLUDED.mezzo_modello_tipo_fk;
        ";

        await using var cmd = new NpgsqlCommand(sql, connection, transaction);

        cmd.Parameters.AddWithValue("id", id);
        cmd.Parameters.AddWithValue("descrizione", descrizione);
        cmd.Parameters.AddWithValue("mezzoFk", mezzoFk);
        cmd.Parameters.AddWithValue("tipoFk", (object?)tipoFk ?? DBNull.Value);

        await cmd.ExecuteNonQueryAsync();
    }

    private int? GetInt(DataRow row, string col) => row.Table.Columns.Contains(col) && row[col] != DBNull.Value && int.TryParse(row[col].ToString(), out int v) ? v : null;
}
