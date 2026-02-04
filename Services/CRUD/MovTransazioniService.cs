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
    /// Recupera tutte le transazioni di tutte le aziende, includendo dettagli Fornitore e Valuta.
    /// Utilizzato da SuperAdmin per visualizzare tutto.
    /// Ordinamento decrescente per Data Transazione.
    /// </summary>
    public async Task<IEnumerable<MovTransazioni>> GetAllAsync()
    {
        try
        {
            _logger.LogInformation("GetAllAsync: Recupero di tutte le transazioni...");
            using var conn = await _dbService.GetConnectionAsync();

            // Query semplice senza JOIN
            string sql = @"SELECT * FROM mov_transazioni ORDER BY transazione_data DESC, created_at DESC";

            var result = await conn.QueryAsync<MovTransazioni>(sql);
            var resultList = result.ToList();

            _logger.LogInformation("GetAllAsync: Recuperate {Count} transazioni", resultList.Count);

            if (resultList.Count > 0)
            {
                // Carica dati correlati manualmente
                foreach (var item in resultList)
                {
                    // Imposta azienda_id come codice
                    item.AziendaCodice = item.TransazioneAziendaId.ToString();

                    // Query per fornitore
                    var fornitore = await conn.QueryFirstOrDefaultAsync<dynamic>(
                        "SELECT ragione_sociale FROM ana_fornitori WHERE fornitore_id = @Id",
                        new { Id = item.TransazioneFornitoreId });
                    if (fornitore != null)
                        item.FornitoreRagioneSociale = fornitore.ragione_sociale;

                    // Query per valuta
                    var valuta = await conn.QueryFirstOrDefaultAsync<dynamic>(
                        "SELECT valuta_codice_iso FROM ana_valute WHERE valuta_id = @Id",
                        new { Id = item.TransazioneValutaId });
                    if (valuta != null)
                        item.ValutaCodiceIso = valuta.valuta_codice_iso;

                    // Query per viaggio (opzionale)
                    if (item.TransazioneViaggioId.HasValue)
                    {
                        var viaggio = await conn.QueryFirstOrDefaultAsync<dynamic>(
                            "SELECT descrizione_breve FROM ana_viaggi WHERE viaggio_id = @Id",
                            new { Id = item.TransazioneViaggioId.Value });
                        if (viaggio != null)
                            item.ViaggioDescrizione = viaggio.descrizione_breve;
                    }
                }
            }

            return resultList;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero di tutte le transazioni");
            return Enumerable.Empty<MovTransazioni>();
        }
    }

    /// <summary>
    /// Recupera tutte le transazioni per una data Azienda, includendo dettagli Fornitore e Valuta.
    /// Ordinamento decrescente per Data Transazione.
    /// </summary>
    public async Task<IEnumerable<MovTransazioni>> GetByAziendaAsync(int aziendaId)
    {
        try
        {
            _logger.LogInformation("GetByAziendaAsync: Recupero transazioni per azienda {AziendaId}...", aziendaId);
            using var conn = await _dbService.GetConnectionAsync();

            // Query semplice senza JOIN
            string sql = @"
                SELECT * FROM mov_transazioni
                WHERE transazione_azienda_id = @AziendaId
                ORDER BY transazione_data DESC, created_at DESC";

            var result = await conn.QueryAsync<MovTransazioni>(sql, new { AziendaId = aziendaId });
            var resultList = result.ToList();

            _logger.LogInformation("GetByAziendaAsync: Recuperate {Count} transazioni per azienda {AziendaId}", resultList.Count, aziendaId);

            if (resultList.Count > 0)
            {
                // Carica dati correlati manualmente
                foreach (var item in resultList)
                {
                    // Imposta azienda_id come codice
                    item.AziendaCodice = item.TransazioneAziendaId.ToString();

                    // Query per fornitore
                    var fornitore = await conn.QueryFirstOrDefaultAsync<dynamic>(
                        "SELECT ragione_sociale FROM ana_fornitori WHERE fornitore_id = @Id",
                        new { Id = item.TransazioneFornitoreId });
                    if (fornitore != null)
                        item.FornitoreRagioneSociale = fornitore.ragione_sociale;

                    // Query per valuta
                    var valuta = await conn.QueryFirstOrDefaultAsync<dynamic>(
                        "SELECT valuta_codice_iso FROM ana_valute WHERE valuta_id = @Id",
                        new { Id = item.TransazioneValutaId });
                    if (valuta != null)
                        item.ValutaCodiceIso = valuta.valuta_codice_iso;

                    // Query per viaggio (opzionale)
                    if (item.TransazioneViaggioId.HasValue)
                    {
                        var viaggio = await conn.QueryFirstOrDefaultAsync<dynamic>(
                            "SELECT descrizione_breve FROM ana_viaggi WHERE viaggio_id = @Id",
                            new { Id = item.TransazioneViaggioId.Value });
                        if (viaggio != null)
                            item.ViaggioDescrizione = viaggio.descrizione_breve;
                    }
                }
            }

            return resultList;
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
