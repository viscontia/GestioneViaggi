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
         catch (PostgresException ex) when (ex.SqlState == "42883") // Undefined function
         {
             _logger.LogWarning("Function get_max_old_year_company missing. Creating it on the fly and defaulting to -5 years.");
             // Execute creation script directly here to fix race condition
             await CreateFunctionAsync();
             return currentYear - 5;
         }
         catch (Exception ex)
         {
             _logger.LogError(ex, "Error getting max old year for company {AziendaId}", aziendaId);
             return currentYear - 5; // Default fallback on error
         }
    }

    private async Task CreateFunctionAsync()
    {
        try 
        {
             var sql = @"
                DROP FUNCTION IF EXISTS get_max_old_year_company(integer);

                CREATE OR REPLACE FUNCTION get_max_old_year_company(p_azienda_id integer)
                RETURNS integer AS $$
                DECLARE
                    v_min_year integer;
                BEGIN
                    IF p_azienda_id IS NULL THEN
                        -- SuperAdmin: cerca globalmente su tutte le aziende
                        SELECT MIN(EXTRACT(YEAR FROM dv.data_viaggio_data_inizio))::integer
                        INTO v_min_year
                        FROM ana_date_viaggi dv;
                    ELSE
                        -- Utente normale: filtra per azienda
                        SELECT MIN(EXTRACT(YEAR FROM dv.data_viaggio_data_inizio))::integer
                        INTO v_min_year
                        FROM ana_date_viaggi dv
                        JOIN ana_viaggi av ON dv.viaggio_id_fk = av.viaggio_id
                        WHERE av.azienda_id = p_azienda_id;
                    END IF;

                    -- Ritorna l'anno minimo trovato, oppure Current Year - 5 come default
                    RETURN COALESCE(v_min_year, EXTRACT(YEAR FROM CURRENT_DATE)::integer - 5);
                END;
                $$ LANGUAGE plpgsql;
             ";
             await using var connection = await _databaseService.GetConnectionAsync();
             await using var command = new NpgsqlCommand(sql, connection);
             await command.ExecuteNonQueryAsync();
             _logger.LogInformation("Function get_max_old_year_company created successfully.");
        }
        catch(Exception ex)
        {
            _logger.LogError(ex, "Failed to create function on the fly.");
        }
    }
}
