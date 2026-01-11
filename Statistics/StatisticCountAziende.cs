using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Statistics;

public class StatisticCountAziende : StatisticBase
{
    public StatisticCountAziende(IDatabaseService databaseService, ILogger<StatisticCountAziende> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync(int year)
    {
        long totalCountAtYear = await ExecuteScalarCountAsync("SELECT COUNT(*) FROM ana_aziende WHERE EXTRACT(YEAR FROM data_creazione) <= @year", ("year", year));
        long yearCount = await GetYearCountAsync(year);

        return StatisticResult.CreateCumulative(totalCountAtYear, yearCount);
    }

    private async Task<long> GetYearCountAsync(int year)
    {
        const string sql = "SELECT COUNT(*) FROM ana_aziende WHERE EXTRACT(YEAR FROM data_creazione) = @year";
        return await ExecuteScalarCountAsync(sql, ("year", year));
    }
}
