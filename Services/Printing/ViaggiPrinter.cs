using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Microsoft.Maui.Storage;
using IContainer = QuestPDF.Infrastructure.IContainer;
using Colors = QuestPDF.Helpers.Colors;

namespace GestioneViaggi.Services.Printing;

public class ViaggiPrinter
{


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
                page.DefaultTextStyle(x => x.FontSize(ReportHeaderHelper.FontSizeBody).FontFamily("Lato").FontColor(ReportHeaderHelper.BrandColors.Text));

                page.Content().Element(content => ComposeCover(content, data));
                page.Footer().Element(footer => ComposeFooter(footer));
            });

            // CONTENT PAGE(S) - Participants by Crew
            container.Page(page =>
            {
                page.Size(PageSizes.A4.Landscape());
                page.Margin(1, Unit.Centimetre);
                page.PageColor(QuestPDF.Helpers.Colors.White);
                page.DefaultTextStyle(x => x.FontSize(ReportHeaderHelper.FontSizeBody).FontFamily("Lato").FontColor(ReportHeaderHelper.BrandColors.Text));

                page.Header().Element(header => ComposePageHeader(header, data));
                page.Content().Column(colonna =>
                {
                    colonna.Item().Element(content => ComposeContent(content, data.Participants));
                    colonna.Item().Element(nota => NotaDocumentiPdf.Componi(nota, data.DocumentiDaSistemare));
                });
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
                    page.DefaultTextStyle(x => x.FontSize(ReportHeaderHelper.FontSizeBody).FontFamily("Lato").FontColor(ReportHeaderHelper.BrandColors.Text));

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
                        .FontSize(24).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary)
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
            mainColumn.Item().PaddingTop(15).Row(dateRow =>
            {
                dateRow.RelativeItem().Column(dc =>
                {
                    dc.Item().Text("Date del Viaggio:").FontSize(14).SemiBold().FontColor(ReportHeaderHelper.BrandColors.Primary);
                    dc.Item().PaddingTop(3).Text(data.Header.DateFormatted).FontSize(18).Bold();
                });
            });

            // CHARACTERISTICS SECTION (Expanded Interlinear) - Reduced padding to fit on one page
            mainColumn.Item().PaddingTop(12).Column(c =>
            {
                c.Item().PaddingBottom(8).Text("Caratteristiche del Viaggio:").FontSize(16).Bold().Underline();

                c.Item().Border(1).BorderColor(ReportHeaderHelper.BrandColors.Accent).Row(r =>
                {
                    // LEFT: Details Table with Padding - reduced to prevent page break
                    r.RelativeItem(4).Padding(8).Table(table =>
                    {
                        table.ColumnsDefinition(cols =>
                        {
                            cols.ConstantColumn(140);
                            cols.RelativeColumn();
                        });

                        void AddRow(string label, string val) {
                            // Reduced vertical padding to fit on one page
                            table.Cell().PaddingVertical(5).Text(label).SemiBold().FontSize(12);
                            table.Cell().PaddingVertical(5).Text(val).FontSize(12);
                        }

                        AddRow("Tipo del Viaggio:", data.Header.TipoViaggio);
                        AddRow("Luogo:", data.Header.Destinazione);
                        AddRow("N. Giorni/Notti:", $"{data.Header.Giorni}/{data.Header.Notti}");
                        AddRow("Trattamento Previsto:", data.Header.Trattamento);
                        AddRow("Pasti al sacco:", data.Header.PastiSacco ? "Si" : "No");
                        AddRow("Km. Viaggio:", data.Header.Km.ToString());
                    });

                    // RIGHT: Big Totals
                    r.RelativeItem(1).BorderLeft(1).BorderColor(ReportHeaderHelper.BrandColors.Accent).Column(stats =>
                    {
                        void BigStat(IContainer cnt, string number, string label)
                        {
                            cnt.Column(statCol =>
                            {
                                statCol.Item().AlignCenter().Text(number).FontSize(36).Bold().FontColor(ReportHeaderHelper.BrandColors.Text);
                                statCol.Item().AlignCenter().Text(label.ToUpper()).FontSize(12).SemiBold();
                            });
                        }

                        stats.Item().PaddingVertical(15).Element(e => BigStat(e, data.Header.TotalVehicles.ToString(), "MEZZI"));
                        stats.Item().BorderTop(1).BorderColor(ReportHeaderHelper.BrandColors.Accent).PaddingVertical(15).Element(e => BigStat(e, data.Header.TotalParticipants.ToString(), "PERSONE"));
                    });
                });
            });
            
            // Note footer on cover
             if (!string.IsNullOrWhiteSpace(data.Header.Note))
            {
                mainColumn.Item().PaddingTop(15).BorderTop(1).BorderColor(Colors.Grey.Lighten2).PaddingTop(5).Text(text =>
                {
                    text.Span("Note: ").Bold();
                    text.Span(data.Header.Note).Italic();
                });
            }
        });
    }

     private static void ComposePageHeader(IContainer container, TravelPrintDTO data)
    {
        ReportHeaderHelper.ComposeCompanyHeader(
            container,
            data.Company,
            data.Header.Titolo,
            DateTime.Now,
            null,
            $"{data.Header.Destinazione} - {data.Header.DateFormatted}"
        );
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
                    table.Cell().Element(BodyCellStyle).ShowEntire().AlignCenter().Text(globalIndex.ToString()).FontSize(ReportHeaderHelper.FontSizeSmall);

                    // Pilota/Guida
                    table.Cell().Element(BodyCellStyle).ShowEntire().Text(text =>
                    {
                        if (pilot != null)
                        {
                            bool isGuida = pilot.Ruolo.Contains("Guida", StringComparison.OrdinalIgnoreCase);
                            bool isGuidaInSeconda = pilot.Ruolo.Contains("Seconda", StringComparison.OrdinalIgnoreCase);

                            if (isGuida)
                            {
                                text.Span(pilot.Nominativo).Bold().FontColor(ReportHeaderHelper.BrandColors.Accent);
                                text.Span(isGuidaInSeconda ? " (GS)" : " (G)").FontColor(ReportHeaderHelper.BrandColors.Accent);
                            }
                            else
                            {
                                text.Span(pilot.Nominativo).Bold();
                            }

                            if (pilot.CaneSino == "Y" || pilot.CaneSino == "S")
                            {
                                text.Span(" [CANE]").FontColor(ReportHeaderHelper.BrandColors.Accent).Bold();
                            }
                        }
                        else
                        {
                            text.Span("N/D").Italic().FontColor(Colors.Grey.Medium);
                        }
                    });

                    // Passeggeri (Horizontal list in cell)
                    table.Cell().Element(BodyCellStyle).ShowEntire().Text(text =>
                    {
                        if (passengers.Any())
                        {
                            for (int i = 0; i < passengers.Count; i++)
                            {
                                var p = passengers[i];
                                text.Span(p.Nominativo);
                                if (p.CaneSino == "Y" || p.CaneSino == "S")
                                {
                                    text.Span(" [CANE]").FontColor(ReportHeaderHelper.BrandColors.Accent).Bold();
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
                    table.Cell().Element(BodyCellStyle).ShowEntire().Text(text => 
                    {
                         if(pilot != null)
                         {
                             if(!string.IsNullOrEmpty(pilot.Telefono)) text.Line(pilot.Telefono).FontSize(ReportHeaderHelper.FontSizeSmall);
                             if(!string.IsNullOrEmpty(pilot.Email)) text.Span(pilot.Email).FontSize(ReportHeaderHelper.FontSizeSmall).FontColor(Colors.Blue.Medium);
                         }
                    });

                    // Residenza (Pilota Only)
                    table.Cell().Element(BodyCellStyle).ShowEntire().Text(pilot?.Residenza ?? "").FontSize(ReportHeaderHelper.FontSizeSmall);

                    // Dati Personali (Pilota Only)
                    table.Cell().Element(BodyCellStyle).ShowEntire().Text(text => 
                    {
                        if(pilot != null)
                        {
                            if(!string.IsNullOrEmpty(pilot.CodiceFiscale)) text.Line(pilot.CodiceFiscale).FontSize(ReportHeaderHelper.FontSizeSmall).Bold();
                            text.Span(pilot.LuogoDataNascitaFormatted).FontSize(ReportHeaderHelper.FontSizeSmall);
                        }
                    });

                    // Mezzo (Combined or Pilot's)
                    var vehicleInfo = pilot?.MezzoDettagli ?? members.FirstOrDefault(m => !string.IsNullOrEmpty(m.MezzoDettagli))?.MezzoDettagli ?? "";
                    table.Cell().Element(BodyCellStyle).ShowEntire().Text(vehicleInfo).FontSize(8);

                    // Note (Combined)
                    var allNotes = members.Where(m => !string.IsNullOrWhiteSpace(m.Note)).Select(m => $"{m.Nominativo}: {m.Note}");
                    var allIntolerance = members.Where(m => !string.IsNullOrWhiteSpace(m.Intolleranze)).Select(m => $"[!] {m.Nominativo}: {m.Intolleranze}");
                    var combinedNotes = string.Join("\n", allIntolerance.Concat(allNotes));

                    table.Cell().Element(BodyCellStyle).ShowEntire().Text(combinedNotes).FontSize(8).FontColor(ReportHeaderHelper.BrandColors.Accent);

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
                .FontSize(16).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);

            foreach (var group in vehicleGroups)
            {
                // Group Header with Count
                column.Item().PaddingTop(15).PaddingBottom(5)
                    .Background(ReportHeaderHelper.BrandColors.LightGray)
                    .Border(1).BorderColor(ReportHeaderHelper.BrandColors.Accent)
                    .Padding(8)
                    .Text(group.DisplayName)
                    .FontSize(14).Bold().FontColor(ReportHeaderHelper.BrandColors.Accent);

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
                        table.Cell().Element(BodyCellStyle).AlignCenter().Text(index.ToString()).FontSize(ReportHeaderHelper.FontSizeSmall);

                        table.Cell().Element(BodyCellStyle).Text(pilot.Nominativo).Bold();

                        table.Cell().Element(BodyCellStyle).Text(text =>
                        {
                            if (!string.IsNullOrEmpty(pilot.Telefono)) text.Line(pilot.Telefono).FontSize(ReportHeaderHelper.FontSizeSmall);
                            if (!string.IsNullOrEmpty(pilot.Email)) text.Span(pilot.Email).FontSize(ReportHeaderHelper.FontSizeSmall).FontColor(Colors.Blue.Medium);
                        });

                        table.Cell().Element(BodyCellStyle).Text(pilot.Residenza).FontSize(ReportHeaderHelper.FontSizeSmall);

                        table.Cell().Element(BodyCellStyle).Text(text =>
                        {
                            if (!string.IsNullOrEmpty(pilot.CodiceFiscale)) text.Line(pilot.CodiceFiscale).FontSize(ReportHeaderHelper.FontSizeSmall).Bold();
                            text.Span(pilot.LuogoDataNascitaFormatted).FontSize(ReportHeaderHelper.FontSizeSmall);
                        });

                        table.Cell().Element(BodyCellStyle).Text(pilot.Targa).FontSize(ReportHeaderHelper.FontSizeSmall);

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
            .BorderColor(ReportHeaderHelper.BrandColors.Border)
            .Background(ReportHeaderHelper.BrandColors.LightGray)
            .Padding(5)
            .AlignMiddle()
            .AlignCenter();
    }

    private static IContainer BodyCellStyle(IContainer container)
    {
        return container
            .Border(1)
            .BorderColor(ReportHeaderHelper.BrandColors.Border)
            .Padding(5)
            .AlignMiddle();
    }

    private static void ComposeFooter(IContainer container)
    {
        ReportHeaderHelper.ComposeFooter(container);
    }
    public static async Task GenerateDetailedPdfAsync(TravelPrintDTO data, string outputPath)
    {
        QuestPDF.Settings.EnableDebugging = false;
        await PdfUtils.EnsureQuestPdfInitializedAsync();

        Document.Create(container =>
        {
            // COVER PAGE (Identical)
            container.Page(page =>
            {
                page.Size(PageSizes.A4.Landscape());
                page.Margin(1, Unit.Centimetre);
                page.PageColor(QuestPDF.Helpers.Colors.White);
                page.DefaultTextStyle(x => x.FontSize(ReportHeaderHelper.FontSizeBody).FontFamily("Lato").FontColor(ReportHeaderHelper.BrandColors.Text));

                page.Content().Element(content => ComposeCover(content, data));
                page.Footer().Element(footer => ComposeFooter(footer));
            });

            // CONTENT PAGE(S) - Detailed Participants List
            container.Page(page =>
            {
                page.Size(PageSizes.A4.Landscape());
                page.Margin(1, Unit.Centimetre);
                page.PageColor(QuestPDF.Helpers.Colors.White);
                page.DefaultTextStyle(x => x.FontSize(ReportHeaderHelper.FontSizeBody).FontFamily("Lato").FontColor(ReportHeaderHelper.BrandColors.Text));

                page.Header().Element(header => ComposePageHeader(header, data));
                page.Content().Column(colonna =>
                {
                    colonna.Item().Element(content => ComposeDetailedContent(content, data.Participants));
                    colonna.Item().Element(nota => NotaDocumentiPdf.Componi(nota, data.DocumentiDaSistemare));
                });
                page.Footer().Element(footer => ComposeFooter(footer));
            });
        })
        .GeneratePdf(outputPath);
    }

    private static void ComposeDetailedContent(IContainer container, List<ParticipantPrintInfo> participants)
    {
        container.Column(column =>
        {
             column.Item().PaddingBottom(10).Text("Elenco Partecipanti Dettagliato")
                .FontSize(16).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);

            // Group by Crew
            var crews = participants.GroupBy(p => p.GroupingKey)
                .OrderBy(g =>
                {
                    var pilot = g.FirstOrDefault(m => m.IsPilot) ?? g.FirstOrDefault(m => m.ClienteId == g.Key);
                    return pilot?.Nominativo ?? "ZZZZ";
                }).ToList();

            foreach (var crew in crews)
            {
                var members = crew.ToList();
                var pilot = members.FirstOrDefault(m => m.IsPilot) ?? members.FirstOrDefault(m => m.ClienteId == m.GroupingKey);
                var passengers = members.Where(m => m != pilot).OrderBy(m => m.Nominativo).ToList();

                column.Item().BorderBottom(1).BorderColor(Colors.Grey.Lighten2).PaddingVertical(10)
                .Row(row => 
                {
                    row.RelativeItem().Column(c => 
                    {
                        // PILOTA
                        if(pilot != null)
                        {
                            c.Item().ShowEntire().Column(pilotCol => 
                            {
                                pilotCol.Item().PaddingBottom(2).Text(text => 
                                {
                                    text.Span("Pilota: ").Bold();
                                    text.Span(pilot.Nominativo).Bold().FontSize(11).FontColor(ReportHeaderHelper.BrandColors.Primary);
                                    if(pilot.DataNascita.HasValue)
                                    {
                                        var age = DateTime.Today.Year - pilot.DataNascita.Value.Year;
                                        if (pilot.DataNascita.Value.Date > DateTime.Today.AddYears(-age)) age--;
                                        text.Span($" ({age} Anni)");
                                    }
                                });

                                 // Pilot Details Line 1: Tel, Email, CF
                                pilotCol.Item().Text(text => 
                                {
                                    if(!string.IsNullOrEmpty(pilot.Telefono)) text.Span($"Telefono: {pilot.Telefono}   ");
                                    if(!string.IsNullOrEmpty(pilot.Email)) text.Span($"Email: {pilot.Email}   ");
                                    if(!string.IsNullOrEmpty(pilot.CodiceFiscale)) text.Span($"Codice Fiscale: {pilot.CodiceFiscale}");
                                });

                                // Pilot Details Line 2: Residenza
                                if(!string.IsNullOrEmpty(pilot.Residenza))
                                {
                                    pilotCol.Item().Text($"Residenza: {pilot.Residenza}");
                                }

                                // Pilot Details Line 3: Nato a
                                if(!string.IsNullOrEmpty(pilot.LuogoDataNascitaFormatted))
                                {
                                   pilotCol.Item().Text(text => 
                                    {
                                        text.Span("Nato a: ");
                                        text.Span(pilot.LuogoDataNascitaFormatted.Replace("\n", " in Data: "));
                                    });
                                }
                                
                                // DOCUMENT DETAILS
                                if(!string.IsNullOrEmpty(pilot.TipoDocumento) || !string.IsNullOrEmpty(pilot.NumeroDocumento))
                                {
                                    pilotCol.Item().PaddingTop(2).Text(text => 
                                    {
                                        text.Span("Documento: ").Bold();
                                        text.Span($"{pilot.TipoDocumento} nr. {pilot.NumeroDocumento}");
                                        if(pilot.DataScadenza.HasValue) text.Span($" Scad. {pilot.DataScadenzaFormatted}");
                                        if(!string.IsNullOrEmpty(pilot.Nazionalita)) text.Span($" ({pilot.Nazionalita})");
                                    });
                                }

                                // Pilot Vehicle & Dog
                                var veh = pilot.MezzoDettagli;
                                if(!string.IsNullOrEmpty(veh)) pilotCol.Item().PaddingTop(2).Text($"Mezzo: {veh}").Italic();
                                if(pilot.CaneSino == "Y" || pilot.CaneSino == "S") pilotCol.Item().Text("Cane: SI").Bold().FontColor(ReportHeaderHelper.BrandColors.Accent);
                            });
                        }

                        // PASSEGGERI
                        foreach(var pax in passengers)
                        {
                             c.Item().ShowEntire().PaddingTop(10).PaddingLeft(20).Column(pc => 
                             {
                                pc.Item().Text(text => 
                                {
                                    text.Span("Accompagnatore: ").Bold();
                                    text.Span(pax.Nominativo).SemiBold().FontSize(10);
                                     if(pax.DataNascita.HasValue)
                                    {
                                        var age = DateTime.Today.Year - pax.DataNascita.Value.Year;
                                        if (pax.DataNascita.Value.Date > DateTime.Today.AddYears(-age)) age--;
                                        text.Span($" ({age} Anni)");
                                    }
                                });

                                // Pax Details
                                pc.Item().Text(text => 
                                {
                                    if(!string.IsNullOrEmpty(pax.Telefono)) text.Span($"Telefono: {pax.Telefono}   ");
                                    if(!string.IsNullOrEmpty(pax.Email)) text.Span($"Email: {pax.Email}   ");
                                    if(!string.IsNullOrEmpty(pax.CodiceFiscale)) text.Span($"Codice Fiscale: {pax.CodiceFiscale}");
                                });

                                // Pax Residenza & Nato a
                                if(!string.IsNullOrEmpty(pax.Residenza)) pc.Item().Text($"Residenza: {pax.Residenza}");
                                 if(!string.IsNullOrEmpty(pax.LuogoDataNascitaFormatted))
                                {
                                    pc.Item().Text(text => 
                                    {
                                        text.Span("Nato a: ");
                                        text.Span(pax.LuogoDataNascitaFormatted.Replace("\n", " in Data: "));
                                    });
                                }

                                // Pax Document
                                if(!string.IsNullOrEmpty(pax.TipoDocumento) || !string.IsNullOrEmpty(pax.NumeroDocumento))
                                {
                                    pc.Item().PaddingTop(1).Text(text => 
                                    {
                                        text.Span("Documento: ").Bold();
                                        text.Span($"{pax.TipoDocumento} nr. {pax.NumeroDocumento}");
                                        if(pax.DataScadenza.HasValue) text.Span($" Scad. {pax.DataScadenzaFormatted}");
                                        if(!string.IsNullOrEmpty(pax.Nazionalita)) text.Span($" ({pax.Nazionalita})");
                                    });
                                }
                                
                                if(pax.CaneSino == "Y" || pax.CaneSino == "S") pc.Item().Text("Cane: SI").Bold().FontColor(ReportHeaderHelper.BrandColors.Accent);
                             });
                        }
                    });
                });
            }
        });
    }
}

public static class PdfUtils
{
    private static bool _questPdfInitialized = false;
    private static readonly SemaphoreSlim _initLock = new SemaphoreSlim(1, 1);

    /// <summary>
    /// Test diagnostico per identificare dove fallisce QuestPDF su Mac Catalyst.
    /// Ritorna un messaggio che indica quale step ha fallito.
    /// </summary>
    public static async Task<string> RunDiagnosticTestAsync()
    {
        var results = new System.Text.StringBuilder();
        results.AppendLine("=== DIAGNOSTIC TEST QUESTPDF ===");

        try
        {
            // STEP 1: Base QuestPDF Settings
            results.AppendLine("STEP 1: Inizializzazione base QuestPDF...");
            QuestPDF.Settings.License = LicenseType.Community;
            QuestPDF.Settings.CheckIfAllTextGlyphsAreAvailable = false;
            results.AppendLine("✓ STEP 1: OK - QuestPDF Settings configurati");
        }
        catch (Exception ex)
        {
            results.AppendLine($"✗ STEP 1: FAILED - {ex.GetType().Name}: {ex.Message}");
            return results.ToString();
        }

        try
        {
            // STEP 2: Font Loading
            results.AppendLine("STEP 2: Caricamento font custom...");
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
                    results.AppendLine($"  ✓ Font caricato: {font}");
                }
                catch (Exception fontEx)
                {
                    results.AppendLine($"  ✗ Font fallito: {font} - {fontEx.GetType().Name}: {fontEx.Message}");
                    throw; // Re-throw per catturare nel blocco esterno
                }
            }
            results.AppendLine("✓ STEP 2: OK - Tutti i font caricati");
        }
        catch (Exception ex)
        {
            results.AppendLine($"✗ STEP 2: FAILED - {ex.GetType().Name}: {ex.Message}");
            if (ex.InnerException != null)
                results.AppendLine($"  Inner: {ex.InnerException.GetType().Name}: {ex.InnerException.Message}");
            return results.ToString();
        }

        try
        {
            // STEP 3: Minimal Document Creation
            results.AppendLine("STEP 3: Creazione documento minimale...");
            var testPath = Path.Combine(Path.GetTempPath(), "questpdf_test.pdf");

            Document.Create(container =>
            {
                container.Page(page =>
                {
                    page.Size(PageSizes.A4);
                    page.Margin(1, Unit.Centimetre);
                    page.Content().Text("Test Document").FontSize(12);
                });
            }).GeneratePdf(testPath);

            results.AppendLine($"✓ STEP 3: OK - PDF generato: {testPath}");

            // Cleanup
            if (File.Exists(testPath))
                File.Delete(testPath);
        }
        catch (Exception ex)
        {
            results.AppendLine($"✗ STEP 3: FAILED - {ex.GetType().Name}: {ex.Message}");
            if (ex.InnerException != null)
                results.AppendLine($"  Inner: {ex.InnerException.GetType().Name}: {ex.InnerException.Message}");
            return results.ToString();
        }

        results.AppendLine("=== TUTTI I TEST PASSATI ===");
        return results.ToString();
    }

    /// <summary>
    /// Test diagnostico avanzato per identificare dove fallisce nel recupero dati stampa.
    /// Testa: Dapper, JSON deserialization, LINQ GroupBy
    /// </summary>
    public static async Task<string> RunDataRetrievalTestAsync(GestioneViaggi.Services.Database.IDatabaseConnectionManager connectionManager)
    {
        var results = new System.Text.StringBuilder();
        results.AppendLine("=== DIAGNOSTIC TEST DATA RETRIEVAL ===");

        try
        {
            // STEP 4: Database Connection
            results.AppendLine("STEP 4: Test connessione database...");
            await using var conn = await connectionManager.GetConnectionAsync();
            results.AppendLine($"✓ STEP 4: OK - Connessione DB aperta");
        }
        catch (Exception ex)
        {
            results.AppendLine($"✗ STEP 4: FAILED - {ex.GetType().Name}: {ex.Message}");
            if (ex.InnerException != null)
                results.AppendLine($"  Inner: {ex.InnerException.GetType().Name}: {ex.InnerException.Message}");
            return results.ToString();
        }

        try
        {
            // STEP 5: Npgsql Query (Simple)
            results.AppendLine("STEP 5: Test Npgsql query semplice...");
            await using var conn = await connectionManager.GetConnectionAsync();
            await using var cmd = new Npgsql.NpgsqlCommand("SELECT 1", (Npgsql.NpgsqlConnection)conn);
            var simpleResult = await cmd.ExecuteScalarAsync();
            results.AppendLine($"✓ STEP 5: OK - Npgsql query semplice: {simpleResult}");
        }
        catch (Exception ex)
        {
            results.AppendLine($"✗ STEP 5: FAILED - {ex.GetType().Name}: {ex.Message}");
            if (ex.InnerException != null)
                results.AppendLine($"  Inner: {ex.InnerException.GetType().Name}: {ex.InnerException.Message}");
            return results.ToString();
        }

        try
        {
            // STEP 6: Npgsql Query with Parameters
            results.AppendLine("STEP 6: Test Npgsql query con parametri...");
            await using var conn = await connectionManager.GetConnectionAsync();
            await using var cmd = new Npgsql.NpgsqlCommand("SELECT @value", (Npgsql.NpgsqlConnection)conn);
            cmd.Parameters.AddWithValue("value", 42);
            var paramResult = await cmd.ExecuteScalarAsync();
            results.AppendLine($"✓ STEP 6: OK - Npgsql query parametrica: {paramResult}");
        }
        catch (Exception ex)
        {
            results.AppendLine($"✗ STEP 6: FAILED - {ex.GetType().Name}: {ex.Message}");
            if (ex.InnerException != null)
                results.AppendLine($"  Inner: {ex.InnerException.GetType().Name}: {ex.InnerException.Message}");
            // Non return - continua con i test
        }

        try
        {
            // STEP 7: JSON Deserialization
            results.AppendLine("STEP 7: Test deserializzazione JSON...");
            var testJson = "{\"name\":\"Test\",\"value\":123}";
            var testObj = System.Text.Json.JsonSerializer.Deserialize<TestJsonClass>(testJson);
            results.AppendLine($"✓ STEP 7: OK - JSON deserializzato: {testObj?.Name}, {testObj?.Value}");
        }
        catch (Exception ex)
        {
            results.AppendLine($"✗ STEP 7: FAILED - {ex.GetType().Name}: {ex.Message}");
            if (ex.InnerException != null)
                results.AppendLine($"  Inner: {ex.InnerException.GetType().Name}: {ex.InnerException.Message}");
            return results.ToString();
        }

        try
        {
            // STEP 8: LINQ GroupBy (Simple)
            results.AppendLine("STEP 8: Test LINQ GroupBy semplice...");
            var testData = new[] {
                new { Category = "A", Value = 1 },
                new { Category = "B", Value = 2 },
                new { Category = "A", Value = 3 }
            };
            var grouped = testData.GroupBy(x => x.Category).Select(g => new { Category = g.Key, Count = g.Count() }).ToList();
            results.AppendLine($"✓ STEP 8: OK - LINQ GroupBy: {grouped.Count} gruppi");
        }
        catch (Exception ex)
        {
            results.AppendLine($"✗ STEP 8: FAILED - {ex.GetType().Name}: {ex.Message}");
            if (ex.InnerException != null)
                results.AppendLine($"  Inner: {ex.InnerException.GetType().Name}: {ex.InnerException.Message}");
            return results.ToString();
        }

        try
        {
            // STEP 9: LINQ GroupBy (Complex - like TravelPrintService)
            results.AppendLine("STEP 9: Test LINQ GroupBy complesso (come TravelPrintService)...");
            var testVehicles = new[] {
                new TestVehicle { Marca = "Toyota", Modello = "Land Cruiser", Pilota = "Mario" },
                new TestVehicle { Marca = "Toyota", Modello = "Land Cruiser", Pilota = "Luigi" },
                new TestVehicle { Marca = "Jeep", Modello = "Wrangler", Pilota = "Paolo" }
            };
            var vehicleGroups = testVehicles
                .GroupBy(p => new { Marca = p.Marca ?? "N/D", Modello = p.Modello ?? "N/D" })
                .Select(g => new TestVehicleGroup
                {
                    Marca = g.Key.Marca,
                    Modello = g.Key.Modello,
                    Count = g.Count(),
                    Pilots = g.ToList()
                })
                .OrderBy(g => g.Marca)
                .ThenBy(g => g.Modello)
                .ToList();
            results.AppendLine($"✓ STEP 9: OK - LINQ GroupBy complesso: {vehicleGroups.Count} gruppi veicoli");
        }
        catch (Exception ex)
        {
            results.AppendLine($"✗ STEP 9: FAILED - {ex.GetType().Name}: {ex.Message}");
            if (ex.InnerException != null)
                results.AppendLine($"  Inner: {ex.InnerException.GetType().Name}: {ex.InnerException.Message}");
            results.AppendLine($"  Stack Trace: {ex.StackTrace}");
            return results.ToString();
        }

        results.AppendLine("=== TUTTI I TEST DATA RETRIEVAL PASSATI ===");
        return results.ToString();
    }

    // Helper classes for testing
    private class TestJsonClass
    {
        public string? Name { get; set; }
        public int Value { get; set; }
    }

    private class TestVehicle
    {
        public string? Marca { get; set; }
        public string? Modello { get; set; }
        public string? Pilota { get; set; }
    }

    private class TestVehicleGroup
    {
        public string Marca { get; set; } = string.Empty;
        public string Modello { get; set; } = string.Empty;
        public int Count { get; set; }
        public List<TestVehicle> Pilots { get; set; } = new();
    }

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
