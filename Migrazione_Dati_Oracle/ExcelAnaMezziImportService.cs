using System.Data;
using ExcelDataReader;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Migrazione_Dati_Oracle;

public class ExcelAnaMezziImportService
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<ExcelAnaMezziImportService> _logger;

    public ExcelAnaMezziImportService(IDatabaseService databaseService, ILogger<ExcelAnaMezziImportService> logger)
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
            await new NpgsqlCommand("CREATE SEQUENCE IF NOT EXISTS ana_mezzi_seq", connection, transaction).ExecuteNonQueryAsync();
            await new NpgsqlCommand($"SELECT setval('public.ana_mezzi_seq', (SELECT COALESCE(MAX(ana_mezzi_id), 1) FROM public.ana_mezzi))", connection, transaction).ExecuteScalarAsync();

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

    public async Task<ImportResult> ImportFromExcelAsync(string filePath, string tableName = "ana_mezzi", bool dryRun = false)
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

                int processedCount = 0;
                foreach (DataRow row in infoTable.Rows)
                {
                    try
                    {
                        await new NpgsqlCommand("SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        await UpsertMezzoAsync(connection, row, transaction);

                        await new NpgsqlCommand("RELEASE SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();
                        processedCount++;
                    }
                    catch (PostgresException ex) when (ex.SqlState == "23505") // Unique violation
                    {
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string id = row["ANA_MEZZI_ID"]?.ToString() ?? "N/A";
                        string errorMsg = $"DUPLICATO: AnaMezzo [ID {id}] - Violazione UNIQUE constraint.";
                        result.DuplicateDetails.Add(errorMsg);
                        _logger.LogWarning(errorMsg);
                    }
                    catch (PostgresException ex) when (ex.SqlState == "23503") // Foreign key violation
                    {
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string id = row["ANA_MEZZI_ID"]?.ToString() ?? "N/A";
                        string errorMsg = $"FK VIOLATION: AnaMezzo [ID {id}] - {ex.Message}";
                        result.Errors.Add(errorMsg);
                        _logger.LogWarning(errorMsg);
                    }
                    catch (Exception ex)
                    {
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string id = row["ANA_MEZZI_ID"]?.ToString() ?? "N/A";
                        string errorMsg = $"ERRORE RIGA [ID {id}]: {ex.Message}";
                        result.Errors.Add(errorMsg);
                        _logger.LogError(ex, errorMsg);
                    }
                }
                result.RecordsWritten = processedCount;

                // Creazione/Sincronizzazione Sequence
                await new NpgsqlCommand("CREATE SEQUENCE IF NOT EXISTS ana_mezzi_seq", connection, transaction).ExecuteNonQueryAsync();
                await new NpgsqlCommand($"SELECT setval('public.ana_mezzi_seq', (SELECT COALESCE(MAX(ana_mezzi_id), 1) FROM public.{tableName}))", connection, transaction).ExecuteScalarAsync();

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
            _logger.LogError(ex, "Errore durante l'importazione Excel AnaMezzi");
            throw;
        }

        return result;
    }

    private async Task UpsertMezzoAsync(NpgsqlConnection connection, DataRow row, NpgsqlTransaction transaction)
    {
        // Mappatura campi da Excel
        int id = Convert.ToInt32(row["ANA_MEZZI_ID"]);
        string descrizione = row["ANA_MEZZI_DESCRIZIONE"]?.ToString() ?? throw new InvalidDataException("ANA_MEZZI_DESCRIZIONE obbligatorio");

        // Check se esiste già questa descrizione con un ID diverso
        var checkSql = "SELECT ana_mezzi_id FROM ana_mezzi WHERE ana_mezzi_descrizione = @descrizione LIMIT 1";
        await using var checkCmd = new NpgsqlCommand(checkSql, connection, transaction);
        checkCmd.Parameters.AddWithValue("descrizione", descrizione);
        var existingId = await checkCmd.ExecuteScalarAsync();

        if (existingId != null && Convert.ToInt32(existingId) != id)
        {
            // Esiste già con ID diverso - salta (il constraint UNIQUE sulla descrizione lo impedisce comunque)
            _logger.LogWarning("SALTATO: Mezzo '{Descrizione}' esiste già con ID {ExistingId}, Excel ha ID {NewId}",
                descrizione, existingId, id);
            return;
        }

        // Inserisci o aggiorna mantenendo la PK originale dall'Excel
        var sql = @"
            INSERT INTO ana_mezzi (
                ana_mezzi_id,
                ana_mezzi_descrizione
            ) VALUES (
                @id,
                @descrizione
            )
            ON CONFLICT (ana_mezzi_id)
            DO UPDATE SET
                ana_mezzi_descrizione = EXCLUDED.ana_mezzi_descrizione;
        ";

        await using var cmd = new NpgsqlCommand(sql, connection, transaction);

        cmd.Parameters.AddWithValue("id", id);
        cmd.Parameters.AddWithValue("descrizione", descrizione);

        await cmd.ExecuteNonQueryAsync();
    }
}
