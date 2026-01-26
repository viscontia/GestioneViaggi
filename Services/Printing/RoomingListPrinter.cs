using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using IContainer = QuestPDF.Infrastructure.IContainer;
using Colors = QuestPDF.Helpers.Colors;

namespace GestioneViaggi.Services.Printing;

public class RoomingListPrinter
{
    // Define brand colors (matching ViaggiPrinter)
    private static class BrandColors
    {
        public static readonly string Primary = "#2B3A42"; // Dark Slate
        public static readonly string Secondary = "#8D99AE"; // Cool Grey
        public static readonly string Accent = "#E74C3C";  // Red (same as ViaggiPrinter)
        public static readonly string Text = "#000000";
        public static readonly string LightGray = "#F0F0F0";
        public static readonly string Border = "#CCCCCC";
    }

    // Define layout constants
    private const float FontSizeHeader = 18;
    private const float FontSizeSubHeader = 12;
    private const float FontSizeBody = 9;
    private const float FontSizeSmall = 8;

    public static async Task GeneratePdfAsync(RoomingListPrintDTO data, string outputPath)
    {
        QuestPDF.Settings.EnableDebugging = false;

        await PdfUtils.EnsureQuestPdfInitializedAsync();

        Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4); // Portrait
                page.Margin(1, Unit.Centimetre);
                page.PageColor(Colors.White);
                page.DefaultTextStyle(x => x.FontSize(FontSizeBody).FontFamily("Lato").FontColor(BrandColors.Text));

                page.Header().Element(header => ComposeHeader(header, data));
                page.Content().Element(content => ComposeContent(content, data));
                page.Footer().Element(footer => ComposeFooter(footer));
            });
        })
        .GeneratePdf(outputPath);
    }

    private static void ComposeHeader(IContainer container, RoomingListPrintDTO data)
    {
        container.Column(column =>
        {
            // TOP ROW: Logo + Title + Date (repeated on every page)
            column.Item().Row(row =>
            {
                // LEFT: Logo
                if (data.Company.LogoData != null && data.Company.LogoData.Length > 0)
                {
                    row.ConstantItem(80).MaxHeight(60).Image(data.Company.LogoData).FitArea();
                }

                // CENTER: Title (on single line)
                row.RelativeItem().Column(titleCol =>
                {
                    titleCol.Item().AlignCenter().Border(2).BorderColor(BrandColors.Accent).Padding(10)
                        .Text("ROOMING LIST")
                        .FontSize(24).Bold().FontColor(BrandColors.Accent);
                });

                // RIGHT: Print Date
                row.ConstantItem(100).AlignRight().Column(dateCol =>
                {
                    dateCol.Item().AlignRight().Text("Data di Stampa").FontSize(10);
                    dateCol.Item().AlignRight().Text(DateTime.Now.ToString("dd/MM/yyyy")).FontSize(12).Bold();
                });
            });
        });
    }

    private static void ComposeContent(IContainer container, RoomingListPrintDTO data)
    {
        container.Column(column =>
        {
            // VIAGGIO INFO (only on first page)
            column.Item().ShowOnce().PaddingTop(15).Border(2).BorderColor(BrandColors.Text).Padding(8).Column(viaggioCol =>
            {
                viaggioCol.Item().Text(text =>
                {
                    text.Span("VIAGGIO: ").Bold();
                    text.Span(data.Header.Titolo.ToUpper()).Bold().FontSize(12);
                });

                viaggioCol.Item().Text(text =>
                {
                    text.Span("NELLE DATE: ").Bold();
                    text.Span(data.Header.DateFormatted).FontSize(10);
                });
            });

            // CARATTERISTICHE DEL VIAGGIO (only on first page)
            column.Item().ShowOnce().PaddingTop(15).Column(carCol =>
            {
                carCol.Item().PaddingBottom(5).Text("Caratteristiche del Viaggio:").FontSize(12).Bold();

                carCol.Item().Border(2).BorderColor(BrandColors.Accent).Row(carRow =>
                {
                    // LEFT: Details Table
                    carRow.RelativeItem().Padding(8).Table(table =>
                    {
                        table.ColumnsDefinition(cols =>
                        {
                            cols.ConstantColumn(140);
                            cols.RelativeColumn();
                        });

                        void AddRow(string label, string val)
                        {
                            table.Cell().PaddingVertical(3).Text(label).SemiBold();
                            table.Cell().PaddingVertical(3).Text(val);
                        }

                        AddRow("Tipo del Viaggio:", data.Header.TipoViaggio);
                        AddRow("Luogo:", data.Header.Destinazione);
                        AddRow("N. Giorni/Notti:", $"{data.Header.Giorni}/{data.Header.Notti}");
                        AddRow("Trattamento Previsto:", data.Header.Trattamento);
                        AddRow("Pasti al sacco:", data.Header.PastiSacco ? "Si" : "No");
                        AddRow("Km. Viaggio:", data.Header.Km.ToString());
                    });

                    // RIGHT: Big Stats
                    carRow.ConstantItem(100).BorderLeft(2).BorderColor(BrandColors.Accent).Column(statsCol =>
                    {
                        void BigStat(IContainer cnt, string number, string label)
                        {
                            cnt.Column(statCol =>
                            {
                                statCol.Item().AlignCenter().Text(number).FontSize(32).Bold();
                                statCol.Item().AlignCenter().Text(label.ToUpper()).FontSize(10).SemiBold();
                            });
                        }

                        statsCol.Item().PaddingVertical(10).Element(e => BigStat(e, data.TotalParticipants.ToString(), "PERSONE"));
                        statsCol.Item().BorderTop(2).BorderColor(BrandColors.Accent).PaddingVertical(10).Element(e => BigStat(e, data.TotalRooms.ToString(), "CAMERE"));
                    });
                });
            });

            // ROOM GROUPS AND PARTICIPANTS (continues on all pages)
            column.Item().PaddingTop(15).Column(contentCol =>
            {
                foreach (var roomGroup in data.RoomGroups)
                {
                    // ROOM TYPE HEADER
                    contentCol.Item().PaddingTop(10).Background(BrandColors.Accent).Padding(8).Row(headerRow =>
                    {
                        headerRow.RelativeItem().Text(roomGroup.DisplayHeader).FontSize(11).Bold().FontColor(Colors.White);
                        headerRow.ConstantItem(80).AlignRight().Text($"Camere: {roomGroup.RoomCount}").FontSize(10).Bold().FontColor(Colors.White);
                    });

                    int lastRoomId = -1;
                    var sortedParticipants = roomGroup.Participants; // Already sorted by Service

                    for (int i = 0; i < sortedParticipants.Count; i++)
                    {
                        var participant = sortedParticipants[i];
                        
                        // Check for Room Change (Grouping)
                        if (participant.RoomId > 0 && participant.RoomId != lastRoomId)
                        {
                            // If not the very first item, and we are switching rooms, add a strong separator
                            if (lastRoomId != -1)
                            {
                                contentCol.Item().PaddingTop(10).LineHorizontal(1).LineColor(BrandColors.Accent);
                            }
                            lastRoomId = participant.RoomId;
                        }
                        else if (i > 0)
                        {
                            // Same room (or both no room), simple separator
                            contentCol.Item().PaddingTop(5).Text(new string('-', 40)).FontSize(8).FontColor(BrandColors.Border);
                        }

                        // PARTICIPANT BOX
                        contentCol.Item().PaddingTop(5).Column(partCol =>
                        {
                            // Linea 1: Nome (età) - Nato il [data] a [luogo] e residente a [città] in [indirizzo]
                            partCol.Item().Text(text =>
                            {
                                var parts = new List<string>();
                                parts.Add($"{participant.Nominativo} ({participant.Eta} Anni)");

                                if (participant.DataNascita.HasValue || !string.IsNullOrEmpty(participant.LuogoNascita))
                                {
                                    var natoPart = "- Nato";
                                    if (participant.DataNascita.HasValue)
                                        natoPart += $" il {participant.DataNascitaFormatted}";
                                    if (!string.IsNullOrEmpty(participant.LuogoNascita))
                                        natoPart += $" a {participant.LuogoNascita}";
                                    parts.Add(natoPart);
                                }

                                if (!string.IsNullOrEmpty(participant.ResidenzaCompleta))
                                {
                                    parts.Add($"e residente a {participant.ResidenzaCompleta}");
                                }

                                text.Span(string.Join(" ", parts)).FontSize(9);
                            });

                            // Linea 2: Nazionalità
                              if (!string.IsNullOrEmpty(participant.CountryCode) || !string.IsNullOrEmpty(participant.Nationality))
                              {
                                   partCol.Item().Text(text =>
                                   {
                                        var p = "";
                                        if(!string.IsNullOrEmpty(participant.Nationality)) 
                                            p = $"Nazionalità: {participant.Nationality}";
                                        else 
                                            p = $"Nazionalità: {participant.CountryCode} - {participant.CountryName}";
                                        text.Span(p).FontSize(9);
                                   });
                              }

                              // Linea 3: Documento
                              if (!string.IsNullOrEmpty(participant.TipoDocumento) || !string.IsNullOrEmpty(participant.NumeroDocumento))
                              {
                                   partCol.Item().Text(text =>
                                   {
                                        var parts = new List<string>();
                                        if (!string.IsNullOrEmpty(participant.TipoDocumento)) parts.Add($"Tipo Doc.: {participant.TipoDocumento}");
                                        if (!string.IsNullOrEmpty(participant.NumeroDocumento)) parts.Add($"Num. {participant.NumeroDocumento}");
                                        if (!string.IsNullOrEmpty(participant.EnteRilascio)) parts.Add($"Ril.da: {participant.EnteRilascio}");
                                        if (participant.DataRilascio.HasValue) parts.Add($"Il: {participant.DataRilascioFormatted}");
                                        if (participant.DataScadenza.HasValue) parts.Add($"Scad.: {participant.DataScadenzaFormatted}");

                                        text.Span(string.Join("   ", parts)).FontSize(9);
                                   });
                              }
                              else
                              {
                                   // MESSAGGIO AGGIUNTO SU RICHIESTA UTENTE
                                   partCol.Item().Text("Nessun documento registrato").FontSize(9).Italic().FontColor(BrandColors.Secondary);
                              }

                            // Linea 3: Intolleranze (se presenti)
                            if (!string.IsNullOrEmpty(participant.Intolleranze))
                            {
                                partCol.Item().Text($"** INT. ALIMENTARE: {participant.Intolleranze.ToUpper()} **")
                                    .FontSize(9).Bold().FontColor(BrandColors.Accent);
                            }
                        });
                    }

                    // Extra space after each room type group
                    contentCol.Item().PaddingTop(5);
                }
            });
        });
    }

    private static void ComposeFooter(IContainer container)
    {
        container.Column(column =>
        {
            column.Item().LineHorizontal(0.5f).LineColor(BrandColors.Border);
            column.Item().PaddingTop(5).Row(row =>
            {
                row.RelativeItem().AlignLeft().Text(text =>
                {
                    text.Span("Pag. ");
                    text.CurrentPageNumber();
                    text.Span(" di ");
                    text.TotalPages();
                });
            });
        });
    }
}
