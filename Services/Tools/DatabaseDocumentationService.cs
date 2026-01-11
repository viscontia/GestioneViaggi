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

            var functions = await GetFunctionsAsync();


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
                            .Table(table =>
                            {
                                table.ColumnsDefinition(columns =>
                                {
                                    columns.RelativeColumn(3); // Nome
                                    columns.RelativeColumn(3); // Scopo
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

                                foreach (var func in functions)
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

        // Query to get user defined functions in public schema
        // Excluding triggers if possible, or just all functions
        // Excluding extension functions (like pg_trgm ones if any, usually installed in extensions schema or public)
        // We filter by schema public.
        // We try to exclude standard postgres functions by checking owner or OID range, but schema public is a good enough filter for user code usually.
        string query = @"
            SELECT 
                p.proname::text as name, 
                pg_catalog.pg_get_function_arguments(p.oid)::text as args,
                pg_catalog.pg_get_function_result(p.oid)::text as result,
                d.description::text as description
            FROM pg_catalog.pg_proc p
            LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
            LEFT JOIN pg_catalog.pg_description d ON p.oid = d.objoid
            WHERE n.nspname = 'public'
            AND p.prokind != 'a' -- Exclude aggregate functions
            ORDER BY p.proname;
        ";

        using var cmd = new NpgsqlCommand(query, conn);
        using var reader = await cmd.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            list.Add(new DatabaseFunctionInfo
            {
                Name = reader.GetString(0),
                Arguments = reader.IsDBNull(1) ? "" : reader.GetString(1),
                ResultType = reader.IsDBNull(2) ? "" : reader.GetString(2),
                Description = reader.IsDBNull(3) ? "-" : reader.GetString(3)
            });
        }

        return list;
    }
}
