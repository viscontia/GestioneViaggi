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
            await using var conn = await _dbService.GetConnectionAsync();
            string sql = "SELECT * FROM fn_get_viaggi_with_transazioni(@AziendaId)";
            var parameters = new DynamicParameters();
            parameters.Add("AziendaId", aziendaId);
            var result = await conn.QueryAsync<AnaViaggi>(sql, parameters);
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
            await using var conn = await _dbService.GetConnectionAsync();
            string sql = "SELECT * FROM fn_get_date_viaggi_with_transazioni(@ViaggioId)";
            var parameters = new DynamicParameters();
            parameters.Add("ViaggioId", viaggioId);
            var result = await conn.QueryAsync<DataViaggioDTO>(sql, parameters);
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
            await using var conn = await _dbService.GetConnectionAsync();
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
            await using var conn = await _dbService.GetConnectionAsync();
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

    /// <summary>
    /// Recupera tutti i dati necessari per l'inizializzazione del dialog MovTransazioni in un'unica chiamata.
    /// </summary>
    public async Task<TransazioneInitData> GetTransazioneInitDataAsync(int aziendaId, int? transazioneId = null)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();
            string sql = "SELECT fn_get_transazione_init_data(@AziendaId, @TransazioneId)";

            var parameters = new DynamicParameters();
            parameters.Add("AziendaId", aziendaId);
            parameters.Add("TransazioneId", transazioneId);
            var json = await conn.ExecuteScalarAsync<string>(sql, parameters);
            
            if (string.IsNullOrEmpty(json)) return new TransazioneInitData();

            var options = new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true };
            var rawData = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(json, options);
            
            var result = new TransazioneInitData();
            
            if (rawData.TryGetProperty("Causali", out var causali))
                result.Causali = System.Text.Json.JsonSerializer.Deserialize<List<AnaTipoCausale>>(causali.GetRawText(), options) ?? new();
            
            if (rawData.TryGetProperty("AliquoteIva", out var aliquote))
                result.AliquoteIva = System.Text.Json.JsonSerializer.Deserialize<List<AnaAliquotaIva>>(aliquote.GetRawText(), options) ?? new();
            
            if (rawData.TryGetProperty("Valute", out var valute))
                result.Valute = System.Text.Json.JsonSerializer.Deserialize<List<AnaValute>>(valute.GetRawText(), options) ?? new();
            
            if (rawData.TryGetProperty("Controparti", out var controparti))
                result.Controparti = System.Text.Json.JsonSerializer.Deserialize<List<AnaControparte>>(controparti.GetRawText(), options) ?? new();
            
            if (rawData.TryGetProperty("Viaggi", out var viaggi))
                result.Viaggi = System.Text.Json.JsonSerializer.Deserialize<List<AnaViaggi>>(viaggi.GetRawText(), options) ?? new();
            
            if (rawData.TryGetProperty("ShowHelperCalcolo", out var showHelper))
                result.ShowHelperCalcolo = showHelper.GetBoolean();

            if (rawData.TryGetProperty("TransazioneJson", out var transElem) && transElem.ValueKind != System.Text.Json.JsonValueKind.Null)
            {
                if (transElem.TryGetProperty("transazione", out var t))
                    result.Transazione = System.Text.Json.JsonSerializer.Deserialize<MovTransazioni>(t.GetRawText(), options);
                
                if (result.Transazione != null && transElem.TryGetProperty("righe", out var righe))
                    result.Transazione.Righe = System.Text.Json.JsonSerializer.Deserialize<List<MovTransazioniRighe>>(righe.GetRawText(), options) ?? new();
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero dati init per transazione. Azienda: {AziendaId}, ID: {TransazioneId}", aziendaId, transazioneId);
            return new TransazioneInitData();
        }
    }

    public async Task<MovTransazioni?> GetByIdAsync(int id)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();
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

            var parameters = new DynamicParameters();
            parameters.Add("Id", id);
            var transazione = await conn.QueryFirstOrDefaultAsync<MovTransazioni>(sql, parameters);

            if (transazione != null)
            {
                // Caricamento righe di dettaglio
                string sqlRighe = @"
                    SELECT r.*, a.iva_codice as AliquotaIvaCodice, a.iva_descrizione as AliquotaIvaDescrizione, a.iva_percentuale as AliquotaIvaPercentuale
                    FROM mov_transazioni_righe r
                    JOIN ana_aliquote_iva a ON r.riga_aliquota_iva_fk = a.iva_id
                    WHERE r.transazione_fk = @Id
                    ORDER BY r.riga_numero";
                
                var righeParams = new DynamicParameters();
                righeParams.Add("Id", id);
                var righe = await conn.QueryAsync<MovTransazioniRighe>(sqlRighe, righeParams);
                transazione.Righe = righe.ToList();
            }

            return transazione;
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
        await using var conn = await _dbService.GetConnectionAsync();
        using var transaction = conn.BeginTransaction();

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
            if (!valuta.ValutaIsBase)
            {
                item.TransazioneAliquotaIvaFk = null;
                item.TransazioneImponibileEur = null;
                item.TransazioneIvaEur = null;
                item.TransazioneLordoEur = null;
                item.TransazioneIvaModalitaInput = null;
                foreach(var r in item.Righe) { r.RigaIvaValore = 0; r.RigaLordo = r.RigaImponibile; }
            }

            // =============================================
            // STEP 6: Recupero automatico tasso di cambio se valuta != EUR
            // =============================================
            if (!valuta.ValutaIsBase && item.TransazioneDataDocumento.HasValue)
            {
                (bool success, string message) = await _exchangeRateService.UpdateRateForDateAsync(
                    valuta.ValutaCodiceIso,
                    item.TransazioneDataDocumento.Value);

                if (!success)
                {
                    warningMessage = message;
                }
            }

            // =============================================
            // STEP 7: Inserimento della testata
            // =============================================
            string sql = @"
                INSERT INTO mov_transazioni (
                    transazione_azienda_id, transazione_viaggio_id, transazione_data_viaggio_id,
                    transazione_controparte_id, transazione_causale_tipo_id, transazione_tipo_movimento,
                    transazione_importo, transazione_valuta_id, transazione_data,
                    transazione_data_scadenza, transazione_data_pagamento, transazione_stato,
                    transazione_causale, transazione_note, transazione_numero_documento,
                    transazione_data_documento, created_at, created_by
                ) VALUES (
                    @TransazioneAziendaId, @TransazioneViaggioId, @TransazioneDataViaggioId,
                    @TransazioneControparteId, @TransazioneCausaleTipoId, @TransazioneTipoMovimento,
                    @TransazioneImporto, @TransazioneValutaId, @TransazioneData,
                    @TransazioneDataScadenza, @TransazioneDataPagamento, @TransazioneStato,
                    @TransazioneCausale, @TransazioneNote, @TransazioneNumeroDocumento,
                    @TransazioneDataDocumento, NOW(), @CreatedBy
                ) RETURNING transazione_id";

            int transazioneId = await conn.ExecuteScalarAsync<int>(sql, item, transaction);
            item.TransazioneId = transazioneId;

            // =============================================
            // STEP 7.1: Inserimento delle righe
            // =============================================
            if (item.Righe != null && item.Righe.Any())
            {
                string sqlRighe = @"
                    INSERT INTO mov_transazioni_righe (
                        transazione_fk, riga_numero, riga_descrizione, riga_tipo,
                        riga_imponibile, riga_aliquota_iva_fk, riga_iva_valore, riga_lordo,
                        created_at, updated_at
                    ) VALUES (
                        @TransazioneId, @RigaNumero, @RigaDescrizione, @RigaTipo,
                        @RigaImponibile, @RigaAliquotaIvaFk, @RigaIvaValore, @RigaLordo,
                        NOW(), NOW()
                    )";

                foreach (var riga in item.Righe)
                {
                    riga.TransazioneFk = transazioneId;
                    var rigaParams = new DynamicParameters();
                    rigaParams.Add("TransazioneId", transazioneId);
                    rigaParams.Add("RigaNumero", riga.RigaNumero);
                    rigaParams.Add("RigaDescrizione", riga.RigaDescrizione);
                    rigaParams.Add("RigaTipo", riga.RigaTipo);
                    rigaParams.Add("RigaImponibile", riga.RigaImponibile);
                    rigaParams.Add("RigaAliquotaIvaFk", riga.RigaAliquotaIvaFk);
                    rigaParams.Add("RigaIvaValore", riga.RigaIvaValore);
                    rigaParams.Add("RigaLordo", riga.RigaLordo);
                    await conn.ExecuteAsync(sqlRighe, rigaParams, transaction);
                }
            }

            transaction.Commit();

            // =============================================
            // STEP 8: Assegnazione protocollo IVA (fuori transazione atomica per semplicità se fallisce)
            // =============================================
            try
            {
                var protParams = new DynamicParameters();
                protParams.Add("TransazioneId", transazioneId);
                await conn.ExecuteAsync(
                    "SELECT sp_assegna_protocollo_iva(@TransazioneId)",
                    protParams);
            }
            catch (Exception exProt)
            {
                _logger.LogWarning(exProt, "Impossibile assegnare protocollo IVA per transazione {Id}", transazioneId);
            }

            return (transazioneId, warningMessage);
        }
        catch (Exception ex)
        {
            transaction.Rollback();
            _logger.LogError(ex, "Errore nella creazione transazione");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "transazione");
        }
    }

    public async Task<string?> UpdateAsync(MovTransazioni item)
    {
        string? warningMessage = null;
        await using var conn = await _dbService.GetConnectionAsync();
        using var transaction = conn.BeginTransaction();

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
            if (!valuta.ValutaIsBase)
            {
                item.TransazioneAliquotaIvaFk = null;
                item.TransazioneImponibileEur = null;
                item.TransazioneIvaEur = null;
                item.TransazioneLordoEur = null;
                item.TransazioneIvaModalitaInput = null;
                foreach(var r in item.Righe) { r.RigaIvaValore = 0; r.RigaLordo = r.RigaImponibile; }
            }

            // =============================================
            // STEP 7: Recupero automatico tasso di cambio SOLO se necessario
            // =============================================
            if (item.TransazioneDataDocumento.HasValue && !valuta.ValutaIsBase)
            {
                (bool success, string message) = await _exchangeRateService.UpdateRateForDateAsync(
                    valuta.ValutaCodiceIso,
                    item.TransazioneDataDocumento.Value);

                if (!success)
                {
                    warningMessage = message;
                }
            }

            // =============================================
            // STEP 8: Aggiornamento della testata
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
                    updated_at = NOW(),
                    updated_by = @UpdatedBy
                WHERE transazione_id = @TransazioneId";

            await conn.ExecuteAsync(sql, item, transaction);

            // =============================================
            // STEP 9: SINCRONIZZAZIONE RIGHE (DELETE + INSERT)
            // =============================================
            
            // 1. Cancella righe vecchie
            var deleteParams = new DynamicParameters();
            deleteParams.Add("Id", item.TransazioneId);
            await conn.ExecuteAsync(
                "DELETE FROM mov_transazioni_righe WHERE transazione_fk = @Id",
                deleteParams,
                transaction);

            // 2. Inserisce nuove righe
            if (item.Righe != null && item.Righe.Any())
            {
                string sqlRighe = @"
                    INSERT INTO mov_transazioni_righe (
                        transazione_fk, riga_numero, riga_descrizione, riga_tipo,
                        riga_imponibile, riga_aliquota_iva_fk, riga_iva_valore, riga_lordo,
                        created_at, updated_at
                    ) VALUES (
                        @TransazioneId, @RigaNumero, @RigaDescrizione, @RigaTipo,
                        @RigaImponibile, @RigaAliquotaIvaFk, @RigaIvaValore, @RigaLordo,
                        NOW(), NOW()
                    )";

                foreach (var riga in item.Righe)
                {
                    var rigaParams = new DynamicParameters();
                    rigaParams.Add("TransazioneId", item.TransazioneId);
                    rigaParams.Add("RigaNumero", riga.RigaNumero);
                    rigaParams.Add("RigaDescrizione", riga.RigaDescrizione);
                    rigaParams.Add("RigaTipo", riga.RigaTipo);
                    rigaParams.Add("RigaImponibile", riga.RigaImponibile);
                    rigaParams.Add("RigaAliquotaIvaFk", riga.RigaAliquotaIvaFk);
                    rigaParams.Add("RigaIvaValore", riga.RigaIvaValore);
                    rigaParams.Add("RigaLordo", riga.RigaLordo);
                    await conn.ExecuteAsync(sqlRighe, rigaParams, transaction);
                }
            }

            transaction.Commit();

            // =============================================
            // STEP 10: Gestione protocollo IVA (fuori transazione)
            // =============================================
            try
            {
                var protParams2 = new DynamicParameters();
                protParams2.Add("TransazioneId", item.TransazioneId);
                await conn.ExecuteAsync(
                    "SELECT sp_assegna_protocollo_iva(@TransazioneId)",
                    protParams2);
            }
            catch (Exception exProt)
            {
                _logger.LogWarning(exProt, "Impossibile gestire protocollo IVA per transazione {Id}", item.TransazioneId);
            }

            return warningMessage;
        }
        catch (Exception ex)
        {
            transaction.Rollback();
            _logger.LogError(ex, "Errore nell'aggiornamento transazione {Id}", item.TransazioneId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "transazione");
        }
    }

    public async Task DeleteAsync(int id)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            // Blocca eliminazione se la transazione ha un protocollo IVA assegnato
            var checkParams = new DynamicParameters();
            checkParams.Add("Id", id);
            var protocollo = await conn.QueryFirstOrDefaultAsync<int?>(
                "SELECT transazione_numero_protocollo_iva FROM mov_transazioni WHERE transazione_id = @Id",
                checkParams);

            if (protocollo.HasValue)
            {
                throw new InvalidOperationException(
                    "Questa transazione ha un Protocollo IVA assegnato e non può essere eliminata. " +
                    "Per annullarla, cambia lo stato in ANNULLATO dalla scheda di modifica.");
            }

            var delParams = new DynamicParameters();
            delParams.Add("Id", id);
            await conn.ExecuteAsync("DELETE FROM mov_transazioni WHERE transazione_id = @Id", delParams);
        }
        catch (InvalidOperationException)
        {
            throw; // Rilancia senza wrapping
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
            await using var conn = await _dbService.GetConnectionAsync();

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
