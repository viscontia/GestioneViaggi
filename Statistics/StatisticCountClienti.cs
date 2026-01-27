using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Statistics;

public class StatisticCountClienti : StatisticBase
{
    public StatisticCountClienti(IDatabaseService databaseService, ILogger<StatisticCountClienti> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync(int year, int? aziendaId = null, ComparisonMode comparisonMode = ComparisonMode.FullYear)
    {
        string totalSql = "SELECT COUNT(*) FROM ana_clienti WHERE EXTRACT(YEAR FROM created) <= @year";
        var totalParams = new List<(string Name, object? Value)> { ("year", year) };
        if (aziendaId.HasValue)
        {
            totalSql += " AND azienda_fk = @aziendaId";
            totalParams.Add(("aziendaId", aziendaId.Value));
        }

        long totalCount = await ExecuteScalarCountAsync(totalSql, totalParams.ToArray());
        
        long prevCount;
        double percentageChange = 0;
        long currentYearCount;
        long? flowPrev = null;

        if (comparisonMode == ComparisonMode.PeriodOverPeriod && year == DateTime.Now.Year)
        {
            // PoP Logic for Stock (Hybrid):
            // MainValue = Total Stock Now.
            // Increment (Visual) = YTD Growth (Acquired This Year).
            // Percentage = Compare YTD Growth This Year vs YTD Growth Last Year (Flow vs Flow).

            // 1. Calculate Flow This Year (YTD 2026)
            long totalEndLastYear = await ExecuteScalarCountAsync("SELECT COUNT(*) FROM ana_clienti WHERE created <= @date" + (aziendaId.HasValue ? " AND azienda_fk = @aziendaId" : ""),
                ("date", new DateTime(year - 1, 12, 31)),
                ("aziendaId", aziendaId ?? (object)DBNull.Value));
            
            long flowCurrent = totalCount - totalEndLastYear;
            currentYearCount = flowCurrent; // This ensures Increment = flowCurrent (Main - (Main-Flow))

            // 2. Calculate Flow Last Year (Same Period: Jan 1 to Jan 12 2025)
            DateTime prevStart = new DateTime(year - 1, 1, 1);
            DateTime prevEnd = DateTime.Now.AddYears(-1);
            if (prevEnd < prevStart) prevEnd = prevStart;

            string flowPrevSql = "SELECT COUNT(*) FROM ana_clienti WHERE created BETWEEN @start AND @end";
            var flowPrevParams = new List<(string Name, object? Value)> { ("start", prevStart), ("end", prevEnd) };
            if (aziendaId.HasValue)
            {
                flowPrevSql += " AND azienda_fk = @aziendaId";
                flowPrevParams.Add(("aziendaId", aziendaId.Value));
            }
            flowPrev = await ExecuteScalarCountAsync(flowPrevSql, flowPrevParams.ToArray());

            // 3. Calculate Percentage based on Flows
            percentageChange = CalculatePercentage(flowCurrent, flowPrev ?? 0);

            // 4. Set prevCount (PreviousYearValue) such that Increment == flowCurrent
            // StatisticResult.Increment = MainValue - PreviousYearValue
            // We want Increment = flowCurrent
            // So PreviousYearValue = MainValue - flowCurrent
            prevCount = totalCount - flowCurrent; 
        }
        else
        {
             // Standard YoY Logic
             string prevSql = "SELECT COUNT(*) FROM ana_clienti WHERE EXTRACT(YEAR FROM created) <= @year - 1";
            var prevParams = new List<(string Name, object? Value)> { ("year", year) };
             if (aziendaId.HasValue)
            {
                prevSql += " AND azienda_fk = @aziendaId";
                prevParams.Add(("aziendaId", aziendaId.Value));
            }
            prevCount = await ExecuteScalarCountAsync(prevSql, prevParams.ToArray());
            currentYearCount = totalCount - prevCount;
            percentageChange = CalculatePercentage(currentYearCount, prevCount); // Not quite right for YoY Accum, but fits CreateCumulative
        }

        if (comparisonMode == ComparisonMode.PeriodOverPeriod && year == DateTime.Now.Year)
        {
            var result = StatisticResult.CreateCumulative(totalCount, currentYearCount);
            result.TrendData = await GetMonthlyTrendFromDbAsync("ana_clienti", year, aziendaId); // Default created
            result.PercentageChange = percentageChange; // Override with Flow percentage
            result.ReferenceFlowValue = flowPrev;
            return result;
        }

        var res = StatisticResult.CreateCumulative(totalCount, currentYearCount);
        res.TrendData = await GetMonthlyTrendFromDbAsync("ana_clienti", year, aziendaId); 
        return res;
    }

    private double CalculatePercentage(long current, long previous)
    {
        if (previous > 0) return Math.Round(((double)(current - previous) / previous) * 100, 1);
        if (current > 0) return 100;
        return 0;
    }

    private async Task<long> GetYearCountAsync(int year, int? aziendaId)
    {
        string sql = "SELECT COUNT(*) FROM ana_clienti WHERE EXTRACT(YEAR FROM created) = @year";
        var parameters = new List<(string Name, object? Value)> { ("year", year) };

        if (aziendaId.HasValue)
        {
            sql += " AND azienda_fk = @aziendaId";
            parameters.Add(("aziendaId", aziendaId.Value));
        }

        return await ExecuteScalarCountAsync(sql, parameters.ToArray());
    }
}
