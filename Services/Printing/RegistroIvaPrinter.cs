using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using IContainer = QuestPDF.Infrastructure.IContainer;
using Colors = QuestPDF.Helpers.Colors;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Generatore PDF per il Registro IVA (Acquisti e Vendite).
/// Stile grafico coerente con MovTransazioniPrinter.
/// Supporta paginazione con riporto dei totali progressivi.
/// </summary>
public class RegistroIvaPrinter
{
    // Colori brand (coerenti con gli altri report)
    private static class BrandColors
    {
        public static readonly string Primary = "#2B3A42";
        public static readonly string Secondary = "#8D99AE";
        public static readonly string Accent = "#E74C3C";
        public static readonly string Text = "#000000";
        public static readonly string LightGray = "#F0F0F0";
        public static readonly string Border = "#CCCCCC";
        public static readonly string GroupHeader = "#D5E8D4";
        public static readonly string SubTotal = "#FFF2CC";
        public static readonly string Total = "#DAE8FC";
        public static readonly string Success = "#27AE60";
        public static readonly string Warning = "#F39C12";
        public static readonly string IvaHeader = "#E1F5FE";
    }

    // Costanti layout
    private const float FontSizeHeader = 16;
    private const float FontSizeSubHeader = 11;
    private const float FontSizeBody = 8;
    private const float FontSizeSmall = 7;

    // Paginazione: max righe dettaglio per chunk (per gestione riporto)
    private const int MaxRowsFirstChunk = 35;
    private const int MaxRowsNextChunk = 40;

    public static async Task GeneratePdfAsync(RegistroIvaPrintData data, string outputPath)
    {
        QuestPDF.Settings.EnableDebugging = false;
        await PdfUtils.EnsureQuestPdfInitializedAsync();

        Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(1f, Unit.Centimetre);
                page.PageColor(Colors.White);
                page.DefaultTextStyle(x => x.FontSize(FontSizeBody).FontFamily("Lato").FontColor(BrandColors.Text));

                page.Header().Element(header => ComposeHeader(header, data));
                page.Content().Element(content => ComposeContent(content, data));
                page.Footer().Element(footer => ComposeFooter(footer, data));
            });
        })
        .GeneratePdf(outputPath);
    }

    private static void ComposeHeader(IContainer container, RegistroIvaPrintData data)
    {
        container.Column(column =>
        {
            ReportHeaderHelper.ComposeCompanyHeader(
                column.Item(),
                data.Azienda,
                "REGISTRO IVA",
                data.DataStampa,
                data.UtenteStampa
            );

            // Periodo centrato sotto l'header, con font più leggibile
            column.Item().AlignCenter().PaddingBottom(5).Text($"Periodo: {data.PeriodoDisplay}")
                .FontSize(FontSizeSubHeader).Bold().FontColor(BrandColors.Primary);
        });
    }

    private static void ComposeContent(IContainer container, RegistroIvaPrintData data)
    {
        container.PaddingTop(5).Column(column =>
        {
            if (!data.HasData)
            {
                column.Item().AlignCenter().Padding(50).Text("Nessuna fattura con IVA trovata nel periodo selezionato.")
                    .FontSize(FontSizeSubHeader).Italic().FontColor(BrandColors.Secondary);
                return;
            }

            // Sezione 1: REGISTRO IVA ACQUISTI
            if (data.HasAcquisti)
            {
                ComposeRegistroSection(column, "REGISTRO IVA ACQUISTI", data.Acquisti,
                    data.SubTotaliAcquisti, data.TotaleImponibileAcquisti,
                    data.TotaleIvaAcquisti, data.TotaleLordoAcquisti, BrandColors.Accent);
            }

            // Spaziatura tra sezioni
            if (data.HasAcquisti && data.HasVendite)
            {
                column.Item().PaddingVertical(8);
            }

            // Sezione 2: REGISTRO IVA VENDITE
            if (data.HasVendite)
            {
                ComposeRegistroSection(column, "REGISTRO IVA VENDITE", data.Vendite,
                    data.SubTotaliVendite, data.TotaleImponibileVendite,
                    data.TotaleIvaVendite, data.TotaleLordoVendite, BrandColors.Success);
            }

            // Sezione 3: RIEPILOGO E LIQUIDAZIONE
            column.Item().PaddingTop(12);
            ComposeRiepilogoLiquidazione(column, data);
        });
    }

    private static void ComposeRegistroSection(
        ColumnDescriptor column,
        string titolo,
        List<RegistroIvaItem> items,
        List<SubTotaleAliquota> subTotali,
        decimal totaleImponibile,
        decimal totaleIva,
        decimal totaleLordo,
        string accentColor)
    {
        // Titolo sezione
        column.Item().Background(accentColor).Padding(5).Text(titolo)
            .FontSize(FontSizeSubHeader).Bold().FontColor(Colors.White);

        // Suddivide le righe in blocchi per gestire il riporto tra pagine
        var chunks = SplitIntoChunks(items, MaxRowsFirstChunk, MaxRowsNextChunk);

        decimal runningImponibile = 0;
        decimal runningIva = 0;
        decimal runningLordo = 0;
        int globalRowIndex = 0;

        for (int chunkIdx = 0; chunkIdx < chunks.Count; chunkIdx++)
        {
            var chunk = chunks[chunkIdx];
            bool isFirstChunk = chunkIdx == 0;
            bool isLastChunk = chunkIdx == chunks.Count - 1;

            // Totali progressivi dalla pagina precedente
            decimal prevRunningImponibile = runningImponibile;
            decimal prevRunningIva = runningIva;
            decimal prevRunningLordo = runningLordo;

            // Accumula i totali per questo blocco
            foreach (var item in chunk)
            {
                runningImponibile += item.ImponibileEur;
                runningIva += item.IvaEur;
                runningLordo += item.LordoEur;
            }

            // Interruzione di pagina e titolo continuazione per i blocchi successivi al primo
            if (!isFirstChunk)
            {
                column.Item().PageBreak();
                column.Item().Background(accentColor).Padding(5).Text($"{titolo} (segue)")
                    .FontSize(FontSizeSubHeader).Bold().FontColor(Colors.White);
            }

            // Tabella per questo blocco di righe
            column.Item().Table(table =>
            {
                DefineRegistroColumns(table);
                ComposeRegistroTableHeader(table);

                // Riga "Riporto" con i totali dalla pagina precedente
                if (!isFirstChunk)
                {
                    ComposeRiportoRow(table, "Riporto da pagina precedente",
                        prevRunningImponibile, prevRunningIva, prevRunningLordo, isRiporto: true);
                }

                // Righe dati
                int localRowIndex = 0;
                foreach (var item in chunk)
                {
                    var bgColor = (globalRowIndex + localRowIndex) % 2 == 0 ? Colors.White : BrandColors.LightGray;
                    ComposeRegistroDataRow(table, item, bgColor);
                    localRowIndex++;
                }

                // Riga "Da riportare" con i totali progressivi
                if (!isLastChunk)
                {
                    ComposeRiportoRow(table, "Da riportare",
                        runningImponibile, runningIva, runningLordo, isRiporto: false);
                }
            });

            globalRowIndex += chunk.Count;
        }

        // Sub-totali per aliquota
        if (subTotali.Any())
        {
            column.Item().PaddingTop(3).Background(BrandColors.SubTotal).Padding(4).Column(subCol =>
            {
                subCol.Item().Text("Riepilogo per Aliquota:").FontSize(FontSizeBody).Bold();

                subCol.Item().PaddingTop(2).Table(t =>
                {
                    t.ColumnsDefinition(c =>
                    {
                        c.RelativeColumn(1.5f); // Aliquota
                        c.ConstantColumn(30);   // N. doc
                        c.ConstantColumn(80);   // Imponibile
                        c.ConstantColumn(70);   // IVA
                        c.ConstantColumn(80);   // Lordo
                    });

                    // Header subtotali
                    var hStyle = QuestPDF.Infrastructure.TextStyle.Default.FontSize(FontSizeSmall).Bold();
                    t.Cell().Padding(2).Text("Aliquota").Style(hStyle);
                    t.Cell().Padding(2).AlignCenter().Text("Docs").Style(hStyle);
                    t.Cell().Padding(2).AlignRight().Text("Imponibile").Style(hStyle);
                    t.Cell().Padding(2).AlignRight().Text("IVA").Style(hStyle);
                    t.Cell().Padding(2).AlignRight().Text("Lordo").Style(hStyle);

                    foreach (var sub in subTotali)
                    {
                        t.Cell().Padding(2).Text(sub.AliquotaDescrizione ?? sub.AliquotaDisplay).FontSize(FontSizeSmall);
                        t.Cell().Padding(2).AlignCenter().Text($"{sub.Conteggio}").FontSize(FontSizeSmall);
                        t.Cell().Padding(2).AlignRight().Text($"{sub.TotaleImponibile:N2}").FontSize(FontSizeSmall);
                        t.Cell().Padding(2).AlignRight().Text($"{sub.TotaleIva:N2}").FontSize(FontSizeSmall);
                        t.Cell().Padding(2).AlignRight().Text($"{sub.TotaleLordo:N2}").FontSize(FontSizeSmall);
                    }

                    // Totale sezione
                    t.Cell().BorderTop(1).BorderColor(BrandColors.Border).Padding(2).Text("TOTALE").FontSize(FontSizeBody).Bold();
                    t.Cell().BorderTop(1).BorderColor(BrandColors.Border).Padding(2).AlignCenter()
                        .Text($"{items.Count}").FontSize(FontSizeBody).Bold();
                    t.Cell().BorderTop(1).BorderColor(BrandColors.Border).Padding(2).AlignRight()
                        .Text($"{totaleImponibile:N2}").FontSize(FontSizeBody).Bold();
                    t.Cell().BorderTop(1).BorderColor(BrandColors.Border).Padding(2).AlignRight()
                        .Text($"{totaleIva:N2}").FontSize(FontSizeBody).Bold();
                    t.Cell().BorderTop(1).BorderColor(BrandColors.Border).Padding(2).AlignRight()
                        .Text($"{totaleLordo:N2}").FontSize(FontSizeBody).Bold();
                });
            });
        }
    }

    /// <summary>
    /// Suddivide una lista in blocchi dimensionati per pagina.
    /// Il primo blocco ha dimensione ridotta (la prima pagina ha il titolo sezione).
    /// </summary>
    private static List<List<T>> SplitIntoChunks<T>(List<T> items, int firstChunkSize, int nextChunkSize)
    {
        var chunks = new List<List<T>>();
        if (items.Count == 0)
            return chunks;

        if (items.Count <= firstChunkSize)
        {
            chunks.Add(items);
            return chunks;
        }

        chunks.Add(items.Take(firstChunkSize).ToList());
        var remaining = items.Skip(firstChunkSize).ToList();

        while (remaining.Count > 0)
        {
            var chunk = remaining.Take(nextChunkSize).ToList();
            chunks.Add(chunk);
            remaining = remaining.Skip(nextChunkSize).ToList();
        }

        return chunks;
    }

    /// <summary>
    /// Definisce il layout a 9 colonne della tabella dettaglio registro.
    /// </summary>
    private static void DefineRegistroColumns(TableDescriptor table)
    {
        table.ColumnsDefinition(columns =>
        {
            columns.ConstantColumn(50);   // Prot.
            columns.ConstantColumn(55);   // Data Doc
            columns.ConstantColumn(60);   // N. Doc
            columns.RelativeColumn(1.5f); // Controparte
            columns.RelativeColumn(0.8f); // Causale
            columns.ConstantColumn(55);   // Aliquota
            columns.ConstantColumn(70);   // Imponibile
            columns.ConstantColumn(60);   // IVA
            columns.ConstantColumn(70);   // Lordo
        });
    }

    /// <summary>
    /// Renderizza l'header colonne della tabella dettaglio.
    /// </summary>
    private static void ComposeRegistroTableHeader(TableDescriptor table)
    {
        table.Header(header =>
        {
            var headerStyle = QuestPDF.Infrastructure.TextStyle.Default.FontSize(FontSizeSmall).Bold().FontColor(Colors.White);

            header.Cell().Background(BrandColors.Primary).Padding(3).Text("Prot.").Style(headerStyle);
            header.Cell().Background(BrandColors.Primary).Padding(3).Text("Data Doc").Style(headerStyle);
            header.Cell().Background(BrandColors.Primary).Padding(3).Text("N. Doc").Style(headerStyle);
            header.Cell().Background(BrandColors.Primary).Padding(3).Text("Controparte").Style(headerStyle);
            header.Cell().Background(BrandColors.Primary).Padding(3).Text("Causale").Style(headerStyle);
            header.Cell().Background(BrandColors.Primary).Padding(3).AlignCenter().Text("Aliq.").Style(headerStyle);
            header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("Imponibile").Style(headerStyle);
            header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("IVA").Style(headerStyle);
            header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("Lordo").Style(headerStyle);
        });
    }

    /// <summary>
    /// Renderizza una singola riga dati nella tabella dettaglio.
    /// </summary>
    private static void ComposeRegistroDataRow(TableDescriptor table, RegistroIvaItem item, string bgColor)
    {
        table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2)
            .Text(item.NumeroProtocolloDisplay).FontSize(FontSizeSmall);
        table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2)
            .Text(item.DataDocumentoFormatted).FontSize(FontSizeBody);
        table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2)
            .Text(item.TransazioneNumeroDocumento ?? "-").FontSize(FontSizeBody);
        table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2)
            .Text(item.ControparteRagioneSociale).FontSize(FontSizeBody);
        table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2)
            .Text(item.CausaleDescrizione).FontSize(FontSizeBody);
        table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).AlignCenter()
            .Text(item.AliquotaDisplay).FontSize(FontSizeSmall);
        table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).AlignRight()
            .Text(item.ImponibileFormatted).FontSize(FontSizeBody);
        table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).AlignRight()
            .Text(item.IvaFormatted).FontSize(FontSizeBody);
        table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).AlignRight()
            .Text(item.LordoFormatted).FontSize(FontSizeBody).Bold();
    }

    /// <summary>
    /// Renderizza una riga di riporto ("Riporto da pagina precedente" o "Da riportare")
    /// con i totali progressivi di Imponibile, IVA e Lordo.
    /// </summary>
    private static void ComposeRiportoRow(TableDescriptor table, string label,
        decimal imponibile, decimal iva, decimal lordo, bool isRiporto)
    {
        var bgColor = isRiporto ? BrandColors.IvaHeader : BrandColors.SubTotal;

        table.Cell().ColumnSpan(6).Background(bgColor).BorderBottom(1).BorderColor(BrandColors.Primary)
            .Padding(3).Text(label).FontSize(FontSizeBody).Bold().FontColor(BrandColors.Primary);
        table.Cell().Background(bgColor).BorderBottom(1).BorderColor(BrandColors.Primary)
            .Padding(3).AlignRight().Text($"{imponibile:N2}").FontSize(FontSizeBody).Bold().FontColor(BrandColors.Primary);
        table.Cell().Background(bgColor).BorderBottom(1).BorderColor(BrandColors.Primary)
            .Padding(3).AlignRight().Text($"{iva:N2}").FontSize(FontSizeBody).Bold().FontColor(BrandColors.Primary);
        table.Cell().Background(bgColor).BorderBottom(1).BorderColor(BrandColors.Primary)
            .Padding(3).AlignRight().Text($"{lordo:N2}").FontSize(FontSizeBody).Bold().FontColor(BrandColors.Primary);
    }

    private static void ComposeRiepilogoLiquidazione(ColumnDescriptor column, RegistroIvaPrintData data)
    {
        // Titolo
        column.Item().Background(BrandColors.Primary).Padding(5).Text("RIEPILOGO E LIQUIDAZIONE IVA DEL PERIODO")
            .FontSize(FontSizeSubHeader).Bold().FontColor(Colors.White);

        // Tabella riepilogativa per aliquota
        if (data.RiepilogoPerAliquota.Any())
        {
            column.Item().PaddingTop(3).Table(table =>
            {
                table.ColumnsDefinition(columns =>
                {
                    columns.RelativeColumn(1.5f); // Aliquota
                    columns.ConstantColumn(80);   // Imponibile Acquisti
                    columns.ConstantColumn(70);   // IVA Acquisti
                    columns.ConstantColumn(80);   // Imponibile Vendite
                    columns.ConstantColumn(70);   // IVA Vendite
                });

                // Header
                table.Header(header =>
                {
                    var headerStyle = QuestPDF.Infrastructure.TextStyle.Default.FontSize(FontSizeSmall).Bold().FontColor(Colors.White);

                    header.Cell().Background(BrandColors.Primary).Padding(3).Text("Aliquota").Style(headerStyle);
                    header.Cell().Background(BrandColors.Accent).Padding(3).AlignRight().Text("Impon. Acquisti").Style(headerStyle);
                    header.Cell().Background(BrandColors.Accent).Padding(3).AlignRight().Text("IVA Acquisti").Style(headerStyle);
                    header.Cell().Background(BrandColors.Success).Padding(3).AlignRight().Text("Impon. Vendite").Style(headerStyle);
                    header.Cell().Background(BrandColors.Success).Padding(3).AlignRight().Text("IVA Vendite").Style(headerStyle);
                });

                int rowIndex = 0;
                foreach (var riepilogo in data.RiepilogoPerAliquota)
                {
                    var bgColor = rowIndex % 2 == 0 ? Colors.White : BrandColors.LightGray;

                    table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(3)
                        .Text(riepilogo.AliquotaDescrizione ?? riepilogo.AliquotaDisplay).FontSize(FontSizeBody);
                    table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(3).AlignRight()
                        .Text($"{riepilogo.ImponibileAcquisti:N2}").FontSize(FontSizeBody);
                    table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(3).AlignRight()
                        .Text($"{riepilogo.IvaAcquisti:N2}").FontSize(FontSizeBody);
                    table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(3).AlignRight()
                        .Text($"{riepilogo.ImponibileVendite:N2}").FontSize(FontSizeBody);
                    table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(3).AlignRight()
                        .Text($"{riepilogo.IvaVendite:N2}").FontSize(FontSizeBody);

                    rowIndex++;
                }

                // Riga totali
                table.Cell().BorderTop(1.5f).BorderColor(BrandColors.Primary).Background(BrandColors.Total).Padding(3)
                    .Text("TOTALE").FontSize(FontSizeBody).Bold();
                table.Cell().BorderTop(1.5f).BorderColor(BrandColors.Primary).Background(BrandColors.Total).Padding(3).AlignRight()
                    .Text($"{data.TotaleImponibileAcquisti:N2}").FontSize(FontSizeBody).Bold();
                table.Cell().BorderTop(1.5f).BorderColor(BrandColors.Primary).Background(BrandColors.Total).Padding(3).AlignRight()
                    .Text($"{data.TotaleIvaAcquisti:N2}").FontSize(FontSizeBody).Bold().FontColor(BrandColors.Accent);
                table.Cell().BorderTop(1.5f).BorderColor(BrandColors.Primary).Background(BrandColors.Total).Padding(3).AlignRight()
                    .Text($"{data.TotaleImponibileVendite:N2}").FontSize(FontSizeBody).Bold();
                table.Cell().BorderTop(1.5f).BorderColor(BrandColors.Primary).Background(BrandColors.Total).Padding(3).AlignRight()
                    .Text($"{data.TotaleIvaVendite:N2}").FontSize(FontSizeBody).Bold().FontColor(BrandColors.Success);
            });
        }

        // Box Liquidazione IVA
        column.Item().PaddingTop(8);
        ComposeLiquidazioneBox(column, data.Liquidazione);
    }

    private static void ComposeLiquidazioneBox(ColumnDescriptor column, LiquidazioneIva liquidazione)
    {
        var borderColor = liquidazione.IsDebito ? BrandColors.Accent : (liquidazione.IsCredito ? BrandColors.Success : BrandColors.Primary);

        column.Item().Border(2).BorderColor(borderColor).Padding(10).Column(box =>
        {
            box.Item().AlignCenter().Text("LIQUIDAZIONE IVA DEL PERIODO")
                .FontSize(FontSizeSubHeader).Bold().FontColor(BrandColors.Primary);

            box.Item().PaddingTop(8).Row(row =>
            {
                // IVA a Debito (Vendite)
                row.RelativeItem().Column(c =>
                {
                    c.Item().Text("IVA a Debito (Vendite)").FontSize(FontSizeBody).Bold();
                    c.Item().Text($"{liquidazione.IvaDebito:N2} EUR")
                        .FontSize(FontSizeSubHeader).Bold().FontColor(BrandColors.Accent);
                });

                // Separatore -
                row.ConstantItem(20).AlignCenter().AlignMiddle().Text("-")
                    .FontSize(FontSizeHeader).Bold().FontColor(BrandColors.Primary);

                // IVA a Credito (Acquisti)
                row.RelativeItem().Column(c =>
                {
                    c.Item().Text("IVA a Credito (Acquisti)").FontSize(FontSizeBody).Bold();
                    c.Item().Text($"{liquidazione.IvaCredito:N2} EUR")
                        .FontSize(FontSizeSubHeader).Bold().FontColor(BrandColors.Success);
                });

                // Credito periodo precedente (solo se presente)
                if (liquidazione.HasCreditoPrecedente)
                {
                    // Separatore -
                    row.ConstantItem(20).AlignCenter().AlignMiddle().Text("-")
                        .FontSize(FontSizeHeader).Bold().FontColor(BrandColors.Primary);

                    row.RelativeItem().Column(c =>
                    {
                        c.Item().Text("Credito Periodo Prec.").FontSize(FontSizeBody).Bold();
                        c.Item().Text($"{liquidazione.CreditoPrecedente:N2} EUR")
                            .FontSize(FontSizeSubHeader).Bold().FontColor(BrandColors.Success);
                    });
                }

                // Separatore =
                row.ConstantItem(20).AlignCenter().AlignMiddle().Text("=")
                    .FontSize(FontSizeHeader).Bold().FontColor(BrandColors.Primary);

                // Saldo
                row.RelativeItem().Column(c =>
                {
                    c.Item().Text(liquidazione.SaldoLabel).FontSize(FontSizeBody).Bold();
                    c.Item().Text(liquidazione.SaldoFormatted)
                        .FontSize(FontSizeHeader).Bold()
                        .FontColor(liquidazione.IsDebito ? BrandColors.Accent : (liquidazione.IsCredito ? BrandColors.Success : BrandColors.Primary));
                });
            });
        });
    }

    private static void ComposeFooter(IContainer container, RegistroIvaPrintData data)
    {
        container.Row(row =>
        {
            row.RelativeItem().Text(text =>
            {
                text.Span($"Registro IVA generato da GestioneViaggi - {data.DataStampa:dd/MM/yyyy HH:mm}")
                    .FontSize(FontSizeSmall).FontColor(BrandColors.Secondary);
            });

            row.RelativeItem().AlignRight().Text(text =>
            {
                text.Span($"{data.PeriodoDa.Year} / Pagina ").FontSize(FontSizeSmall);
                text.CurrentPageNumber().FontSize(FontSizeSmall);
                text.Span(" di ").FontSize(FontSizeSmall);
                text.TotalPages().FontSize(FontSizeSmall);
            });
        });
    }
}
