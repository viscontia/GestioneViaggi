using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Service per l'estrazione dei dati per la stampa PDF dei movimenti contabili.
/// Utilizza la function DB Fat Init fn_get_mov_transazioni_print_data.
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
    /// Recupera tutti i dati necessari per la stampa PDF delle transazioni tramite pattern Fat Init.
    /// </summary>
    public async Task<TransazioniPrintData> GetDataPerStampaAsync(
        TransazioniFiltriDTO filtri,
        string ordinamento,
        int? valutaTargetId,
        string valutaTargetIso,
        UserInfo currentUser)
    {
        _logger.LogInformation("Inizio estrazione dati stampa transazioni (Fat Init). Ordinamento: {Ord}", ordinamento);

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
            await using var connection = await _dbService.GetConnectionAsync();

            var sql = "SELECT fn_get_mov_transazioni_print_data(@AziendaId, @ControparteId, @CausaleTipoId, @Stati, @ViaggioId, @DataViaggioId, @ValutaId, @DataTransazioneDa, @DataTransazioneA, @DataDocumentoDa, @DataDocumentoA, @ImportoDa, @ImportoA, @NumeroDocumento, @SoloConDocumento, @SoloScadute, @SoloConViaggio, @SoloSenzaViaggio, @SoloConFattura, @Ordinamento, @ValutaTargetId, @CausaleCiclo)";

            var jsonResponse = await connection.QueryFirstOrDefaultAsync<string>(sql, new
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

            if (string.IsNullOrEmpty(jsonResponse)) return result;

            var rawData = JsonSerializer.Deserialize<MovTransazioniRawResponse>(jsonResponse, PrintJsonHelper.GetDefaultOptions());

            if (rawData != null)
            {
                // Mappatura Info Azienda
                if (rawData.Azienda != null)
                {
                    result.Azienda = new CompanyPrintInfo
                    {
                        RagioneSociale = rawData.Azienda.RagioneSociale ?? "",
                        Telefono = rawData.Azienda.Telefono ?? "",
                        Email = rawData.Azienda.Email ?? "",
                        SitoWeb = rawData.Azienda.SitoWeb ?? "",
                        Piva = rawData.Azienda.Piva ?? "",
                        LogoData = rawData.Azienda.LogoData ?? Array.Empty<byte>()
                    };
                }

                // Mappatura Dettagli e Subtotali
                result.Dettagli = rawData.Dettagli ?? new List<TransazionePrintItem>();
                result.Subtotali = rawData.Subtotali ?? new List<SubTotaleItem>();

                // Calcolo Totale Generale
                result.TotaleGeneraleValutaTarget = result.Subtotali
                    .Where(s => s.IsTotaleGenerale)
                    .Sum(s => s.TotaleValutaTarget);
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei dati per la stampa (Fat Init)");
            throw;
        }
    }

    // Helper classes for JSON Deserialization
    private class MovTransazioniRawResponse
    {
        public MovAziendaRaw? Azienda { get; set; }
        public List<TransazionePrintItem>? Dettagli { get; set; }
        public List<SubTotaleItem>? Subtotali { get; set; }
    }

    private class MovAziendaRaw
    {
        [JsonPropertyName("ragione_sociale")] public string? RagioneSociale { get; set; }
        [JsonPropertyName("telefono")] public string? Telefono { get; set; }
        [JsonPropertyName("email")] public string? Email { get; set; }
        [JsonPropertyName("sito_web")] public string? SitoWeb { get; set; }
        [JsonPropertyName("piva")] public string? Piva { get; set; }
        [JsonPropertyName("logo_data")] public byte[]? LogoData { get; set; }
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
