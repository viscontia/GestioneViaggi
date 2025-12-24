using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Statistics;

public class StatisticCountViaggiDaFare : StatisticBase
{
    public StatisticCountViaggiDaFare(IDatabaseService databaseService, ILogger<StatisticCountViaggiDaFare> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync(int? aziendaId = null)
    {
        DateTime todayCurrent = DateTime.Today;
        DateTime endOfCurrentYear = new DateTime(todayCurrent.Year, 12, 31);

        DateTime todayPrevious = todayCurrent.AddYears(-1);
        DateTime endOfPreviousYear = new DateTime(todayPrevious.Year, 12, 31);

        long currentCount = await GetPeriodCountAsync(todayCurrent, endOfCurrentYear, aziendaId);
        long previousCount = await GetPeriodCountAsync(todayPrevious, endOfPreviousYear, aziendaId);

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
