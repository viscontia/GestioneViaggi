using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Statistics;

public class StatisticCountViaggiFatti : StatisticBase
{
    public StatisticCountViaggiFatti(IDatabaseService databaseService, ILogger<StatisticCountViaggiFatti> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync(int year, int? aziendaId = null, ComparisonMode comparisonMode = ComparisonMode.FullYear)
    {
        long currentCount = await GetCountForYearAsync(year, aziendaId);
        long previousCount;

        if (comparisonMode == ComparisonMode.PeriodOverPeriod && year == DateTime.Now.Year)
        {
             // PoP: 01/01/PrevYear to Today/PrevYear
             DateTime prevStart = new DateTime(year - 1, 1, 1);
             DateTime prevEnd = DateTime.Now.AddYears(-1);
             // Safety check: ensure prevEnd is not before prevStart (e.g. if run on Jan 1st?)
             if (prevEnd < prevStart) prevEnd = prevStart;
             
             previousCount = await GetPeriodCountAsync(prevStart, prevEnd, aziendaId);
        }
        else
        {
             previousCount = await GetCountForYearAsync(year - 1, aziendaId);
        }

        var result = StatisticResult.Create(currentCount, currentCount, previousCount);

        // Populate trend data for chart visualization with custom filter for completed trips
        result.TrendData = await GetMonthlyTrendForCompletedTripsAsync(year, aziendaId);

        return result;
    }

    private async Task<List<double>> GetMonthlyTrendForCompletedTripsAsync(int year, int? aziendaId)
    {
        var trend = new List<double>();
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            string sql = @"
                WITH months AS (
                    SELECT generate_series(1, 12) AS month_num
                ),
                counts AS (
                    SELECT
                        EXTRACT(MONTH FROM data_viaggio_data_inizio)::INT AS month_num,
                        COUNT(*) as cnt
                    FROM ana_date_viaggi
                    WHERE EXTRACT(YEAR FROM data_viaggio_data_inizio) = @year
                      AND data_viaggio_effettuato_sino = 'Y'";

            if (aziendaId.HasValue)
            {
                sql += " AND azienda_id = @aziendaId";
            }

            sql += @"
                    GROUP BY 1
                )
                SELECT
                    m.month_num,
                    COALESCE(c.cnt, 0) as count_val
                FROM months m
                LEFT JOIN counts c ON m.month_num = c.month_num
                ORDER BY m.month_num";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("year", year);
            if (aziendaId.HasValue)
            {
                command.Parameters.AddWithValue("aziendaId", aziendaId.Value);
            }

            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                trend.Add(reader.GetInt64(1)); // Index 1 = count_val
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching monthly trend for completed trips, Year {Year}", year);
        }

        // Ensure we always have 12 items
        while (trend.Count < 12) trend.Add(0);

        return trend;
    }

    private async Task<long> GetCountForYearAsync(int year, int? aziendaId)
    {
        DateTime startOfYear = new DateTime(year, 1, 1);
        DateTime endOfYear = new DateTime(year, 12, 31);
        DateTime effectiveEndDate = DateTime.Today < endOfYear ? DateTime.Today : endOfYear;

        if (startOfYear > effectiveEndDate) return 0;

        return await GetPeriodCountAsync(startOfYear, effectiveEndDate, aziendaId);
    }

    private async Task<long> GetPeriodCountAsync(DateTime fromDate, DateTime toDate, int? aziendaId)
    {
        string sql = "SELECT COUNT(*) FROM ana_date_viaggi WHERE data_viaggio_data_inizio >= @fromDate AND data_viaggio_data_inizio <= @toDate AND data_viaggio_effettuato_sino = 'Y'";
        var parameters = new List<(string Name, object? Value)>
        {
            ("fromDate", fromDate),
            ("toDate", toDate)
        };

        if (aziendaId.HasValue)
        {
            sql += " AND azienda_id = @aziendaId";
            parameters.Add(("aziendaId", aziendaId.Value));
        }

        return await ExecuteScalarCountAsync(sql, parameters.ToArray());
    }
}
