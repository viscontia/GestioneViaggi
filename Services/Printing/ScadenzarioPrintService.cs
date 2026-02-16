using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Service per l'estrazione dei dati per la stampa PDF dello scadenzario.
/// Architettura DB-First: utilizza fn_get_scadenzario_stampa per query.
/// </summary>
public class ScadenzarioPrintService
{
    private readonly IDatabaseService _dbService;
    private readonly ILogger<ScadenzarioPrintService> _logger;

    public ScadenzarioPrintService(
        IDatabaseService dbService,
        ILogger<ScadenzarioPrintService> logger)
    {
        _dbService = dbService;
        _logger = logger;
    }

    /// <summary>
    /// Recupera tutti i dati necessari per la stampa PDF dello scadenzario.
    /// Utilizza la function DB fn_get_scadenzario_stampa.
    /// </summary>
    public async Task<ScadenzarioPrintData> GetDataPerStampaAsync(
        ScadenzarioFiltriDTO filtri,
        string raggruppamento, // "URGENZA" | "MESE" | "CONTROPARTE"
        string? valutaTargetIso,
        UserInfo currentUser)
    {
        _logger.LogInformation("Inizio estrazione dati stampa scadenzario. Raggruppamento: {Ragg}", raggruppamento);

        var result = new ScadenzarioPrintData
        {
            ValutaTargetCodiceIso = valutaTargetIso ?? "EUR",
            DataStampa = DateTime.Now,
            UtenteStampa = currentUser.FullName,
            Filtri = filtri.ToFiltriApplicatiInfo()
        };

        try
        {
            using var connection = await _dbService.GetConnectionAsync();

            // Chiamata alla function DB fn_get_scadenzario_stampa
            var dettagli = await connection.QueryAsync<ScadenzarioItem>(
                "SELECT * FROM fn_get_scadenzario_stampa(@AziendaId, @ControparteId, @CausaleCiclo, @Urgenza, @DataScadenzaDa, @DataScadenzaA, @ViaggioId, @SoloConViaggio, @SoloSenzaViaggio, @Raggruppamento)",
                new
                {
                    AziendaId = filtri.AziendaId,
                    ControparteId = filtri.ControparteId,
                    CausaleCiclo = filtri.CausaleCiclo,
                    Urgenza = filtri.Urgenza,
                    DataScadenzaDa = filtri.DataScadenzaDa,
                    DataScadenzaA = filtri.DataScadenzaA,
                    ViaggioId = filtri.ViaggioId,
                    SoloConViaggio = filtri.SoloConViaggio,
                    SoloSenzaViaggio = filtri.SoloSenzaViaggio,
                    Raggruppamento = raggruppamento
                });

            result.Dettagli = dettagli.ToList();

            // Calcola subtotali per gruppo (logica applicativa su dati già estratti)
            result.Subtotali = CalcolaSubtotali(result.Dettagli);

            // Calcola totali generali
            result.TotaleGeneraleAttivo = result.Dettagli
                .Where(d => d.CausaleCiclo == "ATTIVO")
                .Sum(d => d.Residuo);

            result.TotaleGeneralePassivo = result.Dettagli
                .Where(d => d.CausaleCiclo == "PASSIVO")
                .Sum(d => Math.Abs(d.Residuo)); // Valore assoluto per le uscite

            result.SaldoNetto = result.TotaleGeneraleAttivo - result.TotaleGeneralePassivo;

            // Se filtrato per azienda, recupera info azienda tramite function DB
            if (filtri.AziendaId.HasValue)
            {
                result.Azienda = await GetAziendaInfoAsync(filtri.AziendaId.Value);
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei dati per la stampa scadenzario");
            throw;
        }
    }

    /// <summary>
    /// Calcola subtotali per gruppo aggregando i dati già estratti.
    /// Questa è logica applicativa che opera su dati in memoria.
    /// </summary>
    private List<ScadenzarioSubTotale> CalcolaSubtotali(List<ScadenzarioItem> dettagli)
    {
        var subtotali = dettagli
            .GroupBy(d => new { d.GruppoChiave, d.GruppoDisplay, d.GruppoOrdine })
            .Select(g => new ScadenzarioSubTotale
            {
                GruppoChiave = g.Key.GruppoChiave,
                GruppoDisplay = g.Key.GruppoDisplay,
                GruppoOrdine = g.Key.GruppoOrdine,
                TotaleAttivo = g.Where(d => d.CausaleCiclo == "ATTIVO").Sum(d => d.Residuo),
                TotalePassivo = g.Where(d => d.CausaleCiclo == "PASSIVO").Sum(d => Math.Abs(d.Residuo)),
                ConteggioTransazioni = g.Count(),
                IsTotaleGenerale = false
            })
            .ToList();

        // Calcola saldo netto per ogni gruppo
        foreach (var sub in subtotali)
        {
            sub.SaldoNetto = sub.TotaleAttivo - sub.TotalePassivo;
        }

        // Aggiungi totale generale
        if (subtotali.Any())
        {
            subtotali.Add(new ScadenzarioSubTotale
            {
                GruppoChiave = "TOTALE_GENERALE",
                GruppoDisplay = "TOTALE GENERALE",
                GruppoOrdine = 999,
                TotaleAttivo = subtotali.Sum(s => s.TotaleAttivo),
                TotalePassivo = subtotali.Sum(s => s.TotalePassivo),
                SaldoNetto = subtotali.Sum(s => s.SaldoNetto),
                ConteggioTransazioni = subtotali.Sum(s => s.ConteggioTransazioni),
                IsTotaleGenerale = true
            });
        }

        return subtotali;
    }

    /// <summary>
    /// Recupera info azienda tramite function DB get_company_print_info.
    /// </summary>
    private async Task<CompanyPrintInfo> GetAziendaInfoAsync(int aziendaId)
    {
        try
        {
            using var connection = await _dbService.GetConnectionAsync();
            return await connection.QueryFirstOrDefaultAsync<CompanyPrintInfo>(
                "SELECT * FROM get_company_print_info(@AziendaId)",
                new { AziendaId = aziendaId }) ?? new CompanyPrintInfo();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero info azienda {Id} per stampa", aziendaId);
            return new CompanyPrintInfo();
        }
    }
}
