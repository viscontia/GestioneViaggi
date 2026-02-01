using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.CRUD;

public class MovTransazioniService
{
    private readonly IDatabaseService _dbService;
    private readonly ILogger<MovTransazioniService> _logger;

    public MovTransazioniService(IDatabaseService dbService, ILogger<MovTransazioniService> logger)
    {
        _dbService = dbService;
        _logger = logger;
    }

    /// <summary>
    /// Recupera tutte le transazioni per una data Azienda, includendo dettagli Fornitore e Valuta.
    /// Ordinamento decrescente per Data Transazione.
    /// </summary>
    public async Task<IEnumerable<MovTransazioni>> GetByAziendaAsync(int aziendaId)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            string sql = @"
                SELECT 
                    t.*,
                    f.ragione_sociale as FornitoreRagioneSociale,
                    v.valuta_codice_iso as ValutaCodiceIso,
                    vi.descrizione_breve as ViaggioDescrizione
                FROM mov_transazioni t
                JOIN ana_fornitori f ON t.transazione_fornitore_id = f.fornitore_id
                JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
                LEFT JOIN ana_viaggi vi ON t.transazione_viaggio_id = vi.viaggio_id
                WHERE t.transazione_azienda_id = @AziendaId
                ORDER BY t.transazione_data DESC, t.created_at DESC";

            return await conn.QueryAsync<MovTransazioni>(sql, new { AziendaId = aziendaId });
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
                    f.ragione_sociale as FornitoreRagioneSociale,
                    v.valuta_codice_iso as ValutaCodiceIso
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

    public async Task<int> CreateAsync(MovTransazioni item)
    {
        try
        {
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
                    NOW(),
                    @CreatedBy
                ) RETURNING transazione_id";

            // Nota: transazione_importo_eur è calcolato dal trigger DB
            return await conn.ExecuteScalarAsync<int>(sql, item);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nella creazione transazione");
            throw;
        }
    }

    public async Task UpdateAsync(MovTransazioni item)
    {
        try
        {
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
                    updated_at = NOW(),
                    updated_by = @UpdatedBy
                WHERE transazione_id = @TransazioneId";

            await conn.ExecuteAsync(sql, item);
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
