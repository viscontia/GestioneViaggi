using Dapper;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Service per l'estrazione dei dati per la stampa delle fatture attive.
/// Utilizza le function DB fn_get_fattura_attiva_stampa e fn_get_fatture_attive_elenco.
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
    /// Recupera tutti i dati necessari per la stampa di una singola fattura attiva.
    /// </summary>
    public async Task<FatturaAttivaPrintData?> GetFatturaAttivaDataAsync(int transazioneId)
    {
        _logger.LogInformation("Inizio estrazione dati fattura attiva. Transazione: {TransazioneId}", transazioneId);

        try
        {
            using var connection = await _dbService.GetConnectionAsync();

            // 1. Recupera dati principali dalla function DB
            var sql = "SELECT * FROM fn_get_fattura_attiva_stampa(@TransazioneId)";
            var row = await connection.QueryFirstOrDefaultAsync<dynamic>(sql, new { TransazioneId = transazioneId });

            if (row == null)
            {
                _logger.LogWarning("Fattura attiva non trovata per transazione {TransazioneId}", transazioneId);
                return null;
            }

            // 2. Mappa dati principali
            var result = new FatturaAttivaPrintData
            {
                TransazioneId = (int)row.transazione_id,
                NumeroDocumento = (string?)row.transazione_numero_documento,
                DataDocumento = (DateTime?)row.transazione_data_documento,
                DataScadenza = (DateTime?)row.transazione_data_scadenza,
                Stato = (string?)row.transazione_stato ?? string.Empty,
                Causale = (string?)row.transazione_causale,
                NumeroProtocolloIva = (int?)row.transazione_numero_protocollo_iva,
                ImponibileEur = (decimal)row.transazione_imponibile_eur,
                IvaEur = (decimal)row.transazione_iva_eur,
                LordoEur = (decimal)row.transazione_lordo_eur,
                CausaleDescrizione = (string?)row.causale_descrizione,
                CausaleCodice = (string?)row.causale_codice,
                TipoDocumentoSdi = (string?)row.tipo_documento_sdi,
                DataStampa = DateTime.Now,

                Company = new InvoiceCompanyInfo
                {
                    RagioneSociale = (string?)row.azienda_ragione_sociale ?? string.Empty,
                    FormaGiuridica = (string?)row.azienda_forma_giuridica ?? string.Empty,
                    PartitaIva = (string?)row.azienda_partita_iva ?? string.Empty,
                    CodiceFiscale = (string?)row.azienda_codice_fiscale,
                    Telefono = (string?)row.azienda_telefono ?? string.Empty,
                    Pec = (string?)row.azienda_pec,
                    SitoWeb = (string?)row.azienda_sito_web,
                    CodiceSdi = (string?)row.azienda_codice_sdi,
                    LogoData = row.logo_data != null ? (byte[])row.logo_data : Array.Empty<byte>(),
                    Indirizzo = (string?)row.sede_indirizzo ?? string.Empty,
                    NumeroCivico = (string?)row.sede_numero_civico,
                    Cap = (string?)row.sede_cap ?? string.Empty,
                    Comune = (string?)row.sede_comune ?? string.Empty,
                    ProvinciaSigla = (string?)row.sede_provincia_sigla ?? string.Empty,
                    ReaNumero = (string?)row.azienda_rea_numero,
                    ReaProvinciaSigla = (string?)row.azienda_rea_provincia_sigla,
                    CapitaleSociale = (decimal?)row.azienda_capitale_sociale,
                    SocioUnico = (bool?)row.azienda_socio_unico ?? false,
                    InLiquidazione = (bool?)row.azienda_in_liquidazione ?? false,
                    RegimeCodice = (string?)row.regime_codice,
                    RegimeDescrizione = (string?)row.regime_descrizione,
                    IsIvaDetraibile = (bool?)row.regime_is_iva_detraibile ?? true,
                    RegimeCodiceSdi = (string?)row.regime_codice_sdi,
                    TipoCassaSdi = (string?)row.tipo_cassa_sdi,
                    CassaPrevPercentuale = (decimal?)row.cassa_prev_percentuale
                },

                Client = new InvoiceClientInfo
                {
                    Id = (int)row.controparte_id,
                    RagioneSociale = (string?)row.controparte_ragione_sociale ?? string.Empty,
                    Indirizzo = (string?)row.controparte_indirizzo,
                    Cap = (string?)row.controparte_cap,
                    Comune = (string?)row.controparte_comune,
                    ProvinciaSigla = (string?)row.controparte_provincia_sigla,
                    PartitaIva = (string?)row.controparte_partita_iva,
                    CodiceFiscale = (string?)row.controparte_codice_fiscale,
                    CodiceSdi = (string?)row.controparte_codice_sdi,
                    Pec = (string?)row.controparte_pec,
                    FornitoreEstero = (bool?)row.controparte_fornitore_estero ?? false
                }
            };

            // 3. Carica righe di dettaglio
            var sqlRighe = @"
                SELECT
                    r.riga_numero AS RigaNumero,
                    r.riga_descrizione AS RigaDescrizione,
                    r.riga_tipo AS RigaTipo,
                    r.riga_imponibile AS RigaImponibile,
                    a.iva_codice AS AliquotaIvaCodice,
                    a.iva_percentuale AS AliquotaIvaPercentuale,
                    a.iva_natura AS AliquotaIvaNatura,
                    r.riga_iva_valore AS RigaIvaValore,
                    r.riga_lordo AS RigaLordo
                FROM mov_transazioni_righe r
                JOIN ana_aliquote_iva a ON r.riga_aliquota_iva_fk = a.iva_id
                WHERE r.transazione_fk = @TransazioneId
                ORDER BY r.riga_numero";

            result.Righe = (await connection.QueryAsync<InvoiceLineItem>(sqlRighe, new { TransazioneId = transazioneId })).ToList();

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

            _logger.LogInformation(
                "Fattura attiva estratta: {Righe} righe, {Aliquote} aliquote IVA",
                result.Righe.Count, result.RiepilogoIva.Count);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei dati fattura attiva per transazione {TransazioneId}", transazioneId);
            throw;
        }
    }

    /// <summary>
    /// Recupera gli anni distinti in cui esistono fatture attive per un'azienda.
    /// Usato per popolare il combobox Anno nella pagina di ricerca.
    /// </summary>
    public async Task<List<int>> GetAnniDisponibiliAsync(int aziendaId)
    {
        try
        {
            using var connection = await _dbService.GetConnectionAsync();

            var sql = "SELECT anno FROM fn_get_anni_fatture_attive(@AziendaId)";

            var anni = await connection.QueryAsync<int>(sql, new { AziendaId = aziendaId });
            return anni.ToList();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero anni disponibili per azienda {AziendaId}", aziendaId);
            return new List<int>();
        }
    }

    /// <summary>
    /// Recupera l'elenco delle fatture attive filtrato per la pagina di ricerca.
    /// </summary>
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
        _logger.LogInformation(
            "Ricerca fatture attive. Azienda: {AziendaId}, Controparte: {ControparteId}, Periodo: {Da} - {A}",
            aziendaId, controparteId, dataDocDa, dataDocA);

        try
        {
            using var connection = await _dbService.GetConnectionAsync();

            var sql = @"
                SELECT
                    transazione_id AS TransazioneId,
                    transazione_data AS TransazioneData,
                    data_documento AS DataDocumento,
                    numero_documento AS NumeroDocumento,
                    numero_protocollo_iva AS NumeroProtocolloIva,
                    controparte_ragione_sociale AS ControparteRagioneSociale,
                    imponibile_eur AS ImponibileEur,
                    iva_eur AS IvaEur,
                    lordo_eur AS LordoEur,
                    stato AS Stato,
                    data_scadenza AS DataScadenza,
                    causale_descrizione AS CausaleDescrizione
                FROM fn_get_fatture_attive_elenco(
                    @AziendaId, @ControparteId, @DataDocDa::DATE, @DataDocA::DATE,
                    @ImportoDa, @ImportoA, @Stato::VARCHAR, @NumeroDocumento::VARCHAR)";

            var items = await connection.QueryAsync<FatturaAttivaListItem>(sql, new
            {
                AziendaId = aziendaId,
                ControparteId = controparteId,
                DataDocDa = dataDocDa,
                DataDocA = dataDocA,
                ImportoDa = importoDa,
                ImportoA = importoA,
                Stato = stato,
                NumeroDocumento = numeroDocumento
            });

            var result = items.ToList();

            _logger.LogInformation("Fatture attive trovate: {Count}", result.Count);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la ricerca fatture attive per azienda {AziendaId}", aziendaId);
            throw;
        }
    }
}
