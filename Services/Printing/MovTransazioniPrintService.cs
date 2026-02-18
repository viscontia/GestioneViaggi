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
            Filtri = filtri.ToFiltriApplicatiInfo() // Mappa i filtri per la visualizzazione
        };

        try
        {
            using var connection = await _dbService.GetConnectionAsync();

            // 1. Recupera dettagli transazioni
            // Mapping 1:1 con le colonne restituite da fn_get_transazioni_stampa_dettaglio
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
                    
                    controparte_ragione_sociale as ControparteRagioneSociale, -- ex Fornitore
                    
                    tipo_movimento_codice as TipoMovimentoCodice,
                    tipo_movimento_descrizione as TipoMovimentoDescrizione,
                    causale_segno as CausaleSegno,
                    transazione_causale as Causale,
                    causale_ciclo as CausaleCiclo, -- Nuovo
                    
                    transazione_stato as Stato,
                    transazione_numero_documento as NumeroDocumento,
                    valuta_codice_iso as ValutaCodiceIso,
                    
                    -- Valori Originali
                    imponibile_eur as ImponibileEur,
                    iva_eur as IvaEur,
                    lordo_eur as LordoEur, -- ex Importo

                    -- Dati IVA
                    aliquota_iva_codice as AliquotaIvaCodice,
                    aliquota_iva_percentuale as AliquotaIvaPercentuale,

                    -- Valori Convertiti
                    importo_valuta_target as ImportoValutaTarget,
                    valuta_target_iso as ValutaTargetIso,
                    
                    viaggio_descrizione as ViaggioDescrizione,
                    data_viaggio_inizio as DataViaggioInizio
                FROM fn_get_transazioni_stampa_dettaglio(
                    @AziendaId,
                    @ControparteId, -- ex FornitoreId
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
                    @ValutaTargetId,
                    @CausaleCiclo -- Nuovo
                )";

            var dettagli = await connection.QueryAsync<TransazionePrintItem>(dettagliSql, new
            {
                AziendaId = filtri.AziendaId,
                ControparteId = filtri.ControparteId, // ex FornitoreId
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
                ValutaTargetId = valutaTargetId,
                CausaleCiclo = filtri.CausaleCiclo
            });

            result.Dettagli = dettagli.ToList();

            // 2. Recupera subtotali per gruppo
            var subtotaliSql = @"
                SELECT
                    gruppo_chiave as GruppoChiave,
                    gruppo_display as GruppoDisplay,
                    gruppo_ordine as GruppoOrdine,
                    valuta_codice_iso as ValutaCodiceIso,
                    
                    totale_valuta_originale as TotaleValutaOriginale,
                    totale_valuta_target as TotaleValutaTarget,
                    
                    totale_fatturato_target as TotaleFatturatoTarget,
                    totale_pagato_target as TotalePagatoTarget,
                    
                    -- Nuovi Totali
                    totale_imponibile_target as TotaleImponibileTarget,
                    totale_iva_target as TotaleIvaTarget,

                    valuta_target_iso as ValutaTargetIso,
                    conteggio_transazioni as ConteggioTransazioni,
                    is_totale_generale as IsTotaleGenerale
                FROM fn_get_transazioni_stampa_subtotali(
                    @AziendaId,
                    @ControparteId, -- ex FornitoreId
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
                    @ValutaTargetId,
                    @CausaleCiclo -- Nuovo
                )";

            var subtotali = await connection.QueryAsync<SubTotaleItem>(subtotaliSql, new
            {
                AziendaId = filtri.AziendaId,
                ControparteId = filtri.ControparteId,
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
                ValutaTargetId = valutaTargetId,
                CausaleCiclo = filtri.CausaleCiclo
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
            
            // Use the shared function for consistent company info including logo
            var companySql = "SELECT * FROM get_company_print_info(@AziendaId)";
            var companyRaw = await connection.QueryFirstOrDefaultAsync<dynamic>(companySql, new { AziendaId = aziendaId });

            if (companyRaw != null)
            {
                return new CompanyPrintInfo
                {
                    RagioneSociale = (string)companyRaw.ragione_sociale ?? "",
                    Telefono = (string)companyRaw.telefono ?? "",
                    Email = (string)companyRaw.email ?? "",
                    SitoWeb = (string)companyRaw.sito_web ?? "",
                    Piva = (string)companyRaw.piva ?? "",
                    LogoData = companyRaw.logo_data != null ? (byte[])companyRaw.logo_data : Array.Empty<byte>()
                };
            }
            
            return new CompanyPrintInfo();
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
    public int? ControparteId { get; set; } // ex FornitoreId
    public int? CausaleTipoId { get; set; }
    public string? CausaleCiclo { get; set; } // Nuovo
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
    public string? ControparteNome { get; set; } // ex FornitoreNome
    public string? ValutaNome { get; set; }
    public string? ViaggioNome { get; set; }
    public string? TipoMovimentoNome { get; set; }

    public FiltriApplicatiInfo ToFiltriApplicatiInfo()
    {
        var info = new FiltriApplicatiInfo
        {
            Azienda = AziendaNome,
            Controparte = ControparteNome,
            CausaleCiclo = CausaleCiclo,
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
