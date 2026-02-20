using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Service per l'estrazione dei dati per la stampa del Registro IVA (Acquisti e Vendite).
/// Utilizza la function DB fn_get_registro_iva.
/// </summary>
public class RegistroIvaPrintService
{
    private readonly IDatabaseService _dbService;
    private readonly ILogger<RegistroIvaPrintService> _logger;

    public RegistroIvaPrintService(
        IDatabaseService dbService,
        ILogger<RegistroIvaPrintService> logger)
    {
        _dbService = dbService;
        _logger = logger;
    }

    /// <summary>
    /// Recupera tutti i dati necessari per la stampa del Registro IVA.
    /// </summary>
    public async Task<RegistroIvaPrintData> GetRegistroIvaDataAsync(
        int aziendaId,
        DateTime periodoDa,
        DateTime periodoA,
        UserInfo currentUser)
    {
        _logger.LogInformation(
            "Inizio estrazione dati Registro IVA. Azienda: {AziendaId}, Periodo: {Da} - {A}",
            aziendaId, periodoDa, periodoA);

        var result = new RegistroIvaPrintData
        {
            PeriodoDa = periodoDa,
            PeriodoA = periodoA,
            DataStampa = DateTime.Now,
            UtenteStampa = currentUser.FullName
        };

        try
        {
            using var connection = await _dbService.GetConnectionAsync();

            // 1. Recupera dettagli fatture con IVA
            var sql = @"
                SELECT
                    causale_ciclo AS CausaleCiclo,
                    transazione_id AS TransazioneId,
                    transazione_data_documento AS TransazioneDataDocumento,
                    transazione_numero_documento AS TransazioneNumeroDocumento,
                    controparte_ragione_sociale AS ControparteRagioneSociale,
                    causale_codice AS CausaleCodice,
                    causale_descrizione AS CausaleDescrizione,
                    aliquota_iva_codice AS AliquotaIvaCodice,
                    aliquota_iva_percentuale AS AliquotaIvaPercentuale,
                    aliquota_iva_descrizione AS AliquotaIvaDescrizione,
                    imponibile_eur AS ImponibileEur,
                    iva_eur AS IvaEur,
                    lordo_eur AS LordoEur,
                    causale_segno AS CausaleSegno
                FROM fn_get_registro_iva(@AziendaId, @PeriodoDa, @PeriodoA)";

            var items = (await connection.QueryAsync<RegistroIvaItem>(sql, new
            {
                AziendaId = aziendaId,
                PeriodoDa = periodoDa,
                PeriodoA = periodoA
            })).ToList();

            // 2. Separa Acquisti e Vendite
            result.Acquisti = items.Where(i => i.CausaleCiclo == "PASSIVO").ToList();
            result.Vendite = items.Where(i => i.CausaleCiclo == "ATTIVO").ToList();

            // 3. Calcola sub-totali per aliquota (Acquisti)
            result.SubTotaliAcquisti = CalcolaSubTotaliPerAliquota(result.Acquisti);
            result.TotaleImponibileAcquisti = result.SubTotaliAcquisti.Sum(s => s.TotaleImponibile);
            result.TotaleIvaAcquisti = result.SubTotaliAcquisti.Sum(s => s.TotaleIva);
            result.TotaleLordoAcquisti = result.SubTotaliAcquisti.Sum(s => s.TotaleLordo);

            // 4. Calcola sub-totali per aliquota (Vendite)
            result.SubTotaliVendite = CalcolaSubTotaliPerAliquota(result.Vendite);
            result.TotaleImponibileVendite = result.SubTotaliVendite.Sum(s => s.TotaleImponibile);
            result.TotaleIvaVendite = result.SubTotaliVendite.Sum(s => s.TotaleIva);
            result.TotaleLordoVendite = result.SubTotaliVendite.Sum(s => s.TotaleLordo);

            // 5. Riepilogo cross Acquisti/Vendite per aliquota
            result.RiepilogoPerAliquota = CalcolaRiepilogoPerAliquota(result.SubTotaliAcquisti, result.SubTotaliVendite);

            // 6. Liquidazione IVA
            result.Liquidazione = new LiquidazioneIva
            {
                IvaDebito = result.TotaleIvaVendite,
                IvaCredito = result.TotaleIvaAcquisti
            };

            // 7. Info azienda
            result.Azienda = await GetAziendaInfoAsync(aziendaId);

            _logger.LogInformation(
                "Registro IVA estratto: {Acquisti} acquisti, {Vendite} vendite",
                result.Acquisti.Count, result.Vendite.Count);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei dati per il Registro IVA");
            throw;
        }
    }

    private static List<SubTotaleAliquota> CalcolaSubTotaliPerAliquota(List<RegistroIvaItem> items)
    {
        return items
            .GroupBy(i => new { Codice = i.AliquotaIvaCodice ?? "N/D", Percentuale = i.AliquotaIvaPercentuale ?? 0 })
            .Select(g => new SubTotaleAliquota
            {
                AliquotaCodice = g.Key.Codice,
                AliquotaPercentuale = g.Key.Percentuale,
                AliquotaDescrizione = g.First().AliquotaIvaDescrizione,
                TotaleImponibile = g.Sum(i => i.ImponibileEur),
                TotaleIva = g.Sum(i => i.IvaEur),
                TotaleLordo = g.Sum(i => i.LordoEur),
                Conteggio = g.Count()
            })
            .OrderByDescending(s => s.AliquotaPercentuale)
            .ThenBy(s => s.AliquotaCodice)
            .ToList();
    }

    private static List<RiepilogoAliquotaItem> CalcolaRiepilogoPerAliquota(
        List<SubTotaleAliquota> subAcquisti,
        List<SubTotaleAliquota> subVendite)
    {
        // Unione delle aliquote presenti in entrambe le sezioni
        var aliquote = subAcquisti.Select(s => new { s.AliquotaCodice, s.AliquotaPercentuale, s.AliquotaDescrizione })
            .Union(subVendite.Select(s => new { s.AliquotaCodice, s.AliquotaPercentuale, s.AliquotaDescrizione }))
            .Distinct()
            .OrderByDescending(a => a.AliquotaPercentuale)
            .ThenBy(a => a.AliquotaCodice);

        return aliquote.Select(a =>
        {
            var acq = subAcquisti.FirstOrDefault(s => s.AliquotaCodice == a.AliquotaCodice);
            var ven = subVendite.FirstOrDefault(s => s.AliquotaCodice == a.AliquotaCodice);

            return new RiepilogoAliquotaItem
            {
                AliquotaCodice = a.AliquotaCodice,
                AliquotaPercentuale = a.AliquotaPercentuale,
                AliquotaDescrizione = a.AliquotaDescrizione,
                ImponibileAcquisti = acq?.TotaleImponibile ?? 0,
                IvaAcquisti = acq?.TotaleIva ?? 0,
                ConteggioAcquisti = acq?.Conteggio ?? 0,
                ImponibileVendite = ven?.TotaleImponibile ?? 0,
                IvaVendite = ven?.TotaleIva ?? 0,
                ConteggioVendite = ven?.Conteggio ?? 0
            };
        }).ToList();
    }

    private async Task<CompanyPrintInfo> GetAziendaInfoAsync(int aziendaId)
    {
        try
        {
            using var connection = await _dbService.GetConnectionAsync();

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
            _logger.LogError(ex, "Errore nel recupero info azienda {Id} per Registro IVA", aziendaId);
            return new CompanyPrintInfo();
        }
    }
}
