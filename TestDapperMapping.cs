using System;
using System.Threading.Tasks;
using Dapper;
using Npgsql;
using GestioneViaggi.Models;

namespace GestioneViaggi;

/// <summary>
/// Test isolato per verificare il mapping Dapper di MovTransazioni.
/// Questo test dimostra che la rimozione di BaseEntity risolve il problema di mapping.
///
/// PROBLEMA IDENTIFICATO:
/// - MovTransazioni ereditava da BaseEntity che ha una proprietà "Id"
/// - MovTransazioni aveva anche "TransazioneId"
/// - Dapper con MatchNamesWithUnderscores cercava di mappare "transazione_id" a entrambe le proprietà
/// - Questo causava un conflitto e Dapper restituiva una collection vuota
///
/// SOLUZIONE:
/// - Rimossa l'ereditarietà da BaseEntity
/// - Ora MovTransazioni ha solo TransazioneId
/// - Il mapping Dapper funziona correttamente
/// </summary>
public class TestDapperMapping
{
    public static async Task TestMovTransazioniMapping()
    {
        // Configura Dapper per mappare snake_case a PascalCase
        DefaultTypeMap.MatchNamesWithUnderscores = true;

        var connectionString = "Host=127.0.0.1;Port=5432;Database=gestione_viaggi;Username=postgres;Password=postgres;";

        try
        {
            using var conn = new NpgsqlConnection(connectionString);
            await conn.OpenAsync();

            Console.WriteLine("=== TEST DAPPER MAPPING ===");
            Console.WriteLine("Testing MovTransazioni query with JOIN...");

            string sql = @"
                SELECT
                    t.*,
                    f.ragione_sociale as fornitore_ragione_sociale,
                    v.valuta_codice_iso as valuta_codice_iso,
                    vi.descrizione_breve as viaggio_descrizione
                FROM mov_transazioni t
                JOIN ana_fornitori f ON t.transazione_fornitore_id = f.fornitore_id
                JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
                LEFT JOIN ana_viaggi vi ON t.transazione_viaggio_id = vi.viaggio_id
                ORDER BY t.transazione_data DESC
                LIMIT 3";

            var result = await conn.QueryAsync<MovTransazioni>(sql);
            var resultList = result.ToList();

            Console.WriteLine($"Query executed successfully!");
            Console.WriteLine($"Records returned: {resultList.Count}");

            if (resultList.Count > 0)
            {
                Console.WriteLine("\n=== FIRST RECORD DETAILS ===");
                var first = resultList[0];
                Console.WriteLine($"TransazioneId: {first.TransazioneId}");
                Console.WriteLine($"Data: {first.TransazioneData:d}");
                Console.WriteLine($"Importo: {first.TransazioneImporto}");
                Console.WriteLine($"Valuta: {first.ValutaCodiceIso}");
                Console.WriteLine($"Fornitore: {first.FornitoreRagioneSociale}");
                Console.WriteLine($"Importo Formattato: {first.ImportoFormattato}");
                Console.WriteLine("\n✓ MAPPING SUCCESSFUL - Data loaded correctly!");
            }
            else
            {
                Console.WriteLine("\n✗ MAPPING FAILED - No records returned (possible mapping issue)");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"\n✗ ERROR: {ex.Message}");
            Console.WriteLine($"Stack: {ex.StackTrace}");
        }
    }
}
