using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

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

        return StatisticResult.Create(currentCount, currentCount, previousCount);
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
