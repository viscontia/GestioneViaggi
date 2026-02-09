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
                    transazione_tipo_movimento as TipoMovimento,
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
                    @TipoMovimento,
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
                TipoMovimento = filtri.TipoMovimento,
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
            _logger.LogInformation("Recuperate {Count} transazioni", result.Dettagli.Count);

            // 2. Recupera sub-totali
            var subtotaliSql = @"
                SELECT 
                    gruppo_chiave as GruppoChiave,
                    gruppo_display as GruppoDisplay,
                    gruppo_ordine as GruppoOrdine,
                    valuta_codice_iso as ValutaCodiceIso,
                    totale_valuta_originale as TotaleOriginale,
                    totale_valuta_target as TotaleValutaTarget,
                    valuta_target_iso as ValutaTargetIso,
                    conteggio_transazioni as ConteggioTransazioni,
                    is_totale_generale as IsTotaleGenerale
                FROM fn_get_transazioni_stampa_subtotali(
                    @AziendaId,
                    @FornitoreId,
                    @TipoMovimento,
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
                TipoMovimento = filtri.TipoMovimento,
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

            result.SubTotali = subtotali.ToList();
            _logger.LogInformation("Recuperati {Count} sub-totali", result.SubTotali.Count);

            // 3. Recupera informazioni azienda
            result.Company = await GetCompanyInfoAsync(connection, filtri.AziendaId);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante estrazione dati stampa transazioni");
            throw;
        }
    }

    private async Task<CompanyPrintInfo> GetCompanyInfoAsync(System.Data.IDbConnection connection, int? aziendaId)
    {
        if (!aziendaId.HasValue)
            return new CompanyPrintInfo { RagioneSociale = "Tutte le Aziende" };

        try
        {
            var sql = @"SELECT * FROM get_company_print_info(@AziendaId)";
            var company = await connection.QueryFirstOrDefaultAsync<CompanyPrintInfo>(sql, new { AziendaId = aziendaId });
            return company ?? new CompanyPrintInfo();
        }
        catch
        {
            // Se la function non esiste, fallback a query diretta
            var sql = @"
                SELECT 
                    a.azienda_denominazione as RagioneSociale,
                    a.azienda_telefono as Telefono,
                    a.azienda_email as Email,
                    a.azienda_sito_web as SitoWeb,
                    a.azienda_partita_iva as Piva,
                    (SELECT al.binary_data 
                     FROM ana_aziende_logo al 
                     WHERE al.azienda_fk = a.azienda_id 
                       AND al.logo_type = 'primary' 
                       AND al.is_active = true 
                       AND al.is_default = true 
                     LIMIT 1) as LogoData
                FROM ana_aziende a
                WHERE a.azienda_id = @AziendaId";
            var company = await connection.QueryFirstOrDefaultAsync<CompanyPrintInfo>(sql, new { AziendaId = aziendaId });
            return company ?? new CompanyPrintInfo();
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
    public string? TipoMovimento { get; set; }
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

    public FiltriApplicatiInfo ToFiltriApplicatiInfo()
    {
        var info = new FiltriApplicatiInfo
        {
            Azienda = AziendaNome,
            Fornitore = FornitoreNome,
            TipoMovimento = TipoMovimento,
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
