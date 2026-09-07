using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Statistics;

public class StatisticYearService
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<StatisticYearService> _logger;

    public StatisticYearService(IDatabaseService databaseService, ILogger<StatisticYearService> logger)
    {
        _databaseService = databaseService;
        _logger = logger;
    }

    public async Task<int> GetMaxOldYearCompanyAsync(int? aziendaId)
    {
         int currentYear = DateTime.Now.Year;
         try
         {
             await using var connection = await _databaseService.GetConnectionAsync();
             await using var command = new NpgsqlCommand("SELECT get_max_old_year_company(@aziendaId)", connection);
             command.Parameters.AddWithValue("aziendaId", (object?)aziendaId ?? DBNull.Value);

             var result = await command.ExecuteScalarAsync();
             int dbYear = Convert.ToInt32(result ?? currentYear);

             // If DB returns current year (no data) or future, force at least 5 years of history
             // to allow users to see empty stats for past years.
             return dbYear >= currentYear ? currentYear - 5 : dbYear;
         }
         catch (Exception ex)
         {
             _logger.LogError(ex, "Error getting max old year for company {AziendaId}", aziendaId);
             return currentYear - 5; // Default fallback on error
         }
    }

}
