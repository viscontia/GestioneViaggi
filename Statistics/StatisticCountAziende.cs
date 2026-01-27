using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Statistics;

public class StatisticCountAziende : StatisticBase
{
    public StatisticCountAziende(IDatabaseService databaseService, ILogger<StatisticCountAziende> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync(int year, int? aziendaId = null, ComparisonMode comparisonMode = ComparisonMode.FullYear)
    {
        // SECURITY: Multi-tenant filter - only SuperAdmin (aziendaId = null) can see all companies
        string aziendaFilter = aziendaId.HasValue ? $" AND azienda_id = {aziendaId.Value}" : "";

        long totalCountAtYear = await ExecuteScalarCountAsync($"SELECT COUNT(*) FROM ana_aziende WHERE EXTRACT(YEAR FROM data_creazione) <= @year{aziendaFilter}", ("year", year));
        long prevCount;
        double percentageChange = 0;
        long yearCount;
        long? flowPrev = null;

        if (comparisonMode == ComparisonMode.PeriodOverPeriod && year == DateTime.Now.Year)
        {
            // PoP Logic for Stock (Hybrid):
            // 1. Calculate Flow This Year
            long totalEndLastYear = await ExecuteScalarCountAsync($"SELECT COUNT(*) FROM ana_aziende WHERE EXTRACT(YEAR FROM data_creazione) <= @year - 1{aziendaFilter}", ("year", year));
            long flowCurrent = totalCountAtYear - totalEndLastYear;
            yearCount = flowCurrent;

            // 2. Flow Last Year (Jan 1 - Jan 12 2025)
            DateTime prevStart = new DateTime(year - 1, 1, 1);
            DateTime prevEnd = DateTime.Now.AddYears(-1);
            if (prevEnd < prevStart) prevEnd = prevStart;

            flowPrev = await ExecuteScalarCountAsync($"SELECT COUNT(*) FROM ana_aziende WHERE data_creazione BETWEEN @start AND @end{aziendaFilter}",
                ("start", prevStart), ("end", prevEnd));

            // 3. Percentage
            percentageChange = CalculatePercentage(flowCurrent, flowPrev ?? 0);

            // 4. Force Increment = flowCurrent
            // (CreateCumulative sets Previous = Main - YearCount, so Increment becomes YearCount)
            // So we just need to pass yearCount correctly to CreateCumulative and then override Percentage.
        }
        else
        {
            // FullYear (YoY): Count up to end of previous year
            prevCount = await ExecuteScalarCountAsync($"SELECT COUNT(*) FROM ana_aziende WHERE EXTRACT(YEAR FROM data_creazione) <= @year - 1{aziendaFilter}", ("year", year));
            yearCount = totalCountAtYear - prevCount;
        }

        var result = StatisticResult.CreateCumulative(totalCountAtYear, yearCount);
        result.TrendData = await GetMonthlyTrendFromDbAsync("ana_aziende", year, null, "data_creazione");

        if (comparisonMode == ComparisonMode.PeriodOverPeriod && year == DateTime.Now.Year)
        {
             result.PercentageChange = percentageChange;
             result.ReferenceFlowValue = flowPrev;
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
