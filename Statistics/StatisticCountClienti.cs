using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Statistics;

public class StatisticCountClienti : StatisticBase
{
    public StatisticCountClienti(IDatabaseService databaseService, ILogger<StatisticCountClienti> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync(int year, int? aziendaId = null)
    {
        string totalSql = "SELECT COUNT(*) FROM ana_clienti WHERE EXTRACT(YEAR FROM created) <= @year";
        var totalParams = new List<(string Name, object? Value)> { ("year", year) };
        if (aziendaId.HasValue)
        {
            totalSql += " AND azienda_fk = @aziendaId";
            totalParams.Add(("aziendaId", aziendaId.Value));
        }

        long totalCount = await ExecuteScalarCountAsync(totalSql, totalParams.ToArray());
        long currentYearCount = await GetYearCountAsync(year, aziendaId);

        return StatisticResult.CreateCumulative(totalCount, currentYearCount);
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
