using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Models.DTOs;
using GestioneViaggi.Services.Shared;
using Microsoft.Extensions.Logging;
using Npgsql;

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
            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("AziendaId", (object?)aziendaId ?? DBNull.Value);

            var result = new List<AnaViaggi>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(MapReaderToAnaViaggi(reader));
            }
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
            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("ViaggioId", viaggioId);

            var result = new List<DataViaggioDTO>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(MapReaderToDataViaggioDTO(reader));
            }
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
            string sql = @"SELECT * FROM fn_get_all_transazioni(@ViaggioId, @DataViaggioId, @DataTransazione, @SoloDaPagare, @CausaleTipoId)";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("ViaggioId", (object?)viaggioId ?? DBNull.Value);
            cmd.Parameters.AddWithValue("DataViaggioId", (object?)dataViaggioId ?? DBNull.Value);
            cmd.Parameters.AddWithValue("DataTransazione", (object?)dataTransazione ?? DBNull.Value);
            cmd.Parameters.AddWithValue("SoloDaPagare", soloDaPagare);
            cmd.Parameters.AddWithValue("CausaleTipoId", (object?)causaleTipoId ?? DBNull.Value);

            var result = new List<MovTransazioni>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(MapReaderToMovTransazioni(reader));
            }
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
            string sql = @"SELECT * FROM fn_get_transazioni_by_azienda(@AziendaId, @ViaggioId, @DataViaggioId, @DataTransazione, @SoloDaPagare, @CausaleTipoId)";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);
            cmd.Parameters.AddWithValue("ViaggioId", (object?)viaggioId ?? DBNull.Value);
            cmd.Parameters.AddWithValue("DataViaggioId", (object?)dataViaggioId ?? DBNull.Value);
            cmd.Parameters.AddWithValue("DataTransazione", (object?)dataTransazione ?? DBNull.Value);
            cmd.Parameters.AddWithValue("SoloDaPagare", soloDaPagare);
            cmd.Parameters.AddWithValue("CausaleTipoId", (object?)causaleTipoId ?? DBNull.Value);

            var result = new List<MovTransazioni>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(MapReaderToMovTransazioni(reader));
            }
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

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);
            cmd.Parameters.AddWithValue("TransazioneId", (object?)transazioneId ?? DBNull.Value);
            var json = await cmd.ExecuteScalarAsync() as string;
            
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
                    aiva.iva_descrizione as aliquota_iva_descrizione,
                    aiva.iva_percentuale as aliquota_iva_percentuale,
                    aiva.iva_codice as aliquota_iva_codice
                FROM mov_transazioni t
                JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
                JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
                JOIN ana_tipi_causali tc ON t.transazione_causale_tipo_id = tc.causale_id
                LEFT JOIN ana_aliquote_iva aiva ON t.transazione_aliquota_iva_fk = aiva.iva_id
                WHERE t.transazione_id = @Id";

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("Id", id);

            MovTransazioni? transazione = null;
            await using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                transazione = MapReaderToMovTransazioni(reader);
            }
            await reader.CloseAsync();

            if (transazione != null)
            {
                // Caricamento righe di dettaglio
                string sqlRighe = @"
                    SELECT r.*, a.iva_codice as aliquota_iva_codice, a.iva_descrizione as aliquota_iva_descrizione, a.iva_percentuale as aliquota_iva_percentuale
                    FROM mov_transazioni_righe r
                    JOIN ana_aliquote_iva a ON r.riga_aliquota_iva_fk = a.iva_id
                    WHERE r.transazione_fk = @Id
                    ORDER BY r.riga_numero";

                await using var cmdRighe = new NpgsqlCommand(sqlRighe, conn);
                cmdRighe.Parameters.AddWithValue("Id", id);

                await using var readerRighe = await cmdRighe.ExecuteReaderAsync();
                while (await readerRighe.ReadAsync())
                {
                    transazione.Righe.Add(MapReaderToMovTransazioniRighe(readerRighe));
                }
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

            await using var cmdInsert = new NpgsqlCommand(sql, conn, transaction);
            cmdInsert.Parameters.AddWithValue("TransazioneAziendaId", item.TransazioneAziendaId);
            cmdInsert.Parameters.AddWithValue("TransazioneViaggioId", (object?)item.TransazioneViaggioId ?? DBNull.Value);
            cmdInsert.Parameters.AddWithValue("TransazioneDataViaggioId", (object?)item.TransazioneDataViaggioId ?? DBNull.Value);
            cmdInsert.Parameters.AddWithValue("TransazioneControparteId", item.TransazioneControparteId);
            cmdInsert.Parameters.AddWithValue("TransazioneCausaleTipoId", item.TransazioneCausaleTipoId);
            cmdInsert.Parameters.AddWithValue("TransazioneTipoMovimento", item.TransazioneTipoMovimento);
            cmdInsert.Parameters.AddWithValue("TransazioneImporto", item.TransazioneImporto);
            cmdInsert.Parameters.AddWithValue("TransazioneValutaId", item.TransazioneValutaId);
            cmdInsert.Parameters.AddWithValue("TransazioneData", item.TransazioneData);
            cmdInsert.Parameters.AddWithValue("TransazioneDataScadenza", (object?)item.TransazioneDataScadenza ?? DBNull.Value);
            cmdInsert.Parameters.AddWithValue("TransazioneDataPagamento", (object?)item.TransazioneDataPagamento ?? DBNull.Value);
            cmdInsert.Parameters.AddWithValue("TransazioneStato", item.TransazioneStato);
            cmdInsert.Parameters.AddWithValue("TransazioneCausale", item.TransazioneCausale);
            cmdInsert.Parameters.AddWithValue("TransazioneNote", (object?)item.TransazioneNote ?? DBNull.Value);
            cmdInsert.Parameters.AddWithValue("TransazioneNumeroDocumento", (object?)item.TransazioneNumeroDocumento ?? DBNull.Value);
            cmdInsert.Parameters.AddWithValue("TransazioneDataDocumento", (object?)item.TransazioneDataDocumento ?? DBNull.Value);
            cmdInsert.Parameters.AddWithValue("CreatedBy", (object?)item.CreatedBy ?? DBNull.Value);

            var result = await cmdInsert.ExecuteScalarAsync();
            int transazioneId = Convert.ToInt32(result);
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
                    await using var cmdRiga = new NpgsqlCommand(sqlRighe, conn, transaction);
                    cmdRiga.Parameters.AddWithValue("TransazioneId", transazioneId);
                    cmdRiga.Parameters.AddWithValue("RigaNumero", riga.RigaNumero);
                    cmdRiga.Parameters.AddWithValue("RigaDescrizione", riga.RigaDescrizione);
                    cmdRiga.Parameters.AddWithValue("RigaTipo", riga.RigaTipo);
                    cmdRiga.Parameters.AddWithValue("RigaImponibile", riga.RigaImponibile);
                    cmdRiga.Parameters.AddWithValue("RigaAliquotaIvaFk", riga.RigaAliquotaIvaFk);
                    cmdRiga.Parameters.AddWithValue("RigaIvaValore", riga.RigaIvaValore);
                    cmdRiga.Parameters.AddWithValue("RigaLordo", riga.RigaLordo);
                    await cmdRiga.ExecuteNonQueryAsync();
                }
            }

            transaction.Commit();

            // =============================================
            // STEP 8: Assegnazione protocollo IVA (fuori transazione atomica per semplicità se fallisce)
            // =============================================
            try
            {
                await using var cmdProt = new NpgsqlCommand("SELECT sp_assegna_protocollo_iva(@TransazioneId)", conn);
                cmdProt.Parameters.AddWithValue("TransazioneId", transazioneId);
                await cmdProt.ExecuteNonQueryAsync();
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

            await using var cmdUpdate = new NpgsqlCommand(sql, conn, transaction);
            cmdUpdate.Parameters.AddWithValue("TransazioneViaggioId", (object?)item.TransazioneViaggioId ?? DBNull.Value);
            cmdUpdate.Parameters.AddWithValue("TransazioneDataViaggioId", (object?)item.TransazioneDataViaggioId ?? DBNull.Value);
            cmdUpdate.Parameters.AddWithValue("TransazioneControparteId", item.TransazioneControparteId);
            cmdUpdate.Parameters.AddWithValue("TransazioneCausaleTipoId", item.TransazioneCausaleTipoId);
            cmdUpdate.Parameters.AddWithValue("TransazioneTipoMovimento", item.TransazioneTipoMovimento);
            cmdUpdate.Parameters.AddWithValue("TransazioneImporto", item.TransazioneImporto);
            cmdUpdate.Parameters.AddWithValue("TransazioneValutaId", item.TransazioneValutaId);
            cmdUpdate.Parameters.AddWithValue("TransazioneData", item.TransazioneData);
            cmdUpdate.Parameters.AddWithValue("TransazioneDataScadenza", (object?)item.TransazioneDataScadenza ?? DBNull.Value);
            cmdUpdate.Parameters.AddWithValue("TransazioneDataPagamento", (object?)item.TransazioneDataPagamento ?? DBNull.Value);
            cmdUpdate.Parameters.AddWithValue("TransazioneStato", item.TransazioneStato);
            cmdUpdate.Parameters.AddWithValue("TransazioneCausale", item.TransazioneCausale);
            cmdUpdate.Parameters.AddWithValue("TransazioneNote", (object?)item.TransazioneNote ?? DBNull.Value);
            cmdUpdate.Parameters.AddWithValue("TransazioneNumeroDocumento", (object?)item.TransazioneNumeroDocumento ?? DBNull.Value);
            cmdUpdate.Parameters.AddWithValue("TransazioneDataDocumento", (object?)item.TransazioneDataDocumento ?? DBNull.Value);
            cmdUpdate.Parameters.AddWithValue("UpdatedBy", (object?)item.UpdatedBy ?? DBNull.Value);
            cmdUpdate.Parameters.AddWithValue("TransazioneId", item.TransazioneId);
            await cmdUpdate.ExecuteNonQueryAsync();

            // =============================================
            // STEP 9: SINCRONIZZAZIONE RIGHE (DELETE + INSERT)
            // =============================================

            // 1. Cancella righe vecchie
            await using var cmdDel = new NpgsqlCommand("DELETE FROM mov_transazioni_righe WHERE transazione_fk = @Id", conn, transaction);
            cmdDel.Parameters.AddWithValue("Id", item.TransazioneId);
            await cmdDel.ExecuteNonQueryAsync();

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
                    await using var cmdRiga = new NpgsqlCommand(sqlRighe, conn, transaction);
                    cmdRiga.Parameters.AddWithValue("TransazioneId", item.TransazioneId);
                    cmdRiga.Parameters.AddWithValue("RigaNumero", riga.RigaNumero);
                    cmdRiga.Parameters.AddWithValue("RigaDescrizione", riga.RigaDescrizione);
                    cmdRiga.Parameters.AddWithValue("RigaTipo", riga.RigaTipo);
                    cmdRiga.Parameters.AddWithValue("RigaImponibile", riga.RigaImponibile);
                    cmdRiga.Parameters.AddWithValue("RigaAliquotaIvaFk", riga.RigaAliquotaIvaFk);
                    cmdRiga.Parameters.AddWithValue("RigaIvaValore", riga.RigaIvaValore);
                    cmdRiga.Parameters.AddWithValue("RigaLordo", riga.RigaLordo);
                    await cmdRiga.ExecuteNonQueryAsync();
                }
            }

            transaction.Commit();

            // =============================================
            // STEP 10: Gestione protocollo IVA (fuori transazione)
            // =============================================
            try
            {
                await using var cmdProt = new NpgsqlCommand("SELECT sp_assegna_protocollo_iva(@TransazioneId)", conn);
                cmdProt.Parameters.AddWithValue("TransazioneId", item.TransazioneId);
                await cmdProt.ExecuteNonQueryAsync();
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
            await using var cmdCheck = new NpgsqlCommand(
                "SELECT transazione_numero_protocollo_iva FROM mov_transazioni WHERE transazione_id = @Id", conn);
            cmdCheck.Parameters.AddWithValue("Id", id);
            var protocolloObj = await cmdCheck.ExecuteScalarAsync();
            int? protocollo = protocolloObj != null && protocolloObj != DBNull.Value ? Convert.ToInt32(protocolloObj) : (int?)null;

            if (protocollo.HasValue)
            {
                throw new InvalidOperationException(
                    "Questa transazione ha un Protocollo IVA assegnato e non può essere eliminata. " +
                    "Per annullarla, cambia lo stato in ANNULLATO dalla scheda di modifica.");
            }

            await using var cmdDel = new NpgsqlCommand("DELETE FROM mov_transazioni WHERE transazione_id = @Id", conn);
            cmdDel.Parameters.AddWithValue("Id", id);
            await cmdDel.ExecuteNonQueryAsync();
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

            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("TransazioneId", transazioneId);
            cmd.Parameters.AddWithValue("ImportoPagamento", (object?)importoPagamento ?? DBNull.Value);
            cmd.Parameters.AddWithValue("DataPagamento", (object?)dataPagamento ?? DBNull.Value);
            cmd.Parameters.AddWithValue("NotePagamento", (object?)notePagamento ?? DBNull.Value);
            cmd.Parameters.AddWithValue("CurrentUser", currentUser ?? "System");

            RegistraPagamentoResult? result = null;
            await using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                result = MapReaderToRegistraPagamentoResult(reader);
            }

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

    #region Mapping Helpers (AOT compatibili - no Reflection.Emit)

    /// <summary>
    /// Helper per verificare se una colonna esiste nel reader (compatibilità AOT - no exception)
    /// </summary>
    private static bool HasColumn(NpgsqlDataReader reader, string columnName)
    {
        for (int i = 0; i < reader.FieldCount; i++)
        {
            if (reader.GetName(i).Equals(columnName, StringComparison.OrdinalIgnoreCase))
                return true;
        }
        return false;
    }

    /// <summary>
    /// Mappa un NpgsqlDataReader a AnaViaggi (AOT compatibile)
    /// </summary>
    private static AnaViaggi MapReaderToAnaViaggi(NpgsqlDataReader reader)
    {
        var viaggio = new AnaViaggi();

        // Campi obbligatori - il DB function fn_get_viaggi_with_transazioni restituisce solo alcuni campi
        if (HasColumn(reader, "viaggio_id"))
            viaggio.Id = reader.GetInt32(reader.GetOrdinal("viaggio_id"));
        if (HasColumn(reader, "descrizione_breve"))
            viaggio.DescrizioneBreve = reader.GetString(reader.GetOrdinal("descrizione_breve"));
        if (HasColumn(reader, "descrizione_estesa"))
        {
            var ordEst = reader.GetOrdinal("descrizione_estesa");
            viaggio.DescrizioneEstesa = reader.IsDBNull(ordEst) ? string.Empty : reader.GetString(ordEst);
        }
        if (HasColumn(reader, "azienda_id"))
            viaggio.AziendaId = reader.GetInt32(reader.GetOrdinal("azienda_id"));

        // Campi opzionali che potrebbero essere restituiti dalla function
        if (HasColumn(reader, "nazione_id_fk"))
        {
            var ord = reader.GetOrdinal("nazione_id_fk");
            viaggio.NazioneIdFk = reader.IsDBNull(ord) ? 0 : reader.GetInt32(ord);
        }
        if (HasColumn(reader, "tipo_viaggio_id_fk"))
        {
            var ord = reader.GetOrdinal("tipo_viaggio_id_fk");
            viaggio.TipoViaggioIdFk = reader.IsDBNull(ord) ? 0 : reader.GetInt32(ord);
        }
        if (HasColumn(reader, "tipo_trattamento_id_fk"))
        {
            var ord = reader.GetOrdinal("tipo_trattamento_id_fk");
            viaggio.TipoTrattamentoIdFk = reader.IsDBNull(ord) ? 0 : reader.GetInt32(ord);
        }
        if (HasColumn(reader, "tipo_pernottamento_id_fk"))
        {
            var ord = reader.GetOrdinal("tipo_pernottamento_id_fk");
            viaggio.TipoPernottamentoIdFk = reader.IsDBNull(ord) ? 0 : reader.GetInt32(ord);
        }
        if (HasColumn(reader, "tipo_avvicinamento_id_fk"))
        {
            var ord = reader.GetOrdinal("tipo_avvicinamento_id_fk");
            viaggio.TipoAvvicinamentoIdFk = reader.IsDBNull(ord) ? 0 : reader.GetInt32(ord);
        }
        if (HasColumn(reader, "numero_giorni"))
        {
            var ord = reader.GetOrdinal("numero_giorni");
            viaggio.NumeroGiorni = reader.IsDBNull(ord) ? 0 : reader.GetInt32(ord);
        }
        if (HasColumn(reader, "numero_notti"))
        {
            var ord = reader.GetOrdinal("numero_notti");
            viaggio.NumeroNotti = reader.IsDBNull(ord) ? 0 : reader.GetInt32(ord);
        }
        if (HasColumn(reader, "km"))
        {
            var ord = reader.GetOrdinal("km");
            viaggio.Km = reader.IsDBNull(ord) ? 0 : reader.GetInt32(ord);
        }
        if (HasColumn(reader, "pasti_al_sacco"))
        {
            var ord = reader.GetOrdinal("pasti_al_sacco");
            viaggio.PastiAlSacco = reader.IsDBNull(ord) ? "N" : reader.GetString(ord);
        }
        if (HasColumn(reader, "note"))
        {
            var ord = reader.GetOrdinal("note");
            viaggio.Note = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "link"))
        {
            var ord = reader.GetOrdinal("link");
            viaggio.Link = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }

        return viaggio;
    }

    /// <summary>
    /// Mappa un NpgsqlDataReader a DataViaggioDTO (AOT compatibile)
    /// </summary>
    private static DataViaggioDTO MapReaderToDataViaggioDTO(NpgsqlDataReader reader)
    {
        var dto = new DataViaggioDTO();

        if (HasColumn(reader, "data_viaggio_id"))
            dto.DataViaggioId = reader.GetInt32(reader.GetOrdinal("data_viaggio_id"));
        if (HasColumn(reader, "viaggio_id_fk"))
            dto.ViaggioIdFk = reader.GetInt32(reader.GetOrdinal("viaggio_id_fk"));
        if (HasColumn(reader, "data_viaggio_data_inizio"))
            dto.DataInizio = reader.GetDateTime(reader.GetOrdinal("data_viaggio_data_inizio"));
        if (HasColumn(reader, "data_viaggio_data_fine"))
            dto.DataFine = reader.GetDateTime(reader.GetOrdinal("data_viaggio_data_fine"));
        if (HasColumn(reader, "data_viaggio_effettuato_sino"))
        {
            var ord = reader.GetOrdinal("data_viaggio_effettuato_sino");
            dto.Effettuato = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "has_transactions"))
        {
            var ord = reader.GetOrdinal("has_transactions");
            dto.HasTransactions = !reader.IsDBNull(ord) && reader.GetBoolean(ord);
        }

        return dto;
    }

    /// <summary>
    /// Mappa un NpgsqlDataReader a MovTransazioni (AOT compatibile)
    /// </summary>
    private static MovTransazioni MapReaderToMovTransazioni(NpgsqlDataReader reader)
    {
        var trans = new MovTransazioni();

        // Campi obbligatori
        if (HasColumn(reader, "transazione_id"))
            trans.TransazioneId = reader.GetInt32(reader.GetOrdinal("transazione_id"));
        if (HasColumn(reader, "transazione_azienda_id"))
            trans.TransazioneAziendaId = reader.GetInt32(reader.GetOrdinal("transazione_azienda_id"));
        if (HasColumn(reader, "transazione_controparte_id"))
            trans.TransazioneControparteId = reader.GetInt32(reader.GetOrdinal("transazione_controparte_id"));
        if (HasColumn(reader, "transazione_causale_tipo_id"))
            trans.TransazioneCausaleTipoId = reader.GetInt32(reader.GetOrdinal("transazione_causale_tipo_id"));
        if (HasColumn(reader, "transazione_tipo_movimento"))
            trans.TransazioneTipoMovimento = reader.GetString(reader.GetOrdinal("transazione_tipo_movimento"));
        if (HasColumn(reader, "transazione_importo"))
            trans.TransazioneImporto = reader.GetDecimal(reader.GetOrdinal("transazione_importo"));
        if (HasColumn(reader, "transazione_valuta_id"))
            trans.TransazioneValutaId = reader.GetInt32(reader.GetOrdinal("transazione_valuta_id"));
        if (HasColumn(reader, "transazione_data"))
            trans.TransazioneData = reader.GetDateTime(reader.GetOrdinal("transazione_data"));
        if (HasColumn(reader, "transazione_stato"))
            trans.TransazioneStato = reader.GetString(reader.GetOrdinal("transazione_stato"));
        if (HasColumn(reader, "transazione_causale"))
            trans.TransazioneCausale = reader.GetString(reader.GetOrdinal("transazione_causale"));

        // Campi nullable
        if (HasColumn(reader, "transazione_viaggio_id"))
        {
            var ord = reader.GetOrdinal("transazione_viaggio_id");
            trans.TransazioneViaggioId = reader.IsDBNull(ord) ? null : reader.GetInt32(ord);
        }
        if (HasColumn(reader, "transazione_data_viaggio_id"))
        {
            var ord = reader.GetOrdinal("transazione_data_viaggio_id");
            trans.TransazioneDataViaggioId = reader.IsDBNull(ord) ? null : reader.GetInt32(ord);
        }
        if (HasColumn(reader, "transazione_data_scadenza"))
        {
            var ord = reader.GetOrdinal("transazione_data_scadenza");
            trans.TransazioneDataScadenza = reader.IsDBNull(ord) ? null : reader.GetDateTime(ord);
        }
        if (HasColumn(reader, "transazione_data_pagamento"))
        {
            var ord = reader.GetOrdinal("transazione_data_pagamento");
            trans.TransazioneDataPagamento = reader.IsDBNull(ord) ? null : reader.GetDateTime(ord);
        }
        if (HasColumn(reader, "transazione_note"))
        {
            var ord = reader.GetOrdinal("transazione_note");
            trans.TransazioneNote = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "transazione_numero_documento"))
        {
            var ord = reader.GetOrdinal("transazione_numero_documento");
            trans.TransazioneNumeroDocumento = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "transazione_data_documento"))
        {
            var ord = reader.GetOrdinal("transazione_data_documento");
            trans.TransazioneDataDocumento = reader.IsDBNull(ord) ? null : reader.GetDateTime(ord);
        }
        if (HasColumn(reader, "transazione_fattura_fk"))
        {
            var ord = reader.GetOrdinal("transazione_fattura_fk");
            trans.TransazioneFatturaFk = reader.IsDBNull(ord) ? null : reader.GetInt32(ord);
        }

        // IVA fields
        if (HasColumn(reader, "transazione_aliquota_iva_fk"))
        {
            var ord = reader.GetOrdinal("transazione_aliquota_iva_fk");
            trans.TransazioneAliquotaIvaFk = reader.IsDBNull(ord) ? null : reader.GetInt32(ord);
        }
        if (HasColumn(reader, "transazione_imponibile_eur"))
        {
            var ord = reader.GetOrdinal("transazione_imponibile_eur");
            trans.TransazioneImponibileEur = reader.IsDBNull(ord) ? null : reader.GetDecimal(ord);
        }
        if (HasColumn(reader, "transazione_iva_eur"))
        {
            var ord = reader.GetOrdinal("transazione_iva_eur");
            trans.TransazioneIvaEur = reader.IsDBNull(ord) ? null : reader.GetDecimal(ord);
        }
        if (HasColumn(reader, "transazione_lordo_eur"))
        {
            var ord = reader.GetOrdinal("transazione_lordo_eur");
            trans.TransazioneLordoEur = reader.IsDBNull(ord) ? null : reader.GetDecimal(ord);
        }
        if (HasColumn(reader, "transazione_iva_modalita_input"))
        {
            var ord = reader.GetOrdinal("transazione_iva_modalita_input");
            trans.TransazioneIvaModalitaInput = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "transazione_numero_protocollo_iva"))
        {
            var ord = reader.GetOrdinal("transazione_numero_protocollo_iva");
            trans.TransazioneNumeroProtocolloIva = reader.IsDBNull(ord) ? null : reader.GetInt32(ord);
        }

        // Exchange rate fields
        if (HasColumn(reader, "transazione_tasso_cambio_applicato"))
        {
            var ord = reader.GetOrdinal("transazione_tasso_cambio_applicato");
            trans.TransazioneTassoCambioApplicato = reader.IsDBNull(ord) ? null : reader.GetDecimal(ord);
        }
        if (HasColumn(reader, "transazione_tasso_fonte"))
        {
            var ord = reader.GetOrdinal("transazione_tasso_fonte");
            trans.TransazioneTassoFonte = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "transazione_tasso_data_validita"))
        {
            var ord = reader.GetOrdinal("transazione_tasso_data_validita");
            trans.TransazioneTassoDataValidita = reader.IsDBNull(ord) ? null : reader.GetDateTime(ord);
        }

        // Audit fields
        if (HasColumn(reader, "created_at"))
        {
            var ord = reader.GetOrdinal("created_at");
            trans.Created = reader.IsDBNull(ord) ? null : reader.GetDateTime(ord);
        }
        if (HasColumn(reader, "created_by"))
        {
            var ord = reader.GetOrdinal("created_by");
            trans.CreatedBy = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "updated_at"))
        {
            var ord = reader.GetOrdinal("updated_at");
            trans.Updated = reader.IsDBNull(ord) ? null : reader.GetDateTime(ord);
        }
        if (HasColumn(reader, "updated_by"))
        {
            var ord = reader.GetOrdinal("updated_by");
            trans.UpdatedBy = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }

        // Navigation/Display properties (from JOINs)
        if (HasColumn(reader, "controparte_ragione_sociale"))
        {
            var ord = reader.GetOrdinal("controparte_ragione_sociale");
            trans.ControparteRagioneSociale = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "valuta_codice_iso"))
        {
            var ord = reader.GetOrdinal("valuta_codice_iso");
            trans.ValutaCodiceIso = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "causale_descrizione"))
        {
            var ord = reader.GetOrdinal("causale_descrizione");
            trans.CausaleDescrizione = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "causale_segno"))
        {
            var ord = reader.GetOrdinal("causale_segno");
            trans.CausaleSegno = reader.IsDBNull(ord) ? null : reader.GetInt32(ord);
        }
        if (HasColumn(reader, "causale_ciclo"))
        {
            var ord = reader.GetOrdinal("causale_ciclo");
            trans.CausaleCiclo = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "viaggio_descrizione"))
        {
            var ord = reader.GetOrdinal("viaggio_descrizione");
            trans.ViaggioDescrizione = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "data_viaggio_inizio"))
        {
            var ord = reader.GetOrdinal("data_viaggio_inizio");
            trans.DataViaggioInizio = reader.IsDBNull(ord) ? null : reader.GetDateTime(ord);
        }
        if (HasColumn(reader, "azienda_codice"))
        {
            var ord = reader.GetOrdinal("azienda_codice");
            trans.AziendaCodice = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }

        // IVA display properties (from JOINs)
        if (HasColumn(reader, "aliquota_iva_descrizione"))
        {
            var ord = reader.GetOrdinal("aliquota_iva_descrizione");
            trans.AliquotaIvaDescrizione = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "aliquota_iva_percentuale"))
        {
            var ord = reader.GetOrdinal("aliquota_iva_percentuale");
            trans.AliquotaIvaPercentuale = reader.IsDBNull(ord) ? null : reader.GetDecimal(ord);
        }
        if (HasColumn(reader, "aliquota_iva_codice"))
        {
            var ord = reader.GetOrdinal("aliquota_iva_codice");
            trans.AliquotaIvaCodice = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }

        return trans;
    }

    /// <summary>
    /// Mappa un NpgsqlDataReader a MovTransazioniRighe (AOT compatibile)
    /// </summary>
    private static MovTransazioniRighe MapReaderToMovTransazioniRighe(NpgsqlDataReader reader)
    {
        var riga = new MovTransazioniRighe();

        if (HasColumn(reader, "riga_id"))
            riga.RigaId = reader.GetInt32(reader.GetOrdinal("riga_id"));
        if (HasColumn(reader, "transazione_fk"))
            riga.TransazioneFk = reader.GetInt32(reader.GetOrdinal("transazione_fk"));
        if (HasColumn(reader, "riga_numero"))
            riga.RigaNumero = reader.GetInt32(reader.GetOrdinal("riga_numero"));
        if (HasColumn(reader, "riga_descrizione"))
            riga.RigaDescrizione = reader.GetString(reader.GetOrdinal("riga_descrizione"));
        if (HasColumn(reader, "riga_tipo"))
            riga.RigaTipo = reader.GetString(reader.GetOrdinal("riga_tipo"));
        if (HasColumn(reader, "riga_imponibile"))
            riga.RigaImponibile = reader.GetDecimal(reader.GetOrdinal("riga_imponibile"));
        if (HasColumn(reader, "riga_aliquota_iva_fk"))
            riga.RigaAliquotaIvaFk = reader.GetInt32(reader.GetOrdinal("riga_aliquota_iva_fk"));
        if (HasColumn(reader, "riga_iva_valore"))
            riga.RigaIvaValore = reader.GetDecimal(reader.GetOrdinal("riga_iva_valore"));
        if (HasColumn(reader, "riga_lordo"))
            riga.RigaLordo = reader.GetDecimal(reader.GetOrdinal("riga_lordo"));

        // Audit
        if (HasColumn(reader, "created_at"))
        {
            var ord = reader.GetOrdinal("created_at");
            riga.CreatedAt = reader.IsDBNull(ord) ? null : reader.GetDateTime(ord);
        }
        if (HasColumn(reader, "updated_at"))
        {
            var ord = reader.GetOrdinal("updated_at");
            riga.UpdatedAt = reader.IsDBNull(ord) ? null : reader.GetDateTime(ord);
        }

        // Navigation properties
        if (HasColumn(reader, "aliquota_iva_codice"))
        {
            var ord = reader.GetOrdinal("aliquota_iva_codice");
            riga.AliquotaIvaCodice = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "aliquota_iva_descrizione"))
        {
            var ord = reader.GetOrdinal("aliquota_iva_descrizione");
            riga.AliquotaIvaDescrizione = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "aliquota_iva_percentuale"))
        {
            var ord = reader.GetOrdinal("aliquota_iva_percentuale");
            riga.AliquotaIvaPercentuale = reader.IsDBNull(ord) ? null : reader.GetDecimal(ord);
        }

        return riga;
    }

    /// <summary>
    /// Mappa un NpgsqlDataReader a RegistraPagamentoResult (AOT compatibile)
    /// </summary>
    private static RegistraPagamentoResult MapReaderToRegistraPagamentoResult(NpgsqlDataReader reader)
    {
        var result = new RegistraPagamentoResult();

        if (HasColumn(reader, "pg_transazione_id"))
        {
            var ord = reader.GetOrdinal("pg_transazione_id");
            result.PgTransazioneId = reader.IsDBNull(ord) ? null : reader.GetInt32(ord);
        }
        if (HasColumn(reader, "nuovo_stato"))
        {
            var ord = reader.GetOrdinal("nuovo_stato");
            result.NuovoStato = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }
        if (HasColumn(reader, "importo_effettivo"))
        {
            var ord = reader.GetOrdinal("importo_effettivo");
            result.ImportoEffettivo = reader.IsDBNull(ord) ? null : reader.GetDecimal(ord);
        }
        if (HasColumn(reader, "error_message"))
        {
            var ord = reader.GetOrdinal("error_message");
            result.ErrorMessage = reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }

        return result;
    }

    #endregion
}
