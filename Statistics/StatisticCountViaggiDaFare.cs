using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Statistics;

public class StatisticCountViaggiDaFare : StatisticBase
{
    public StatisticCountViaggiDaFare(IDatabaseService databaseService, ILogger<StatisticCountViaggiDaFare> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync(int year, int? aziendaId = null)
    {
        long currentCount = await GetCountForYearAsync(year, aziendaId);
        long previousCount = await GetCountForYearAsync(year - 1, aziendaId);

        return StatisticResult.Create(currentCount, currentCount, previousCount);
    }

    private async Task<long> GetCountForYearAsync(int year, int? aziendaId)
    {
        DateTime startOfYear = new DateTime(year, 1, 1);
        DateTime endOfYear = new DateTime(year, 12, 31);
        DateTime effectiveStartDate = DateTime.Today > startOfYear ? DateTime.Today : startOfYear;

        if (effectiveStartDate > endOfYear) return 0;

        return await GetPeriodCountAsync(effectiveStartDate, endOfYear, aziendaId);
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
