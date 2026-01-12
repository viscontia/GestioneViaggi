using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Statistics;

public class StatisticRevenue : StatisticBase
{
    public StatisticRevenue(IDatabaseService databaseService, ILogger<StatisticRevenue> logger)
        : base(databaseService, logger)
    {
    }

    public async Task<StatisticResult> GetStatsAsync(int year, int? aziendaId = null, ComparisonMode comparisonMode = ComparisonMode.FullYear)
    {
        // Placeholder per fatturato futuro
        await Task.CompletedTask;
        return StatisticResult.Create(0, 0, 0);
    }
}
