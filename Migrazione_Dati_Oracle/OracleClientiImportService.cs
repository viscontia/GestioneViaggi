using System.Data;
using ExcelDataReader;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Migrazione_Dati_Oracle;

public class ImportResult
{
    public int RecordsRead { get; set; }
    public int RecordsWritten { get; set; }
    public int DbCountBefore { get; set; }
    public int DbCountAfter { get; set; }
    public int Delta => DbCountAfter - DbCountBefore;
    public List<string> DuplicateDetails { get; set; } = new();
    public List<string> Errors { get; set; } = new();
}

public class OracleClientiImportService
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<OracleClientiImportService> _logger;

    public OracleClientiImportService(IDatabaseService databaseService, ILogger<OracleClientiImportService> logger)
    {
        _databaseService = databaseService;
        _logger = logger;

        // Ensure ExcelDataReader encoding provider is registered
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
            await new NpgsqlCommand($"SELECT setval('public.ana_clienti_seq', (SELECT MAX(cliente_id) FROM public.ana_clienti))", connection, transaction).ExecuteScalarAsync();

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

    public async Task<ImportResult> ImportFromExcelAsync(string filePath, string tableName = "ana_clienti", bool dryRun = false)
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
                        // SAVEPOINT logic is critical for Partial Rollback on unique constraints
                        await new NpgsqlCommand("SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        await UpsertClienteAsync(connection, row, transaction);

                        await new NpgsqlCommand("RELEASE SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();
                        processedCount++;
                    }
                    catch (PostgresException ex) when (ex.SqlState == "23505") // Unique violation
                    {
                        // Restore transaction state to savepoint, keeping the main transaction alive
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string id = row["CLIENTE_ID"]?.ToString() ?? "N/A";
                        string cognome = row["CLIENTE_COGNOME"]?.ToString() ?? "N/A";
                        string nome = row["CLIENTE_NOME"]?.ToString() ?? "N/A";
                        string cf = row["CLIENTE_CODICEFISCALE"]?.ToString() ?? "N/A";

                        string errorMsg = $"DUPLICATO: {cognome} {nome} (CF: {cf}) [Excel ID: {id}] - Violazione vincolo unicità.";
                        result.DuplicateDetails.Add(errorMsg);
                        _logger.LogWarning(errorMsg);
                    }
                    catch (Exception ex)
                    {
                        // Also Rollback to savepoint for other errors inside loop
                        await new NpgsqlCommand("ROLLBACK TO SAVEPOINT sp_row", connection, transaction).ExecuteNonQueryAsync();

                        string id = row["CLIENTE_ID"]?.ToString() ?? "N/A";
                        string errorMsg = $"ERRORE RIGA [ID {id}]: {ex.Message}";
                        result.Errors.Add(errorMsg);
                        _logger.LogError(ex, errorMsg);
                    }
                }
                result.RecordsWritten = processedCount;

                using var cmdSeq = new NpgsqlCommand("SELECT setval('public.ana_clienti_seq', (SELECT MAX(cliente_id) FROM public.ana_clienti))", connection, transaction);
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
            _logger.LogError(ex, "Errore durante l'importazione Excel");
            throw;
        }

        return result;
    }

    private async Task UpsertClienteAsync(NpgsqlConnection connection, DataRow row, NpgsqlTransaction transaction)
    {
        // 1. Map Data
        int clienteId = Convert.ToInt32(row["CLIENTE_ID"]);
        string oracleUser = row["CREATED_BY"]?.ToString() ?? "UNKNOWN";
        var (aziendaFk, createdBy) = MapUserToAzienda(oracleUser);

        string? titolo = GetString(row, "CLIENTE_TITOLO");
        string cognome = GetString(row, "CLIENTE_COGNOME") ?? "UNKNOWN";
        string nome = GetString(row, "CLIENTE_NOME") ?? "UNKNOWN";
        string sesso = GetString(row, "CLIENTE_SESSO") ?? "M";

        int? comuneResFk = GetInt(row, "CLIENTE_COMUNE_RESIDENZA_FK") ?? 0;
        string? indirizzo = GetString(row, "CLIENTE_INDIRIZZO_RESIDENZA");
        int? comuneNasFk = GetInt(row, "CLIENTE_COMUNE_NASCITA_FK") ?? 0;
        DateTime? dataNascita = GetDate(row, "CLIENTE_DATA_NASCITA");

        string? tipoDoc = GetString(row, "CLIENTE_TIPODOC_IDENTITA");
        string? numDoc = GetString(row, "CLIENTE_DOCUMENTO_NUMERO");
        string? rilascioDa = GetString(row, "CLIENTE_DOCUMENTO_RILASCIATO_DA");
        DateTime? dataRilascio = GetDate(row, "CLIENTE_DOCUMENTO_RILASCIATO_DATA");
        DateTime? dataScadenza = GetDate(row, "CLIENTE_DOCUMENTO_RILASCIATO_SCADENZA");

        var sql = @"
            INSERT INTO ana_clienti (
                cliente_id, cliente_titolo, cliente_cognome, cliente_nome, cliente_sesso,
                cliente_comune_residenza_fk, cliente_indirizzo_residenza, 
                cliente_comune_nascita_fk, cliente_data_nascita,
                cliente_preftelint, cliente_telefono, cliente_email, 
                cliente_codicefiscale, cliente_iban,
                cliente_note, cliente_intolleranza,
                cliente_tipodoc_identita, cliente_documento_numero,
                cliente_documento_rilasciato_da, cliente_documento_rilasciato_data,
                cliente_documento_rilasciato_scadenza,
                azienda_fk, created_by, created, updated_by, updated
            ) VALUES (
                @id, @titolo, @cognome, @nome, @sesso,
                @comuneRes, @indirizzo,
                @comuneNas, @dataNas,
                @prefTel, @tel, @email,
                @cf, @iban,
                @note, @intolleranza,
                @tipoDoc, @numDoc,
                @rilascioDa, @dataRilascio,
                @dataScadenza,
                @azienda, @createdBy, @created, NULL, NULL
            )
            ON CONFLICT (cliente_id) DO UPDATE SET
                cliente_titolo = EXCLUDED.cliente_titolo,
                cliente_cognome = EXCLUDED.cliente_cognome,
                cliente_nome = EXCLUDED.cliente_nome,
                cliente_sesso = EXCLUDED.cliente_sesso,
                cliente_comune_residenza_fk = EXCLUDED.cliente_comune_residenza_fk,
                cliente_indirizzo_residenza = EXCLUDED.cliente_indirizzo_residenza,
                cliente_comune_nascita_fk = EXCLUDED.cliente_comune_nascita_fk,
                cliente_data_nascita = EXCLUDED.cliente_data_nascita,
                cliente_preftelint = EXCLUDED.cliente_preftelint,
                cliente_telefono = EXCLUDED.cliente_telefono,
                cliente_email = EXCLUDED.cliente_email,
                cliente_codicefiscale = EXCLUDED.cliente_codicefiscale,
                cliente_iban = EXCLUDED.cliente_iban,
                cliente_note = EXCLUDED.cliente_note,
                cliente_intolleranza = EXCLUDED.cliente_intolleranza,
                cliente_tipodoc_identita = EXCLUDED.cliente_tipodoc_identita,
                cliente_documento_numero = EXCLUDED.cliente_documento_numero,
                cliente_documento_rilasciato_da = EXCLUDED.cliente_documento_rilasciato_da,
                cliente_documento_rilasciato_data = EXCLUDED.cliente_documento_rilasciato_data,
                cliente_documento_rilasciato_scadenza = EXCLUDED.cliente_documento_rilasciato_scadenza,
                azienda_fk = EXCLUDED.azienda_fk,
                created_by = EXCLUDED.created_by,
                created = EXCLUDED.created,
                updated_by = NULL,
                updated = NULL;
        ";

        await using var cmd = new NpgsqlCommand(sql, connection, transaction);
        cmd.Parameters.AddWithValue("id", clienteId);
        cmd.Parameters.AddWithValue("titolo", (object?)titolo ?? DBNull.Value);
        cmd.Parameters.AddWithValue("cognome", cognome);
        cmd.Parameters.AddWithValue("nome", nome);
        cmd.Parameters.AddWithValue("sesso", sesso);
        cmd.Parameters.AddWithValue("comuneRes", (object?)comuneResFk ?? DBNull.Value);
        cmd.Parameters.AddWithValue("indirizzo", (object?)indirizzo ?? DBNull.Value);
        cmd.Parameters.AddWithValue("comuneNas", (object?)comuneNasFk ?? DBNull.Value);
        cmd.Parameters.AddWithValue("dataNas", (object?)dataNascita ?? DBNull.Value);

        cmd.Parameters.AddWithValue("prefTel", (object?)GetString(row, "CLIENTE_PREFTELINT") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("tel", (object?)GetString(row, "CLIENTE_TELEFONO") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("email", (object?)GetString(row, "CLIENTE_EMAIL") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("cf", (object?)GetString(row, "CLIENTE_CODICEFISCALE") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("iban", (object?)GetString(row, "CLIENTE_IBAN") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("note", (object?)GetString(row, "CLIENTE_NOTE") ?? DBNull.Value);
        cmd.Parameters.AddWithValue("intolleranza", (object?)GetString(row, "CLIENTE_INTOLLERANZA") ?? DBNull.Value);

        cmd.Parameters.AddWithValue("tipoDoc", (object?)tipoDoc ?? DBNull.Value);
        cmd.Parameters.AddWithValue("numDoc", (object?)numDoc ?? DBNull.Value);
        cmd.Parameters.AddWithValue("rilascioDa", (object?)rilascioDa ?? DBNull.Value);
        cmd.Parameters.AddWithValue("dataRilascio", (object?)dataRilascio ?? DBNull.Value);
        cmd.Parameters.AddWithValue("dataScadenza", (object?)dataScadenza ?? DBNull.Value);

        cmd.Parameters.AddWithValue("azienda", aziendaFk);
        cmd.Parameters.AddWithValue("createdBy", createdBy);
        DateTime createdDate = GetDate(row, "CREATED") ?? DateTime.UtcNow;
        cmd.Parameters.AddWithValue("created", createdDate);

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
    private DateTime? GetDate(DataRow row, string col) => row.Table.Columns.Contains(col) && row[col] != DBNull.Value && DateTime.TryParse(row[col].ToString(), out DateTime d) ? d : null;
}
