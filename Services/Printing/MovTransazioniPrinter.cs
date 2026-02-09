using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using IContainer = QuestPDF.Infrastructure.IContainer;
using Colors = QuestPDF.Helpers.Colors;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Generatore PDF per i movimenti contabili.
/// Usa lo stesso stile grafico di ViaggiPrinter e RoomingListPrinter.
/// </summary>
public class MovTransazioniPrinter
{
    // Colori brand (coerenti con gli altri report)
    private static class BrandColors
    {
        public static readonly string Primary = "#2B3A42";    // Dark Slate
        public static readonly string Secondary = "#8D99AE";  // Cool Grey
        public static readonly string Accent = "#E74C3C";     // Red
        public static readonly string Text = "#000000";
        public static readonly string LightGray = "#F0F0F0";
        public static readonly string Border = "#CCCCCC";
        public static readonly string GroupHeader = "#D5E8D4"; // Verde chiaro per rotture
        public static readonly string SubTotal = "#FFF2CC";    // Giallo chiaro per sub-totali
        public static readonly string Total = "#DAE8FC";       // Blu chiaro per totali generali
    }

    // Costanti layout
    private const float FontSizeHeader = 16;
    private const float FontSizeSubHeader = 11;
    private const float FontSizeBody = 8;
    private const float FontSizeSmall = 7;

    public static async Task GeneratePdfAsync(TransazioniPrintData data, string outputPath)
    {
        QuestPDF.Settings.EnableDebugging = false;
        await PdfUtils.EnsureQuestPdfInitializedAsync();

        Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4.Landscape());
                page.Margin(0.8f, Unit.Centimetre);
                page.PageColor(Colors.White);
                page.DefaultTextStyle(x => x.FontSize(FontSizeBody).FontFamily("Lato").FontColor(BrandColors.Text));

                page.Header().Element(header => ComposeHeader(header, data));
                page.Content().Element(content => ComposeContent(content, data));
                page.Footer().Element(footer => ComposeFooter(footer, data));
            });
        })
        .GeneratePdf(outputPath);
    }

    private static void ComposeHeader(IContainer container, TransazioniPrintData data)
    {
        container.Column(column =>
        {
            // 1. Riga Superiore: Logo/Azienda (Sinistra) + Info Stampa (Destra)
            column.Item().Row(row =>
            {
                // Sinistra: Logo/Azienda
                row.RelativeItem().Column(col =>
                {
                    if (data.Company.LogoData != null && data.Company.LogoData.Length > 0)
                    {
                        col.Item().MaxHeight(40).Image(data.Company.LogoData).FitArea();
                    }
                    else
                    {
                        col.Item().Text(data.Company.RagioneSociale)
                            .FontSize(FontSizeHeader).Bold().FontColor(BrandColors.Primary);
                    }

                    var infoParts = new List<string>();
                    if (!string.IsNullOrEmpty(data.Company.RagioneSociale)) infoParts.Add(data.Company.RagioneSociale);
                    if (!string.IsNullOrEmpty(data.Company.Piva)) infoParts.Add($"P.IVA: {data.Company.Piva}");
                    if (!string.IsNullOrEmpty(data.Company.Telefono)) infoParts.Add(data.Company.Telefono);

                    if (infoParts.Any())
                    {
                        col.Item().PaddingTop(2).Text(string.Join(" - ", infoParts)).FontSize(FontSizeSmall);
                    }
                });

                // Destra: Info Stampa
                row.RelativeItem().AlignRight().Column(col =>
                {
                    col.Item().Text($"Stampato il: {data.DataStampa:dd/MM/yyyy HH:mm}")
                        .FontSize(FontSizeSmall);
                    col.Item().Text($"Da: {data.UtenteStampa}")
                        .FontSize(FontSizeSmall);
                    col.Item().Text($"Valuta target: {data.ValutaTargetCodiceIso}")
                        .FontSize(FontSizeSmall).Bold();
                });
            });

            // 2. Riga Titolo: Centrata nel documento su un'unica riga
            column.Item().PaddingVertical(10).AlignCenter().Column(col =>
            {
                col.Item().Text("STAMPA MOVIMENTI CONTABILI")
                    .FontSize(FontSizeHeader).Bold().FontColor(BrandColors.Accent);
                
                col.Item().AlignCenter().Text($"Ordinamento: {data.TipoOrdinamentoDisplay}")
                    .FontSize(10).FontColor(BrandColors.Secondary);
            });

            // Filtri applicati (se presenti)
            if (data.Filtri.HasAnyFilter)
            {
                column.Item().PaddingTop(5).Background(BrandColors.LightGray).Padding(5).Row(row =>
                {
                    row.RelativeItem().Text(text =>
                    {
                        text.Span("Filtri: ").Bold().FontSize(FontSizeSmall);
                        var filters = new List<string>();
                        
                        if (!string.IsNullOrEmpty(data.Filtri.Fornitore))
                            filters.Add($"Fornitore: {data.Filtri.Fornitore}");
                        if (!string.IsNullOrEmpty(data.Filtri.TipoMovimento))
                            filters.Add($"Tipo: {data.Filtri.TipoMovimento}");
                        if (!string.IsNullOrEmpty(data.Filtri.Valuta))
                            filters.Add($"Valuta: {data.Filtri.Valuta}");
                        if (!string.IsNullOrEmpty(data.Filtri.DataDocumentoDal) || !string.IsNullOrEmpty(data.Filtri.DataDocumentoAl))
                            filters.Add($"Data Doc: {data.Filtri.DataDocumentoDal ?? "..."} - {data.Filtri.DataDocumentoAl ?? "..."}");
                        if (!string.IsNullOrEmpty(data.Filtri.ImportoDa) || !string.IsNullOrEmpty(data.Filtri.ImportoA))
                            filters.Add($"Importo: {data.Filtri.ImportoDa ?? "0"} - {data.Filtri.ImportoA ?? "∞"}");
                        if (data.Filtri.Checkbox.Any())
                            filters.AddRange(data.Filtri.Checkbox);
                        
                        text.Span(string.Join(" | ", filters)).FontSize(FontSizeSmall);
                    });
                });
            }

            column.Item().PaddingTop(5).LineHorizontal(1).LineColor(BrandColors.Border);
        });
    }

    private static void ComposeContent(IContainer container, TransazioniPrintData data)
    {
        container.PaddingTop(5).Column(column =>
        {
            if (!data.Dettagli.Any())
            {
                column.Item().AlignCenter().Padding(50).Text("Nessuna transazione trovata con i filtri applicati.")
                    .FontSize(FontSizeSubHeader).Italic().FontColor(BrandColors.Secondary);
                return;
            }

            // Itera per ogni gruppo usando il raggruppamento del DTO
            foreach (var group in data.DettagliRaggruppati)
            {
                ComposeGroupTable(column, group.Key, group, data);
            }

            // Totali generali
            column.Item().PaddingTop(10);
            ComposeTotaliGenerali(column, data);
        });
    }

    private static void ComposeGroupTable(ColumnDescriptor column, string? gruppoChiave, IEnumerable<TransazionePrintItem> groupItems, TransazioniPrintData data)
    {
        var firstItem = groupItems.FirstOrDefault();
        if (firstItem == null) return;

        column.Item().Table(table =>
        {
            // Definizione colonne (pesi ricalibrati dalla versione Landscape)
            table.ColumnsDefinition(columns =>
            {
                columns.ConstantColumn(55);  // Data Doc
                columns.ConstantColumn(55);  // Data Trans
                columns.RelativeColumn(1.5f); // Fornitore
                columns.ConstantColumn(45);  // Tipo
                columns.RelativeColumn(1.5f); // Causale
                columns.RelativeColumn(1.5f); // Viaggio / Data
                columns.ConstantColumn(55);  // Stato
                columns.ConstantColumn(70);  // Num. Doc
                columns.ConstantColumn(85);  // Importo Orig.
                columns.ConstantColumn(85);  // Importo Conv.
            });

            // Header ripetibile (contiene Nome Gruppo + Intestazioni Colonne)
            table.Header(header =>
            {
                // Riga 1: Nome Gruppo (Sfondo Verde)
                header.Cell().ColumnSpan(10).Background(BrandColors.GroupHeader).Padding(4).Row(row =>
                {
                    var title = firstItem.GruppoDisplay ?? firstItem.GruppoChiave ?? "-";
                    row.RelativeItem().Text(title).FontSize(FontSizeSubHeader).Bold().FontColor(BrandColors.Primary);
                });

                // Riga 2: Intestazioni Colonne (Sfondo Blu Navy)
                var headerStyle = QuestPDF.Infrastructure.TextStyle.Default.FontSize(FontSizeSmall).Bold().FontColor(Colors.White);

                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Data Doc").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Data Trans").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Fornitore").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Tipo").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Causale").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Viaggio / Data").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Stato").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Num. Doc").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("Importo Orig.").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("Importo Conv.").Style(headerStyle);
            });

            // Righe transizioni
            int rowIndex = 0;
            foreach (var item in groupItems)
            {
                var bgColor = rowIndex % 2 == 0 ? Colors.White : BrandColors.LightGray;
                
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.DataDocumentoFormatted).FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.DataTransazioneFormatted).FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.Fornitore).FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.TipoMovimentoDisplay).FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.Causale ?? "-").FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.ViaggioFullDisplay).FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.StatoDisplay).FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.NumeroDocumento ?? "-").FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).AlignRight().Text(item.ImportoFormatted).FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).AlignRight().Text(item.ImportoTargetFormatted).FontSize(FontSizeBody).Bold();
                
                rowIndex++;
            }
        });

        // Sub-totali del gruppo
        if (gruppoChiave != null)
        {
            ComposeGroupSubtotals(column, data, gruppoChiave);
        }

        column.Item().PaddingVertical(3);
    }



    private static void ComposeGroupSubtotals(ColumnDescriptor column, TransazioniPrintData data, string gruppoChiave)
    {
        var subtotali = data.SubTotaliGruppi.Where(s => s.GruppoChiave == gruppoChiave).ToList();
        
        if (!subtotali.Any()) return;

        column.Item().Background(BrandColors.SubTotal).Padding(3).Column(subCol =>
        {
            foreach (var sub in subtotali)
            {
                subCol.Item().Row(row =>
                {
                    row.RelativeItem().Text($"Sub-totale {sub.GruppoDisplay} ({sub.ValutaCodiceIso}):")
                        .FontSize(FontSizeBody).Bold();
                    row.ConstantItem(100).AlignRight().Text(sub.TotaleOriginaleFormatted)
                        .FontSize(FontSizeBody).Bold();
                    row.ConstantItem(100).AlignRight().Text($"-> {sub.TotaleTargetFormatted}")
                        .FontSize(FontSizeBody).Bold();
                    row.ConstantItem(60).AlignRight().Text($"({sub.ConteggioTransazioni} mov.)")
                        .FontSize(FontSizeSmall).Italic();
                });
            }
        });
    }

    private static void ComposeTotaliGenerali(ColumnDescriptor column, TransazioniPrintData data)
    {
        var totali = data.TotaliGenerali.ToList();
        
        if (!totali.Any()) return;

        column.Item().Background(BrandColors.Total).Border(1).BorderColor(BrandColors.Primary).Padding(5).Column(totCol =>
        {
            totCol.Item().Text("TOTALI GENERALI")
                .FontSize(FontSizeSubHeader).Bold().FontColor(BrandColors.Primary);
            
            totCol.Item().PaddingTop(3);

            foreach (var tot in totali)
            {
                totCol.Item().Row(row =>
                {
                    row.RelativeItem().Text($"Totale {tot.ValutaCodiceIso}:")
                        .FontSize(FontSizeBody).Bold();
                    row.ConstantItem(120).AlignRight().Text(tot.TotaleOriginaleFormatted)
                        .FontSize(FontSizeSubHeader).Bold();
                    row.ConstantItem(120).AlignRight().Text($"-> {tot.TotaleTargetFormatted}")
                        .FontSize(FontSizeSubHeader).Bold().FontColor(BrandColors.Accent);
                    row.ConstantItem(80).AlignRight().Text($"({tot.ConteggioTransazioni} mov.)")
                        .FontSize(FontSizeSmall);
                });
            }

            // Totale complessivo nella valuta target
            var totaleComplessivo = totali.Sum(t => t.TotaleValutaTarget);
            var conteggioComplessivo = totali.Sum(t => t.ConteggioTransazioni);
            
            totCol.Item().PaddingTop(5).BorderTop(1).BorderColor(BrandColors.Primary).PaddingTop(3).Row(row =>
            {
                row.RelativeItem().Text($"TOTALE COMPLESSIVO ({data.ValutaTargetCodiceIso}):")
                    .FontSize(FontSizeSubHeader).Bold().FontColor(BrandColors.Primary);
                row.ConstantItem(150).AlignRight().Text($"{totaleComplessivo:N2} {data.ValutaTargetCodiceIso}")
                    .FontSize(FontSizeHeader).Bold().FontColor(BrandColors.Accent);
                row.ConstantItem(80).AlignRight().Text($"({conteggioComplessivo} mov.)")
                    .FontSize(FontSizeSmall);
            });
        });
    }

    private static void ComposeFooter(IContainer container, TransazioniPrintData data)
    {
        container.Row(row =>
        {
            row.RelativeItem().Text(text =>
            {
                text.Span($"Report generato da GestioneViaggi - {data.DataStampa:dd/MM/yyyy HH:mm}")
                    .FontSize(FontSizeSmall).FontColor(BrandColors.Secondary);
            });

            row.RelativeItem().AlignRight().Text(text =>
            {
                text.Span("Pagina ").FontSize(FontSizeSmall);
                text.CurrentPageNumber().FontSize(FontSizeSmall);
                text.Span(" di ").FontSize(FontSizeSmall);
                text.TotalPages().FontSize(FontSizeSmall);
            });
        });
    }
}
