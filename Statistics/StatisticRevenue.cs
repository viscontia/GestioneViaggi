using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Statistics;

public class StatisticRevenue : StatisticBase
{
    public StatisticRevenue(IDatabaseService databaseService, ILogger<StatisticRevenue> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync(
        int year,
        int? aziendaId = null,
        ComparisonMode comparisonMode = ComparisonMode.FullYear,
        int? valutaTargetId = null)
    {
        if (!aziendaId.HasValue)
        {
            _logger.LogWarning("GetStatsAsync called without aziendaId - returning zero values");
            return StatisticResult.Create(0, 0, 0);
        }

        // Se non viene passata una valuta target, usa EUR (valuta base)
        int effectiveValutaId = valutaTargetId ?? await GetValutaBaseIdAsync();

        try
        {
            decimal currentYearRevenue = await GetFatturatoAnnualeAsync(aziendaId.Value, year, effectiveValutaId);
            decimal previousYearRevenue;
            List<double> trendData;

            if (comparisonMode == ComparisonMode.PeriodOverPeriod && year == DateTime.Now.Year)
            {
                // Period over Period: confronta stesso periodo anno precedente
                DateTime periodStart = new DateTime(year, 1, 1);
                DateTime periodEnd = DateTime.Now;
                DateTime prevStart = new DateTime(year - 1, 1, 1);
                DateTime prevEnd = DateTime.Now.AddYears(-1);

                currentYearRevenue = await GetFatturatoPeriodoAsync(aziendaId.Value, periodStart, periodEnd, effectiveValutaId);
                previousYearRevenue = await GetFatturatoPeriodoAsync(aziendaId.Value, prevStart, prevEnd, effectiveValutaId);
            }
            else
            {
                // Full Year: confronta intero anno precedente
                previousYearRevenue = await GetFatturatoAnnualeAsync(aziendaId.Value, year - 1, effectiveValutaId);
            }

            // Trend mensile per l'anno selezionato
            trendData = await GetFatturatoMensileTrendAsync(aziendaId.Value, year, effectiveValutaId);

            var result = StatisticResult.Create(
                (long)Math.Round(currentYearRevenue),
                (long)Math.Round(currentYearRevenue),
                (long)Math.Round(previousYearRevenue)
            );
            result.TrendData = trendData;

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error calculating revenue for azienda {AziendaId}, year {Year}", aziendaId, year);
            return StatisticResult.Create(0, 0, 0);
        }
    }

    private async Task<decimal> GetFatturatoAnnualeAsync(int aziendaId, int anno, int valutaTargetId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand(
                "SELECT fn_get_fatturato_annuale(@azienda_id, @anno, @valuta_target_id)",
                connection);

            command.Parameters.AddWithValue("azienda_id", aziendaId);
            command.Parameters.AddWithValue("anno", anno);
            command.Parameters.AddWithValue("valuta_target_id", valutaTargetId);

            var result = await command.ExecuteScalarAsync();
            return result != null && result != DBNull.Value ? Convert.ToDecimal(result) : 0;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching annual revenue for azienda {AziendaId}, year {Year}", aziendaId, anno);
            return 0;
        }
    }

    private async Task<decimal> GetFatturatoPeriodoAsync(int aziendaId, DateTime dataInizio, DateTime dataFine, int valutaTargetId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand(
                "SELECT fn_get_fatturato_periodo(@azienda_id, @data_inizio, @data_fine, @valuta_target_id)",
                connection);

            command.Parameters.AddWithValue("azienda_id", aziendaId);
            command.Parameters.AddWithValue("data_inizio", dataInizio);
            command.Parameters.AddWithValue("data_fine", dataFine);
            command.Parameters.AddWithValue("valuta_target_id", valutaTargetId);

            var result = await command.ExecuteScalarAsync();
            return result != null && result != DBNull.Value ? Convert.ToDecimal(result) : 0;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching period revenue for azienda {AziendaId}", aziendaId);
            return 0;
        }
    }

    private async Task<List<double>> GetFatturatoMensileTrendAsync(int aziendaId, int anno, int valutaTargetId)
    {
        var trend = new List<double>();
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand(
                "SELECT fatturato FROM fn_get_fatturato_mensile_trend(@azienda_id, @anno, @valuta_target_id)",
                connection);

            command.Parameters.AddWithValue("azienda_id", aziendaId);
            command.Parameters.AddWithValue("anno", anno);
            command.Parameters.AddWithValue("valuta_target_id", valutaTargetId);

            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                var value = reader.GetDecimal(0);
                trend.Add((double)value);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching monthly revenue trend for azienda {AziendaId}, year {Year}", aziendaId, anno);
        }

        // Assicura 12 mesi
        while (trend.Count < 12) trend.Add(0);

        return trend;
    }

    private async Task<int> GetValutaBaseIdAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand(
                "SELECT valuta_id FROM ana_valute WHERE valuta_is_base = TRUE LIMIT 1",
                connection);

            var result = await command.ExecuteScalarAsync();
            return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 2; // Default EUR id=2
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching base currency ID");
            return 2; // Default EUR
        }
    }
}
