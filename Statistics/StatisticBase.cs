using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Statistics;

public abstract class StatisticBase
{
    protected readonly IDatabaseService _databaseService;
    protected readonly ILogger _logger;

    protected StatisticBase(IDatabaseService databaseService, ILogger logger)
    {
        _databaseService = databaseService;
        _logger = logger;
    }

    protected async Task<long> ExecuteScalarCountAsync(string sql, params (string Name, object? Value)[] parameters)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand(sql, connection);

            foreach (var param in parameters)
            {
                command.Parameters.AddWithValue(param.Name, param.Value ?? DBNull.Value);
            }

            var result = await command.ExecuteScalarAsync();
            return Convert.ToInt64(result ?? 0);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error executing count statistic: {Sql}", sql);
            throw;
        }
    }
    protected async Task<List<double>> GetMonthlyTrendFromDbAsync(string tableName, int year, int? aziendaId, string dateColumn = "created")
    {
        var trend = new List<double>();
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand("SELECT count_val FROM fn_get_monthly_trend(@table_name, @year, @azienda_id, @date_column)", connection);

            command.Parameters.AddWithValue("table_name", tableName);
            command.Parameters.AddWithValue("year", year);
            command.Parameters.AddWithValue("azienda_id", aziendaId ?? (object)DBNull.Value);
            command.Parameters.AddWithValue("date_column", dateColumn);

            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                trend.Add(reader.GetInt64(0)); // Index 0 = count_val (only column selected)
            }

            _logger.LogInformation("GetMonthlyTrendFromDbAsync: Table={Table}, Year={Year}, AziendaId={AziendaId}, TrendCount={Count}",
                tableName, year, aziendaId, trend.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching monthly trend for {Table} Year {Year}", tableName, year);
            // Fallback: return empty list logic handled by caller or initialization
        }

        // Ensure we always have 12 items even if DB fails or returns partial (though function ensures 12)
        while (trend.Count < 12) trend.Add(0);

        _logger.LogInformation("GetMonthlyTrendFromDbAsync FINAL: Table={Table}, Year={Year}, FinalCount={Count}, Data={Data}",
            tableName, year, trend.Count, string.Join(",", trend));

        return trend;
    }
}

public class StatisticResult
{
    public long MainValue { get; set; }
    public long CurrentYearValue { get; set; }
    public long PreviousYearValue { get; set; }
    public long Increment => MainValue - PreviousYearValue;
    public double PercentageChange { get; set; }
    public long? ReferenceFlowValue { get; set; } // Holds the comparative flow value for PoP Hybrid mode
    public List<double> TrendData { get; set; } = new(); // Holds monthly trend data (Jan-Dec)

    public static StatisticResult Create(long mainValue, long currentPeriod, long previousPeriod)
    {
        double change = 0;
        if (previousPeriod > 0)
        {
            change = Math.Round(((double)(currentPeriod - previousPeriod) / previousPeriod) * 100, 1);
        }
        else if (currentPeriod > 0)
        {
            change = 100;
        }

        return new StatisticResult
        {
            MainValue = mainValue,
            CurrentYearValue = currentPeriod,
            PreviousYearValue = previousPeriod,
            PercentageChange = change
        };
    }

    public static StatisticResult CreateCumulative(long totalNow, long acquiredThisYear)
    {
        double change = 0;
        long totalAtStartOfYear = totalNow - acquiredThisYear;

        if (totalAtStartOfYear > 0)
        {
            change = Math.Round(((double)acquiredThisYear / totalAtStartOfYear) * 100, 1);
        }
        else if (acquiredThisYear > 0)
        {
            change = 100;
        }

        return new StatisticResult
        {
            MainValue = totalNow,
            CurrentYearValue = acquiredThisYear,
            PreviousYearValue = totalAtStartOfYear, // Contextually correct for cumulative
            PercentageChange = change
        };
    }
}
