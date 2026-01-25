using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Microsoft.Maui.Storage;
using IContainer = QuestPDF.Infrastructure.IContainer;
using Colors = QuestPDF.Helpers.Colors;

namespace GestioneViaggi.Services.Printing;

public class ViaggiPrinter
{
    // Define brand colors
    private static class BrandColors
    {
        public static readonly string Primary = "#2B3A42"; // Dark Slate
        public static readonly string Secondary = "#8D99AE"; // Cool Grey
        public static readonly string Accent = "#E74C3C";  // Red
        public static readonly string Text = "#000000";
        public static readonly string LightGray = "#F0F0F0";
        public static readonly string Border = "#CCCCCC";
    }
    
    // Define layout constants
    private const float FontSizeHeader = 18;
    private const float FontSizeSubHeader = 12;
    private const float FontSizeBody = 9;
    private const float FontSizeSmall = 8;


    public static async Task GeneratePdfAsync(TravelPrintDTO data, string outputPath)
    {
        // Enable Debugging as requested by error message to visualize constraints if conflicts persist
        QuestPDF.Settings.EnableDebugging = false; 
        
        await PdfUtils.EnsureQuestPdfInitializedAsync();

        Document.Create(container =>
        {
            // COVER PAGE
            container.Page(page =>
            {
                page.Size(PageSizes.A4.Landscape());
                page.Margin(1, Unit.Centimetre);
                page.PageColor(QuestPDF.Helpers.Colors.White);
                page.DefaultTextStyle(x => x.FontSize(FontSizeBody).FontFamily("Lato").FontColor(BrandColors.Text));

                page.Content().Element(content => ComposeCover(content, data));
                page.Footer().Element(footer => ComposeFooter(footer));
            });

            // CONTENT PAGE(S) - Participants by Crew
            container.Page(page =>
            {
                page.Size(PageSizes.A4.Landscape());
                page.Margin(1, Unit.Centimetre);
                page.PageColor(QuestPDF.Helpers.Colors.White);
                page.DefaultTextStyle(x => x.FontSize(FontSizeBody).FontFamily("Lato").FontColor(BrandColors.Text));

                page.Header().Element(header => ComposePageHeader(header, data));
                page.Content().Element(content => ComposeContent(content, data.Participants));
                page.Footer().Element(footer => ComposeFooter(footer));
            });

            // VEHICLES PAGE - Pilots grouped by Vehicle Brand/Model
            if (data.VehicleGroups != null && data.VehicleGroups.Any())
            {
                container.Page(page =>
                {
                    page.Size(PageSizes.A4.Landscape());
                    page.Margin(1, Unit.Centimetre);
                    page.PageColor(QuestPDF.Helpers.Colors.White);
                    page.DefaultTextStyle(x => x.FontSize(FontSizeBody).FontFamily("Lato").FontColor(BrandColors.Text));

                    page.Header().Element(header => ComposePageHeader(header, data));
                    page.Content().Element(content => ComposeVehiclesPage(content, data.VehicleGroups));
                    page.Footer().Element(footer => ComposeFooter(footer));
                });
            }
        })
        .GeneratePdf(outputPath);
    }

    private static void ComposeCover(IContainer container, TravelPrintDTO data)
    {
        container.PaddingTop(20).Column(mainColumn =>
        {
             // TOP ROW: Title & Company Info
            mainColumn.Item().Row(row =>
            {
                // LEFT: Trip Title & Desc
                row.RelativeItem(3).Column(column =>
                {
                    // Title: Allow wrap, specific color. Ensure no height constraint.
                    column.Item().Text(data.Header.Titolo)
                        .FontSize(24).Bold().FontColor(BrandColors.Primary)
                        .LineHeight(1.1f);

                    if (!string.IsNullOrWhiteSpace(data.Header.Descrizione) && data.Header.Descrizione != data.Header.Titolo)
                    {
                         column.Item().PaddingTop(5).Text(data.Header.Descrizione).FontSize(14).Italic();
                    }
                });

                // RIGHT: Company Info & Logo
                row.RelativeItem(1).AlignRight().Column(column =>
                {
                    if (data.Company.LogoData != null && data.Company.LogoData.Length > 0)
                    {
                        column.Item().PaddingBottom(10).MaxHeight(60).AlignRight().Image(data.Company.LogoData).FitArea();
                    }
                    column.Item().AlignRight().Text(data.Company.RagioneSociale).FontSize(12).Bold();
                    
                    if(!string.IsNullOrEmpty(data.Company.Piva)) column.Item().AlignRight().Text($"P.IVA: {data.Company.Piva}").FontSize(10);
                    if(!string.IsNullOrEmpty(data.Company.Telefono)) column.Item().AlignRight().Text($"Tel: {data.Company.Telefono}").FontSize(10);
                    if(!string.IsNullOrEmpty(data.Company.Email)) column.Item().AlignRight().Text($"Email: {data.Company.Email}").FontSize(10);
                    if(!string.IsNullOrEmpty(data.Company.SitoWeb)) column.Item().AlignRight().Text(data.Company.SitoWeb).FontSize(10).FontColor(Colors.Blue.Medium);
                });
            });

            // DATES SECTION (Prominent display)
            mainColumn.Item().PaddingTop(25).Row(dateRow =>
            {
                dateRow.RelativeItem().Column(dc =>
                {
                    dc.Item().Text("Date del Viaggio:").FontSize(14).SemiBold().FontColor(BrandColors.Primary);
                    dc.Item().PaddingTop(3).Text(data.Header.DateFormatted).FontSize(18).Bold();
                });
            });

            // CHARACTERISTICS SECTION (Expanded Interlinear)
            mainColumn.Item().PaddingTop(20).Column(c =>
            {
                c.Item().PaddingBottom(10).Text("Caratteristiche del Viaggio:").FontSize(16).Bold().Underline();
                
                c.Item().Border(1).BorderColor(BrandColors.Accent).Row(r =>
                {
                    // LEFT: Details Table with Padding - increased space to prevent truncation
                    r.RelativeItem(4).Padding(10).Table(table =>
                    {
                        table.ColumnsDefinition(cols =>
                        {
                            cols.ConstantColumn(140);
                            cols.RelativeColumn();
                        });

                        void AddRow(string label, string val) {
                            // Increased vertical padding for better spacing
                            table.Cell().PaddingVertical(8).Text(label).SemiBold().FontSize(12);
                            table.Cell().PaddingVertical(8).Text(val).FontSize(12);
                        }

                        AddRow("Tipo del Viaggio:", data.Header.TipoViaggio);
                        AddRow("Luogo:", data.Header.Destinazione);
                        AddRow("N. Giorni/Notti:", $"{data.Header.Giorni}/{data.Header.Notti}");
                        AddRow("Trattamento Previsto:", data.Header.Trattamento);
                        AddRow("Pasti al sacco:", data.Header.PastiSacco ? "Si" : "No");
                        AddRow("Km. Viaggio:", data.Header.Km.ToString());
                    });

                    // RIGHT: Big Totals
                    r.RelativeItem(1).BorderLeft(1).BorderColor(BrandColors.Accent).Column(stats => 
                    {
                        void BigStat(IContainer cnt, string number, string label)
                        {
                            cnt.Column(statCol => 
                            {
                                statCol.Item().AlignCenter().Text(number).FontSize(36).Bold().FontColor(BrandColors.Text);
                                statCol.Item().AlignCenter().Text(label.ToUpper()).FontSize(12).SemiBold();
                            });
                        }

                        stats.Item().PaddingVertical(20).Element(e => BigStat(e, data.Header.TotalVehicles.ToString(), "MEZZI"));
                        stats.Item().BorderTop(1).BorderColor(BrandColors.Accent).PaddingVertical(20).Element(e => BigStat(e, data.Header.TotalParticipants.ToString(), "PERSONE"));
                    });
                });
            });
            
            // Note footer on cover
             if (!string.IsNullOrWhiteSpace(data.Header.Note))
            {
                mainColumn.Item().PaddingTop(20).BorderTop(1).BorderColor(Colors.Grey.Lighten2).PaddingTop(5).Text(text =>
                {
                    text.Span("Note: ").Bold();
                    text.Span(data.Header.Note).Italic();
                });
            }
        });
    }

     private static void ComposePageHeader(IContainer container, TravelPrintDTO data)
    {
        container.PaddingBottom(10).Row(row =>
        {
             row.RelativeItem().Column(c =>
             {
                c.Item().Text(data.Header.Titolo).FontSize(14).Bold().FontColor(BrandColors.Primary);
                c.Item().Text($"{data.Header.Destinazione} - {data.Header.DateFormatted}").FontSize(10).Italic();
             });
             
             if (data.Company.LogoData != null && data.Company.LogoData.Length > 0)
            {
                row.ConstantItem(100).AlignRight().MaxHeight(30).Image(data.Company.LogoData).FitArea();
            }
        });
    }

    private static void ComposeContent(IContainer container, List<ParticipantPrintInfo> participants)
    {
        container.Column(column =>
        {
            column.Item().Table(table =>
            {
                // Defined Columns for DETAILED Horizontal Crew Layout
                table.ColumnsDefinition(columns =>
                {
                    columns.ConstantColumn(25); // #
                    columns.RelativeColumn(3);  // Pilota
                    columns.RelativeColumn(3);  // Passeggeri
                    columns.RelativeColumn(3);  // Contatti (Pilota)
                    columns.RelativeColumn(3);  // Residenza (Pilota)
                    columns.RelativeColumn(3);  // Dati (Pilota)
                    columns.RelativeColumn(2);  // Mezzo
                    columns.RelativeColumn(2);  // Note
                });

                // Table Header (Multi-row)
                table.Header(header =>
                {
                    // Prima riga di header - con "Dati del Pilota" che spanna 3 colonne
                    header.Cell().RowSpan(2).Element(HeaderCellStyle).Text("#");
                    header.Cell().RowSpan(2).Element(HeaderCellStyle).Text("Pilota/Guida");
                    header.Cell().RowSpan(2).Element(HeaderCellStyle).Text("Passeggeri");
                    header.Cell().ColumnSpan(3).Element(HeaderCellStyle).AlignCenter().Text("Dati del Pilota/Guida").Bold();
                    header.Cell().RowSpan(2).Element(HeaderCellStyle).Text("Mezzo / Cane");
                    header.Cell().RowSpan(2).Element(HeaderCellStyle).Text("Note / Intolleranze");

                    // Seconda riga di header - solo per le 3 sottocolonne dei dati del pilota
                    header.Cell().Element(HeaderCellStyle).Text("Contatti");
                    header.Cell().Element(HeaderCellStyle).Text("Residenza");
                    header.Cell().Element(HeaderCellStyle).Text("Dati Personali");
                });

                // Group by Crew
                var crews = participants.GroupBy(p => p.GroupingKey)
                    .OrderBy(g =>  // Order: Crews with concrete Pilot first, by name
                    {
                        var pilot = g.FirstOrDefault(m => m.IsPilot) ?? g.FirstOrDefault(m => m.ClienteId == g.Key);
                        return pilot?.Nominativo ?? "ZZZZ";
                    }).ToList();

                int globalIndex = 1;

                foreach (var crew in crews)
                {
                    var members = crew.ToList();
                    var pilot = members.FirstOrDefault(m => m.IsPilot) ?? members.FirstOrDefault(m => m.ClienteId == m.GroupingKey);
                    var passengers = members.Where(m => m != pilot).OrderBy(m => m.Nominativo).ToList();

                    // ROW - ONE PER CREW
                    table.Cell().Element(BodyCellStyle).AlignCenter().Text(globalIndex.ToString()).FontSize(FontSizeSmall);

                    // Pilota/Guida
                    table.Cell().Element(BodyCellStyle).Text(text =>
                    {
                        if (pilot != null)
                        {
                            bool isGuida = pilot.Ruolo.Contains("Guida", StringComparison.OrdinalIgnoreCase);
                            bool isGuidaInSeconda = pilot.Ruolo.Contains("Seconda", StringComparison.OrdinalIgnoreCase);

                            if (isGuida)
                            {
                                text.Span(pilot.Nominativo).Bold().FontColor(BrandColors.Accent);
                                text.Span(isGuidaInSeconda ? " (GS)" : " (G)").FontColor(BrandColors.Accent);
                            }
                            else
                            {
                                text.Span(pilot.Nominativo).Bold();
                            }

                            if (pilot.CaneSino == "Y" || pilot.CaneSino == "S")
                            {
                                text.Span(" [CANE]").FontColor(BrandColors.Accent).Bold();
                            }
                        }
                        else
                        {
                            text.Span("N/D").Italic().FontColor(Colors.Grey.Medium);
                        }
                    });

                    // Passeggeri (Horizontal list in cell)
                    table.Cell().Element(BodyCellStyle).Text(text =>
                    {
                        if (passengers.Any())
                        {
                            for (int i = 0; i < passengers.Count; i++)
                            {
                                var p = passengers[i];
                                text.Span(p.Nominativo);
                                if (p.CaneSino == "Y" || p.CaneSino == "S")
                                {
                                    text.Span(" [CANE]").FontColor(BrandColors.Accent).Bold();
                                }
                                if (i < passengers.Count - 1) text.Span(", ");
                            }
                        }
                        else
                        {
                           text.Span("-").FontColor(Colors.Grey.Lighten1);
                        }
                    });

                    // Contatti (Pilota Only)
                    table.Cell().Element(BodyCellStyle).Text(text => 
                    {
                         if(pilot != null)
                         {
                             if(!string.IsNullOrEmpty(pilot.Telefono)) text.Line(pilot.Telefono).FontSize(FontSizeSmall);
                             if(!string.IsNullOrEmpty(pilot.Email)) text.Span(pilot.Email).FontSize(FontSizeSmall).FontColor(Colors.Blue.Medium);
                         }
                    });

                    // Residenza (Pilota Only)
                    table.Cell().Element(BodyCellStyle).Text(pilot?.Residenza ?? "").FontSize(FontSizeSmall);

                    // Dati Personali (Pilota Only)
                    table.Cell().Element(BodyCellStyle).Text(text => 
                    {
                        if(pilot != null)
                        {
                            if(!string.IsNullOrEmpty(pilot.CodiceFiscale)) text.Line(pilot.CodiceFiscale).FontSize(FontSizeSmall).Bold();
                            text.Span(pilot.LuogoDataNascitaFormatted).FontSize(FontSizeSmall);
                        }
                    });

                    // Mezzo (Combined or Pilot's)
                    var vehicleInfo = pilot?.MezzoDettagli ?? members.FirstOrDefault(m => !string.IsNullOrEmpty(m.MezzoDettagli))?.MezzoDettagli ?? "";
                    table.Cell().Element(BodyCellStyle).Text(vehicleInfo).FontSize(8);

                    // Note (Combined)
                    var allNotes = members.Where(m => !string.IsNullOrWhiteSpace(m.Note)).Select(m => $"{m.Nominativo}: {m.Note}");
                    var allIntolerance = members.Where(m => !string.IsNullOrWhiteSpace(m.Intolleranze)).Select(m => $"[!] {m.Nominativo}: {m.Intolleranze}");
                    var combinedNotes = string.Join("\n", allIntolerance.Concat(allNotes));

                    table.Cell().Element(BodyCellStyle).Text(combinedNotes).FontSize(8).FontColor(BrandColors.Accent);

                    globalIndex++;
                }
            });
        });
    }

    private static void ComposeVehiclesPage(IContainer container, List<VehicleGroupInfo> vehicleGroups)
    {
        container.Column(column =>
        {
            column.Item().PaddingBottom(10).Text("Piloti raggruppati per Veicolo")
                .FontSize(16).Bold().FontColor(BrandColors.Primary);

            foreach (var group in vehicleGroups)
            {
                // Group Header with Count
                column.Item().PaddingTop(15).PaddingBottom(5)
                    .Background(BrandColors.LightGray)
                    .Border(1).BorderColor(BrandColors.Accent)
                    .Padding(8)
                    .Text(group.DisplayName)
                    .FontSize(14).Bold().FontColor(BrandColors.Accent);

                // Pilots Table for this group
                column.Item().Table(table =>
                {
                    table.ColumnsDefinition(columns =>
                    {
                        columns.ConstantColumn(25); // #
                        columns.RelativeColumn(2);  // Nominativo
                        columns.RelativeColumn(2);  // Contatti
                        columns.RelativeColumn(2);  // Residenza
                        columns.RelativeColumn(2);  // Dati Personali
                        columns.RelativeColumn(1);  // Targa
                    });

                    // Table Header
                    table.Header(header =>
                    {
                        header.Cell().Element(HeaderCellStyle).Text("#");
                        header.Cell().Element(HeaderCellStyle).Text("Pilota");
                        header.Cell().Element(HeaderCellStyle).Text("Contatti");
                        header.Cell().Element(HeaderCellStyle).Text("Residenza");
                        header.Cell().Element(HeaderCellStyle).Text("Dati Personali");
                        header.Cell().Element(HeaderCellStyle).Text("Targa");
                    });

                    int index = 1;
                    foreach (var pilot in group.Pilots)
                    {
                        // Row for each pilot
                        table.Cell().Element(BodyCellStyle).AlignCenter().Text(index.ToString()).FontSize(FontSizeSmall);

                        table.Cell().Element(BodyCellStyle).Text(pilot.Nominativo).Bold();

                        table.Cell().Element(BodyCellStyle).Text(text =>
                        {
                            if (!string.IsNullOrEmpty(pilot.Telefono)) text.Line(pilot.Telefono).FontSize(FontSizeSmall);
                            if (!string.IsNullOrEmpty(pilot.Email)) text.Span(pilot.Email).FontSize(FontSizeSmall).FontColor(Colors.Blue.Medium);
                        });

                        table.Cell().Element(BodyCellStyle).Text(pilot.Residenza).FontSize(FontSizeSmall);

                        table.Cell().Element(BodyCellStyle).Text(text =>
                        {
                            if (!string.IsNullOrEmpty(pilot.CodiceFiscale)) text.Line(pilot.CodiceFiscale).FontSize(FontSizeSmall).Bold();
                            text.Span(pilot.LuogoDataNascitaFormatted).FontSize(FontSizeSmall);
                        });

                        table.Cell().Element(BodyCellStyle).Text(pilot.Targa).FontSize(FontSizeSmall);

                        index++;
                    }
                });
            }
        });
    }

    private static IContainer HeaderCellStyle(IContainer container)
    {
        return container
            .Border(1)
            .BorderColor(BrandColors.Border)
            .Background(BrandColors.LightGray)
            .Padding(5)
            .AlignMiddle()
            .AlignCenter();
    }

    private static IContainer BodyCellStyle(IContainer container)
    {
        return container
            .Border(1)
            .BorderColor(BrandColors.Border)
            .Padding(5)
            .AlignMiddle();
    }

    private static void ComposeFooter(IContainer container)
    {
        container.PaddingTop(10).Column(column =>
        {
            column.Item().LineHorizontal(0.5f).LineColor(BrandColors.Border);
            column.Item().PaddingTop(5).Row(row =>
            {
                row.RelativeItem().Text(x =>
                {
                    x.Span("Generato il ");
                    x.Span(DateTime.Now.ToString("dd/MM/yyyy HH:mm")).Bold();
                });
                
                row.RelativeItem().AlignRight().Text(x =>
                {
                    x.CurrentPageNumber();
                    x.Span(" / ");
                    x.TotalPages();
                });
            });
        });
    }
}

public static class PdfUtils
{
    private static bool _questPdfInitialized = false;
    private static readonly SemaphoreSlim _initLock = new SemaphoreSlim(1, 1);

    public static async Task EnsureQuestPdfInitializedAsync()
    {
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
                }
            }
            
            _questPdfInitialized = true;
        }
        finally
        {
            _initLock.Release();
        }
    }
}
