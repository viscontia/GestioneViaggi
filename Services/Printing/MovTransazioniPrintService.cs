using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Service per l'estrazione dei dati per la stampa PDF dei movimenti contabili.
/// Utilizza le function DB fn_get_transazioni_stampa_dettaglio e fn_get_transazioni_stampa_subtotali.
/// </summary>
public class MovTransazioniPrintService
{
    private readonly IDatabaseService _dbService;
    private readonly ILogger<MovTransazioniPrintService> _logger;

    public MovTransazioniPrintService(
        IDatabaseService dbService,
        ILogger<MovTransazioniPrintService> logger)
    {
        _dbService = dbService;
        _logger = logger;
    }

    /// <summary>
    /// Recupera tutti i dati necessari per la stampa PDF delle transazioni.
    /// </summary>
    public async Task<TransazioniPrintData> GetDataPerStampaAsync(
        TransazioniFiltriDTO filtri,
        string ordinamento,
        int? valutaTargetId,
        string valutaTargetIso,
        UserInfo currentUser)
    {
        _logger.LogInformation("Inizio estrazione dati stampa transazioni. Ordinamento: {Ord}", ordinamento);

        var result = new TransazioniPrintData
        {
            TipoOrdinamento = ordinamento,
            ValutaTargetCodiceIso = valutaTargetIso,
            DataStampa = DateTime.Now,
            UtenteStampa = currentUser.FullName,
            Filtri = filtri.ToFiltriApplicatiInfo()
        };

        try
        {
            using var connection = await _dbService.GetConnectionAsync();

            // 1. Recupera dettagli transazioni
            var dettagliSql = @"
                SELECT 
                    gruppo_chiave as GruppoChiave,
                    gruppo_display as GruppoDisplay,
                    gruppo_ordine as GruppoOrdine,
                    transazione_id as TransazioneId,
                    transazione_data as DataTransazione,
                    transazione_data_documento as DataDocumento,
                    transazione_data_scadenza as DataScadenza,
                    transazione_data_pagamento as DataPagamento,
                    fornitore_ragione_sociale as Fornitore,
                    tipo_movimento_codice as TipoMovimentoCodice,
                    tipo_movimento_descrizione as TipoMovimentoDescrizione,
                    causale_segno as CausaleSegno,
                    transazione_causale as Causale,
                    transazione_stato as Stato,
                    transazione_numero_documento as NumeroDocumento,
                    valuta_codice_iso as ValutaCodiceIso,
                    transazione_importo as Importo,
                    importo_valuta_target as ImportoValutaTarget,
                    valuta_target_iso as ValutaTargetIso,
                    viaggio_descrizione as ViaggioDescrizione,
                    data_viaggio_inizio as DataViaggioInizio
                FROM fn_get_transazioni_stampa_dettaglio(
                    @AziendaId,
                    @FornitoreId,
                    @CausaleTipoId,
                    @Stati,
                    @ViaggioId,
                    @DataViaggioId,
                    @ValutaId,
                    @DataTransazioneDa,
                    @DataTransazioneA,
                    @DataDocumentoDa,
                    @DataDocumentoA,
                    @ImportoDa,
                    @ImportoA,
                    @NumeroDocumento,
                    @SoloConDocumento,
                    @SoloScadute,
                    @SoloConViaggio,
                    @SoloSenzaViaggio,
                    @SoloConFattura,
                    @Ordinamento,
                    @ValutaTargetId
                )";

            var dettagli = await connection.QueryAsync<TransazionePrintItem>(dettagliSql, new
            {
                AziendaId = filtri.AziendaId,
                FornitoreId = filtri.FornitoreId,
                CausaleTipoId = filtri.CausaleTipoId,
                Stati = filtri.Stati,
                ViaggioId = filtri.ViaggioId,
                DataViaggioId = filtri.DataViaggioId,
                ValutaId = filtri.ValutaId,
                DataTransazioneDa = filtri.DataTransazioneDa,
                DataTransazioneA = filtri.DataTransazioneA,
                DataDocumentoDa = filtri.DataDocumentoDa,
                DataDocumentoA = filtri.DataDocumentoA,
                ImportoDa = filtri.ImportoDa,
                ImportoA = filtri.ImportoA,
                NumeroDocumento = filtri.NumeroDocumento,
                SoloConDocumento = filtri.SoloConDocumento,
                SoloScadute = filtri.SoloScadute,
                SoloConViaggio = filtri.SoloConViaggio,
                SoloSenzaViaggio = filtri.SoloSenzaViaggio,
                SoloConFattura = filtri.SoloConFattura,
                Ordinamento = ordinamento,
                ValutaTargetId = valutaTargetId
            });

            result.Dettagli = dettagli.ToList();

            // 2. Recupera subtotali per gruppo
            var subtotaliSql = @"
                SELECT
                    gruppo_chiave as GruppoChiave,
                    gruppo_display as GruppoDisplay,
                    gruppo_ordine as GruppoOrdine,
                    valuta_codice_iso as ValutaCodiceIso,
                    totale_valuta_originale as TotaleOriginale,
                    totale_valuta_target as TotaleValutaTarget,
                    totale_fatturato_target as TotaleFatturatoTarget,
                    totale_pagato_target as TotalePagatoTarget,
                    valuta_target_iso as ValutaTargetIso,
                    conteggio_transazioni as ConteggioTransazioni,
                    is_totale_generale as IsTotaleGenerale
                FROM fn_get_transazioni_stampa_subtotali(
                    @AziendaId,
                    @FornitoreId,
                    @CausaleTipoId,
                    @Stati,
                    @ViaggioId,
                    @DataViaggioId,
                    @ValutaId,
                    @DataTransazioneDa,
                    @DataTransazioneA,
                    @DataDocumentoDa,
                    @DataDocumentoA,
                    @ImportoDa,
                    @ImportoA,
                    @NumeroDocumento,
                    @SoloConDocumento,
                    @SoloScadute,
                    @SoloConViaggio,
                    @SoloSenzaViaggio,
                    @SoloConFattura,
                    @Ordinamento,
                    @ValutaTargetId
                )";

            var subtotali = await connection.QueryAsync<SubTotaleItem>(subtotaliSql, new
            {
                AziendaId = filtri.AziendaId,
                FornitoreId = filtri.FornitoreId,
                CausaleTipoId = filtri.CausaleTipoId,
                Stati = filtri.Stati,
                ViaggioId = filtri.ViaggioId,
                DataViaggioId = filtri.DataViaggioId,
                ValutaId = filtri.ValutaId,
                DataTransazioneDa = filtri.DataTransazioneDa,
                DataTransazioneA = filtri.DataTransazioneA,
                DataDocumentoDa = filtri.DataDocumentoDa,
                DataDocumentoA = filtri.DataDocumentoA,
                ImportoDa = filtri.ImportoDa,
                ImportoA = filtri.ImportoA,
                NumeroDocumento = filtri.NumeroDocumento,
                SoloConDocumento = filtri.SoloConDocumento,
                SoloScadute = filtri.SoloScadute,
                SoloConViaggio = filtri.SoloConViaggio,
                SoloSenzaViaggio = filtri.SoloSenzaViaggio,
                SoloConFattura = filtri.SoloConFattura,
                Ordinamento = ordinamento,
                ValutaTargetId = valutaTargetId
            });

            result.Subtotali = subtotali.ToList();

            // 3. Calcola il totale generale
            result.TotaleGeneraleValutaTarget = result.Subtotali.Where(s => s.IsTotaleGenerale).Sum(s => s.TotaleValutaTarget);

            // 4. Se filtrato per azienda, recupera info azienda
            if (filtri.AziendaId.HasValue)
            {
                result.Azienda = await GetAziendaInfoAsync(filtri.AziendaId.Value);
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei dati per la stampa");
            throw;
        }
    }

    private async Task<CompanyPrintInfo> GetAziendaInfoAsync(int aziendaId)
    {
        try
        {
            using var connection = await _dbService.GetConnectionAsync();
            string sql = "SELECT azienda_codice as Codice, azienda_ragione_sociale as RagioneSociale FROM ana_aziende WHERE azienda_id = @Id";
            return await connection.QueryFirstOrDefaultAsync<CompanyPrintInfo>(sql, new { Id = aziendaId }) ?? new CompanyPrintInfo();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero info azienda {Id} per stampa", aziendaId);
            return new CompanyPrintInfo();
        }
    }
}

/// <summary>
/// DTO per i filtri passati al service di stampa
/// </summary>
public class TransazioniFiltriDTO
{
    public int? AziendaId { get; set; }
    public int? FornitoreId { get; set; }
    public int? CausaleTipoId { get; set; }
    public string[]? Stati { get; set; }
    public int? ViaggioId { get; set; }
    public int? DataViaggioId { get; set; }
    public int? ValutaId { get; set; }
    public DateTime? DataTransazioneDa { get; set; }
    public DateTime? DataTransazioneA { get; set; }
    public DateTime? DataDocumentoDa { get; set; }
    public DateTime? DataDocumentoA { get; set; }
    public decimal? ImportoDa { get; set; }
    public decimal? ImportoA { get; set; }
    public string? NumeroDocumento { get; set; }
    public bool SoloConDocumento { get; set; }
    public bool SoloScadute { get; set; }
    public bool SoloConViaggio { get; set; }
    public bool SoloSenzaViaggio { get; set; }
    public bool SoloConFattura { get; set; }

    // Nomi per visualizzazione nei filtri applicati
    public string? AziendaNome { get; set; }
    public string? FornitoreNome { get; set; }
    public string? ValutaNome { get; set; }
    public string? ViaggioNome { get; set; }
    public string? TipoMovimentoNome { get; set; }

    public FiltriApplicatiInfo ToFiltriApplicatiInfo()
    {
        var info = new FiltriApplicatiInfo
        {
            Azienda = AziendaNome,
            Fornitore = FornitoreNome,
            TipoMovimento = TipoMovimentoNome,
            Valuta = ValutaNome,
            Viaggio = ViaggioNome,
            DataDocumentoDal = DataDocumentoDa?.ToString("dd/MM/yyyy"),
            DataDocumentoAl = DataDocumentoA?.ToString("dd/MM/yyyy"),
            DataTransazioneDal = DataTransazioneDa?.ToString("dd/MM/yyyy"),
            DataTransazioneAl = DataTransazioneA?.ToString("dd/MM/yyyy"),
            ImportoDa = ImportoDa?.ToString("N2"),
            ImportoA = ImportoA?.ToString("N2"),
            NumeroDocumento = NumeroDocumento
        };

        if (SoloConDocumento) info.Checkbox.Add("Solo con documento");
        if (SoloScadute) info.Checkbox.Add("Solo scadute");
        if (SoloConViaggio) info.Checkbox.Add("Solo con viaggio");
        if (SoloSenzaViaggio) info.Checkbox.Add("Solo senza viaggio");
        if (SoloConFattura) info.Checkbox.Add("Solo con fattura");

        return info;
    }
}
