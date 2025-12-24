using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Statistics;

public class StatisticCountClienti : StatisticBase
{
    public StatisticCountClienti(IDatabaseService databaseService, ILogger<StatisticCountClienti> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync(int? aziendaId = null)
    {
        int currentYear = DateTime.Now.Year;
        int previousYear = currentYear - 1;

        string totalSql = "SELECT COUNT(*) FROM ana_clienti";
        var totalParams = new List<(string Name, object? Value)>();
        if (aziendaId.HasValue)
        {
            totalSql += " WHERE azienda_fk = @aziendaId";
            totalParams.Add(("aziendaId", aziendaId.Value));
        }

        long totalCount = await ExecuteScalarCountAsync(totalSql, totalParams.ToArray());
        long currentYearCount = await GetYearCountAsync(currentYear, aziendaId);

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
