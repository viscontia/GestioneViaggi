using Npgsql;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Service per l'estrazione dei dati per la stampa PDF dello scadenzario.
/// Utilizza la function DB Fat Init fn_get_scadenzario_print_data.
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
    /// Recupera tutti i dati necessari per la stampa PDF dello scadenzario tramite pattern Fat Init.
    /// </summary>
    public async Task<ScadenzarioPrintData> GetDataPerStampaAsync(
        ScadenzarioFiltriDTO filtri,
        string raggruppamento, // "URGENZA" | "MESE" | "CONTROPARTE"
        string? valutaTargetIso,
        UserInfo currentUser)
    {
        _logger.LogInformation("Inizio estrazione dati stampa scadenzario (Fat Init). Raggruppamento: {Ragg}", raggruppamento);

        var result = new ScadenzarioPrintData
        {
            ValutaTargetCodiceIso = valutaTargetIso ?? "EUR",
            DataStampa = DateTime.Now,
            UtenteStampa = currentUser.FullName,
            Filtri = filtri.ToFiltriApplicatiInfo()
        };

        try
        {
            await using var connection = await _dbService.GetConnectionAsync();

            var sql = "SELECT fn_get_scadenzario_print_data(@AziendaId, @ControparteId, @CausaleCiclo, @Urgenza, @DataScadenzaDa, @DataScadenzaA, @ViaggioId, @SoloConViaggio, @SoloSenzaViaggio, @Raggruppamento)";

            await using var cmd = new NpgsqlCommand(sql, (NpgsqlConnection)connection);
            cmd.Parameters.AddWithValue("AziendaId", filtri.AziendaId ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("ControparteId", filtri.ControparteId ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("CausaleCiclo", filtri.CausaleCiclo ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("Urgenza", filtri.Urgenza ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("DataScadenzaDa", filtri.DataScadenzaDa ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("DataScadenzaA", filtri.DataScadenzaA ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("ViaggioId", filtri.ViaggioId ?? (object)DBNull.Value);
            cmd.Parameters.AddWithValue("SoloConViaggio", filtri.SoloConViaggio);
            cmd.Parameters.AddWithValue("SoloSenzaViaggio", filtri.SoloSenzaViaggio);
            cmd.Parameters.AddWithValue("Raggruppamento", raggruppamento);

            var jsonResponse = await cmd.ExecuteScalarAsync() as string;

            if (string.IsNullOrEmpty(jsonResponse)) return result;

            var rawData = JsonSerializer.Deserialize<ScadenzarioRawResponse>(jsonResponse, PrintJsonHelper.GetDefaultOptions());

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

                result.Dettagli = rawData.Dettagli ?? new List<ScadenzarioItem>();

                // Calcola subtotali per gruppo
                result.Subtotali = CalcolaSubtotali(result.Dettagli);

                // Calcola totali generali
                result.TotaleGeneraleAttivo = result.Dettagli
                    .Where(d => d.CausaleCiclo == "ATTIVO")
                    .Sum(d => d.Residuo);

                result.TotaleGeneralePassivo = result.Dettagli
                    .Where(d => d.CausaleCiclo == "PASSIVO")
                    .Sum(d => Math.Abs(d.Residuo));

                result.SaldoNetto = result.TotaleGeneraleAttivo - result.TotaleGeneralePassivo;
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei dati per la stampa scadenzario (Fat Init)");
            throw;
        }
    }

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

        foreach (var sub in subtotali)
        {
            sub.SaldoNetto = sub.TotaleAttivo - sub.TotalePassivo;
        }

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

    // Helper classes for JSON Deserialization
    private class ScadenzarioRawResponse
    {
        public ScadAziendaRaw? Azienda { get; set; }
        public List<ScadenzarioItem>? Dettagli { get; set; }
    }

    private class ScadAziendaRaw
    {
        [JsonPropertyName("ragione_sociale")] public string? RagioneSociale { get; set; }
        [JsonPropertyName("telefono")] public string? Telefono { get; set; }
        [JsonPropertyName("email")] public string? Email { get; set; }
        [JsonPropertyName("sito_web")] public string? SitoWeb { get; set; }
        [JsonPropertyName("piva")] public string? Piva { get; set; }
        [JsonPropertyName("logo_data")] public byte[]? LogoData { get; set; }
    }
}
