using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using IContainer = QuestPDF.Infrastructure.IContainer;
using Colors = QuestPDF.Helpers.Colors;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Generatore PDF per fattura attiva singola.
/// Layout A4 Portrait con sezioni: testata azienda, identificativo fattura,
/// destinatario, dettaglio righe, riepilogo IVA, totali, dati bancari, scadenza, note legali.
/// </summary>
public static class FatturaAttivaPrinter
{
    public static async Task GeneratePdfAsync(FatturaAttivaPrintData data, string outputPath)
    {
        QuestPDF.Settings.EnableDebugging = false;
        await PdfUtils.EnsureQuestPdfInitializedAsync();

        Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(1.5f, Unit.Centimetre);
                page.PageColor(Colors.White);
                page.DefaultTextStyle(x => x.FontSize(ReportHeaderHelper.FontSizeBodyCompact).FontFamily("Lato").FontColor(ReportHeaderHelper.BrandColors.Text));

                page.Header().Element(header => ComposeHeader(header, data));
                page.Content().Element(content => ComposeContent(content, data));
                page.Footer().Element(ReportHeaderHelper.ComposeFooter);
            });
        })
        .GeneratePdf(outputPath);
    }

    private static void ComposeHeader(IContainer container, FatturaAttivaPrintData data)
    {
        container.Column(column =>
        {
            // Riga superiore: Logo + Dati Azienda (Sinistra) | FATTURA (Centro-Destra)
            column.Item().Row(row =>
            {
                // Sinistra: Logo e info azienda
                row.RelativeItem(3).Column(col =>
                {
                    // Logo
                    if (data.Company.LogoData.Length > 0)
                    {
                        col.Item().MaxHeight(50).Image(data.Company.LogoData).FitArea();
                    }
                    else
                    {
                        col.Item().Text(data.Company.RagioneSociale)
                            .FontSize(ReportHeaderHelper.FontSizeHeaderCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);
                    }

                    // Ragione Sociale + Forma Giuridica
                    var denominazione = !string.IsNullOrEmpty(data.Company.FormaGiuridica)
                        ? $"{data.Company.RagioneSociale} {data.Company.FormaGiuridica}"
                        : data.Company.RagioneSociale;
                    col.Item().PaddingTop(2).Text(denominazione).FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();

                    // Indirizzo
                    col.Item().Text($"{data.Company.IndirizzoCompleto} - {data.Company.CittaCompleta}")
                        .FontSize(ReportHeaderHelper.FontSizeSmallCompact);

                    // P.IVA e C.F.
                    var fiscali = new List<string>();
                    if (!string.IsNullOrEmpty(data.Company.PartitaIva)) fiscali.Add($"P.IVA: {data.Company.PartitaIva}");
                    if (!string.IsNullOrEmpty(data.Company.CodiceFiscale)) fiscali.Add($"C.F.: {data.Company.CodiceFiscale}");
                    if (fiscali.Any())
                        col.Item().Text(string.Join(" - ", fiscali)).FontSize(ReportHeaderHelper.FontSizeSmallCompact);

                    // REA + SDI
                    var extra = new List<string>();
                    if (!string.IsNullOrEmpty(data.Company.ReaDisplay)) extra.Add(data.Company.ReaDisplay);
                    if (!string.IsNullOrEmpty(data.Company.CodiceSdi)) extra.Add($"SDI: {data.Company.CodiceSdi}");
                    if (extra.Any())
                        col.Item().Text(string.Join(" - ", extra)).FontSize(ReportHeaderHelper.FontSizeSmallCompact);

                    // Contatti
                    var contatti = new List<string>();
                    if (!string.IsNullOrEmpty(data.Company.Telefono)) contatti.Add($"Tel: {data.Company.Telefono}");
                    if (!string.IsNullOrEmpty(data.Company.Pec)) contatti.Add($"PEC: {data.Company.Pec}");
                    if (!string.IsNullOrEmpty(data.Company.SitoWeb)) contatti.Add(data.Company.SitoWeb);
                    if (contatti.Any())
                        col.Item().Text(string.Join(" - ", contatti)).FontSize(ReportHeaderHelper.FontSizeSmallCompact);

                    // Regime fiscale
                    if (!string.IsNullOrEmpty(data.Company.RegimeDescrizione))
                        col.Item().Text($"Regime: {data.Company.RegimeDescrizione}")
                            .FontSize(ReportHeaderHelper.FontSizeCaption).Italic();

                    // Capitale Sociale
                    if (!string.IsNullOrEmpty(data.Company.CapitaleSocialeDisplay))
                        col.Item().Text(data.Company.CapitaleSocialeDisplay)
                            .FontSize(ReportHeaderHelper.FontSizeCaption).Italic();
                });

                // Destra: Box FATTURA
                row.RelativeItem(2).AlignRight().Column(col =>
                {
                    col.Item().Background(ReportHeaderHelper.BrandColors.Primary).Padding(8).Column(box =>
                    {
                        box.Item().AlignCenter().Text("FATTURA")
                            .FontSize(ReportHeaderHelper.FontSizeHeaderCompact).Bold().FontColor(Colors.White);

                        if (!string.IsNullOrEmpty(data.NumeroDocumento))
                        {
                            box.Item().PaddingTop(3).AlignCenter()
                                .Text($"N. {data.NumeroDocumento}")
                                .FontSize(ReportHeaderHelper.FontSizeSubHeaderCompact).Bold().FontColor(Colors.White);
                        }

                        box.Item().PaddingTop(3).AlignCenter()
                            .Text($"Data: {data.DataDocumentoFormatted}")
                            .FontSize(ReportHeaderHelper.FontSizeBodyCompact).FontColor(Colors.White);

                        if (data.NumeroProtocolloIva.HasValue)
                        {
                            box.Item().PaddingTop(2).AlignCenter()
                                .Text($"Prot. IVA: {data.NumeroProtocolloDisplay}")
                                .FontSize(ReportHeaderHelper.FontSizeSmallCompact).FontColor(Colors.White);
                        }
                    });
                });
            });

            // Divider
            column.Item().PaddingVertical(5).LineHorizontal(1.5f).LineColor(ReportHeaderHelper.BrandColors.Primary);
        });
    }

    private static void ComposeContent(IContainer container, FatturaAttivaPrintData data)
    {
        container.Column(column =>
        {
            // SEZIONE DESTINATARIO
            ComposeClientSection(column, data);

            // SEZIONE CAUSALE (se presente)
            if (!string.IsNullOrEmpty(data.CausaleDescrizione))
            {
                column.Item().PaddingTop(5).Text(text =>
                {
                    text.Span("Causale: ").FontSize(ReportHeaderHelper.FontSizeSmallCompact).Bold();
                    text.Span(data.CausaleDescrizione).FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                });
            }

            // SEZIONE DETTAGLIO RIGHE
            column.Item().PaddingTop(8);
            ComposeLineItemsTable(column, data);

            // SEZIONE RIEPILOGO IVA
            if (data.RiepilogoIva.Any())
            {
                column.Item().PaddingTop(8);
                ComposeVatSummary(column, data);
            }

            // SEZIONE TOTALI
            column.Item().PaddingTop(8);
            ComposeTotals(column, data);

            // SEZIONE DATI BANCARI
            if (data.Bank != null)
            {
                column.Item().PaddingTop(10);
                ComposeBankInfo(column, data);
            }

            // SEZIONE SCADENZA E PAGAMENTO
            column.Item().PaddingTop(8);
            ComposePaymentInfo(column, data);

            // NOTE LEGALI
            ComposeNotices(column, data);
        });
    }

    private static void ComposeClientSection(ColumnDescriptor column, FatturaAttivaPrintData data)
    {
        column.Item().Row(row =>
        {
            // Spazio a sinistra
            row.RelativeItem(1);

            // Box destinatario a destra
            row.RelativeItem(2).Border(1).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(10).Column(box =>
            {
                box.Item().Text("DESTINATARIO").FontSize(ReportHeaderHelper.FontSizeSmallCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);
                box.Item().PaddingTop(3).Text(data.Client.RagioneSociale).FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();

                if (!string.IsNullOrEmpty(data.Client.Indirizzo))
                    box.Item().Text(data.Client.IndirizzoCompleto).FontSize(ReportHeaderHelper.FontSizeSmallCompact);

                var fiscaliCliente = new List<string>();
                if (!string.IsNullOrEmpty(data.Client.PartitaIva)) fiscaliCliente.Add($"P.IVA: {data.Client.PartitaIva}");
                if (!string.IsNullOrEmpty(data.Client.CodiceFiscale)) fiscaliCliente.Add($"C.F.: {data.Client.CodiceFiscale}");
                if (fiscaliCliente.Any())
                    box.Item().PaddingTop(2).Text(string.Join(" - ", fiscaliCliente)).FontSize(ReportHeaderHelper.FontSizeSmallCompact);

                var recapitiCliente = new List<string>();
                if (!string.IsNullOrEmpty(data.Client.CodiceSdi)) recapitiCliente.Add($"SDI: {data.Client.CodiceSdi}");
                if (!string.IsNullOrEmpty(data.Client.Pec)) recapitiCliente.Add($"PEC: {data.Client.Pec}");
                if (recapitiCliente.Any())
                    box.Item().Text(string.Join(" - ", recapitiCliente)).FontSize(ReportHeaderHelper.FontSizeSmallCompact);
            });
        });
    }

    private static void ComposeLineItemsTable(ColumnDescriptor column, FatturaAttivaPrintData data)
    {
        column.Item().Text("DETTAGLIO").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);

        column.Item().PaddingTop(3).Table(table =>
        {
            // Definizione colonne
            table.ColumnsDefinition(columns =>
            {
                columns.ConstantColumn(25);   // #
                columns.RelativeColumn(3f);   // Descrizione
                columns.ConstantColumn(60);   // Tipo
                columns.ConstantColumn(50);   // Aliquota
                columns.ConstantColumn(75);   // Imponibile
                columns.ConstantColumn(60);   // IVA
                columns.ConstantColumn(75);   // Totale
            });

            // Header
            table.Header(header =>
            {
                var headerStyle = QuestPDF.Infrastructure.TextStyle.Default.FontSize(ReportHeaderHelper.FontSizeSmallCompact).Bold().FontColor(Colors.White);

                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignCenter().Text("#").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Descrizione").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignCenter().Text("Tipo").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignCenter().Text("Aliq.").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignRight().Text("Imponibile").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignRight().Text("IVA").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignRight().Text("Totale").Style(headerStyle);
            });

            // Righe dati
            int rowIndex = 0;
            foreach (var riga in data.Righe)
            {
                var bgColor = rowIndex % 2 == 0 ? Colors.White : ReportHeaderHelper.BrandColors.LightGray;

                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border)
                    .Padding(3).AlignCenter().Text($"{riga.RigaNumero}").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border)
                    .Padding(3).Text(riga.RigaDescrizione).FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border)
                    .Padding(3).AlignCenter().Text(riga.TipoDisplay).FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border)
                    .Padding(3).AlignCenter().Text(riga.AliquotaDisplay).FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border)
                    .Padding(3).AlignRight().Text($"{riga.RigaImponibile:N2}").FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border)
                    .Padding(3).AlignRight().Text($"{riga.RigaIvaValore:N2}").FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border)
                    .Padding(3).AlignRight().Text($"{riga.RigaLordo:N2}").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();

                rowIndex++;
            }
        });
    }

    private static void ComposeVatSummary(ColumnDescriptor column, FatturaAttivaPrintData data)
    {
        column.Item().Text("RIEPILOGO IVA").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);

        column.Item().PaddingTop(3).Table(table =>
        {
            table.ColumnsDefinition(columns =>
            {
                columns.RelativeColumn(2f);   // Aliquota
                columns.ConstantColumn(90);    // Imponibile
                columns.ConstantColumn(80);    // IVA
                columns.ConstantColumn(90);    // Totale
            });

            // Header
            table.Header(header =>
            {
                var headerStyle = QuestPDF.Infrastructure.TextStyle.Default.FontSize(ReportHeaderHelper.FontSizeSmallCompact).Bold().FontColor(Colors.White);

                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Aliquota").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignRight().Text("Imponibile").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignRight().Text("IVA").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignRight().Text("Totale").Style(headerStyle);
            });

            int rowIndex = 0;
            foreach (var summary in data.RiepilogoIva)
            {
                var bgColor = rowIndex % 2 == 0 ? Colors.White : ReportHeaderHelper.BrandColors.LightGray;

                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border)
                    .Padding(3).Text(summary.AliquotaDisplay).FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border)
                    .Padding(3).AlignRight().Text($"{summary.TotaleImponibile:N2}").FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border)
                    .Padding(3).AlignRight().Text($"{summary.TotaleIva:N2}").FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border)
                    .Padding(3).AlignRight().Text($"{summary.TotaleLordo:N2}").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();

                rowIndex++;
            }
        });
    }

    private static void ComposeTotals(ColumnDescriptor column, FatturaAttivaPrintData data)
    {
        column.Item().Row(row =>
        {
            // Spazio a sinistra
            row.RelativeItem(2);

            // Box totali a destra
            row.RelativeItem(2).Border(1.5f).BorderColor(ReportHeaderHelper.BrandColors.Primary).Padding(8).Column(box =>
            {
                // Totale Imponibile
                box.Item().Row(r =>
                {
                    r.RelativeItem().Text("Totale Imponibile:").FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                    r.ConstantItem(100).AlignRight().Text($"EUR {data.ImponibileEur:N2}").FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                });

                // Totale IVA
                box.Item().PaddingTop(2).Row(r =>
                {
                    r.RelativeItem().Text("Totale IVA:").FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                    r.ConstantItem(100).AlignRight().Text($"EUR {data.IvaEur:N2}").FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                });

                // Separatore
                box.Item().PaddingVertical(3).LineHorizontal(1).LineColor(ReportHeaderHelper.BrandColors.Primary);

                // TOTALE FATTURA
                box.Item().Row(r =>
                {
                    r.RelativeItem().Text("TOTALE FATTURA:").FontSize(ReportHeaderHelper.FontSizeSubHeaderCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);
                    r.ConstantItem(100).AlignRight().Text($"EUR {data.LordoEur:N2}")
                        .FontSize(ReportHeaderHelper.FontSizeSubHeaderCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);
                });
            });
        });
    }

    private static void ComposeBankInfo(ColumnDescriptor column, FatturaAttivaPrintData data)
    {
        if (data.Bank == null) return;

        column.Item().Background(ReportHeaderHelper.BrandColors.IvaHeader).Padding(8).Column(box =>
        {
            box.Item().Text("DATI BANCARI PER IL PAGAMENTO").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);

            var bancaLabel = !string.IsNullOrEmpty(data.Bank.Filiale)
                ? $"{data.Bank.NomeBanca} - {data.Bank.Filiale}"
                : data.Bank.NomeBanca;
            box.Item().PaddingTop(3).Text(text =>
            {
                text.Span("Banca: ").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();
                text.Span(bancaLabel).FontSize(ReportHeaderHelper.FontSizeBodyCompact);
            });

            box.Item().Text(text =>
            {
                text.Span("IBAN: ").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();
                text.Span(FormatIban(data.Bank.Iban)).FontSize(ReportHeaderHelper.FontSizeBodyCompact);
            });

            if (!string.IsNullOrEmpty(data.Bank.SwiftBic))
            {
                box.Item().Text(text =>
                {
                    text.Span("SWIFT/BIC: ").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();
                    text.Span(data.Bank.SwiftBic).FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                });
            }
        });
    }

    private static void ComposePaymentInfo(ColumnDescriptor column, FatturaAttivaPrintData data)
    {
        column.Item().Background(ReportHeaderHelper.BrandColors.LightGray).Padding(8).Row(row =>
        {
            row.RelativeItem().Column(col =>
            {
                col.Item().Text(text =>
                {
                    text.Span("Data Scadenza: ").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();
                    text.Span(data.DataScadenzaFormatted).FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                });
            });

            row.RelativeItem().AlignRight().Column(col =>
            {
                col.Item().Text(text =>
                {
                    text.Span("Stato: ").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();
                    text.Span(data.StatoDisplay).FontSize(ReportHeaderHelper.FontSizeBodyCompact)
                        .FontColor(data.Stato == "PAGATO" ? ReportHeaderHelper.BrandColors.Success : ReportHeaderHelper.BrandColors.Accent);
                });
            });
        });
    }

    private static void ComposeNotices(ColumnDescriptor column, FatturaAttivaPrintData data)
    {
        // Nota regime forfettario
        if (!string.IsNullOrEmpty(data.ForfettarioNotice))
        {
            column.Item().PaddingTop(8).Border(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(6)
                .Text(data.ForfettarioNotice).FontSize(ReportHeaderHelper.FontSizeCaption).Italic().FontColor(ReportHeaderHelper.BrandColors.Secondary);
        }

        // Nota bollo
        if (!string.IsNullOrEmpty(data.BolloNotice))
        {
            column.Item().PaddingTop(4).Border(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(6)
                .Text(data.BolloNotice).FontSize(ReportHeaderHelper.FontSizeCaption).Italic().FontColor(ReportHeaderHelper.BrandColors.Secondary);
        }

        // Nota descrizione causale (come oggetto fattura, se presente)
        if (!string.IsNullOrEmpty(data.Causale))
        {
            column.Item().PaddingTop(6).Text(text =>
            {
                text.Span("Note: ").FontSize(ReportHeaderHelper.FontSizeSmallCompact).Bold();
                text.Span(data.Causale).FontSize(ReportHeaderHelper.FontSizeSmallCompact);
            });
        }
    }

    /// <summary>
    /// Formatta IBAN con spazi ogni 4 caratteri per leggibilità
    /// </summary>
    private static string FormatIban(string iban)
    {
        if (string.IsNullOrEmpty(iban)) return iban;
        var clean = iban.Replace(" ", "");
        var parts = new List<string>();
        for (int i = 0; i < clean.Length; i += 4)
        {
            parts.Add(clean.Substring(i, Math.Min(4, clean.Length - i)));
        }
        return string.Join(" ", parts);
    }
}
