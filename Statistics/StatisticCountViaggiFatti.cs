using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Statistics;

public class StatisticCountViaggiFatti : StatisticBase
{
    public StatisticCountViaggiFatti(IDatabaseService databaseService, ILogger<StatisticCountViaggiFatti> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync(int? aziendaId = null)
    {
        DateTime todayCurrent = DateTime.Today;
        DateTime startOfCurrentYear = new DateTime(todayCurrent.Year, 1, 1);

        DateTime todayPrevious = todayCurrent.AddYears(-1);
        DateTime startOfPreviousYear = new DateTime(todayPrevious.Year, 1, 1);

        long currentCount = await GetPeriodCountAsync(startOfCurrentYear, todayCurrent, aziendaId);
        long previousCount = await GetPeriodCountAsync(startOfPreviousYear, todayPrevious, aziendaId);

        return StatisticResult.Create(currentCount, currentCount, previousCount);
    }

    private async Task<long> GetPeriodCountAsync(DateTime fromDate, DateTime toDate, int? aziendaId)
    {
        string sql = "SELECT COUNT(*) FROM ana_date_viaggi WHERE data_viaggio_data_inizio >= @fromDate AND data_viaggio_data_inizio <= @toDate";
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
