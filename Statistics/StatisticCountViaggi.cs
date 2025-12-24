using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Statistics;

public class StatisticCountViaggi : StatisticBase
{
    public StatisticCountViaggi(IDatabaseService databaseService, ILogger<StatisticCountViaggi> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync(int? aziendaId = null)
    {
        int currentYear = DateTime.Now.Year;

        string totalSql = "SELECT COUNT(*) FROM ana_viaggi";
        var parameters = new List<(string Name, object? Value)>();
        if (aziendaId.HasValue)
        {
            totalSql += " WHERE azienda_id = @aziendaId";
            parameters.Add(("aziendaId", aziendaId.Value));
        }

        long totalCount = await ExecuteScalarCountAsync(totalSql, parameters.ToArray());

        string yearSql = "SELECT COUNT(*) FROM ana_viaggi WHERE EXTRACT(YEAR FROM created) = @year";
        var yearParams = new List<(string Name, object? Value)> { ("year", currentYear) };
        if (aziendaId.HasValue)
        {
            yearSql += " AND azienda_id = @aziendaId";
            yearParams.Add(("aziendaId", aziendaId.Value));
        }
        long currentYearCount = await ExecuteScalarCountAsync(yearSql, yearParams.ToArray());

        return StatisticResult.CreateCumulative(totalCount, currentYearCount);
    }
}
