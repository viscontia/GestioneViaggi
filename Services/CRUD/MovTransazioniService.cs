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
            // La function ritorna già tutti i campi incluse le descrizioni in join.
            // Non serve fare ulteriori JOIN qui, ma Dapper mapperà le colonne snake_case sulle proprietà PascalCase.
            string sql = @"SELECT * FROM fn_get_all_transazioni(@ViaggioId, @DataViaggioId, @DataTransazione, @SoloDaPagare, @CausaleTipoId)";

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
            // La function ritorna già tutti i campi incluse le descrizioni in join.
            // Non serve fare ulteriori JOIN qui, ma Dapper mapperà le colonne snake_case sulle proprietà PascalCase.
            string sql = @"SELECT * FROM fn_get_transazioni_by_azienda(@AziendaId, @ViaggioId, @DataViaggioId, @DataTransazione, @SoloDaPagare, @CausaleTipoId)";

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
            // STEP 0: Recupera causale per metadati
            // =============================================
            var causale = await _causaliService.GetByIdAsync(item.TransazioneCausaleTipoId);
            if (causale == null)
            {
                throw new InvalidOperationException($"Causale ID {item.TransazioneCausaleTipoId} non trovata");
            }

            // PASSIVO (fornitori) → USCITA | ATTIVO (clienti) → ENTRATA
            item.TransazioneTipoMovimento = causale.CausaleCiclo == "ATTIVO" ? "ENTRATA" : "USCITA";

            _logger.LogInformation(
                "Tipo movimento impostato automaticamente: {TipoMovimento} (causale_ciclo: {CausaleCiclo})",
                item.TransazioneTipoMovimento,
                causale.CausaleCiclo);

            // =============================================
            // STEP 1: Recupera valuta per controllo IVA
            // =============================================
            var valuta = await _valuteService.GetByIdAsync(item.TransazioneValutaId);
            if (valuta == null)
            {
                throw new InvalidOperationException($"Valuta ID {item.TransazioneValutaId} non trovata");
            }

            // =============================================
            // STEP 2: LOGICA IVA - Se valuta != EUR, azzera IVA
            // =============================================
            if (!valuta.ValutaIsBase) // ValutaIsBase = true solo per EUR
            {
                item.TransazioneAliquotaIvaFk = null;
                item.TransazioneImponibileEur = null;
                item.TransazioneIvaEur = null;
                item.TransazioneLordoEur = null;
                item.TransazioneIvaModalitaInput = null;

                _logger.LogInformation(
                    "IVA azzerata per transazione in valuta estera ({ValutaIso})",
                    valuta.ValutaCodiceIso);
            }

            // =============================================
            // STEP 3: LOGICA IVA - Se causale non genera IVA, azzera aliquota
            // =============================================
            if (!causale.CausaleGeneraIva)
            {
                item.TransazioneAliquotaIvaFk = null;
                // Non azzerare imponibile/IVA/lordo: trigger li popolerà correttamente

                _logger.LogInformation(
                    "Aliquota IVA azzerata per causale che non genera IVA ({CausaleDescrizione})",
                    causale.CausaleDescrizione);
            }

            // =============================================
            // STEP 4: LOGICA IVA - Auto-imposta aliquota default (solo EUR + genera IVA)
            // =============================================
            if (causale.CausaleGeneraIva &&
                valuta.ValutaIsBase &&
                item.TransazioneAliquotaIvaFk == null &&
                causale.CausaleAliquotaIvaDefaultFk.HasValue)
            {
                item.TransazioneAliquotaIvaFk = causale.CausaleAliquotaIvaDefaultFk.Value;

                _logger.LogInformation(
                    "Aliquota IVA default impostata: {AliquotaId} (da causale {CausaleDescrizione})",
                    item.TransazioneAliquotaIvaFk,
                    causale.CausaleDescrizione);
            }

            // =============================================
            // STEP 5: LOGICA IVA - Auto-imposta modalità input da ciclo causale
            // =============================================
            if (item.TransazioneIvaModalitaInput == null &&
                item.TransazioneAliquotaIvaFk.HasValue)
            {
                // PASSIVO (fornitori) → LORDO (scorporo)
                // ATTIVO (clienti) → NETTO (calcolo IVA)
                item.TransazioneIvaModalitaInput = causale.CausaleCiclo == "PASSIVO" ? "LORDO" : "NETTO";

                _logger.LogInformation(
                    "Modalità IVA auto-determinata: {Modalita} (ciclo: {Ciclo})",
                    item.TransazioneIvaModalitaInput,
                    causale.CausaleCiclo);
            }

            // =============================================
            // STEP 6: Recupero automatico tasso di cambio se valuta != EUR
            // =============================================
            if (!valuta.ValutaIsBase && item.TransazioneDataDocumento.HasValue)
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
            // STEP 7: Inserimento della transazione (il trigger calcolerà l'importo EUR e IVA)
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
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "transazione");
        }
    }

    public async Task<string?> UpdateAsync(MovTransazioni item)
    {
        string? warningMessage = null;

        try
        {
            // =============================================
            // STEP 0: Recupera causale per metadati
            // =============================================
            var causale = await _causaliService.GetByIdAsync(item.TransazioneCausaleTipoId);
            if (causale == null)
            {
                throw new InvalidOperationException($"Causale ID {item.TransazioneCausaleTipoId} non trovata");
            }

            // PASSIVO (fornitori) → USCITA | ATTIVO (clienti) → ENTRATA
            item.TransazioneTipoMovimento = causale.CausaleCiclo == "ATTIVO" ? "ENTRATA" : "USCITA";

            _logger.LogInformation(
                "Tipo movimento impostato automaticamente: {TipoMovimento} (causale_ciclo: {CausaleCiclo})",
                item.TransazioneTipoMovimento,
                causale.CausaleCiclo);

            // =============================================
            // STEP 1: Recupera valuta per controllo IVA
            // =============================================
            var valuta = await _valuteService.GetByIdAsync(item.TransazioneValutaId);
            if (valuta == null)
            {
                throw new InvalidOperationException($"Valuta ID {item.TransazioneValutaId} non trovata");
            }

            // =============================================
            // STEP 2: LOGICA IVA - Se valuta != EUR, azzera IVA
            // =============================================
            if (!valuta.ValutaIsBase) // ValutaIsBase = true solo per EUR
            {
                item.TransazioneAliquotaIvaFk = null;
                item.TransazioneImponibileEur = null;
                item.TransazioneIvaEur = null;
                item.TransazioneLordoEur = null;
                item.TransazioneIvaModalitaInput = null;

                _logger.LogInformation(
                    "IVA azzerata per transazione in valuta estera ({ValutaIso})",
                    valuta.ValutaCodiceIso);
            }

            // =============================================
            // STEP 3: LOGICA IVA - Se causale non genera IVA, azzera aliquota
            // =============================================
            if (!causale.CausaleGeneraIva)
            {
                item.TransazioneAliquotaIvaFk = null;
                // Non azzerare imponibile/IVA/lordo: trigger li popolerà correttamente

                _logger.LogInformation(
                    "Aliquota IVA azzerata per causale che non genera IVA ({CausaleDescrizione})",
                    causale.CausaleDescrizione);
            }

            // =============================================
            // STEP 4: LOGICA IVA - Auto-imposta aliquota default (solo EUR + genera IVA)
            // =============================================
            if (causale.CausaleGeneraIva &&
                valuta.ValutaIsBase &&
                item.TransazioneAliquotaIvaFk == null &&
                causale.CausaleAliquotaIvaDefaultFk.HasValue)
            {
                item.TransazioneAliquotaIvaFk = causale.CausaleAliquotaIvaDefaultFk.Value;

                _logger.LogInformation(
                    "Aliquota IVA default impostata: {AliquotaId} (da causale {CausaleDescrizione})",
                    item.TransazioneAliquotaIvaFk,
                    causale.CausaleDescrizione);
            }

            // =============================================
            // STEP 5: LOGICA IVA - Auto-imposta modalità input da ciclo causale
            // =============================================
            if (item.TransazioneIvaModalitaInput == null &&
                item.TransazioneAliquotaIvaFk.HasValue)
            {
                // PASSIVO (fornitori) → LORDO (scorporo)
                // ATTIVO (clienti) → NETTO (calcolo IVA)
                item.TransazioneIvaModalitaInput = causale.CausaleCiclo == "PASSIVO" ? "LORDO" : "NETTO";

                _logger.LogInformation(
                    "Modalità IVA auto-determinata: {Modalita} (ciclo: {Ciclo})",
                    item.TransazioneIvaModalitaInput,
                    causale.CausaleCiclo);
            }

            using var conn = await _dbService.GetConnectionAsync();

            // =============================================
            // STEP 6: Verifica se la valuta è cambiata, la data è cambiata, o se *manca* il tasso di cambio
            // =============================================
            string checkSql = @"
                SELECT t.transazione_valuta_id, 
                       t.transazione_data_documento,
                       (SELECT COUNT(*) FROM ana_tassi_cambio tc 
                        WHERE tc.tasso_valuta_da_fk = (SELECT valuta_id FROM ana_valute WHERE valuta_codice_iso = 'EUR')
                          AND tc.tasso_valuta_a_fk = t.transazione_valuta_id
                          AND tc.tasso_data_validita = @DataDoc) as count_tassi
                FROM mov_transazioni t
                WHERE t.transazione_id = @TransazioneId";

            var original = await conn.QueryFirstOrDefaultAsync<(int ValutaId, DateTime? DataDocumento, int CountTassi)>(
                checkSql,
                new { item.TransazioneId, DataDoc = item.TransazioneDataDocumento });

            bool valutaCambiata = original.ValutaId != item.TransazioneValutaId;
            bool dataDocumentoCambiata = original.DataDocumento != item.TransazioneDataDocumento;
            bool tassoMancante = !valuta.ValutaIsBase && original.CountTassi == 0;

            // =============================================
            // STEP 7: Recupero automatico tasso di cambio SOLO se necessario
            // =============================================
            if ((valutaCambiata || dataDocumentoCambiata || tassoMancante) && item.TransazioneDataDocumento.HasValue)
            {
                if (!valuta.ValutaIsBase)
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
            // STEP 8: Aggiornamento della transazione (il trigger ricalcolerà IVA e importi)
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
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "transazione");
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
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "transazione");
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

            // Chiama la stored function sp_registra_pagamento
            string sql = @"
                SELECT * FROM sp_registra_pagamento(
                    @TransazioneId,
                    @ImportoPagamento,
                    @DataPagamento::DATE,
                    @NotePagamento,
                    @CurrentUser
                )";

            var result = await conn.QueryFirstOrDefaultAsync<RegistraPagamentoResult>(sql, new
            {
                TransazioneId = transazioneId,
                ImportoPagamento = importoPagamento,
                DataPagamento = dataPagamento,
                NotePagamento = notePagamento,
                CurrentUser = currentUser ?? "System"
            });

            if (result == null)
            {
                throw new InvalidOperationException("Errore durante la registrazione del pagamento: nessun risultato dalla stored function");
            }

            // Se c'è un messaggio di errore, lancia un'eccezione
            if (!string.IsNullOrEmpty(result.ErrorMessage))
            {
                throw new InvalidOperationException(result.ErrorMessage);
            }

            // Verifica che l'ID sia valido
            if (!result.PgTransazioneId.HasValue)
            {
                throw new InvalidOperationException("Errore durante la registrazione del pagamento: ID transazione non valido");
            }

            _logger.LogInformation(
                "Pagamento registrato tramite stored function: Transazione {OrigId} → {Stato}, creata transazione {PgId} per {Importo} EUR",
                transazioneId, result.NuovoStato, result.PgTransazioneId.Value, result.ImportoEffettivo ?? 0);

            return result.PgTransazioneId.Value;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante registrazione pagamento per transazione {Id}", transazioneId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "transazione");
        }
    }

    /// <summary>
    /// DTO per il risultato della stored function sp_registra_pagamento
    /// </summary>
    private class RegistraPagamentoResult
    {
        public int? PgTransazioneId { get; set; }
        public string? NuovoStato { get; set; }
        public decimal? ImportoEffettivo { get; set; }
        public string? ErrorMessage { get; set; }
    }
}
