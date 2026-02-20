using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using GestioneViaggi.Services.CRUD;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.ExternalApis;

public interface ICurrencyApiService
{
    Task<bool> CheckInternetConnectionAsync();

    /// <summary>
    /// Recupera il tasso di cambio dalla valuta base (es. EUR) alla valuta target (es. USD) per 'oggi'.
    /// </summary>
    Task<decimal?> GetLatestRateAsync(string fromIsoCode, string toIsoCode);

    /// <summary>
    /// Recupera il tasso di cambio storico per una data specifica.
    /// </summary>
    Task<decimal?> GetHistoricalRateAsync(string fromIsoCode, string toIsoCode, DateTime date);

    /// <summary>
    /// Recupera i tassi correnti di tutte le valute rispetto a una valuta base (es. EUR).
    /// </summary>
    Task<Dictionary<string, decimal>?> GetAllLatestRatesAsync(string baseIsoCode);
}

public class CurrencyApiService : ICurrencyApiService
{
    private readonly HttpClient _httpClient;
    private readonly ApiConfigService _apiConfigService;
    private readonly ILogger<CurrencyApiService> _logger;

    private const string FRANKFURTER_API_BASE_URL = "https://api.frankfurter.app";
    private const string JSDELIVR_FALLBACK_BASE_URL = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api";
    private const string UNIRATE_API_BASE_URL = "https://api.unirateapi.com/api";
    private const string ALPHA_VANTAGE_API_BASE_URL = "https://www.alphavantage.co/query";

    private const string API_VALUTE_SERVICE_CODE = "API_VALUTE";

    // Cache in-memory delle API key per evitare query ripetute al DB nella stessa sessione
    private string? _cachedUnirateApiKey;
    private string? _cachedAlphaVantageApiKey;
    private bool _keysLoaded;

    public CurrencyApiService(HttpClient httpClient, ApiConfigService apiConfigService, ILogger<CurrencyApiService> logger)
    {
        _httpClient = httpClient;
        // The service should have a short timeout since it is called synchronously during saves
        _httpClient.Timeout = TimeSpan.FromSeconds(5);
        _apiConfigService = apiConfigService;
        _logger = logger;
    }

    /// <summary>
    /// Carica le API key dal database (tabella ana_api_config) con service_code = API_VALUTE.
    /// Le chiavi vengono cachate in memoria per la durata del service scope.
    /// </summary>
    private async Task EnsureApiKeysLoadedAsync()
    {
        if (_keysLoaded) return;

        try
        {
            _cachedUnirateApiKey = await _apiConfigService.GetConfigValueAsync(API_VALUTE_SERVICE_CODE, "UNIRATE_API_KEY");
            _cachedAlphaVantageApiKey = await _apiConfigService.GetConfigValueAsync(API_VALUTE_SERVICE_CODE, "ALPHA_VANTAGE_API_KEY");
            _keysLoaded = true;

            if (string.IsNullOrEmpty(_cachedUnirateApiKey))
                _logger.LogWarning("API key UniRate non trovata o disattivata nella configurazione DB (API_VALUTE/UNIRATE_API_KEY).");
            if (string.IsNullOrEmpty(_cachedAlphaVantageApiKey))
                _logger.LogWarning("API key Alpha Vantage non trovata o disattivata nella configurazione DB (API_VALUTE/ALPHA_VANTAGE_API_KEY).");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento delle API key dal database. I provider che richiedono API key non saranno disponibili.");
            _keysLoaded = true; // Evita retry continui in caso di errore DB
        }
    }

    public async Task<bool> CheckInternetConnectionAsync()
    {
        try
        {
            var response = await _httpClient.GetAsync($"{FRANKFURTER_API_BASE_URL}/latest?from=EUR&to=USD");
            return response.IsSuccessStatusCode;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Internet connection check failed");
            return false;
        }
    }

    public async Task<Dictionary<string, decimal>?> GetAllLatestRatesAsync(string baseIsoCode)
    {
        try
        {
            // 1. Try Frankfurter
             var response = await _httpClient.GetFromJsonAsync<FrankfurterResponse>($"{FRANKFURTER_API_BASE_URL}/latest?from={baseIsoCode}");
             if (response?.Rates != null && response.Rates.Any())
             {
                 return response.Rates;
             }
        }
        catch (Exception ex)
        {
             _logger.LogWarning(ex, "Failed to fetch all rates from primary API.");
        }
        
        return null;
    }

    public async Task<decimal?> GetLatestRateAsync(string fromIsoCode, string toIsoCode)
    {
        return await GetHistoricalRateAsync(fromIsoCode, toIsoCode, DateTime.Today);
    }

    public async Task<decimal?> GetHistoricalRateAsync(string fromIsoCode, string toIsoCode, DateTime date)
    {
        fromIsoCode = fromIsoCode.ToUpper();
        toIsoCode = toIsoCode.ToUpper();

        if (fromIsoCode == toIsoCode) return 1m;

        // Carica API key dal DB (ana_api_config) se non già in cache
        await EnsureApiKeysLoadedAsync();

        // Formato per le API
        string frankfurterDateString = date == DateTime.Today ? "latest" : date.ToString("yyyy-MM-dd");

        // ----------------------------------------------------
        // 1. TENTATIVO CON FRANKFURTER (Gratuita, affidabile per valute BCE)
        // ----------------------------------------------------
        try
        {
            var response = await _httpClient.GetFromJsonAsync<FrankfurterResponse>(
                $"{FRANKFURTER_API_BASE_URL}/{frankfurterDateString}?from={fromIsoCode}&to={toIsoCode}");
                
            if (response?.Rates != null && response.Rates.TryGetValue(toIsoCode, out decimal fRate))
            {
                _logger.LogInformation("Tasso trovato su Frankfurter API per {From}->{To} il {Date}: {Rate}", fromIsoCode, toIsoCode, date.ToString("yyyy-MM-dd"), fRate);
                return fRate;
            }
        }
        catch (HttpRequestException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            _logger.LogInformation("Valuta/Data non supportata dalla BCE (Frankfurter API): {ToIsoCode} per data {Date}", toIsoCode, date.ToString("yyyy-MM-dd"));
        }
        catch (TaskCanceledException)
        {
            _logger.LogWarning("Timeout durante interrogazione Frankfurter API.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore generico su Frankfurter API.");
        }

        // ----------------------------------------------------
        // 2. TENTATIVO CON USDELIVR FALLBACK (Gratuita, >= 2024 storico extra-BCE, o latest)
        // ----------------------------------------------------
        try
        {
            string jsdelivrDateString = date == DateTime.Today ? "latest" : date.ToString("yyyy-MM-dd");
            string url = $"{JSDELIVR_FALLBACK_BASE_URL}@{jsdelivrDateString}/v1/currencies/{fromIsoCode.ToLower()}.json";
            
            var response = await _httpClient.GetFromJsonAsync<JsdelivrApiResponse>(url);
            
            if (response?.CurrencyDictionary != null && response.CurrencyDictionary.TryGetValue(toIsoCode.ToLower(), out decimal jRate))
            {
                _logger.LogInformation("Tasso trovato su jsDelivr API per {From}->{To} il {Date}: {Rate}", fromIsoCode, toIsoCode, date.ToString("yyyy-MM-dd"), jRate);
                return jRate;
            }
        }
        catch (HttpRequestException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            _logger.LogInformation("Data o valuta non trovata su jsDelivr per la data {Date}", date.ToString("yyyy-MM-dd"));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore generico su jsDelivr API.");
        }

        // ----------------------------------------------------
        // 3. TENTATIVO CON UNIRATE API (Richiede KEY) - Solo 'latest' se free tier
        // ----------------------------------------------------
        if (!string.IsNullOrEmpty(_cachedUnirateApiKey))
        {
            try
            {
                string endpoint = date == DateTime.Today
                    ? $"rates?api_key={_cachedUnirateApiKey}&base={fromIsoCode}&symbols={toIsoCode}"
                    : $"historical/rates?api_key={_cachedUnirateApiKey}&date={date:yyyy-MM-dd}&base={fromIsoCode}&symbols={toIsoCode}"; 
                
                var response = await _httpClient.GetFromJsonAsync<UniRateApiResponse>($"{UNIRATE_API_BASE_URL}/{endpoint}");

                if (response?.Rates != null && response.Rates.TryGetValue(toIsoCode, out decimal uRate))
                {
                    _logger.LogInformation("Tasso trovato su UniRate API per {From}->{To} il {Date}: {Rate}", fromIsoCode, toIsoCode, date.ToString("yyyy-MM-dd"), uRate);
                    return uRate;
                }
            }
            catch (HttpRequestException ex) when (ex.StatusCode == HttpStatusCode.Forbidden || ex.StatusCode == HttpStatusCode.Unauthorized || ex.StatusCode == HttpStatusCode.PaymentRequired)
            {
                // UniRate returns 403 or similar if historical dates require PRO plan
                _logger.LogWarning("Richiesta negata su UniRate API. Potrebbe essere necessario un piano PRO per i dati storici.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Errore generico su UniRate API.");
            }
        }

        // ----------------------------------------------------
        // 4. TENTATIVO CON ALPHA VANTAGE (Gratuito, Storico illimitato)
        // ----------------------------------------------------
        if (!string.IsNullOrEmpty(_cachedAlphaVantageApiKey))
        {
            try
            {
                string url = $"{ALPHA_VANTAGE_API_BASE_URL}?function=FX_DAILY&from_symbol={fromIsoCode}&to_symbol={toIsoCode}&outputsize=full&apikey={_cachedAlphaVantageApiKey}";
                
                var response = await _httpClient.GetFromJsonAsync<AlphaVantageApiResponse>(url);

                if (response?.TimeSeries != null)
                {
                    // Controlliamo fino a 7 giorni indietro nel caso di weekend o giorni festivi
                    for (int i = 0; i <= 7; i++)
                    {
                        string dateKey = date.AddDays(-i).ToString("yyyy-MM-dd");
                        if (response.TimeSeries.TryGetValue(dateKey, out var dayData) && dayData.Close > 0)
                        {
                            if (i == 0)
                                _logger.LogInformation("Tasso trovato su Alpha Vantage API per {From}->{To} il {Date}: {Rate}", fromIsoCode, toIsoCode, dateKey, dayData.Close);
                            else
                                _logger.LogInformation("Tasso esatto non trovato per {DateOrigin}. Usato tasso Alpha Vantage del giorno lavorativo precedente {DateFound}: {Rate}", date.ToString("yyyy-MM-dd"), dateKey, dayData.Close);
                            
                            return dayData.Close;
                        }
                    }
                    
                    _logger.LogWarning("Dato non presente in Alpha Vantage per la data {Date} e per i 7 giorni precedenti.", date.ToString("yyyy-MM-dd"));
                }
                else if (response?.Information != null)
                {
                    _logger.LogWarning("Alpha Vantage rate limit raggiunto o errore: {Msg}", response.Information);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Errore generico su Alpha Vantage API.");
            }
        }

        return null; // Tass non trovato da nessun provider
    }

    #region Response DTOs
    
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

    private class JsdelivrApiResponse
    {
        [JsonPropertyName("date")]
        public string Date { get; set; } = string.Empty;

        // Custom JSON parser to map the dynamic key (e.g. "eur", "usd") to a dictionary
        [JsonExtensionData]
        public Dictionary<string, System.Text.Json.JsonElement>? ExtensionData { get; set; }

        public Dictionary<string, decimal> CurrencyDictionary
        {
            get
            {
                var dict = new Dictionary<string, decimal>();
                if (ExtensionData == null) return dict;

                // Trova l'oggetto annidato che contiene i tassi 
                // (di solito c'è la key "eur" in cui dentro vi è il dizionario finale)
                foreach(var key in ExtensionData.Keys)
                {
                    if (key != "date" && ExtensionData[key].ValueKind == System.Text.Json.JsonValueKind.Object)
                    {
                        var ratesObj = ExtensionData[key];
                        foreach(var rateProp in ratesObj.EnumerateObject())
                        {
                            if (rateProp.Value.TryGetDecimal(out decimal rateValue))
                            {
                                dict[rateProp.Name] = rateValue;
                            }
                        }
                    }
                }
                return dict;
            }
        }
    }

    private class UniRateApiResponse
    {
        [JsonPropertyName("success")]
        public bool Success { get; set; }

        [JsonPropertyName("rates")]
        public Dictionary<string, decimal> Rates { get; set; } = new();
    }
    
    private class AlphaVantageApiResponse
    {
        [JsonPropertyName("Information")]
        public string? Information { get; set; }

        [JsonPropertyName("Time Series FX (Daily)")]
        public Dictionary<string, AlphaVantageDailyData>? TimeSeries { get; set; }
    }

    private class AlphaVantageDailyData
    {
        [JsonPropertyName("1. open")]
        public string OpenString { get; set; } = string.Empty;

        [JsonPropertyName("2. high")]
        public string HighString { get; set; } = string.Empty;

        [JsonPropertyName("3. low")]
        public string LowString { get; set; } = string.Empty;

        [JsonPropertyName("4. close")]
        public string CloseString { get; set; } = string.Empty;

        public decimal Close 
        {
            get 
            {
                if (decimal.TryParse(CloseString, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out decimal val))
                    return val;
                return 0;
            }
        }
    }
    
    #endregion
}
