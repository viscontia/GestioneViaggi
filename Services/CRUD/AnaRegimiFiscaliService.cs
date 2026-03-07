using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Service per gestione CRUD ana_regimi_fiscali.
/// Tabella system-level (NON multi-tenant).
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
    // SQL SELECT comune
    // ==========================================

    private const string SelectColumns = @"
        regime_id AS RegimeId,
        regime_codice AS RegimeCodice,
        regime_descrizione AS RegimeDescrizione,
        show_helper_calcolo AS ShowHelperCalcolo,
        default_aliquota_iva_codice AS DefaultAliquotaIvaCodice,
        is_iva_detraibile AS IsIvaDetraibile,
        cassa_prev_percentuale AS CassaPrevPercentuale,
        cassa_prev_descrizione AS CassaPrevDescrizione,
        cassa_prev_aliquota_codice AS CassaPrevAliquotaCodice,
        bollo_soglia AS BolloSoglia,
        bollo_importo AS BolloImporto,
        bollo_aliquota_codice AS BolloAliquotaCodice,
        regime_codice_sdi AS RegimeCodiceSdi,
        tipo_cassa_sdi AS TipoCassaSdi,
        attivo AS Attivo,
        created_at AS Created,
        created_by AS CreatedBy,
        updated_at AS Updated,
        updated_by AS UpdatedBy";

    // ==========================================
    // READ
    // ==========================================

    public async Task<IEnumerable<AnaRegimeFiscale>> GetAllAsync()
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();

            var sql = $"SELECT {SelectColumns} FROM ana_regimi_fiscali ORDER BY regime_codice";

            return await conn.QueryAsync<AnaRegimeFiscale>(sql);
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
            using var conn = await _dbService.GetConnectionAsync();

            var sql = $"SELECT {SelectColumns} FROM ana_regimi_fiscali WHERE attivo = TRUE ORDER BY regime_codice";

            return await conn.QueryAsync<AnaRegimeFiscale>(sql);
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
            using var conn = await _dbService.GetConnectionAsync();

            var sql = $"SELECT {SelectColumns} FROM ana_regimi_fiscali WHERE regime_id = @Id";

            return await conn.QuerySingleOrDefaultAsync<AnaRegimeFiscale>(sql, new { Id = id });
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
            using var conn = await _dbService.GetConnectionAsync();

            var sql = $"SELECT {SelectColumns} FROM ana_regimi_fiscali WHERE regime_codice = @Codice";

            return await conn.QuerySingleOrDefaultAsync<AnaRegimeFiscale>(sql, new { Codice = codice.ToUpper() });
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
            using var conn = await _dbService.GetConnectionAsync();

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

            return await conn.ExecuteScalarAsync<int>(sql, item);
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
            using var conn = await _dbService.GetConnectionAsync();

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

            await conn.ExecuteAsync(sql, item);
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
            using var conn = await _dbService.GetConnectionAsync();

            const string sql = "DELETE FROM ana_regimi_fiscali WHERE regime_id = @Id";

            await conn.ExecuteAsync(sql, new { Id = id });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nella cancellazione regime fiscale {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "il regime fiscale");
        }
    }
}
