using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Service per gestione CRUD ana_regimi_fiscali.
/// Tabella system-level (NON multi-tenant).
/// AOT compatibile - no Dapper/Reflection.Emit
/// </summary>
public class AnaRegimiFiscaliService
{
    private readonly IDatabaseService _dbService;
    private readonly ILogger<AnaRegimiFiscaliService> _logger;

    public AnaRegimiFiscaliService(IDatabaseService dbService, ILogger<AnaRegimiFiscaliService> logger)
    {
        _dbService = dbService;
        _logger = logger;
    }

    // ==========================================
    // READ
    // ==========================================

    public async Task<IEnumerable<AnaRegimeFiscale>> GetAllAsync()
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            const string sql = "SELECT * FROM ana_regimi_fiscali ORDER BY regime_codice";

            await using var cmd = new NpgsqlCommand(sql, conn);
            var results = new List<AnaRegimeFiscale>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero dei regimi fiscali");
            return Enumerable.Empty<AnaRegimeFiscale>();
        }
    }

    public async Task<IEnumerable<AnaRegimeFiscale>> GetActiveAsync()
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            const string sql = "SELECT * FROM ana_regimi_fiscali WHERE attivo = TRUE ORDER BY regime_codice";

            await using var cmd = new NpgsqlCommand(sql, conn);
            var results = new List<AnaRegimeFiscale>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero dei regimi fiscali attivi");
            return Enumerable.Empty<AnaRegimeFiscale>();
        }
    }

    public async Task<AnaRegimeFiscale?> GetByIdAsync(int id)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            const string sql = "SELECT * FROM ana_regimi_fiscali WHERE regime_id = @Id";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", id);

            await using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero regime fiscale {Id}", id);
            return null;
        }
    }

    public async Task<AnaRegimeFiscale?> GetByCodiceAsync(string codice)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            const string sql = "SELECT * FROM ana_regimi_fiscali WHERE regime_codice = @Codice";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Codice", codice.ToUpper());

            await using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero regime fiscale per codice {Codice}", codice);
            return null;
        }
    }

    // ==========================================
    // CREATE
    // ==========================================

    public async Task<int> CreateAsync(AnaRegimeFiscale item)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            item.RegimeCodice = item.RegimeCodice?.ToUpper() ?? throw new ArgumentNullException(nameof(item.RegimeCodice));

            const string sql = @"
                INSERT INTO ana_regimi_fiscali (
                    regime_codice, regime_descrizione,
                    show_helper_calcolo, default_aliquota_iva_codice, is_iva_detraibile,
                    cassa_prev_percentuale, cassa_prev_descrizione, cassa_prev_aliquota_codice,
                    bollo_soglia, bollo_importo, bollo_aliquota_codice,
                    regime_codice_sdi, tipo_cassa_sdi,
                    attivo, created_at, created_by
                ) VALUES (
                    @RegimeCodice, @RegimeDescrizione,
                    @ShowHelperCalcolo, @DefaultAliquotaIvaCodice, @IsIvaDetraibile,
                    @CassaPrevPercentuale, @CassaPrevDescrizione, @CassaPrevAliquotaCodice,
                    @BolloSoglia, @BolloImporto, @BolloAliquotaCodice,
                    @RegimeCodiceSdi, @TipoCassaSdi,
                    @Attivo, NOW(), @CreatedBy
                )
                RETURNING regime_id";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("RegimeCodice", item.RegimeCodice);
            cmd.Parameters.AddWithValue("RegimeDescrizione", item.RegimeDescrizione);
            cmd.Parameters.AddWithValue("ShowHelperCalcolo", item.ShowHelperCalcolo);
            cmd.Parameters.AddWithValue("DefaultAliquotaIvaCodice", (object?)item.DefaultAliquotaIvaCodice ?? DBNull.Value);
            cmd.Parameters.AddWithValue("IsIvaDetraibile", item.IsIvaDetraibile);
            cmd.Parameters.AddWithValue("CassaPrevPercentuale", (object?)item.CassaPrevPercentuale ?? DBNull.Value);
            cmd.Parameters.AddWithValue("CassaPrevDescrizione", (object?)item.CassaPrevDescrizione ?? DBNull.Value);
            cmd.Parameters.AddWithValue("CassaPrevAliquotaCodice", (object?)item.CassaPrevAliquotaCodice ?? DBNull.Value);
            cmd.Parameters.AddWithValue("BolloSoglia", (object?)item.BolloSoglia ?? DBNull.Value);
            cmd.Parameters.AddWithValue("BolloImporto", (object?)item.BolloImporto ?? DBNull.Value);
            cmd.Parameters.AddWithValue("BolloAliquotaCodice", (object?)item.BolloAliquotaCodice ?? DBNull.Value);
            cmd.Parameters.AddWithValue("RegimeCodiceSdi", (object?)item.RegimeCodiceSdi ?? DBNull.Value);
            cmd.Parameters.AddWithValue("TipoCassaSdi", (object?)item.TipoCassaSdi ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Attivo", item.Attivo);
            cmd.Parameters.AddWithValue("CreatedBy", (object?)item.CreatedBy ?? DBNull.Value);

            var result = await cmd.ExecuteScalarAsync();
            return Convert.ToInt32(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nella creazione regime fiscale");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "il regime fiscale");
        }
    }

    // ==========================================
    // UPDATE
    // ==========================================

    public async Task UpdateAsync(AnaRegimeFiscale item)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            item.RegimeCodice = item.RegimeCodice?.ToUpper() ?? throw new ArgumentNullException(nameof(item.RegimeCodice));

            const string sql = @"
                UPDATE ana_regimi_fiscali SET
                    regime_codice = @RegimeCodice,
                    regime_descrizione = @RegimeDescrizione,
                    show_helper_calcolo = @ShowHelperCalcolo,
                    default_aliquota_iva_codice = @DefaultAliquotaIvaCodice,
                    is_iva_detraibile = @IsIvaDetraibile,
                    cassa_prev_percentuale = @CassaPrevPercentuale,
                    cassa_prev_descrizione = @CassaPrevDescrizione,
                    cassa_prev_aliquota_codice = @CassaPrevAliquotaCodice,
                    bollo_soglia = @BolloSoglia,
                    bollo_importo = @BolloImporto,
                    bollo_aliquota_codice = @BolloAliquotaCodice,
                    regime_codice_sdi = @RegimeCodiceSdi,
                    tipo_cassa_sdi = @TipoCassaSdi,
                    attivo = @Attivo,
                    updated_by = @UpdatedBy
                WHERE regime_id = @RegimeId";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("RegimeCodice", item.RegimeCodice);
            cmd.Parameters.AddWithValue("RegimeDescrizione", item.RegimeDescrizione);
            cmd.Parameters.AddWithValue("ShowHelperCalcolo", item.ShowHelperCalcolo);
            cmd.Parameters.AddWithValue("DefaultAliquotaIvaCodice", (object?)item.DefaultAliquotaIvaCodice ?? DBNull.Value);
            cmd.Parameters.AddWithValue("IsIvaDetraibile", item.IsIvaDetraibile);
            cmd.Parameters.AddWithValue("CassaPrevPercentuale", (object?)item.CassaPrevPercentuale ?? DBNull.Value);
            cmd.Parameters.AddWithValue("CassaPrevDescrizione", (object?)item.CassaPrevDescrizione ?? DBNull.Value);
            cmd.Parameters.AddWithValue("CassaPrevAliquotaCodice", (object?)item.CassaPrevAliquotaCodice ?? DBNull.Value);
            cmd.Parameters.AddWithValue("BolloSoglia", (object?)item.BolloSoglia ?? DBNull.Value);
            cmd.Parameters.AddWithValue("BolloImporto", (object?)item.BolloImporto ?? DBNull.Value);
            cmd.Parameters.AddWithValue("BolloAliquotaCodice", (object?)item.BolloAliquotaCodice ?? DBNull.Value);
            cmd.Parameters.AddWithValue("RegimeCodiceSdi", (object?)item.RegimeCodiceSdi ?? DBNull.Value);
            cmd.Parameters.AddWithValue("TipoCassaSdi", (object?)item.TipoCassaSdi ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Attivo", item.Attivo);
            cmd.Parameters.AddWithValue("UpdatedBy", (object?)item.UpdatedBy ?? DBNull.Value);
            cmd.Parameters.AddWithValue("RegimeId", item.RegimeId);

            await cmd.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nell'aggiornamento regime fiscale {Id}", item.RegimeId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "il regime fiscale");
        }
    }

    // ==========================================
    // DELETE
    // ==========================================

    public async Task DeleteAsync(int id)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            const string sql = "DELETE FROM ana_regimi_fiscali WHERE regime_id = @Id";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", id);
            await cmd.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nella cancellazione regime fiscale {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "il regime fiscale");
        }
    }

    #region Mapping Helpers (AOT compatibili)

    private static AnaRegimeFiscale MapFromReader(NpgsqlDataReader reader)
    {
        return new AnaRegimeFiscale
        {
            RegimeId = reader.GetInt32(reader.GetOrdinal("regime_id")),
            RegimeCodice = reader.GetString(reader.GetOrdinal("regime_codice")),
            RegimeDescrizione = reader.GetString(reader.GetOrdinal("regime_descrizione")),
            ShowHelperCalcolo = reader.GetBoolean(reader.GetOrdinal("show_helper_calcolo")),
            DefaultAliquotaIvaCodice = GetNullableString(reader, "default_aliquota_iva_codice"),
            IsIvaDetraibile = reader.GetBoolean(reader.GetOrdinal("is_iva_detraibile")),
            CassaPrevPercentuale = GetNullableDecimal(reader, "cassa_prev_percentuale"),
            CassaPrevDescrizione = GetNullableString(reader, "cassa_prev_descrizione"),
            CassaPrevAliquotaCodice = GetNullableString(reader, "cassa_prev_aliquota_codice"),
            BolloSoglia = GetNullableDecimal(reader, "bollo_soglia"),
            BolloImporto = GetNullableDecimal(reader, "bollo_importo"),
            BolloAliquotaCodice = GetNullableString(reader, "bollo_aliquota_codice"),
            RegimeCodiceSdi = GetNullableString(reader, "regime_codice_sdi"),
            TipoCassaSdi = GetNullableString(reader, "tipo_cassa_sdi"),
            Attivo = reader.GetBoolean(reader.GetOrdinal("attivo")),
            Created = GetNullableDateTime(reader, "created_at"),
            CreatedBy = GetNullableString(reader, "created_by"),
            Updated = GetNullableDateTime(reader, "updated_at"),
            UpdatedBy = GetNullableString(reader, "updated_by")
        };
    }

    private static string? GetNullableString(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }

    private static decimal? GetNullableDecimal(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetDecimal(ordinal);
    }

    private static DateTime? GetNullableDateTime(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetDateTime(ordinal);
    }

    #endregion
}
