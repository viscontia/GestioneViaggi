using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using IContainer = QuestPDF.Infrastructure.IContainer;
using Colors = QuestPDF.Helpers.Colors;

namespace GestioneViaggi.Services.Printing;

public static class ReportHeaderHelper
{
    // Define brand colors
    public static class BrandColors
    {
        public static readonly string Primary = "#2B3A42"; // Dark Slate
        public static readonly string Secondary = "#8D99AE"; // Cool Grey
        public static readonly string Accent = "#E74C3C";  // Red
        public static readonly string Text = "#000000";
        public static readonly string LightGray = "#F0F0F0";
        public static readonly string Border = "#CCCCCC";
    }

    // Define layout constants
    public const float FontSizeHeader = 18;
    public const float FontSizeSubHeader = 12;
    public const float FontSizeBody = 9;
    public const float FontSizeSmall = 8;
    
    public static void ComposeCompanyHeader(IContainer container, CompanyPrintInfo companyData, string reportTitle, DateTime? printDate = null, string? printUser = null, string? extraInfo = null)
    {
        container.Column(column =>
        {
            // 1. Riga Superiore: Logo/Azienda (Sinistra) + Info Stampa (Destra)
            column.Item().Row(row =>
            {
                // Sinistra: Logo/Azienda
                row.RelativeItem(2).Column(col =>
                {
                    if (companyData.LogoData != null && companyData.LogoData.Length > 0)
                    {
                        col.Item().MaxHeight(50).Image(companyData.LogoData).FitArea();
                    }
                    else
                    {
                        col.Item().Text(companyData.RagioneSociale)
                            .FontSize(20).Bold().FontColor(BrandColors.Primary);
                    }

                    var infoParts = new List<string>();
                    if (!string.IsNullOrEmpty(companyData.RagioneSociale)) infoParts.Add(companyData.RagioneSociale);
                    if (!string.IsNullOrEmpty(companyData.Piva)) infoParts.Add($"P.IVA: {companyData.Piva}");
                    if (!string.IsNullOrEmpty(companyData.Telefono)) infoParts.Add(companyData.Telefono);
                    // if (!string.IsNullOrEmpty(companyData.Email)) infoParts.Add(companyData.Email);

                    if (infoParts.Any())
                    {
                        col.Item().PaddingTop(2).Text(string.Join(" - ", infoParts)).FontSize(FontSizeSmall);
                    }
                });

                // Centro: Titolo Report
                row.RelativeItem(2).AlignCenter().Column(col => 
                {
                     col.Item().PaddingTop(10).Text(reportTitle).FontSize(16).Bold().FontColor(BrandColors.Primary);
                });

                // Destra: Info Stampa
                row.RelativeItem(1).AlignRight().Column(col =>
                {
                    var date = printDate ?? DateTime.Now;
                    col.Item().Text($"Data: {date:dd/MM/yyyy HH:mm}")
                        .FontSize(FontSizeSmall);
                    
                    if (!string.IsNullOrEmpty(printUser))
                    {
                        col.Item().Text($"Operatore: {printUser}")
                            .FontSize(FontSizeSmall);
                    }
                    
                    if (!string.IsNullOrEmpty(extraInfo))
                    {
                        col.Item().Text(extraInfo)
                            .FontSize(FontSizeSmall).Bold();
                    }
                });
            });
            
            // Divider
            column.Item().PaddingVertical(5).LineHorizontal(1).LineColor(Colors.Grey.Lighten2);
        });
    }

    public static void ComposeFooter(IContainer container)
    {
        container.Column(column =>
        {
            column.Item().LineHorizontal(0.5f).LineColor(BrandColors.Border);
            column.Item().PaddingTop(5).Row(row =>
            {
                row.RelativeItem().Text(x =>
                {
                    x.Span("Generato il ");
                    x.Span(DateTime.Now.ToString("dd/MM/yyyy HH:mm"));
                });
                
                row.RelativeItem().AlignRight().Text(x =>
                {
                    x.Span("Pag. ");
                    x.CurrentPageNumber();
                    x.Span(" di ");
                    x.TotalPages();
                });
            });
        });
    }
    
    // Helper Styles
    public static IContainer HeaderCellStyle(IContainer container)
    {
        return container
            .Border(1)
            .BorderColor(BrandColors.Border)
            .Background(BrandColors.LightGray)
            .Padding(5)
            .AlignMiddle()
            .AlignCenter();
    }

    public static IContainer BodyCellStyle(IContainer container)
    {
        return container
            .Border(1)
            .BorderColor(BrandColors.Border)
            .Padding(5)
            .AlignMiddle();
    }
}
