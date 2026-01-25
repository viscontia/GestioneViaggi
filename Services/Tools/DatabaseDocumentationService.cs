using GestioneViaggi.Models;
using Microsoft.Extensions.Configuration;
using Npgsql;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Microsoft.Maui.Storage;
using System.Threading;

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

    private static bool _questPdfInitialized = false;
    private static readonly SemaphoreSlim _initLock = new SemaphoreSlim(1, 1);

    public async Task<string> GeneratePdfDocumentationAsync(string outputPath)
    {
        await EnsureQuestPdfInitializedAsync();

        try
        {
            var groupedFunctions = await GetFunctionsAsync();

            // Ensure directory exists
            var dir = Path.GetDirectoryName(outputPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            // Generate PDF
            Document.Create(container =>
            {
                container.Page(page =>
                {
                    page.Size(QuestPDF.Helpers.PageSizes.A4.Landscape());
                    page.Margin(1, Unit.Centimetre);
                    page.PageColor(QuestPDF.Helpers.Colors.White);
                    page.DefaultTextStyle(x => x.FontSize(9).FontFamily("Lato"));

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

            return outputPath;
        }
        catch (Exception ex)
        {
            throw new Exception($"Errore durante la generazione del PDF: {ex.Message}", ex);
        }
    }

    private async Task EnsureQuestPdfInitializedAsync()
    {
        // Double-check locking pattern for static initialization
        if (_questPdfInitialized) return;

        await _initLock.WaitAsync();
        try
        {
            if (_questPdfInitialized) return;

            QuestPDF.Settings.License = LicenseType.Community;
            QuestPDF.Settings.CheckIfAllTextGlyphsAreAvailable = false;

            // Register Fonts from App Package
            var fonts = new[] { "Lato-Regular.ttf", "Lato-Bold.ttf", "Lato-Italic.ttf", "Lato-BoldItalic.ttf" };
            foreach (var font in fonts)
            {
                try
                {
                    using var stream = await FileSystem.OpenAppPackageFileAsync(font);
                    using var ms = new MemoryStream();
                    await stream.CopyToAsync(ms);
                    ms.Position = 0;
                    QuestPDF.Drawing.FontManager.RegisterFont(ms);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[QuestPDF] Failed to load font {font}: {ex.Message}");
                    // Continue, as some fonts might be missing but we don't want to crash.
                    // Fallback will occur if font is not found.
                }
            }
            
            _questPdfInitialized = true;
        }
        finally
        {
            _initLock.Release();
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
