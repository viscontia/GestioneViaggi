using GestioneViaggi.Models;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.ExternalApis;
using GestioneViaggi.Services.Session;
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
    private readonly ICurrencyApiService _currencyApiService;
    private readonly AnaValuteService _valuteService;
    private readonly AnaTassiCambioService _tassiService;
    private readonly ITenantContext _tenantContext;
    private readonly ILogger<ExchangeRateService> _logger;

    public ExchangeRateService(
        ICurrencyApiService currencyApiService,
        AnaValuteService valuteService,
        AnaTassiCambioService tassiService,
        ITenantContext tenantContext,
        ILogger<ExchangeRateService> logger)
    {
        _currencyApiService = currencyApiService;
        _valuteService = valuteService;
        _tassiService = tassiService;
        _tenantContext = tenantContext;
        _logger = logger;
    }

    public async Task<bool> CheckInternetConnectionAsync()
    {
        return await _currencyApiService.CheckInternetConnectionAsync();
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
            var ratesDict = await _currencyApiService.GetAllLatestRatesAsync("EUR");

            if (ratesDict == null || !ratesDict.Any())
            {
                throw new Exception("Risposta API non valida o vuota.");
            }

            foreach (var valuta in activeValute)
            {
                if (valuta.ValutaCodiceIso == "EUR") continue; // 1:1

                if (ratesDict.TryGetValue(valuta.ValutaCodiceIso, out decimal rate))
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
            
            decimal? rate = await _currencyApiService.GetLatestRateAsync("EUR", isoCode);

            if (rate.HasValue)
            {
                await InsertRateAsync(eur.ValutaId, targetValuta.ValutaId, rate.Value);
            }
            else
            {
                throw new Exception($"Impossibile recuperare il tasso corrente per {isoCode}. Verrà utilizzato l'ultimo tasso disponibile.");
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
    /// Utilizza il servizio API esterno (Frankfurter/Jsdelivr/UniRate).
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

            _logger.LogInformation("Recupero tasso cambio per {IsoCode} alla data {Date}", isoCode, date.ToString("yyyy-MM-dd"));

            decimal? rate = await _currencyApiService.GetHistoricalRateAsync("EUR", isoCode, date);

            if (rate.HasValue)
            {
                // Inserisci/aggiorna il tasso nel database
                await InsertRateForDateAsync(eur.ValutaId, targetValuta.ValutaId, rate.Value, date);

                _logger.LogInformation("Tasso cambio aggiornato: EUR -> {IsoCode} = {Rate} (Data: {Date})",
                    isoCode, rate.Value, date.ToString("yyyy-MM-dd"));

                return (true, $"Tasso di cambio aggiornato: 1 EUR = {rate.Value:F4} {isoCode} (Data: {date:yyyy-MM-dd})");
            }
            else
            {
                _logger.LogWarning("Tasso non disponibile dall'API per {IsoCode} alla data {Date}", isoCode, date.ToString("yyyy-MM-dd"));
                return (false, $"Attenzione, il tasso di cambio per questa data non è stato trovato tramite le banche dati, per cui ricorda di inserirlo manualmente nella apposita tabella dei tassi di cambio valuta.");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero del tasso per {IsoCode} alla data {Date}", isoCode, date);
            return (false, $"Attenzione, il tasso di cambio per questa data non è stato trovato tramite le banche dati, per cui ricorda di inserirlo manualmente nella apposita tabella dei tassi di cambio valuta.");
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
            TassoFonte = "API_ESTERNE",
            TassoNote = $"Aggiornamento automatico {DateTime.Now:dd/MM/yyyy HH:mm}",
            CreatedBy = (await _tenantContext.GetCurrentUserAsync())?.Username ?? "SYSTEM"
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
            TassoFonte = "API_ESTERNE",
            TassoNote = $"Recuperato automaticamente per data documento {date:dd/MM/yyyy} alle {DateTime.Now:HH:mm}",
            CreatedBy = (await _tenantContext.GetCurrentUserAsync())?.Username ?? "SYSTEM"
        };

        // Uses UPSERT logic in service
        await _tassiService.CreateAsync(newTasso);
        _logger.LogInformation($"Upsert tasso EUR -> {targetId} = {rateEurToTarget} per data {date:yyyy-MM-dd}");
    }
}

