using Npgsql;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Service per l'estrazione dei dati per la stampa delle fatture attive.
/// Utilizza la function DB Fat Init fn_get_fattura_attiva_print_data.
/// </summary>
public class FatturaAttivaPrintService
{
    private readonly IDatabaseService _dbService;
    private readonly ILogger<FatturaAttivaPrintService> _logger;

    public FatturaAttivaPrintService(
        IDatabaseService dbService,
        ILogger<FatturaAttivaPrintService> logger)
    {
        _dbService = dbService;
        _logger = logger;
    }

    /// <summary>
    /// Recupera tutti i dati necessari per la stampa di una singola fattura attiva tramite pattern Fat Init.
    /// </summary>
    public async Task<FatturaAttivaPrintData?> GetFatturaAttivaDataAsync(int transazioneId)
    {
        _logger.LogInformation("Inizio estrazione dati fattura attiva (Fat Init). Transazione: {TransazioneId}", transazioneId);

        try
        {
            await using var connection = await _dbService.GetConnectionAsync();

            var sql = "SELECT fn_get_fattura_attiva_print_data(@TransazioneId)";
            await using var cmd = new NpgsqlCommand(sql, (NpgsqlConnection)connection);
            cmd.Parameters.AddWithValue("TransazioneId", transazioneId);
            var jsonResponse = await cmd.ExecuteScalarAsync() as string;

            if (string.IsNullOrEmpty(jsonResponse))
            {
                _logger.LogWarning("Fattura attiva non trovata per transazione {TransazioneId}", transazioneId);
                return null;
            }

            var rawData = JsonSerializer.Deserialize<FatturaAttivaRawResponse>(jsonResponse, PrintJsonHelper.GetDefaultOptions());

            if (rawData == null || rawData.Testata == null) return null;

            var t = rawData.Testata;

            var result = new FatturaAttivaPrintData
            {
                TransazioneId = t.TransazioneId,
                NumeroDocumento = t.TransazioneNumeroDocumento,
                DataDocumento = t.TransazioneDataDocumento,
                DataScadenza = t.TransazioneDataScadenza,
                Stato = t.TransazioneStato ?? string.Empty,
                Causale = t.TransazioneCausale,
                NumeroProtocolloIva = t.TransazioneNumeroProtocolloIva,
                ImponibileEur = t.TransazioneImponibileEur,
                IvaEur = t.TransazioneIvaEur,
                LordoEur = t.TransazioneLordoEur,
                CausaleDescrizione = t.CausaleDescrizione,
                CausaleCodice = t.CausaleCodice,
                TipoDocumentoSdi = t.TipoDocumentoSdi,
                DataStampa = DateTime.Now,

                Company = new InvoiceCompanyInfo
                {
                    AziendaId = t.AziendaId,
                    RagioneSociale = t.AziendaRagioneSociale ?? string.Empty,
                    FormaGiuridica = t.AziendaFormaGiuridica ?? string.Empty,
                    PartitaIva = t.AziendaPartitaIva ?? string.Empty,
                    CodiceFiscale = t.AziendaCodiceFiscale,
                    Telefono = t.AziendaTelefono ?? string.Empty,
                    Pec = t.AziendaPec,
                    SitoWeb = t.AziendaSitoWeb,
                    CodiceSdi = t.AziendaCodiceSdi,
                    LogoData = t.LogoData ?? Array.Empty<byte>(),
                    Indirizzo = t.SedeIndirizzo ?? string.Empty,
                    NumeroCivico = t.SedeNumeroCivico,
                    Cap = t.SedeCap ?? string.Empty,
                    Comune = t.SedeComune ?? string.Empty,
                    ProvinciaSigla = t.SedeProvinciaSigla ?? string.Empty,
                    ReaNumero = t.AziendaReaNumero,
                    ReaProvinciaSigla = t.AziendaReaProvinciaSigla,
                    CapitaleSociale = t.AziendaCapitaleSociale,
                    SocioUnico = t.AziendaSocioUnico,
                    InLiquidazione = t.AziendaInLiquidazione,
                    RegimeCodice = t.RegimeCodice,
                    RegimeDescrizione = t.RegimeDescrizione,
                    IsIvaDetraibile = t.RegimeIsIvaDetraibile,
                    RegimeCodiceSdi = t.RegimeCodiceSdi,
                    TipoCassaSdi = t.TipoCassaSdi,
                    CassaPrevPercentuale = t.CassaPrevPercentuale
                },

                Client = new InvoiceClientInfo
                {
                    Id = t.ControparteId,
                    RagioneSociale = t.ControparteRagioneSociale ?? string.Empty,
                    Indirizzo = t.ControparteIndirizzo,
                    Cap = t.ControparteCap,
                    Comune = t.ControparteComune,
                    ProvinciaSigla = t.ControparteProvinciaSigla,
                    PartitaIva = t.ContropartePartitaIva,
                    CodiceFiscale = t.ControparteCodiceFiscale,
                    CodiceSdi = t.ControparteCodiceSdi,
                    Pec = t.ContropartePec,
                    FornitoreEstero = t.ControparteFornitoreEstero
                },
                Righe = rawData.Righe ?? new List<InvoiceLineItem>()
            };

            // 4. Calcola riepilogo IVA raggruppato per aliquota (escluso BOLLO)
            result.RiepilogoIva = result.Righe
                .Where(r => r.RigaTipo != "BOLLO")
                .GroupBy(r => new { Codice = r.AliquotaIvaCodice ?? "N/D", Percentuale = r.AliquotaIvaPercentuale ?? 0, Natura = r.AliquotaIvaNatura })
                .Select(g => new InvoiceVatSummaryRow
                {
                    AliquotaCodice = g.Key.Codice,
                    AliquotaPercentuale = g.Key.Percentuale,
                    AliquotaNatura = g.Key.Natura,
                    TotaleImponibile = g.Sum(r => r.RigaImponibile),
                    TotaleIva = g.Sum(r => r.RigaIvaValore),
                    TotaleLordo = g.Sum(r => r.RigaLordo)
                })
                .OrderByDescending(s => s.AliquotaPercentuale)
                .ThenBy(s => s.AliquotaCodice)
                .ToList();

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei dati fattura attiva (Fat Init) per transazione {TransazioneId}", transazioneId);
            throw;
        }
    }

    public async Task<List<int>> GetAnniDisponibiliAsync(int aziendaId)
    {
        try
        {
            await using var connection = await _dbService.GetConnectionAsync();
            var sql = "SELECT anno FROM fn_get_anni_fatture_attive(@AziendaId)";
            await using var cmd = new NpgsqlCommand(sql, (NpgsqlConnection)connection);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);
            
            var anni = new List<int>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                if (!reader.IsDBNull(0))
                    anni.Add(reader.GetInt32(0));
            }
            return anni;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero anni disponibili per azienda {AziendaId}", aziendaId);
            return new List<int>();
        }
    }

    public async Task<List<FatturaAttivaListItem>> GetElencoFattureAttiveAsync(
        int aziendaId,
        int? controparteId = null,
        DateTime? dataDocDa = null,
        DateTime? dataDocA = null,
        decimal? importoDa = null,
        decimal? importoA = null,
        string? stato = null,
        string? numeroDocumento = null)
    {
        try
        {
            await using var connection = await _dbService.GetConnectionAsync();
            var sql = "SELECT * FROM fn_get_fatture_attive_elenco(@AziendaId, @ControparteId, @DataDocDa, @DataDocA, @ImportoDa, @ImportoA, @Stato, @NumeroDocumento)";
            
            await using var cmd = new NpgsqlCommand(sql, (NpgsqlConnection)connection);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);
            cmd.Parameters.AddWithValue("ControparteId", controparteId ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("DataDocDa", dataDocDa ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("DataDocA", dataDocA ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("ImportoDa", importoDa ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("ImportoA", importoA ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("Stato", stato ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("NumeroDocumento", numeroDocumento ?? (object)DBNull.Value);

            var items = new List<FatturaAttivaListItem>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                items.Add(new FatturaAttivaListItem
                {
                    TransazioneId = reader.GetInt32(reader.GetOrdinal("transazione_id")),
                    TransazioneData = reader.IsDBNull(reader.GetOrdinal("transazione_data")) ? null : reader.GetDateTime(reader.GetOrdinal("transazione_data")),
                    DataDocumento = reader.IsDBNull(reader.GetOrdinal("data_documento")) ? null : reader.GetDateTime(reader.GetOrdinal("data_documento")),
                    NumeroDocumento = reader.IsDBNull(reader.GetOrdinal("numero_documento")) ? null : reader.GetString(reader.GetOrdinal("numero_documento")),
                    NumeroProtocolloIva = reader.IsDBNull(reader.GetOrdinal("numero_protocollo_iva")) ? null : reader.GetInt32(reader.GetOrdinal("numero_protocollo_iva")),
                    ControparteRagioneSociale = reader.IsDBNull(reader.GetOrdinal("controparte_ragione_sociale")) ? string.Empty : reader.GetString(reader.GetOrdinal("controparte_ragione_sociale")),
                    ImponibileEur = reader.GetDecimal(reader.GetOrdinal("imponibile_eur")),
                    IvaEur = reader.GetDecimal(reader.GetOrdinal("iva_eur")),
                    LordoEur = reader.GetDecimal(reader.GetOrdinal("lordo_eur")),
                    Stato = reader.GetString(reader.GetOrdinal("stato")),
                    DataScadenza = reader.IsDBNull(reader.GetOrdinal("data_scadenza")) ? null : reader.GetDateTime(reader.GetOrdinal("data_scadenza")),
                    CausaleDescrizione = reader.IsDBNull(reader.GetOrdinal("causale_descrizione")) ? null : reader.GetString(reader.GetOrdinal("causale_descrizione"))
                });
            }
            return items;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la ricerca fatture attive per azienda {AziendaId}", aziendaId);
            throw;
        }
    }

    // Helper classes for JSON Deserialization
    private class FatturaAttivaRawResponse
    {
        public FatturaTestataRaw? Testata { get; set; }
        public List<InvoiceLineItem>? Righe { get; set; }
    }

    private class FatturaTestataRaw
    {
        [JsonPropertyName("transazione_id")] public int TransazioneId { get; set; }
        [JsonPropertyName("transazione_data")] public DateTime TransazioneData { get; set; }
        [JsonPropertyName("transazione_data_documento")] public DateTime? TransazioneDataDocumento { get; set; }
        [JsonPropertyName("transazione_data_scadenza")] public DateTime? TransazioneDataScadenza { get; set; }
        [JsonPropertyName("transazione_numero_documento")] public string? TransazioneNumeroDocumento { get; set; }
        [JsonPropertyName("transazione_stato")] public string? TransazioneStato { get; set; }
        [JsonPropertyName("transazione_causale")] public string? TransazioneCausale { get; set; }
        [JsonPropertyName("transazione_numero_protocollo_iva")] public int? TransazioneNumeroProtocolloIva { get; set; }
        [JsonPropertyName("transazione_imponibile_eur")] public decimal TransazioneImponibileEur { get; set; }
        [JsonPropertyName("transazione_iva_eur")] public decimal TransazioneIvaEur { get; set; }
        [JsonPropertyName("transazione_lordo_eur")] public decimal TransazioneLordoEur { get; set; }
        [JsonPropertyName("azienda_id")] public int AziendaId { get; set; }
        [JsonPropertyName("azienda_ragione_sociale")] public string? AziendaRagioneSociale { get; set; }
        [JsonPropertyName("azienda_forma_giuridica")] public string? AziendaFormaGiuridica { get; set; }
        [JsonPropertyName("azienda_partita_iva")] public string? AziendaPartitaIva { get; set; }
        [JsonPropertyName("azienda_codice_fiscale")] public string? AziendaCodiceFiscale { get; set; }
        [JsonPropertyName("azienda_telefono")] public string? AziendaTelefono { get; set; }
        [JsonPropertyName("azienda_pec")] public string? AziendaPec { get; set; }
        [JsonPropertyName("azienda_sito_web")] public string? AziendaSitoWeb { get; set; }
        [JsonPropertyName("azienda_codice_sdi")] public string? AziendaCodiceSdi { get; set; }
        [JsonPropertyName("azienda_rea_numero")] public string? AziendaReaNumero { get; set; }
        [JsonPropertyName("azienda_rea_provincia_sigla")] public string? AziendaReaProvinciaSigla { get; set; }
        [JsonPropertyName("azienda_capitale_sociale")] public decimal? AziendaCapitaleSociale { get; set; }
        [JsonPropertyName("azienda_socio_unico")] public bool AziendaSocioUnico { get; set; }
        [JsonPropertyName("azienda_in_liquidazione")] public bool AziendaInLiquidazione { get; set; }
        [JsonPropertyName("regime_codice")] public string? RegimeCodice { get; set; }
        [JsonPropertyName("regime_descrizione")] public string? RegimeDescrizione { get; set; }
        [JsonPropertyName("regime_is_iva_detraibile")] public bool RegimeIsIvaDetraibile { get; set; }
        [JsonPropertyName("regime_codice_sdi")] public string? RegimeCodiceSdi { get; set; }
        [JsonPropertyName("tipo_cassa_sdi")] public string? TipoCassaSdi { get; set; }
        [JsonPropertyName("cassa_prev_percentuale")] public decimal? CassaPrevPercentuale { get; set; }
        [JsonPropertyName("sede_indirizzo")] public string? SedeIndirizzo { get; set; }
        [JsonPropertyName("sede_numero_civico")] public string? SedeNumeroCivico { get; set; }
        [JsonPropertyName("sede_cap")] public string? SedeCap { get; set; }
        [JsonPropertyName("sede_comune")] public string? SedeComune { get; set; }
        [JsonPropertyName("sede_provincia_sigla")] public string? SedeProvinciaSigla { get; set; }
        [JsonPropertyName("logo_data")] public byte[]? LogoData { get; set; }
        [JsonPropertyName("controparte_id")] public int ControparteId { get; set; }
        [JsonPropertyName("controparte_ragione_sociale")] public string? ControparteRagioneSociale { get; set; }
        [JsonPropertyName("controparte_indirizzo")] public string? ControparteIndirizzo { get; set; }
        [JsonPropertyName("controparte_cap")] public string? ControparteCap { get; set; }
        [JsonPropertyName("controparte_comune")] public string? ControparteComune { get; set; }
        [JsonPropertyName("controparte_provincia_sigla")] public string? ControparteProvinciaSigla { get; set; }
        [JsonPropertyName("controparte_partita_iva")] public string? ContropartePartitaIva { get; set; }
        [JsonPropertyName("controparte_codice_fiscale")] public string? ControparteCodiceFiscale { get; set; }
        [JsonPropertyName("controparte_codice_sdi")] public string? ControparteCodiceSdi { get; set; }
        [JsonPropertyName("controparte_pec")] public string? ContropartePec { get; set; }
        [JsonPropertyName("controparte_fornitore_estero")] public bool ControparteFornitoreEstero { get; set; }
        [JsonPropertyName("causale_descrizione")] public string? CausaleDescrizione { get; set; }
        [JsonPropertyName("causale_codice")] public string? CausaleCodice { get; set; }
        [JsonPropertyName("tipo_documento_sdi")] public string? TipoDocumentoSdi { get; set; }
    }
}
