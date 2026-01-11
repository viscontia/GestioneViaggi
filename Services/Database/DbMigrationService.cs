using GestioneViaggi.Services.Database;
using Npgsql;

namespace GestioneViaggi.Services.Database;

public class DbMigrationService
{
    private readonly IDatabaseService _databaseService;

    public DbMigrationService(IDatabaseService databaseService)
    {
        _databaseService = databaseService;
    }

    public async Task ApplyMigrationsAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            var sql = @"
                -- Function for Provincia Auto-Increment
                CREATE OR REPLACE FUNCTION fn_assign_provincia_id() RETURNS TRIGGER AS $$
                BEGIN
                    IF NEW.provincia_id IS NULL THEN
                        SELECT COALESCE(MAX(provincia_id), 0) + 1 INTO NEW.provincia_id FROM ana_geo_province;
                    END IF;
                    RETURN NEW;
                END;
                $$ LANGUAGE plpgsql;

                -- Trigger for Provincia Auto-Increment
                DROP TRIGGER IF EXISTS trg_assign_provincia_id ON ana_geo_province;
                CREATE TRIGGER trg_assign_provincia_id
                BEFORE INSERT ON ana_geo_province
                FOR EACH ROW EXECUTE FUNCTION fn_assign_provincia_id();

                -- Function for Comune Auto-Increment
                CREATE OR REPLACE FUNCTION fn_assign_comune_id() RETURNS TRIGGER AS $$
                BEGIN
                    IF NEW.comune_id IS NULL THEN
                        SELECT COALESCE(MAX(comune_id), 0) + 1 INTO NEW.comune_id FROM ana_geo_comuni;
                    END IF;
                    RETURN NEW;
                END;
                $$ LANGUAGE plpgsql;

                -- Trigger for Comune Auto-Increment
                DROP TRIGGER IF EXISTS trg_assign_comune_id ON ana_geo_comuni;
                CREATE TRIGGER trg_assign_comune_id
                BEFORE INSERT ON ana_geo_comuni
                FOR EACH ROW EXECUTE FUNCTION fn_assign_comune_id();

                -- Function: get_max_old_year_company
                DROP FUNCTION IF EXISTS get_max_old_year_company(integer);
                CREATE OR REPLACE FUNCTION get_max_old_year_company(p_azienda_id integer)
                RETURNS integer AS $$
                DECLARE
                    v_min_year integer;
                BEGIN
                    IF p_azienda_id IS NULL THEN
                        SELECT MIN(EXTRACT(YEAR FROM dv.data_viaggio_data_inizio))::integer
                        INTO v_min_year
                        FROM ana_date_viaggi dv;
                    ELSE
                        SELECT MIN(EXTRACT(YEAR FROM dv.data_viaggio_data_inizio))::integer
                        INTO v_min_year
                        FROM ana_date_viaggi dv
                        JOIN ana_viaggi av ON dv.viaggio_id_fk = av.viaggio_id
                        WHERE av.azienda_id = p_azienda_id;
                    END IF;
                    RETURN COALESCE(v_min_year, EXTRACT(YEAR FROM CURRENT_DATE)::integer - 5);
                END;
                $$ LANGUAGE plpgsql;

                -- Check Constraint for NumAbitanti
                DO $$
                BEGIN
                    -- Safe update for existing invalid data (NumAbitanti)
                    UPDATE ana_geo_comuni SET comune_num_abitanti = 10 WHERE comune_num_abitanti < 10 OR comune_num_abitanti IS NULL;

                    -- Add constraint if not exists
                    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_comune_num_abitanti_min') THEN
                        ALTER TABLE ana_geo_comuni ADD CONSTRAINT check_comune_num_abitanti_min CHECK (comune_num_abitanti >= 10);
                    END IF;
                END $$;
            ";

            await using var command = new NpgsqlCommand(sql, connection);
            await command.ExecuteNonQueryAsync();

            Console.WriteLine("DB MIGRATION: Triggers installed successfully.");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"DB MIGRATION ERROR: {ex.Message}");
            // Log to file for visibility in MacCatalyst
            try
            {
                var path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "maui_migration_error.txt");
                await File.WriteAllTextAsync(path, $"MIGRATION ERROR: {ex.Message}");
            }
            catch { }
            throw;
        }
    }
}
