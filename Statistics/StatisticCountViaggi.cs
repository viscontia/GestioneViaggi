using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Statistics;

public class StatisticCountViaggi : StatisticBase
{
    public StatisticCountViaggi(IDatabaseService databaseService, ILogger<StatisticCountViaggi> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync(int year, int? aziendaId = null)
    {
        string totalSql = "SELECT COUNT(*) FROM ana_viaggi WHERE EXTRACT(YEAR FROM created) <= @year";
        var parameters = new List<(string Name, object? Value)> { ("year", year) };
        if (aziendaId.HasValue)
        {
            totalSql += " AND azienda_id = @aziendaId";
            parameters.Add(("aziendaId", aziendaId.Value));
        }

        long totalCount = await ExecuteScalarCountAsync(totalSql, parameters.ToArray());

        string yearSql = "SELECT COUNT(*) FROM ana_viaggi WHERE EXTRACT(YEAR FROM created) = @year";
        var yearParams = new List<(string Name, object? Value)> { ("year", year) };
        if (aziendaId.HasValue)
        {
            yearSql += " AND azienda_id = @aziendaId";
            yearParams.Add(("aziendaId", aziendaId.Value));
        }
        long yearCount = await ExecuteScalarCountAsync(yearSql, yearParams.ToArray());

        return StatisticResult.CreateCumulative(totalCount, yearCount);
    }
}
