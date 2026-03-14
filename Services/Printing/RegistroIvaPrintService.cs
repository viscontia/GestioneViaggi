using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Service per l'estrazione dei dati per la stampa del Registro IVA (Acquisti e Vendite).
/// Utilizza la function DB Fat Init fn_get_registro_iva_print_data.
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
    /// Recupera tutti i dati necessari per la stampa del Registro IVA tramite pattern Fat Init.
    /// </summary>
    public async Task<RegistroIvaPrintData> GetRegistroIvaDataAsync(
        int aziendaId,
        DateTime periodoDa,
        DateTime periodoA,
        UserInfo currentUser,
        decimal creditoIvaPrecedente = 0m)
    {
        _logger.LogInformation(
            "Inizio estrazione dati Registro IVA (Fat Init). Azienda: {AziendaId}, Periodo: {Da} - {A}",
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
            await using var connection = await _dbService.GetConnectionAsync();

            var sql = "SELECT fn_get_registro_iva_print_data(@AziendaId, @PeriodoDa::date, @PeriodoA::date)";

            var jsonResponse = await connection.QueryFirstOrDefaultAsync<string>(sql, new
            {
                AziendaId = aziendaId,
                PeriodoDa = periodoDa,
                PeriodoA = periodoA
            });

            if (string.IsNullOrEmpty(jsonResponse)) return result;

            var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
            var rawData = JsonSerializer.Deserialize<RegistroIvaRawResponse>(jsonResponse, options);

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

                var items = rawData.Items ?? new List<RegistroIvaItem>();

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
                    IvaCredito = result.TotaleIvaAcquisti,
                    CreditoPrecedente = creditoIvaPrecedente
                };
            }

            _logger.LogInformation(
                "Registro IVA (Fat Init) estratto: {Acquisti} acquisti, {Vendite} vendite",
                result.Acquisti.Count, result.Vendite.Count);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei dati per il Registro IVA (Fat Init)");
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
                AliquotaNatura = g.First().AliquotaIvaNatura,
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
        var aliquote = subAcquisti.Select(s => new { s.AliquotaCodice, s.AliquotaPercentuale, s.AliquotaDescrizione, s.AliquotaNatura })
            .Union(subVendite.Select(s => new { s.AliquotaCodice, s.AliquotaPercentuale, s.AliquotaDescrizione, s.AliquotaNatura }))
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
                AliquotaNatura = a.AliquotaNatura,
                ImponibileAcquisti = acq?.TotaleImponibile ?? 0,
                IvaAcquisti = acq?.TotaleIva ?? 0,
                ConteggioAcquisti = acq?.Conteggio ?? 0,
                ImponibileVendite = ven?.TotaleImponibile ?? 0,
                IvaVendite = ven?.TotaleIva ?? 0,
                ConteggioVendite = ven?.Conteggio ?? 0
            };
        }).ToList();
    }

    // Helper classes for JSON Deserialization
    private class RegistroIvaRawResponse
    {
        public RegIvaAziendaRaw? Azienda { get; set; }
        public List<RegistroIvaItem>? Items { get; set; }
    }

    private class RegIvaAziendaRaw
    {
        [JsonPropertyName("ragione_sociale")] public string? RagioneSociale { get; set; }
        [JsonPropertyName("telefono")] public string? Telefono { get; set; }
        [JsonPropertyName("email")] public string? Email { get; set; }
        [JsonPropertyName("sito_web")] public string? SitoWeb { get; set; }
        [JsonPropertyName("piva")] public string? Piva { get; set; }
        [JsonPropertyName("logo_data")] public byte[]? LogoData { get; set; }
    }
}
