using Dapper;
using GestioneViaggi.Models;
using Npgsql;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace GestioneViaggi
{
    /// <summary>
    /// TEST DIAGNOSTICO APPROFONDITO per identificare il problema del DataGrid vuoto
    /// Questo test simula esattamente il flusso di MovTransazioniService.GetAllAsync()
    /// </summary>
    public class TestDiagnostico
    {
        public static async Task RunDiagnosticTest()
        {
            Console.WriteLine("=== TEST DIAGNOSTICO MOVIMENTI ===\n");

            // Configura Dapper (dovrebbe già essere fatto in MauiProgram, ma per sicurezza)
            DefaultTypeMap.MatchNamesWithUnderscores = true;
            Console.WriteLine("1. Dapper configurato: MatchNamesWithUnderscores = true");

            var connectionString = "Host=127.0.0.1;Port=5432;Database=gestione_viaggi;Username=postgres;Password=postgres;";

            try
            {
                using var conn = new NpgsqlConnection(connectionString);
                await conn.OpenAsync();
                Console.WriteLine("2. Connessione database: OK\n");

                // === STEP 1: Verifica dati grezzi ===
                Console.WriteLine("=== STEP 1: VERIFICA DATI GREZZI ===");
                var countSql = "SELECT COUNT(*) FROM mov_transazioni";
                var count = await conn.ExecuteScalarAsync<int>(countSql);
                Console.WriteLine($"Numero totale transazioni nel DB: {count}");

                if (count == 0)
                {
                    Console.WriteLine("ERRORE: Il database è vuoto! Nessuna transazione presente.");
                    return;
                }

                // === STEP 2: Testa query base senza JOIN ===
                Console.WriteLine("\n=== STEP 2: QUERY BASE (senza JOIN) ===");
                var basicSql = "SELECT * FROM mov_transazioni LIMIT 1";
                var basicResult = await conn.QueryFirstOrDefaultAsync<MovTransazioni>(basicSql);

                if (basicResult == null)
                {
                    Console.WriteLine("ERRORE: Query base non restituisce dati!");
                    return;
                }

                Console.WriteLine("Query base OK - Dati letti:");
                Console.WriteLine($"  TransazioneId: {basicResult.TransazioneId}");
                Console.WriteLine($"  TransazioneAziendaId: {basicResult.TransazioneAziendaId}");
                Console.WriteLine($"  TransazioneControparteId: {basicResult.TransazioneControparteId}");
                Console.WriteLine($"  TransazioneImporto: {basicResult.TransazioneImporto}");
                Console.WriteLine($"  TransazioneData: {basicResult.TransazioneData}");
                Console.WriteLine($"  TransazioneCausale: {basicResult.TransazioneCausale}");

                // === STEP 3: Testa query completa con JOIN (quella vera del service) ===
                Console.WriteLine("\n=== STEP 3: QUERY COMPLETA CON JOIN ===");
                string fullSql = @"
                    SELECT
                        t.*,
                        f.ragione_sociale as controparte_ragione_sociale,
                        v.valuta_codice_iso as valuta_codice_iso,
                        vi.viaggio_descrizione_breve as viaggio_descrizione
                    FROM mov_transazioni t
                    JOIN ana_controparti f ON t.transazione_controparte_id = f.controparte_id
                    JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
                    LEFT JOIN ana_viaggi vi ON t.transazione_viaggio_id = vi.viaggio_id
                    ORDER BY t.transazione_data DESC, t.created_at DESC";

                Console.WriteLine("Esecuzione query completa...");
                var fullResult = await conn.QueryAsync<MovTransazioni>(fullSql);
                var fullResultList = fullResult.ToList();

                Console.WriteLine($"Risultati ottenuti: {fullResultList.Count} transazioni");

                if (fullResultList.Count == 0)
                {
                    Console.WriteLine("PROBLEMA TROVATO: La query con JOIN restituisce 0 risultati!");
                    Console.WriteLine("Possibili cause:");
                    Console.WriteLine("  1. Problema con i JOIN (dati orfani)");
                    Console.WriteLine("  2. Problema nel mapping Dapper delle colonne joined");
                    Console.WriteLine("  3. Conflitto nelle proprietà della classe MovTransazioni");

                    // Test senza i JOIN opzionali
                    Console.WriteLine("\n=== TEST RIDOTTO: Query senza LEFT JOIN ===");
                    var reducedSql = @"
                        SELECT
                            t.*,
                            f.ragione_sociale as fornitore_ragione_sociale,
                            v.valuta_codice_iso as valuta_codice_iso
                        FROM mov_transazioni t
                        JOIN ana_fornitori f ON t.transazione_fornitore_id = f.fornitore_id
                        JOIN ana_valute v ON t.transazione_valuta_id = v.valuta_id
                        LIMIT 3";

                    var reducedResult = await conn.QueryAsync<MovTransazioni>(reducedSql);
                    var reducedList = reducedResult.ToList();
                    Console.WriteLine($"Query ridotta restituisce: {reducedList.Count} risultati");

                    return;
                }

                // === STEP 4: Verifica dettagli primo record ===
                Console.WriteLine("\n=== STEP 4: DETTAGLI PRIMO RECORD ===");
                var first = fullResultList.First();
                Console.WriteLine($"  TransazioneId: {first.TransazioneId}");
                Console.WriteLine($"  ControparteRagioneSociale: {first.ControparteRagioneSociale}");
                Console.WriteLine($"  ValutaCodiceIso: {first.ValutaCodiceIso}");
                Console.WriteLine($"  ViaggioDescrizione: {first.ViaggioDescrizione ?? "(null)"}");
                Console.WriteLine($"  TransazioneCausale: {first.TransazioneCausale}");
                Console.WriteLine($"  TransazioneImporto: {first.TransazioneImporto}");

                // Testa la proprietà computed ImportoFormattato
                try
                {
                    var importoFormattato = first.ImportoFormattato;
                    Console.WriteLine($"  ImportoFormattato: {importoFormattato}");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"  ERRORE in ImportoFormattato: {ex.Message}");
                }

                // === STEP 5: Simula assegnazione a EnterpriseDataGrid ===
                Console.WriteLine("\n=== STEP 5: SIMULA ASSEGNAZIONE A DATAGRID ===");
                IEnumerable<MovTransazioni> items = fullResultList;
                Console.WriteLine($"  IEnumerable<MovTransazioni> items assegnato");
                Console.WriteLine($"  items.Count() = {items.Count()}");
                Console.WriteLine($"  items.Any() = {items.Any()}");

                Console.WriteLine("\n=== TEST COMPLETATO CON SUCCESSO ===");
                Console.WriteLine("Se vedi questo messaggio, il problema NON è nel service o nel mapping Dapper.");
                Console.WriteLine("Il problema potrebbe essere:");
                Console.WriteLine("  1. Nel componente EnterpriseDataGrid (non riceve/renderizza i dati)");
                Console.WriteLine("  2. Nel ciclo di rendering Blazor");
                Console.WriteLine("  3. Nella proprietà Items del componente");
                Console.WriteLine("  4. In StateHasChanged() non chiamato");

            }
            catch (Exception ex)
            {
                Console.WriteLine($"\nERRORE CRITICO: {ex.GetType().Name}");
                Console.WriteLine($"Messaggio: {ex.Message}");
                Console.WriteLine($"StackTrace:\n{ex.StackTrace}");

                if (ex.InnerException != null)
                {
                    Console.WriteLine($"\nInner Exception: {ex.InnerException.Message}");
                }
            }
        }
    }
}
