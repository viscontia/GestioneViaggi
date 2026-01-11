using GestioneViaggi.Models;
using Microsoft.Extensions.Configuration;
using Npgsql;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace GestioneViaggi.Services.Tools;

public interface IDatabaseDocumentationService
{
    Task<string> GeneratePdfDocumentationAsync(string outputPath);
}

public class DatabaseDocumentationService : IDatabaseDocumentationService
{
    private readonly IConfiguration _configuration;
    private readonly string _connectionString;

    public DatabaseDocumentationService(IConfiguration configuration)
    {
        _configuration = configuration;
        _connectionString = _configuration.GetConnectionString("PostgreSQL") 
                            ?? throw new InvalidOperationException("Connection string 'PostgreSQL' not found.");
    }

    public async Task<string> GeneratePdfDocumentationAsync(string outputPath)
    {
        var diagLog = new System.Text.StringBuilder();
        diagLog.AppendLine("--- DIAGNOSTICS START ---");
        
        try 
        {
            var baseDir = AppContext.BaseDirectory;
            diagLog.AppendLine($"BaseDirectory: {baseDir}");

            // 1. Check SkiaSharp
            try 
            {
                var paint = new SkiaSharp.SKPaint();
                diagLog.AppendLine("SkiaSharp: OK");
            }
            catch (Exception ex) { diagLog.AppendLine($"SkiaSharp: FAILED ({ex.Message})"); }

            // 2. Check HarfBuzzSharp
            try 
            {
                using var buffer = new HarfBuzzSharp.Buffer();
                diagLog.AppendLine("HarfBuzzSharp: OK");
            }
            catch (Exception ex) { diagLog.AppendLine($"HarfBuzzSharp: FAILED ({ex.Message})"); }

            // 3. Check Fonts & Auto-Fix
            var fontDir = Path.Combine(baseDir, "LatoFont");
            if (Directory.Exists(fontDir))
            {
                 var files = Directory.GetFiles(fontDir);
                 diagLog.AppendLine($"LatoFont (BaseDir): FOUND ({files.Length} files)");
            }
            else
            {
                 diagLog.AppendLine($"LatoFont (BaseDir): NOT FOUND at {fontDir}");
                 var resDir = Path.Combine(baseDir, "..", "Resources", "LatoFont");
                 if (Directory.Exists(resDir))
                 {
                    var files = Directory.GetFiles(resDir);
                    diagLog.AppendLine($"LatoFont (Resources): FOUND ({files.Length} files). Attempting COPY...");
                    
                    try 
                    {
                        Directory.CreateDirectory(fontDir);
                        foreach (var file in files)
                        {
                            var destName = Path.GetFileName(file);
                            var destPath = Path.Combine(fontDir, destName);
                            File.Copy(file, destPath, true);
                        }
                        diagLog.AppendLine("COPY SUCCESS: Fonts copied to BaseDirectory.");
                    }
                    catch(Exception copyEx)
                    {
                        diagLog.AppendLine($"COPY FAILED: {copyEx.Message}");
                    }
                 }
                 else
                 {
                    diagLog.AppendLine($"LatoFont (Resources): NOT FOUND at {resDir}");
                 }
            }

            // 4. Manual Font Registration (Robustness)
            try 
            {
                var filesToRegister = Directory.GetFiles(fontDir); // fontDir is BaseDirectory/LatoFont
                foreach (var fontFile in filesToRegister)
                {
                    using var stream = File.OpenRead(fontFile);
                    QuestPDF.Drawing.FontManager.RegisterFont(stream);
                }
                diagLog.AppendLine($"MANUAL REGISTRATION: Registered {filesToRegister.Length} fonts.");
            }
            catch(Exception regEx)
            {
                diagLog.AppendLine($"MANUAL REGISTRATION FAILED: {regEx.Message}");
            }
        }
        catch (Exception ex)
        {
            diagLog.AppendLine($"Diag Error: {ex.Message}");
        }
        diagLog.AppendLine("--- DIAGNOSTICS END ---");

        try
        {
            // Configure QuestPDF License (Lazy Init)
            QuestPDF.Settings.License = LicenseType.Community;
            QuestPDF.Settings.CheckIfAllTextGlyphsAreAvailable = false;

            var groupedFunctions = await GetFunctionsAsync();

            // Ensure directory exists
            var dir = Path.GetDirectoryName(outputPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            await Task.Run(() =>
            {
                Document.Create(container =>
                {
                    container.Page(page =>
                    {
                        page.Size(QuestPDF.Helpers.PageSizes.A4.Landscape());
                        page.Margin(1, Unit.Centimetre);
                        page.PageColor(QuestPDF.Helpers.Colors.White);
                        page.DefaultTextStyle(x => x.FontSize(9).FontFamily(QuestPDF.Helpers.Fonts.Arial));

                        page.Header()
                            .AlignCenter()
                            .Text("Documentazione Funzioni Database - Gestione Viaggi")
                            .SemiBold().FontSize(16);

                        page.Content()
                            .PaddingVertical(1, Unit.Centimetre)
                            .Column(col => 
                            { 
                                var groups = groupedFunctions.GroupBy(f => f.Category).OrderBy(g => g.Key);
                                
                                foreach(var group in groups)
                                {
                                    col.Item().PaddingBottom(10).Text(group.Key).FontSize(14).Bold().FontColor(QuestPDF.Helpers.Colors.Blue.Medium);
                                    
                                    col.Item().PaddingBottom(20).Table(table =>
                                    {
                                        table.ColumnsDefinition(columns =>
                                        {
                                            columns.RelativeColumn(3); // Nome
                                            columns.RelativeColumn(4); // Scopo
                                            columns.RelativeColumn(3); // Input
                                            columns.RelativeColumn(2); // Output
                                        });

                                        table.Header(header =>
                                        {
                                            header.Cell().Element(CellStyle).Text("Nome Function");
                                            header.Cell().Element(CellStyle).Text("Scopo");
                                            header.Cell().Element(CellStyle).Text("Input");
                                            header.Cell().Element(CellStyle).Text("Output");

                                            static QuestPDF.Infrastructure.IContainer CellStyle(QuestPDF.Infrastructure.IContainer container)
                                            {
                                                return container.DefaultTextStyle(x => x.SemiBold()).PaddingVertical(5).BorderBottom(1).BorderColor(QuestPDF.Helpers.Colors.Black);
                                            }
                                        });

                                        foreach (var func in group.OrderBy(x => x.Name))
                                        {
                                            table.Cell().Element(CellStyle).Text(func.Name);
                                            table.Cell().Element(CellStyle).Text(func.Description);
                                            table.Cell().Element(CellStyle).Text(func.Arguments);
                                            table.Cell().Element(CellStyle).Text(func.ResultType);

                                            static QuestPDF.Infrastructure.IContainer CellStyle(QuestPDF.Infrastructure.IContainer container)
                                            {
                                                return container.BorderBottom(1).BorderColor(QuestPDF.Helpers.Colors.Grey.Lighten3).PaddingVertical(5);
                                            }
                                        }
                                    });
                                }
                            });

                        page.Footer()
                            .AlignCenter()
                            .Text(x =>
                            {
                                x.Span("Pagina ");
                                x.CurrentPageNumber();
                            });
                    });
                })
                .GeneratePdf(outputPath);
            });

            return outputPath;
        }
        catch (Exception ex)
        {
            throw new Exception($"{diagLog}\nErrore durante la generazione del PDF: {ex.Message}", ex);
        }
    }

    private async Task<List<DatabaseFunctionInfo>> GetFunctionsAsync()
    {
        var list = new List<DatabaseFunctionInfo>();

        using var conn = new NpgsqlConnection(_connectionString);
        await conn.OpenAsync();

        string query = @"
            SELECT 
                p.proname::text as name, 
                pg_catalog.pg_get_function_arguments(p.oid)::text as args,
                pg_catalog.pg_get_function_result(p.oid)::text as result,
                d.description::text as description,
                pg_catalog.pg_get_functiondef(p.oid)::text as definition
            FROM pg_catalog.pg_proc p
            LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
            LEFT JOIN pg_catalog.pg_description d ON p.oid = d.objoid
            WHERE n.nspname = 'public'
            AND p.prokind != 'a' -- Exclude aggregate functions
            AND NOT EXISTS (
                SELECT 1 FROM pg_catalog.pg_depend dep 
                WHERE dep.objid = p.oid 
                AND dep.deptype = 'e'
            )
            ORDER BY p.proname;
        ";

        using var cmd = new NpgsqlCommand(query, conn);
        using var reader = await cmd.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            var info = new DatabaseFunctionInfo
            {
                Name = reader.GetString(0),
                Arguments = reader.IsDBNull(1) ? "" : reader.GetString(1),
                ResultType = reader.IsDBNull(2) ? "" : reader.GetString(2),
                Description = reader.IsDBNull(3) ? "" : reader.GetString(3),
                Definition = reader.IsDBNull(4) ? "" : reader.GetString(4)
            };

            // Infer description if missing
            if (string.IsNullOrWhiteSpace(info.Description))
            {
                info.Description = InferDescription(info.Name, info.Definition);
            }

            // Categorize
            info.Category = CategorizeFunction(info.Name, info.Definition);

            list.Add(info);
        }

        return list;
    }

    private string CategorizeFunction(string name, string code)
    {
        name = name.ToLower();
        code = code.ToLower();

        if (name.Contains("seq") || name.Contains("nextval") || code.Contains("nextval"))
            return "Assegnazione Numerazione PK";
        
        if (name.Contains("check_delete") || code.Contains("check_delete") || (code.Contains("exception") && code.Contains("delete")))
            return "Protezione da Cancellazione";

        if (name.StartsWith("get_") || name.StartsWith("select_") || code.Contains("select * from"))
            return "Ottenimento dati";

        if (name.StartsWith("insert_") || name.StartsWith("create_") || code.Contains("insert into"))
            return "Inserimento Dati";

        if (name.StartsWith("update_") || code.Contains("update "))
            return "Aggiornamento Dati";

        if (name.StartsWith("delete_") || code.Contains("delete from"))
            return "Cancellazione Dati";

        return "Altro / Utility";
    }

    private string InferDescription(string name, string code)
    {
        // Simple heuristic to extract intent from code if no comment exists
        if (code.Contains("--"))
        {
             // Try to find first comment line
             var lines = code.Split('\n');
             foreach(var line in lines)
             {
                 var trim = line.Trim();
                 if (trim.StartsWith("--"))
                    return trim.Substring(2).Trim();
             }
        }

        if (name.Contains("nextval")) return "Restituisce il prossimo valore della sequenza per PK.";
        if (name.Contains("check_delete")) return "Verifica vincoli prima della cancellazione.";
        
        return "Funzione di sistema o logica custom (vedi definizione).";
    }
}
