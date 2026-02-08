using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Models.DTOs;
using GestioneViaggi.Services.Shared;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.CRUD;

public class MovTransazioniService
{
    private readonly IDatabaseService _dbService;
    private readonly ILogger<MovTransazioniService> _logger;
    private readonly IExchangeRateService _exchangeRateService;
    private readonly AnaValuteService _valuteService;

    public MovTransazioniService(
        IDatabaseService dbService,
        ILogger<MovTransazioniService> logger,
        IExchangeRateService exchangeRateService,
        AnaValuteService valuteService)
    {
        _dbService = dbService;
        _logger = logger;
        _exchangeRateService = exchangeRateService;
        _valuteService = valuteService;
    }

    /// <summary>
    /// Recupera i viaggi distinti che hanno transazioni
    /// </summary>
    public async Task<IEnumerable<AnaViaggi>> GetDistinctViaggiAsync(int? aziendaId)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            string sql = "SELECT * FROM fn_get_viaggi_with_transazioni(@AziendaId)";
            var result = await conn.QueryAsync<AnaViaggi>(sql, new { AziendaId = aziendaId });
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero viaggi con transazioni per azienda {AziendaId}", aziendaId);
            return Enumerable.Empty<AnaViaggi>();
        }
    }

    /// <summary>
    /// Recupera le date viaggio distinte che hanno transazioni per un dato viaggio
    /// </summary>
    public async Task<IEnumerable<DataViaggioDTO>> GetDistinctDateViaggiAsync(int viaggioId)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            string sql = "SELECT * FROM fn_get_date_viaggi_with_transazioni(@ViaggioId)";
            var result = await conn.QueryAsync<DataViaggioDTO>(sql, new { ViaggioId = viaggioId });
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero date viaggi con transazioni per viaggio {ViaggioId}", viaggioId);
            return Enumerable.Empty<DataViaggioDTO>();
        }
    }

    /// <summary>
    /// Recupera tutte le transazioni di tutte le aziende, con filtri opzionali.
    /// Utilizzato da SuperAdmin per visualizzare tutto.
    /// Ordinamento decrescente per Data Transazione.
    /// </summary>
    public async Task<IEnumerable<MovTransazioni>> GetAllAsync(
        int? viaggioId = null,
        int? dataViaggioId = null,
        DateTime? dataTransazione = null,
        bool soloDaPagare = false)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            string sql = "SELECT * FROM fn_get_all_transazioni(@ViaggioId, @DataViaggioId, @DataTransazione, @SoloDaPagare)";

            var result = await conn.QueryAsync<MovTransazioni>(sql, new
            {
                ViaggioId = viaggioId,
                DataViaggioId = dataViaggioId,
                DataTransazione = dataTransazione,
                SoloDaPagare = soloDaPagare
            });

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero di tutte le transazioni");
            return Enumerable.Empty<MovTransazioni>();
        }
    }

    /// <summary>
    /// Recupera tutte le transazioni per una data Azienda, con filtri opzionali.
    /// Ordinamento decrescente per Data Transazione.
    /// </summary>
    public async Task<IEnumerable<MovTransazioni>> GetByAziendaAsync(
        int aziendaId,
        int? viaggioId = null,
        int? dataViaggioId = null,
        DateTime? dataTransazione = null,
        bool soloDaPagare = false)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            string sql = "SELECT * FROM fn_get_transazioni_by_azienda(@AziendaId, @ViaggioId, @DataViaggioId, @DataTransazione, @SoloDaPagare)";

            var result = await conn.QueryAsync<MovTransazioni>(sql, new
            {
                AziendaId = aziendaId,
                ViaggioId = viaggioId,
                DataViaggioId = dataViaggioId,
                DataTransazione = dataTransazione,
                SoloDaPagare = soloDaPagare
            });

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero transazioni per azienda {AziendaId}", aziendaId);
            return Enumerable.Empty<MovTransazioni>();
        }
    }

    public async Task<MovTransazioni?> GetByIdAsync(int id)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            string sql = @"
                SELECT
                    t.*,
                    f.ragione_sociale as fornitore_ragione_sociale,
                    v.valuta_codice_iso as valuta_codice_iso
                FROM mov_transazioni t
                JOIN ana_fornitori f ON t.transazione_fornitore_id = f.fornitore_id
                JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
                WHERE t.transazione_id = @Id";

            return await conn.QueryFirstOrDefaultAsync<MovTransazioni>(sql, new { Id = id });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero transazione {Id}", id);
            return null;
        }
    }

    public async Task<(int TransazioneId, string? WarningMessage)> CreateAsync(MovTransazioni item)
    {
        string? warningMessage = null;

        try
        {
            // =============================================
            // STEP 1: Recupero automatico tasso di cambio se valuta != EUR
            // =============================================
                var valuta = await _valuteService.GetByIdAsync(item.TransazioneValutaId);

            if (valuta != null && !valuta.ValutaIsBase && item.TransazioneDataDocumento.HasValue)
            {
                _logger.LogInformation(
                    "Recupero tasso di cambio per {ValutaIso} alla data documento {DataDoc}",
                    valuta.ValutaCodiceIso,
                    item.TransazioneDataDocumento.Value.ToString("yyyy-MM-dd"));

                (bool success, string message) = await _exchangeRateService.UpdateRateForDateAsync(
                    valuta.ValutaCodiceIso,
                    item.TransazioneDataDocumento.Value);

                if (!success)
                {
                    // API fallita o timeout - verrà usato il fallback dal DB
                    warningMessage = message;
                    _logger.LogWarning("Fallback: {Message}", message);
                }
                else
                {
                    _logger.LogInformation("Tasso aggiornato con successo: {Message}", message);
                }
            }

            // =============================================
            // STEP 2: Inserimento della transazione (il trigger calcolerà l'importo EUR)
            // =============================================
            using var conn = await _dbService.GetConnectionAsync();
            string sql = @"
                INSERT INTO mov_transazioni (
                    transazione_azienda_id,
                    transazione_viaggio_id,
                    transazione_data_viaggio_id,
                    transazione_fornitore_id,
                    transazione_tipo_movimento,
                    transazione_importo,
                    transazione_valuta_id,
                    transazione_data,
                    transazione_data_scadenza,
                    transazione_data_pagamento,
                    transazione_stato,
                    transazione_causale,
                    transazione_note,
                    transazione_numero_documento,
                    transazione_data_documento,
                    created_at,
                    created_by
                ) VALUES (
                    @TransazioneAziendaId,
                    @TransazioneViaggioId,
                    @TransazioneDataViaggioId,
                    @TransazioneFornitoreId,
                    @TransazioneTipoMovimento,
                    @TransazioneImporto,
                    @TransazioneValutaId,
                    @TransazioneData,
                    @TransazioneDataScadenza,
                    @TransazioneDataPagamento,
                    @TransazioneStato,
                    @TransazioneCausale,
                    @TransazioneNote,
                    @TransazioneNumeroDocumento,
                    @TransazioneDataDocumento,
                    NOW(),
                    @CreatedBy
                ) RETURNING transazione_id";

            // Nota: transazione_importo_eur, tasso_cambio_applicato, tasso_fonte, tasso_data_validita
            //       sono tutti calcolati automaticamente dal trigger trg_calcola_importo_eur
            int transazioneId = await conn.ExecuteScalarAsync<int>(sql, item);

            return (transazioneId, warningMessage);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nella creazione transazione");
            throw;
        }
    }

    public async Task<string?> UpdateAsync(MovTransazioni item)
    {
        string? warningMessage = null;

        try
        {
            // =============================================
            // STEP 1: Recupero automatico tasso di cambio se valuta != EUR
            // =============================================
                var valuta = await _valuteService.GetByIdAsync(item.TransazioneValutaId);

            if (valuta != null && !valuta.ValutaIsBase && item.TransazioneDataDocumento.HasValue)
            {
                _logger.LogInformation(
                    "Recupero tasso di cambio per {ValutaIso} alla data documento {DataDoc}",
                    valuta.ValutaCodiceIso,
                    item.TransazioneDataDocumento.Value.ToString("yyyy-MM-dd"));

                (bool success, string message) = await _exchangeRateService.UpdateRateForDateAsync(
                    valuta.ValutaCodiceIso,
                    item.TransazioneDataDocumento.Value);

                if (!success)
                {
                    // API fallita o timeout - verrà usato il fallback dal DB
                    warningMessage = message;
                    _logger.LogWarning("Fallback: {Message}", message);
                }
                else
                {
                    _logger.LogInformation("Tasso aggiornato con successo: {Message}", message);
                }
            }

            // =============================================
            // STEP 2: Aggiornamento della transazione (il trigger ricalcolerà l'importo EUR)
            // =============================================
            using var conn = await _dbService.GetConnectionAsync();
            string sql = @"
                UPDATE mov_transazioni SET
                    transazione_viaggio_id = @TransazioneViaggioId,
                    transazione_data_viaggio_id = @TransazioneDataViaggioId,
                    transazione_fornitore_id = @TransazioneFornitoreId,
                    transazione_tipo_movimento = @TransazioneTipoMovimento,
                    transazione_importo = @TransazioneImporto,
                    transazione_valuta_id = @TransazioneValutaId,
                    transazione_data = @TransazioneData,
                    transazione_data_scadenza = @TransazioneDataScadenza,
                    transazione_data_pagamento = @TransazioneDataPagamento,
                    transazione_stato = @TransazioneStato,
                    transazione_causale = @TransazioneCausale,
                    transazione_note = @TransazioneNote,
                    transazione_numero_documento = @TransazioneNumeroDocumento,
                    transazione_data_documento = @TransazioneDataDocumento,
                    updated_at = NOW(),
                    updated_by = @UpdatedBy
                WHERE transazione_id = @TransazioneId";

            await conn.ExecuteAsync(sql, item);

            return warningMessage;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nell'aggiornamento transazione {Id}", item.TransazioneId);
            throw;
        }
    }

    public async Task DeleteAsync(int id)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            await conn.ExecuteAsync("DELETE FROM mov_transazioni WHERE transazione_id = @Id", new { Id = id });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nella cancellazione transazione {Id}", id);
            throw;
        }
    }
}
