using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Statistics;

public class StatisticCountViaggi : StatisticBase
{
    public StatisticCountViaggi(IDatabaseService databaseService, ILogger<StatisticCountViaggi> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync(int year, int? aziendaId = null, ComparisonMode comparisonMode = ComparisonMode.FullYear)
    {
        string totalSql = "SELECT COUNT(*) FROM ana_viaggi WHERE EXTRACT(YEAR FROM created) <= @year";
        var parameters = new List<(string Name, object? Value)> { ("year", year) };
        if (aziendaId.HasValue)
        {
            totalSql += " AND azienda_id = @aziendaId";
            parameters.Add(("aziendaId", aziendaId.Value));
        }

        long totalCount = await ExecuteScalarCountAsync(totalSql, parameters.ToArray());

        long prevCount;
        double percentageChange = 0;
        long yearCount;

        if (comparisonMode == ComparisonMode.PeriodOverPeriod && year == DateTime.Now.Year)
        {
             // PoP Logic (Flow-based):
             
             // 1. Flow This Year
            string endLastYearSql = "SELECT COUNT(*) FROM ana_viaggi WHERE EXTRACT(YEAR FROM created) <= @year - 1";
            var endLastYearParams = new List<(string Name, object? Value)> { ("year", year) };
            if (aziendaId.HasValue)
            {
                endLastYearSql += " AND azienda_id = @aziendaId";
                endLastYearParams.Add(("aziendaId", aziendaId.Value));
            }
            long totalEndLastYear = await ExecuteScalarCountAsync(endLastYearSql, endLastYearParams.ToArray());

            long flowCurrent = totalCount - totalEndLastYear;
            yearCount = flowCurrent;

            // 2. Flow Last Year (Same Period)
            DateTime prevStart = new DateTime(year - 1, 1, 1);
            DateTime prevEnd = DateTime.Now.AddYears(-1);
            if (prevEnd < prevStart) prevEnd = prevStart;

            string flowPrevSql = "SELECT COUNT(*) FROM ana_viaggi WHERE created BETWEEN @start AND @end";
            var flowPrevParams = new List<(string Name, object? Value)> { ("start", prevStart), ("end", prevEnd) };
            if (aziendaId.HasValue)
            {
                flowPrevSql += " AND azienda_id = @aziendaId";
                flowPrevParams.Add(("aziendaId", aziendaId.Value));
            }
            long flowPrev = await ExecuteScalarCountAsync(flowPrevSql, flowPrevParams.ToArray());

            // 3. Percentage
            percentageChange = CalculatePercentage(flowCurrent, flowPrev);

            // 4. Set prevCount so that Result.Increment (Total - Prev) equals flowCurrent
            prevCount = totalCount - flowCurrent;
        }
        else
        {
            string prevSql = "SELECT COUNT(*) FROM ana_viaggi WHERE EXTRACT(YEAR FROM created) <= @year - 1";
            var prevParams = new List<(string Name, object? Value)> { ("year", year) };
            if (aziendaId.HasValue)
            {
                prevSql += " AND azienda_id = @aziendaId";
                prevParams.Add(("aziendaId", aziendaId.Value));
            }
            prevCount = await ExecuteScalarCountAsync(prevSql, prevParams.ToArray());
            yearCount = totalCount - prevCount;
        }

        var result = StatisticResult.CreateCumulative(totalCount, yearCount);
         if (comparisonMode == ComparisonMode.PeriodOverPeriod && year == DateTime.Now.Year)
        {
             result.PercentageChange = percentageChange;
        }
        return result;
    }

    private double CalculatePercentage(long current, long previous)
    {
        if (previous > 0) return Math.Round(((double)(current - previous) / previous) * 100, 1);
        if (current > 0) return 100;
        return 0;
    }
}
