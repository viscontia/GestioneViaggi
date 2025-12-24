using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Statistics;

public class StatisticCountAziende : StatisticBase
{
    public StatisticCountAziende(IDatabaseService databaseService, ILogger<StatisticCountAziende> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync()
    {
        int currentYear = DateTime.Now.Year;

        long totalCount = await ExecuteScalarCountAsync("SELECT COUNT(*) FROM ana_aziende");
        long currentYearCount = await GetYearCountAsync(currentYear);

        return StatisticResult.CreateCumulative(totalCount, currentYearCount);
    }

    private async Task<long> GetYearCountAsync(int year)
    {
        const string sql = "SELECT COUNT(*) FROM ana_aziende WHERE EXTRACT(YEAR FROM data_creazione) = @year";
        return await ExecuteScalarCountAsync(sql, ("year", year));
    }
}
