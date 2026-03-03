using ClosedXML.Excel;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Export;

/// <summary>
/// Definizione di una colonna per l'export Excel
/// </summary>
public class ExcelColumnDefinition<T>
{
    public string Header { get; set; } = string.Empty;
    public Func<T, object?> ValueSelector { get; set; } = _ => null;
    public string? NumberFormat { get; set; }
}

public interface IExcelExportService
{
    Task<string> ExportToExcelAsync<T>(
        IEnumerable<T> data,
        List<ExcelColumnDefinition<T>> columns,
        string fileName,
        string sheetName = "Dati");
}

public class ExcelExportService : IExcelExportService
{
    private readonly ILogger<ExcelExportService> _logger;

    public ExcelExportService(ILogger<ExcelExportService> logger)
    {
        _logger = logger;
    }

    public async Task<string> ExportToExcelAsync<T>(
        IEnumerable<T> data,
        List<ExcelColumnDefinition<T>> columns,
        string fileName,
        string sheetName = "Dati")
    {
        return await Task.Run(() =>
        {
            var targetFolder = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                "Downloads");

            if (!Directory.Exists(targetFolder))
                Directory.CreateDirectory(targetFolder);

            var outputPath = Path.Combine(targetFolder, fileName);

            if (File.Exists(outputPath))
                File.Delete(outputPath);

            using var workbook = new XLWorkbook();
            var worksheet = workbook.Worksheets.Add(sheetName);

            // Header row
            for (int col = 0; col < columns.Count; col++)
            {
                var cell = worksheet.Cell(1, col + 1);
                cell.Value = columns[col].Header;
                cell.Style.Font.Bold = true;
                cell.Style.Fill.BackgroundColor = XLColor.FromHtml("#4472C4");
                cell.Style.Font.FontColor = XLColor.White;
                cell.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
            }

            // Data rows
            int row = 2;
            foreach (var item in data)
            {
                for (int col = 0; col < columns.Count; col++)
                {
                    var value = columns[col].ValueSelector(item);
                    var cell = worksheet.Cell(row, col + 1);

                    switch (value)
                    {
                        case null:
                            cell.Value = Blank.Value;
                            break;
                        case DateTime dt:
                            cell.Value = dt;
                            cell.Style.NumberFormat.Format = columns[col].NumberFormat ?? "dd/MM/yyyy";
                            break;
                        case decimal d:
                            cell.Value = d;
                            if (columns[col].NumberFormat != null)
                                cell.Style.NumberFormat.Format = columns[col].NumberFormat;
                            break;
                        case int i:
                            cell.Value = i;
                            break;
                        case char c:
                            cell.Value = c.ToString();
                            break;
                        default:
                            cell.Value = value.ToString();
                            break;
                    }
                }
                row++;
            }

            // Auto-fit columns
            worksheet.Columns().AdjustToContents();

            // Auto-filter on header row
            if (row > 2)
            {
                worksheet.Range(1, 1, row - 1, columns.Count).SetAutoFilter();
            }

            workbook.SaveAs(outputPath);

            _logger.LogInformation("Excel export completato: {FilePath} ({RowCount} righe)", outputPath, row - 2);

            return outputPath;
        });
    }
}
