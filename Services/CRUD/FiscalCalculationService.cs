using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Servizio per calcoli fiscali basati sul regime dell'azienda.
/// Sostituisce la logica forfettaria hardcoded in MovTransazioniEditDialog.
/// </summary>
public class FiscalCalculationService
{
    private readonly IDatabaseService _dbService;
    private readonly AnaRegimiFiscaliService _regimeService;
    private readonly AnaAliquoteIvaService _aliquoteService;
    private readonly ILogger<FiscalCalculationService> _logger;

    public FiscalCalculationService(
        IDatabaseService dbService,
        AnaRegimiFiscaliService regimeService,
        AnaAliquoteIvaService aliquoteService,
        ILogger<FiscalCalculationService> logger)
    {
        _dbService = dbService;
        _regimeService = regimeService;
        _aliquoteService = aliquoteService;
        _logger = logger;
    }

    /// <summary>
    /// Recupera il regime fiscale dell'azienda tramite la FK in ana_aziende.
    /// </summary>
    public async Task<AnaRegimeFiscale?> GetRegimeForAziendaAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _dbService.GetConnectionAsync();

            const string sql = @"
                SELECT regime_fiscale_fk
                FROM ana_aziende
                WHERE azienda_id = @AziendaId";

            var parameters = new DynamicParameters();
            parameters.Add("AziendaId", aziendaId);
            var regimeFk = await conn.QuerySingleOrDefaultAsync<int?>(sql, parameters);

            if (!regimeFk.HasValue)
            {
                _logger.LogWarning("Azienda {AziendaId} non ha un regime fiscale configurato", aziendaId);
                return null;
            }

            return await _regimeService.GetByIdAsync(regimeFk.Value);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero regime per azienda {AziendaId}", aziendaId);
            return null;
        }
    }

    /// <summary>
    /// Determina se mostrare il bottone helper di calcolo per l'azienda.
    /// </summary>
    public async Task<bool> ShouldShowHelperCalcoloAsync(int aziendaId)
    {
        var regime = await GetRegimeForAziendaAsync(aziendaId);
        return regime?.ShowHelperCalcolo ?? false;
    }

    /// <summary>
    /// Applica il calcolo del regime fiscale generando le righe della transazione.
    /// Ordine righe: 1=PRESTAZIONE, 2=CASSA_PREV, 3=BOLLO.
    /// La soglia bollo e calcolata su Prestazione + Cassa Previdenziale.
    /// </summary>
    public async Task<FiscalCalculationResult> ApplyRegimeCalculationAsync(
        int aziendaId,
        decimal baseImponibile,
        string? descrizione)
    {
        try
        {
            // 1. Recupera regime
            var regime = await GetRegimeForAziendaAsync(aziendaId);
            if (regime == null)
            {
                return FiscalCalculationResult.Error(
                    "Regime fiscale non configurato per questa azienda. Verificare l'anagrafica azienda.");
            }

            if (!regime.ShowHelperCalcolo)
            {
                return FiscalCalculationResult.Error(
                    $"Il regime '{regime.RegimeCodice}' non prevede un calcolatore automatico.");
            }

            // 2. Recupera aliquote IVA dell'azienda
            var aliquote = (await _aliquoteService.GetByAziendaAsync(aziendaId)).ToList();
            if (!aliquote.Any())
            {
                return FiscalCalculationResult.Error(
                    "Nessuna aliquota IVA trovata per questa azienda. Verificare la configurazione delle Aliquote IVA in Tabelle Contabili.");
            }

            var righe = new List<MovTransazioniRighe>();
            int rigaNumero = 1;

            // 3. Riga PRESTAZIONE
            var aliDefault = FindAliquotaByCodice(aliquote, regime.DefaultAliquotaIvaCodice);
            if (aliDefault == null)
            {
                return FiscalCalculationResult.Error(
                    $"Aliquota IVA con codice '{regime.DefaultAliquotaIvaCodice}' non trovata per questa azienda. " +
                    "Verificare la configurazione delle Aliquote IVA in Tabelle Contabili.");
            }

            var rigaPrestazione = CreateRiga(
                rigaNumero++,
                (descrizione ?? "PRESTAZIONE PROFESSIONALE").ToUpper(),
                "PRESTAZIONE",
                baseImponibile,
                aliDefault);
            righe.Add(rigaPrestazione);

            // 4. Riga CASSA_PREV (se configurata)
            decimal cassaPrev = 0;
            if (regime.CassaPrevPercentuale.HasValue && regime.CassaPrevPercentuale.Value > 0)
            {
                var aliCassa = FindAliquotaByCodice(aliquote, regime.CassaPrevAliquotaCodice);
                if (aliCassa == null)
                {
                    return FiscalCalculationResult.Error(
                        $"Aliquota IVA con codice '{regime.CassaPrevAliquotaCodice}' non trovata per questa azienda. " +
                        "Verificare la configurazione delle Aliquote IVA in Tabelle Contabili.");
                }

                cassaPrev = Math.Round(baseImponibile * (regime.CassaPrevPercentuale.Value / 100m), 2);

                var rigaCassa = CreateRiga(
                    rigaNumero++,
                    (regime.CassaPrevDescrizione ?? $"CASSA PREVIDENZIALE {regime.CassaPrevPercentuale.Value:N2}%").ToUpper(),
                    "CASSA_PREV",
                    cassaPrev,
                    aliCassa);
                righe.Add(rigaCassa);
            }

            // 5. Riga BOLLO (se totale Prestazione + Cassa > soglia)
            if (regime.BolloSoglia.HasValue && regime.BolloImporto.HasValue)
            {
                decimal totalePerBollo = baseImponibile + cassaPrev;

                if (totalePerBollo > regime.BolloSoglia.Value)
                {
                    var aliBollo = FindAliquotaByCodice(aliquote, regime.BolloAliquotaCodice);
                    if (aliBollo == null)
                    {
                        return FiscalCalculationResult.Error(
                            $"Aliquota IVA con codice '{regime.BolloAliquotaCodice}' non trovata per questa azienda. " +
                            "Verificare la configurazione delle Aliquote IVA in Tabelle Contabili.");
                    }

                    var rigaBollo = CreateRiga(
                        rigaNumero++,
                        "IMPOSTA DI BOLLO",
                        "BOLLO",
                        regime.BolloImporto.Value,
                        aliBollo);
                    righe.Add(rigaBollo);
                }
            }

            _logger.LogInformation(
                "Calcolo regime {Regime} applicato per azienda {AziendaId}: {NumRighe} righe generate",
                regime.RegimeCodice, aziendaId, righe.Count);

            return FiscalCalculationResult.Ok(righe);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore critico nel calcolo regime per azienda {AziendaId}", aziendaId);
            return FiscalCalculationResult.Error($"Errore critico nel calcolo: {ex.Message}");
        }
    }

    // ==========================================
    // Helper privati
    // ==========================================

    private static AnaAliquotaIva? FindAliquotaByCodice(List<AnaAliquotaIva> aliquote, string? codice)
    {
        if (string.IsNullOrWhiteSpace(codice)) return null;
        return aliquote.FirstOrDefault(a =>
            string.Equals(a.IvaCodice, codice, StringComparison.OrdinalIgnoreCase));
    }

    private static MovTransazioniRighe CreateRiga(
        int numero, string descrizione, string tipo,
        decimal imponibile, AnaAliquotaIva aliquota)
    {
        decimal percentuale = aliquota.IvaPercentuale;
        decimal ivaValore = Math.Round(imponibile * (percentuale / 100m), 2);

        return new MovTransazioniRighe
        {
            RigaNumero = numero,
            RigaDescrizione = descrizione,
            RigaTipo = tipo,
            RigaImponibile = imponibile,
            RigaAliquotaIvaFk = aliquota.IvaId,
            AliquotaIvaCodice = aliquota.IvaCodice,
            AliquotaIvaPercentuale = aliquota.IvaPercentuale,
            RigaIvaValore = ivaValore,
            RigaLordo = imponibile + ivaValore
        };
    }
}
