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
    private readonly AnaTipiCausaliService _causaliService;

    public MovTransazioniService(
        IDatabaseService dbService,
        ILogger<MovTransazioniService> logger,
        IExchangeRateService exchangeRateService,
        AnaValuteService valuteService,
        AnaTipiCausaliService causaliService)
    {
        _dbService = dbService;
        _logger = logger;
        _exchangeRateService = exchangeRateService;
        _valuteService = valuteService;
        _causaliService = causaliService;
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
        bool soloDaPagare = false,
        int? causaleTipoId = null)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            string sql = @"
                SELECT 
                    t.*,
                    aiva.iva_descrizione as AliquotaIvaDescrizione,
                    aiva.iva_percentuale as AliquotaIvaPercentuale,
                    aiva.iva_codice as AliquotaIvaCodice
                FROM fn_get_all_transazioni(@ViaggioId, @DataViaggioId, @DataTransazione, @SoloDaPagare, @CausaleTipoId) t
                LEFT JOIN ana_aliquote_iva aiva ON t.transazione_aliquota_iva_fk = aiva.iva_id";

            var result = await conn.QueryAsync<MovTransazioni>(sql, new
            {
                ViaggioId = viaggioId,
                DataViaggioId = dataViaggioId,
                DataTransazione = dataTransazione,
                SoloDaPagare = soloDaPagare,
                CausaleTipoId = causaleTipoId
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
        bool soloDaPagare = false,
        int? causaleTipoId = null)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            string sql = @"
                SELECT 
                    t.*,
                    aiva.iva_descrizione as AliquotaIvaDescrizione,
                    aiva.iva_percentuale as AliquotaIvaPercentuale,
                    aiva.iva_codice as AliquotaIvaCodice
                FROM fn_get_transazioni_by_azienda(@AziendaId, @ViaggioId, @DataViaggioId, @DataTransazione, @SoloDaPagare, @CausaleTipoId) t
                LEFT JOIN ana_aliquote_iva aiva ON t.transazione_aliquota_iva_fk = aiva.iva_id";

            var result = await conn.QueryAsync<MovTransazioni>(sql, new
            {
                AziendaId = aziendaId,
                ViaggioId = viaggioId,
                DataViaggioId = dataViaggioId,
                DataTransazione = dataTransazione,
                SoloDaPagare = soloDaPagare,
                CausaleTipoId = causaleTipoId
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
                    c.ragione_sociale as controparte_ragione_sociale,
                    v.valuta_codice_iso as valuta_codice_iso,
                    tc.causale_descrizione as causale_descrizione,
                    tc.causale_segno as causale_segno,
                    aiva.iva_descrizione as AliquotaIvaDescrizione,
                    aiva.iva_percentuale as AliquotaIvaPercentuale,
                    aiva.iva_codice as AliquotaIvaCodice
                FROM mov_transazioni t
                JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
                JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
                JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
                LEFT JOIN ana_aliquote_iva aiva ON t.transazione_aliquota_iva_fk = aiva.iva_id
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
            // STEP 0: Calcolo automatico tipo_movimento in base al causale_ciclo
            // =============================================
            var causale = await _causaliService.GetByIdAsync(item.TransazioneCausaleTipoId);
            if (causale != null)
            {
                // PASSIVO (fornitori) → USCITA | ATTIVO (clienti) → ENTRATA
                item.TransazioneTipoMovimento = causale.CausaleCiclo == "ATTIVO" ? "ENTRATA" : "USCITA";

                _logger.LogInformation(
                    "Tipo movimento impostato automaticamente: {TipoMovimento} (causale_ciclo: {CausaleCiclo})",
                    item.TransazioneTipoMovimento,
                    causale.CausaleCiclo);
            }
            else
            {
                // Fallback di sicurezza
                item.TransazioneTipoMovimento = "USCITA";
                _logger.LogWarning("Causale {CausaleId} non trovata, usato fallback USCITA", item.TransazioneCausaleTipoId);
            }

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
            // STEP 2: Inserimento della transazione (il trigger calcolerà l'importo EUR e IVA)
            // =============================================
            using var conn = await _dbService.GetConnectionAsync();
            string sql = @"
                INSERT INTO mov_transazioni (
                    transazione_azienda_id,
                    transazione_viaggio_id,
                    transazione_data_viaggio_id,
                    transazione_controparte_id,
                    transazione_causale_tipo_id,
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
                    transazione_aliquota_iva_fk,
                    transazione_imponibile_eur,
                    transazione_iva_eur,
                    transazione_lordo_eur,
                    transazione_iva_modalita_input,
                    created_at,
                    created_by
                ) VALUES (
                    @TransazioneAziendaId,
                    @TransazioneViaggioId,
                    @TransazioneDataViaggioId,
                    @TransazioneControparteId,
                    @TransazioneCausaleTipoId,
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
                    @TransazioneAliquotaIvaFk,
                    @TransazioneImponibileEur,
                    @TransazioneIvaEur,
                    @TransazioneLordoEur,
                    @TransazioneIvaModalitaInput,
                    NOW(),
                    @CreatedBy
                ) RETURNING transazione_id";

            // Nota: transazione_importo_eur_old è deprecato e non gestito qui (trigger o null)
            //       Tutti i calcoli IVA sono demandati al trigger fn_calcola_iva_transazione
            int transazioneId = await conn.ExecuteScalarAsync<int>(sql, item);

            return (transazioneId, warningMessage);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nella creazione transazione");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "mov_transazioni");
        }
    }

    public async Task<string?> UpdateAsync(MovTransazioni item)
    {
        string? warningMessage = null;

        try
        {
            // =============================================
            // STEP 0: Calcolo automatico tipo_movimento in base al causale_ciclo
            // =============================================
            var causale = await _causaliService.GetByIdAsync(item.TransazioneCausaleTipoId);
            if (causale != null)
            {
                // PASSIVO (fornitori) → USCITA | ATTIVO (clienti) → ENTRATA
                item.TransazioneTipoMovimento = causale.CausaleCiclo == "ATTIVO" ? "ENTRATA" : "USCITA";

                _logger.LogInformation(
                    "Tipo movimento impostato automaticamente: {TipoMovimento} (causale_ciclo: {CausaleCiclo})",
                    item.TransazioneTipoMovimento,
                    causale.CausaleCiclo);
            }
            else
            {
                // Fallback di sicurezza
                item.TransazioneTipoMovimento = "USCITA";
                _logger.LogWarning("Causale {CausaleId} non trovata, usato fallback USCITA", item.TransazioneCausaleTipoId);
            }

            using var conn = await _dbService.GetConnectionAsync();

            // =============================================
            // STEP 1: Verifica se sono cambiati valuta o data documento
            // =============================================
            string checkSql = @"
                SELECT transazione_valuta_id, transazione_data_documento
                FROM mov_transazioni
                WHERE transazione_id = @TransazioneId";

            var original = await conn.QueryFirstOrDefaultAsync<(int ValutaId, DateTime? DataDocumento)>(
                checkSql,
                new { item.TransazioneId });

            bool valutaCambiata = original.ValutaId != item.TransazioneValutaId;
            bool dataDocumentoCambiata = original.DataDocumento != item.TransazioneDataDocumento;

            // =============================================
            // STEP 2: Recupero automatico tasso di cambio SOLO se necessario
            // =============================================
            if ((valutaCambiata || dataDocumentoCambiata) && item.TransazioneDataDocumento.HasValue)
            {
                var valuta = await _valuteService.GetByIdAsync(item.TransazioneValutaId);

                if (valuta != null && !valuta.ValutaIsBase)
                {
                    _logger.LogInformation(
                        "Valuta o data documento modificata - Recupero tasso di cambio per {ValutaIso} alla data {DataDoc}",
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
            }

            // =============================================
            // STEP 3: Aggiornamento della transazione (il trigger ricalcolerà IVA e importi)
            // =============================================
            string sql = @"
                UPDATE mov_transazioni SET
                    transazione_viaggio_id = @TransazioneViaggioId,
                    transazione_data_viaggio_id = @TransazioneDataViaggioId,
                    transazione_controparte_id = @TransazioneControparteId,
                    transazione_causale_tipo_id = @TransazioneCausaleTipoId,
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
                    transazione_aliquota_iva_fk = @TransazioneAliquotaIvaFk,
                    transazione_imponibile_eur = @TransazioneImponibileEur,
                    transazione_iva_eur = @TransazioneIvaEur,
                    transazione_lordo_eur = @TransazioneLordoEur,
                    transazione_iva_modalita_input = @TransazioneIvaModalitaInput,
                    updated_at = NOW(),
                    updated_by = @UpdatedBy
                WHERE transazione_id = @TransazioneId";

            await conn.ExecuteAsync(sql, item);

            return warningMessage;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nell'aggiornamento transazione {Id}", item.TransazioneId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "mov_transazioni");
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
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "mov_transazioni");
        }
    }

    /// <summary>
    /// Registra un pagamento immediato per una transazione DA_PAGARE o PARZIALMENTE_PAGATO.
    /// Crea automaticamente una transazione PG (Pagamento) o IN (Incasso) collegata e aggiorna lo stato.
    /// </summary>
    /// <param name="transazioneId">ID della transazione da pagare</param>
    /// <param name="importoPagamento">Importo del pagamento in EUR (null = pagamento totale)</param>
    /// <param name="dataPagamento">Data del pagamento (null = oggi)</param>
    /// <param name="notePagamento">Note opzionali sul pagamento</param>
    /// <param name="currentUser">Username dell'utente che registra il pagamento</param>
    /// <returns>ID della nuova transazione PG/IN creata</returns>
    public async Task<int> PagaOraAsync(
        int transazioneId,
        decimal? importoPagamento = null,
        DateTime? dataPagamento = null,
        string? notePagamento = null,
        string? currentUser = null)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();

            // Step 1: Retrieve original transaction
            var originalTx = await GetByIdAsync(transazioneId);
            if (originalTx == null)
            {
                throw new InvalidOperationException($"Transazione {transazioneId} non trovata");
            }

            // Step 2: Validate stato
            if (originalTx.TransazioneStato == "PAGATO")
            {
                throw new InvalidOperationException("La transazione è già stata pagata completamente");
            }

            if (originalTx.TransazioneStato == "ANNULLATO")
            {
                throw new InvalidOperationException("Impossibile pagare una transazione annullata");
            }

            // Step 3: Get causale metadata
            var originalCausale = await _causaliService.GetByIdAsync(originalTx.TransazioneCausaleTipoId);
            if (originalCausale == null)
            {
                throw new InvalidOperationException("Causale originale non trovata");
            }

            // Step 4: Find PG/IN causale (Pagamento for PASSIVO, Incasso for ATTIVO)
            string pgCodice = originalCausale.CausaleCiclo == "ATTIVO" ? "IN" : "PG";
            var pgCausale = await conn.QueryFirstOrDefaultAsync<AnaTipoCausale>(
                "SELECT * FROM ana_tipi_causali WHERE azienda_fk = @AziendaFk AND causale_codice = @CodiceTarget AND is_active = TRUE LIMIT 1",
                new { AziendaFk = originalTx.TransazioneAziendaId, CodiceTarget = pgCodice });

            if (pgCausale == null)
            {
                throw new InvalidOperationException($"Causale '{pgCodice}' non trovata per questa azienda. Creare prima la causale di pagamento.");
            }

            // Step 5: Calculate payment amount and check existing payments
            decimal importoNuovoPagamento = importoPagamento ?? originalTx.TransazioneLordoEur ?? originalTx.TransazioneImporto;
            decimal importoDocumento = originalTx.TransazioneLordoEur ?? originalTx.TransazioneImporto;

            // Step 5a: Somma tutti i pagamenti PG/IN già effettuati per questa fattura
            string sqlTotalePagato = @"
                SELECT COALESCE(SUM(ABS(transazione_importo_eur)), 0)
                FROM mov_transazioni
                WHERE transazione_fattura_fk = @FatturaId
                  AND transazione_stato = 'PAGATO'";

            decimal totalePagatoPrecedente = await conn.ExecuteScalarAsync<decimal>(
                sqlTotalePagato,
                new { FatturaId = transazioneId });

            // Step 5b: Calcola totale complessivo dopo questo pagamento
            decimal totalePagatoComplessivo = totalePagatoPrecedente + importoNuovoPagamento;

            // Step 5c: Verifica che non si superi l'importo del documento
            if (totalePagatoComplessivo > importoDocumento)
            {
                throw new InvalidOperationException(
                    $"Impossibile registrare il pagamento: totale pagamenti ({totalePagatoComplessivo:N2} EUR) " +
                    $"supererebbe l'importo del documento ({importoDocumento:N2} EUR). " +
                    $"Già pagati: {totalePagatoPrecedente:N2} EUR. Residuo disponibile: {(importoDocumento - totalePagatoPrecedente):N2} EUR.");
            }

            if (importoNuovoPagamento <= 0)
            {
                throw new InvalidOperationException("L'importo del pagamento deve essere maggiore di zero");
            }

            // Step 6: Determine new stato based on TOTAL paid (not just current payment)
            string nuovoStato;
            decimal importoEffettivo = importoNuovoPagamento;

            if (totalePagatoComplessivo >= importoDocumento)
            {
                nuovoStato = "PAGATO";
                // Se il totale supererebbe, cap l'importo corrente
                if (totalePagatoComplessivo > importoDocumento)
                {
                    importoEffettivo = importoDocumento - totalePagatoPrecedente;
                }
            }
            else if (totalePagatoComplessivo > 0)
            {
                nuovoStato = "PARZIALMENTE_PAGATO";
            }
            else
            {
                throw new InvalidOperationException("Errore nel calcolo dello stato");
            }

            _logger.LogInformation(
                "Calcolo pagamento: Fattura {ImportoDoc} EUR, già pagati {Prec} EUR, nuovo pagamento {Nuovo} EUR, totale {Totale} EUR → Stato: {Stato}",
                importoDocumento, totalePagatoPrecedente, importoEffettivo, totalePagatoComplessivo, nuovoStato);

            DateTime dataEffettivaPagamento = dataPagamento ?? DateTime.Today;

            // Step 7: Create PG/IN transaction using database transaction
            await conn.OpenAsync();
            using var transaction = await conn.BeginTransactionAsync();

            try
            {
                // Insert PG/IN transaction
                string insertSql = @"
                    INSERT INTO mov_transazioni (
                        transazione_azienda_id,
                        transazione_viaggio_id,
                        transazione_data_viaggio_id,
                        transazione_controparte_id,
                        transazione_causale_tipo_id,
                        transazione_tipo_movimento,
                        transazione_importo,
                        transazione_valuta_id,
                        transazione_data,
                        transazione_data_pagamento,
                        transazione_stato,
                        transazione_causale,
                        transazione_note,
                        transazione_fattura_fk,
                        created_at,
                        created_by
                    ) VALUES (
                        @AziendaId,
                        @ViaggioId,
                        @DataViaggioId,
                        @ControparteId,
                        @CausaleTipoId,
                        @TipoMovimento,
                        @Importo,
                        @ValutaId,
                        @DataPagamento,
                        @DataPagamento,
                        'PAGATO',
                        @Causale,
                        @Note,
                        @FatturaFk,
                        NOW(),
                        @CreatedBy
                    ) RETURNING transazione_id";

                int pgTransazioneId = await conn.ExecuteScalarAsync<int>(insertSql, new
                {
                    AziendaId = originalTx.TransazioneAziendaId,
                    ViaggioId = originalTx.TransazioneViaggioId,
                    DataViaggioId = originalTx.TransazioneDataViaggioId,
                    ControparteId = originalTx.TransazioneControparteId,
                    CausaleTipoId = pgCausale.CausaleId,
                    TipoMovimento = originalCausale.CausaleCiclo == "ATTIVO" ? "ENTRATA" : "USCITA",
                    Importo = importoEffettivo,
                    ValutaId = originalTx.TransazioneValutaId,
                    DataPagamento = dataEffettivaPagamento,
                    Causale = $"PAGAMENTO {(nuovoStato == "PARZIALMENTE_PAGATO" ? "PARZIALE" : "TOTALE")} {(originalTx.TransazioneNumeroDocumento != null ? "FATTURA " + originalTx.TransazioneNumeroDocumento : "TRANSAZIONE #" + originalTx.TransazioneId)}",
                    Note = notePagamento ?? $"Pagamento automatico da transazione #{originalTx.TransazioneId}",
                    FatturaFk = transazioneId, // Link back to original invoice
                    CreatedBy = currentUser ?? "System"
                }, transaction);

                // Update original transaction stato and data_pagamento
                string updateSql = @"
                    UPDATE mov_transazioni
                    SET transazione_stato = @Stato,
                        transazione_data_pagamento = @DataPagamento,
                        updated_at = NOW(),
                        updated_by = @UpdatedBy
                    WHERE transazione_id = @TransazioneId";

                await conn.ExecuteAsync(updateSql, new
                {
                    Stato = nuovoStato,
                    DataPagamento = nuovoStato == "PAGATO" ? dataEffettivaPagamento : (DateTime?)null,
                    UpdatedBy = currentUser ?? "System",
                    TransazioneId = transazioneId
                }, transaction);

                await transaction.CommitAsync();

                _logger.LogInformation(
                    "Pagamento registrato: Transazione {OrigId} → {Stato}, creata {TipoCausale} {PgId} per {Importo} EUR",
                    transazioneId, nuovoStato, pgCodice, pgTransazioneId, importoEffettivo);

                return pgTransazioneId;
            }
            catch (Exception)
            {
                await transaction.RollbackAsync();
                throw;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante registrazione pagamento per transazione {Id}", transazioneId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "mov_transazioni");
        }
    }
}
