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
    // Colori brand (coerenti con gli altri report)
    private static class BrandColors
    {
        public static readonly string Primary = "#2B3A42";
        public static readonly string Secondary = "#8D99AE";
        public static readonly string Accent = "#E74C3C";
        public static readonly string Text = "#000000";
        public static readonly string LightGray = "#F0F0F0";
        public static readonly string Border = "#CCCCCC";
        public static readonly string Success = "#27AE60";
        public static readonly string Total = "#DAE8FC";
        public static readonly string IvaHeader = "#E1F5FE";
    }

    // Costanti layout
    private const float FontSizeTitle = 16;
    private const float FontSizeSubTitle = 12;
    private const float FontSizeBody = 9;
    private const float FontSizeSmall = 8;
    private const float FontSizeCaption = 7;

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
                page.DefaultTextStyle(x => x.FontSize(FontSizeBody).FontFamily("Lato").FontColor(BrandColors.Text));

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
                            .FontSize(FontSizeTitle).Bold().FontColor(BrandColors.Primary);
                    }

                    // Ragione Sociale + Forma Giuridica
                    var denominazione = !string.IsNullOrEmpty(data.Company.FormaGiuridica)
                        ? $"{data.Company.RagioneSociale} {data.Company.FormaGiuridica}"
                        : data.Company.RagioneSociale;
                    col.Item().PaddingTop(2).Text(denominazione).FontSize(FontSizeBody).Bold();

                    // Indirizzo
                    col.Item().Text($"{data.Company.IndirizzoCompleto} - {data.Company.CittaCompleta}")
                        .FontSize(FontSizeSmall);

                    // P.IVA e C.F.
                    var fiscali = new List<string>();
                    if (!string.IsNullOrEmpty(data.Company.PartitaIva)) fiscali.Add($"P.IVA: {data.Company.PartitaIva}");
                    if (!string.IsNullOrEmpty(data.Company.CodiceFiscale)) fiscali.Add($"C.F.: {data.Company.CodiceFiscale}");
                    if (fiscali.Any())
                        col.Item().Text(string.Join(" - ", fiscali)).FontSize(FontSizeSmall);

                    // REA + SDI
                    var extra = new List<string>();
                    if (!string.IsNullOrEmpty(data.Company.ReaDisplay)) extra.Add(data.Company.ReaDisplay);
                    if (!string.IsNullOrEmpty(data.Company.CodiceSdi)) extra.Add($"SDI: {data.Company.CodiceSdi}");
                    if (extra.Any())
                        col.Item().Text(string.Join(" - ", extra)).FontSize(FontSizeSmall);

                    // Contatti
                    var contatti = new List<string>();
                    if (!string.IsNullOrEmpty(data.Company.Telefono)) contatti.Add($"Tel: {data.Company.Telefono}");
                    if (!string.IsNullOrEmpty(data.Company.Pec)) contatti.Add($"PEC: {data.Company.Pec}");
                    if (!string.IsNullOrEmpty(data.Company.SitoWeb)) contatti.Add(data.Company.SitoWeb);
                    if (contatti.Any())
                        col.Item().Text(string.Join(" - ", contatti)).FontSize(FontSizeSmall);

                    // Regime fiscale
                    if (!string.IsNullOrEmpty(data.Company.RegimeDescrizione))
                        col.Item().Text($"Regime: {data.Company.RegimeDescrizione}")
                            .FontSize(FontSizeCaption).Italic();

                    // Capitale Sociale
                    if (!string.IsNullOrEmpty(data.Company.CapitaleSocialeDisplay))
                        col.Item().Text(data.Company.CapitaleSocialeDisplay)
                            .FontSize(FontSizeCaption).Italic();
                });

                // Destra: Box FATTURA
                row.RelativeItem(2).AlignRight().Column(col =>
                {
                    col.Item().Background(BrandColors.Primary).Padding(8).Column(box =>
                    {
                        box.Item().AlignCenter().Text("FATTURA")
                            .FontSize(FontSizeTitle).Bold().FontColor(Colors.White);

                        if (!string.IsNullOrEmpty(data.NumeroDocumento))
                        {
                            box.Item().PaddingTop(3).AlignCenter()
                                .Text($"N. {data.NumeroDocumento}")
                                .FontSize(FontSizeSubTitle).Bold().FontColor(Colors.White);
                        }

                        box.Item().PaddingTop(3).AlignCenter()
                            .Text($"Data: {data.DataDocumentoFormatted}")
                            .FontSize(FontSizeBody).FontColor(Colors.White);

                        if (data.NumeroProtocolloIva.HasValue)
                        {
                            box.Item().PaddingTop(2).AlignCenter()
                                .Text($"Prot. IVA: {data.NumeroProtocolloDisplay}")
                                .FontSize(FontSizeSmall).FontColor(Colors.White);
                        }
                    });
                });
            });

            // Divider
            column.Item().PaddingVertical(5).LineHorizontal(1.5f).LineColor(BrandColors.Primary);
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
                    text.Span("Causale: ").FontSize(FontSizeSmall).Bold();
                    text.Span(data.CausaleDescrizione).FontSize(FontSizeSmall);
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
            row.RelativeItem(2).Border(1).BorderColor(BrandColors.Border).Padding(10).Column(box =>
            {
                box.Item().Text("DESTINATARIO").FontSize(FontSizeSmall).Bold().FontColor(BrandColors.Primary);
                box.Item().PaddingTop(3).Text(data.Client.RagioneSociale).FontSize(FontSizeBody).Bold();

                if (!string.IsNullOrEmpty(data.Client.Indirizzo))
                    box.Item().Text(data.Client.IndirizzoCompleto).FontSize(FontSizeSmall);

                var fiscaliCliente = new List<string>();
                if (!string.IsNullOrEmpty(data.Client.PartitaIva)) fiscaliCliente.Add($"P.IVA: {data.Client.PartitaIva}");
                if (!string.IsNullOrEmpty(data.Client.CodiceFiscale)) fiscaliCliente.Add($"C.F.: {data.Client.CodiceFiscale}");
                if (fiscaliCliente.Any())
                    box.Item().PaddingTop(2).Text(string.Join(" - ", fiscaliCliente)).FontSize(FontSizeSmall);

                var recapitiCliente = new List<string>();
                if (!string.IsNullOrEmpty(data.Client.CodiceSdi)) recapitiCliente.Add($"SDI: {data.Client.CodiceSdi}");
                if (!string.IsNullOrEmpty(data.Client.Pec)) recapitiCliente.Add($"PEC: {data.Client.Pec}");
                if (recapitiCliente.Any())
                    box.Item().Text(string.Join(" - ", recapitiCliente)).FontSize(FontSizeSmall);
            });
        });
    }

    private static void ComposeLineItemsTable(ColumnDescriptor column, FatturaAttivaPrintData data)
    {
        column.Item().Text("DETTAGLIO").FontSize(FontSizeBody).Bold().FontColor(BrandColors.Primary);

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
                var headerStyle = QuestPDF.Infrastructure.TextStyle.Default.FontSize(FontSizeSmall).Bold().FontColor(Colors.White);

                header.Cell().Background(BrandColors.Primary).Padding(3).AlignCenter().Text("#").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Descrizione").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignCenter().Text("Tipo").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignCenter().Text("Aliq.").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("Imponibile").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("IVA").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("Totale").Style(headerStyle);
            });

            // Righe dati
            int rowIndex = 0;
            foreach (var riga in data.Righe)
            {
                var bgColor = rowIndex % 2 == 0 ? Colors.White : BrandColors.LightGray;

                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border)
                    .Padding(3).AlignCenter().Text($"{riga.RigaNumero}").FontSize(FontSizeSmall);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border)
                    .Padding(3).Text(riga.RigaDescrizione).FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border)
                    .Padding(3).AlignCenter().Text(riga.TipoDisplay).FontSize(FontSizeSmall);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border)
                    .Padding(3).AlignCenter().Text(riga.AliquotaDisplay).FontSize(FontSizeSmall);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border)
                    .Padding(3).AlignRight().Text($"{riga.RigaImponibile:N2}").FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border)
                    .Padding(3).AlignRight().Text($"{riga.RigaIvaValore:N2}").FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border)
                    .Padding(3).AlignRight().Text($"{riga.RigaLordo:N2}").FontSize(FontSizeBody).Bold();

                rowIndex++;
            }
        });
    }

    private static void ComposeVatSummary(ColumnDescriptor column, FatturaAttivaPrintData data)
    {
        column.Item().Text("RIEPILOGO IVA").FontSize(FontSizeBody).Bold().FontColor(BrandColors.Primary);

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
                var headerStyle = QuestPDF.Infrastructure.TextStyle.Default.FontSize(FontSizeSmall).Bold().FontColor(Colors.White);

                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Aliquota").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("Imponibile").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("IVA").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("Totale").Style(headerStyle);
            });

            int rowIndex = 0;
            foreach (var summary in data.RiepilogoIva)
            {
                var bgColor = rowIndex % 2 == 0 ? Colors.White : BrandColors.LightGray;

                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border)
                    .Padding(3).Text(summary.AliquotaDisplay).FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border)
                    .Padding(3).AlignRight().Text($"{summary.TotaleImponibile:N2}").FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border)
                    .Padding(3).AlignRight().Text($"{summary.TotaleIva:N2}").FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border)
                    .Padding(3).AlignRight().Text($"{summary.TotaleLordo:N2}").FontSize(FontSizeBody).Bold();

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
            row.RelativeItem(2).Border(1.5f).BorderColor(BrandColors.Primary).Padding(8).Column(box =>
            {
                // Totale Imponibile
                box.Item().Row(r =>
                {
                    r.RelativeItem().Text("Totale Imponibile:").FontSize(FontSizeBody);
                    r.ConstantItem(100).AlignRight().Text($"EUR {data.ImponibileEur:N2}").FontSize(FontSizeBody);
                });

                // Totale IVA
                box.Item().PaddingTop(2).Row(r =>
                {
                    r.RelativeItem().Text("Totale IVA:").FontSize(FontSizeBody);
                    r.ConstantItem(100).AlignRight().Text($"EUR {data.IvaEur:N2}").FontSize(FontSizeBody);
                });

                // Separatore
                box.Item().PaddingVertical(3).LineHorizontal(1).LineColor(BrandColors.Primary);

                // TOTALE FATTURA
                box.Item().Row(r =>
                {
                    r.RelativeItem().Text("TOTALE FATTURA:").FontSize(FontSizeSubTitle).Bold().FontColor(BrandColors.Primary);
                    r.ConstantItem(100).AlignRight().Text($"EUR {data.LordoEur:N2}")
                        .FontSize(FontSizeSubTitle).Bold().FontColor(BrandColors.Primary);
                });
            });
        });
    }

    private static void ComposeBankInfo(ColumnDescriptor column, FatturaAttivaPrintData data)
    {
        if (data.Bank == null) return;

        column.Item().Background(BrandColors.IvaHeader).Padding(8).Column(box =>
        {
            box.Item().Text("DATI BANCARI PER IL PAGAMENTO").FontSize(FontSizeBody).Bold().FontColor(BrandColors.Primary);

            var bancaLabel = !string.IsNullOrEmpty(data.Bank.Filiale)
                ? $"{data.Bank.NomeBanca} - {data.Bank.Filiale}"
                : data.Bank.NomeBanca;
            box.Item().PaddingTop(3).Text(text =>
            {
                text.Span("Banca: ").FontSize(FontSizeBody).Bold();
                text.Span(bancaLabel).FontSize(FontSizeBody);
            });

            box.Item().Text(text =>
            {
                text.Span("IBAN: ").FontSize(FontSizeBody).Bold();
                text.Span(FormatIban(data.Bank.Iban)).FontSize(FontSizeBody);
            });

            if (!string.IsNullOrEmpty(data.Bank.SwiftBic))
            {
                box.Item().Text(text =>
                {
                    text.Span("SWIFT/BIC: ").FontSize(FontSizeBody).Bold();
                    text.Span(data.Bank.SwiftBic).FontSize(FontSizeBody);
                });
            }
        });
    }

    private static void ComposePaymentInfo(ColumnDescriptor column, FatturaAttivaPrintData data)
    {
        column.Item().Background(BrandColors.LightGray).Padding(8).Row(row =>
        {
            row.RelativeItem().Column(col =>
            {
                col.Item().Text(text =>
                {
                    text.Span("Data Scadenza: ").FontSize(FontSizeBody).Bold();
                    text.Span(data.DataScadenzaFormatted).FontSize(FontSizeBody);
                });
            });

            row.RelativeItem().AlignRight().Column(col =>
            {
                col.Item().Text(text =>
                {
                    text.Span("Stato: ").FontSize(FontSizeBody).Bold();
                    text.Span(data.StatoDisplay).FontSize(FontSizeBody)
                        .FontColor(data.Stato == "PAGATO" ? BrandColors.Success : BrandColors.Accent);
                });
            });
        });
    }

    private static void ComposeNotices(ColumnDescriptor column, FatturaAttivaPrintData data)
    {
        // Nota regime forfettario
        if (!string.IsNullOrEmpty(data.ForfettarioNotice))
        {
            column.Item().PaddingTop(8).Border(0.5f).BorderColor(BrandColors.Border).Padding(6)
                .Text(data.ForfettarioNotice).FontSize(FontSizeCaption).Italic().FontColor(BrandColors.Secondary);
        }

        // Nota bollo
        if (!string.IsNullOrEmpty(data.BolloNotice))
        {
            column.Item().PaddingTop(4).Border(0.5f).BorderColor(BrandColors.Border).Padding(6)
                .Text(data.BolloNotice).FontSize(FontSizeCaption).Italic().FontColor(BrandColors.Secondary);
        }

        // Nota descrizione causale (come oggetto fattura, se presente)
        if (!string.IsNullOrEmpty(data.Causale))
        {
            column.Item().PaddingTop(6).Text(text =>
            {
                text.Span("Note: ").FontSize(FontSizeSmall).Bold();
                text.Span(data.Causale).FontSize(FontSizeSmall);
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
