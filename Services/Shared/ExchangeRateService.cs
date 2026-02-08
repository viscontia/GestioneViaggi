using System.Net.Http.Json;
using System.Text.Json.Serialization;
using GestioneViaggi.Models;
using GestioneViaggi.Services.CRUD;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Shared;

public interface IExchangeRateService
{
    Task<bool> CheckInternetConnectionAsync();
    Task UpdateAllRatesAsync();
    Task UpdateRateAsync(string isoCode);
    Task<(bool Success, string Message)> UpdateRateForDateAsync(string isoCode, DateTime date);
}

public class ExchangeRateService : IExchangeRateService
{
    private readonly HttpClient _httpClient;
    private readonly AnaValuteService _valuteService;
    private readonly AnaTassiCambioService _tassiService;
    private readonly ILogger<ExchangeRateService> _logger;
    private const string API_BASE_URL = "https://api.frankfurter.app";
    private const int API_TIMEOUT_SECONDS = 5;

    public ExchangeRateService(
        HttpClient httpClient,
        AnaValuteService valuteService,
        AnaTassiCambioService tassiService,
        ILogger<ExchangeRateService> logger)
    {
        _httpClient = httpClient;
        _httpClient.Timeout = TimeSpan.FromSeconds(API_TIMEOUT_SECONDS);
        _valuteService = valuteService;
        _tassiService = tassiService;
        _logger = logger;
    }

    public async Task<bool> CheckInternetConnectionAsync()
    {
        try
        {
            // Simple check to a reliable endpoint
            var response = await _httpClient.GetAsync($"{API_BASE_URL}/latest?from=EUR&to=USD");
            return response.IsSuccessStatusCode;
        }
        catch(Exception ex)
        {
            _logger.LogWarning(ex, "Internet connection check failed");
            return false;
        }
    }

    public async Task UpdateAllRatesAsync()
    {
        if (!await CheckInternetConnectionAsync())
        {
            throw new Exception("Connessione internet non disponibile.");
        }

        try
        {
            // 1. Get all active currencies
            var activeValute = await _valuteService.GetAllValuteAsync();
            var eur = activeValute.FirstOrDefault(v => v.ValutaCodiceIso == "EUR");
            
            if (eur == null) 
            {
                _logger.LogWarning("EUR currency not found in local DB.");
                return;
            }

            // 2. We only need to update rates FROM EUR TO other currencies
            // The API returns rates based on EUR by default
            var response = await _httpClient.GetFromJsonAsync<FrankfurterResponse>($"{API_BASE_URL}/latest?from=EUR");

            if (response?.Rates == null)
            {
                throw new Exception("Risposta API non valida o vuota.");
            }

            foreach (var valuta in activeValute)
            {
                if (valuta.ValutaCodiceIso == "EUR") continue; // 1:1

                if (response.Rates.TryGetValue(valuta.ValutaCodiceIso, out decimal rate))
                {
                    await InsertRateAsync(eur.ValutaId, valuta.ValutaId, rate);
                }
                else
                {
                    _logger.LogWarning($"Tasso per {valuta.ValutaCodiceIso} non trovato nell'API.");
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento massivo dei tassi.");
            throw;
        }
    }

    public async Task UpdateRateAsync(string isoCode)
    {
         if (!await CheckInternetConnectionAsync())
        {
             throw new Exception("Connessione internet non disponibile.");
        }

        try
        {
            var activeValute = await _valuteService.GetAllValuteAsync();
            var targetValuta = activeValute.FirstOrDefault(v => v.ValutaCodiceIso == isoCode);
            var eur = activeValute.FirstOrDefault(v => v.ValutaCodiceIso == "EUR");

            if (targetValuta == null || eur == null)
            {
                throw new Exception($"Valuta non trovata (Target: {isoCode}, Base: EUR)");
            }

            var response = await _httpClient.GetFromJsonAsync<FrankfurterResponse>($"{API_BASE_URL}/latest?from=EUR&to={isoCode}");

             if (response?.Rates != null && response.Rates.TryGetValue(isoCode, out decimal rate))
            {
                 await InsertRateAsync(eur.ValutaId, targetValuta.ValutaId, rate);
            }
             else
            {
                throw new Exception($"Impossibile recuperare il tasso per {isoCode}");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento tasso {Iso}", isoCode);
            throw;
        }
    }

    /// <summary>
    /// Recupera e memorizza il tasso di cambio per una data specifica.
    /// Utilizza la Frankfurter API per ottenere tassi storici.
    /// </summary>
    /// <param name="isoCode">Codice ISO della valuta (es. USD, GBP)</param>
    /// <param name="date">Data per cui recuperare il tasso di cambio</param>
    /// <returns>Tupla (Success, Message) che indica il risultato dell'operazione</returns>
    public async Task<(bool Success, string Message)> UpdateRateForDateAsync(string isoCode, DateTime date)
    {
        try
        {
            // Se è EUR, non serve fare nulla
            if (isoCode.ToUpper() == "EUR")
            {
                return (true, "La valuta EUR non richiede conversione.");
            }

            var activeValute = await _valuteService.GetAllValuteAsync();
            var targetValuta = activeValute.FirstOrDefault(v => v.ValutaCodiceIso == isoCode);
            var eur = activeValute.FirstOrDefault(v => v.ValutaCodiceIso == "EUR");

            if (targetValuta == null || eur == null)
            {
                _logger.LogWarning("Valuta non trovata (Target: {IsoCode}, Base: EUR)", isoCode);
                return (false, $"Valuta {isoCode} non trovata nel database.");
            }

            // Formato data per Frankfurter API: YYYY-MM-DD
            string dateString = date.ToString("yyyy-MM-dd");
            string apiUrl = $"{API_BASE_URL}/{dateString}?from=EUR&to={isoCode}";

            _logger.LogInformation("Recupero tasso cambio per {IsoCode} alla data {Date}", isoCode, dateString);

            FrankfurterResponse? response;

            try
            {
                // Tentativo di chiamata API con timeout di 5 secondi
                response = await _httpClient.GetFromJsonAsync<FrankfurterResponse>(apiUrl);
            }
            catch (TaskCanceledException)
            {
                // Timeout scaduto
                _logger.LogWarning("Timeout durante il recupero del tasso per {IsoCode} alla data {Date}", isoCode, dateString);
                return (false, $"Timeout durante il recupero del tasso di cambio per {isoCode}. Verrà utilizzato l'ultimo tasso disponibile nel database.");
            }
            catch (HttpRequestException ex)
            {
                // Errore di rete
                _logger.LogError(ex, "Errore di rete durante il recupero del tasso per {IsoCode}", isoCode);
                return (false, $"Errore di connessione alla Frankfurter API. Verrà utilizzato l'ultimo tasso disponibile nel database.");
            }

            if (response?.Rates != null && response.Rates.TryGetValue(isoCode, out decimal rate))
            {
                // Inserisci/aggiorna il tasso nel database
                await InsertRateForDateAsync(eur.ValutaId, targetValuta.ValutaId, rate, date);

                _logger.LogInformation("Tasso cambio aggiornato: EUR -> {IsoCode} = {Rate} (Data: {Date})",
                    isoCode, rate, dateString);

                return (true, $"Tasso di cambio aggiornato: 1 EUR = {rate:F4} {isoCode} (Data: {dateString})");
            }
            else
            {
                _logger.LogWarning("Tasso non disponibile dall'API per {IsoCode} alla data {Date}", isoCode, dateString);
                return (false, $"Tasso di cambio non disponibile per {isoCode} alla data {dateString}. Verrà utilizzato l'ultimo tasso disponibile.");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero del tasso per {IsoCode} alla data {Date}", isoCode, date);
            return (false, $"Errore imprevisto durante il recupero del tasso di cambio. Verrà utilizzato l'ultimo tasso disponibile.");
        }
    }

    private async Task InsertRateAsync(int eurId, int targetId, decimal rateEurToTarget)
    {
        var newTasso = new AnaTassiCambio
        {
            TassoValutaDaId = eurId,
            TassoValutaAId = targetId,
            TassoDataValidita = DateTime.Today,
            TassoValore = rateEurToTarget,
            TassoFonte = "FRANKFURTER_API",
            TassoNote = $"Aggiornamento automatico {DateTime.Now:dd/MM/yyyy HH:mm}",
            CreatedBy = "SYSTEM"
        };

        // Uses UPSERT logic in service
        await _tassiService.CreateAsync(newTasso);
        _logger.LogInformation($"Upsert tasso EUR -> {targetId} = {rateEurToTarget}");
    }

    private async Task InsertRateForDateAsync(int eurId, int targetId, decimal rateEurToTarget, DateTime date)
    {
        var newTasso = new AnaTassiCambio
        {
            TassoValutaDaId = eurId,
            TassoValutaAId = targetId,
            TassoDataValidita = date,
            TassoValore = rateEurToTarget,
            TassoFonte = "FRANKFURTER_API",
            TassoNote = $"Recuperato automaticamente per data documento {date:dd/MM/yyyy} alle {DateTime.Now:HH:mm}",
            CreatedBy = "SYSTEM"
        };

        // Uses UPSERT logic in service
        await _tassiService.CreateAsync(newTasso);
        _logger.LogInformation($"Upsert tasso EUR -> {targetId} = {rateEurToTarget} per data {date:yyyy-MM-dd}");
    }

    private class FrankfurterResponse
    {
        [JsonPropertyName("amount")]
        public decimal Amount { get; set; }

        [JsonPropertyName("base")]
        public string Base { get; set; } = string.Empty;

        [JsonPropertyName("date")]
        public string Date { get; set; } = string.Empty;

        [JsonPropertyName("rates")]
        public Dictionary<string, decimal> Rates { get; set; } = new();
    }
}
