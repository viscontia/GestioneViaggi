using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using IContainer = QuestPDF.Infrastructure.IContainer;
using Colors = QuestPDF.Helpers.Colors;
using GestioneViaggi.Models;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Generatore PDF per lo scadenzario pagamenti/incassi.
/// Focus su pianificazione finanziaria con classificazione per urgenza.
/// </summary>
public class ScadenzarioPrinter
{

    /// <summary>
    /// Determina il colore dell'urgenza
    /// </summary>
    private static string GetUrgenzaColor(string urgenza)
    {
        return urgenza switch
        {
            "SCADUTO" => ReportHeaderHelper.BrandColors.Danger,
            "URGENTE" => ReportHeaderHelper.BrandColors.Warning,
            "IN_SCADENZA" => ReportHeaderHelper.BrandColors.Secondary,
            "NORMALE" => ReportHeaderHelper.BrandColors.Success,
            _ => ReportHeaderHelper.BrandColors.Text
        };
    }

    public static async Task GeneratePdfAsync(ScadenzarioPrintData data, string outputPath)
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
                page.DefaultTextStyle(x => x.FontSize(ReportHeaderHelper.FontSizeBodyCompact).FontFamily("Lato").FontColor(ReportHeaderHelper.BrandColors.Text));

                page.Header().Element(header => ComposeHeader(header, data));
                page.Content().Element(content => ComposeContent(content, data));
                page.Footer().Element(footer => ComposeFooter(footer, data));
            });
        })
        .GeneratePdf(outputPath);
    }

    private static void ComposeHeader(IContainer container, ScadenzarioPrintData data)
    {
        container.Column(column =>
        {
            // Riga superiore: Logo/Azienda + Info Stampa
            column.Item().Row(row =>
            {
                // Sinistra: Logo/Azienda
                row.RelativeItem().Column(col =>
                {
                    if (data.Azienda.LogoData != null && data.Azienda.LogoData.Length > 0)
                    {
                        col.Item().MaxHeight(40).Image(data.Azienda.LogoData).FitArea();
                    }
                    else if (!string.IsNullOrEmpty(data.Azienda.RagioneSociale))
                    {
                        col.Item().Text(data.Azienda.RagioneSociale)
                            .FontSize(ReportHeaderHelper.FontSizeHeaderCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);
                    }

                    var infoParts = new List<string>();
                    if (!string.IsNullOrEmpty(data.Azienda.RagioneSociale)) infoParts.Add(data.Azienda.RagioneSociale);
                    if (!string.IsNullOrEmpty(data.Azienda.Piva)) infoParts.Add($"P.IVA: {data.Azienda.Piva}");
                    if (!string.IsNullOrEmpty(data.Azienda.Telefono)) infoParts.Add(data.Azienda.Telefono);

                    if (infoParts.Any())
                    {
                        col.Item().PaddingTop(2).Text(string.Join(" - ", infoParts)).FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                    }
                });

                // Destra: Info Stampa
                row.RelativeItem().AlignRight().Column(col =>
                {
                    col.Item().Text($"Stampato il: {data.DataStampa:dd/MM/yyyy HH:mm}")
                        .FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                    col.Item().Text($"Da: {data.UtenteStampa}")
                        .FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                    col.Item().Text($"Valuta: {data.ValutaTargetCodiceIso}")
                        .FontSize(ReportHeaderHelper.FontSizeSmallCompact).Bold();
                });
            });

            // Titolo centrato
            column.Item().PaddingVertical(10).AlignCenter().Column(col =>
            {
                col.Item().Text("SCADENZARIO PAGAMENTI/INCASSI")
                    .FontSize(ReportHeaderHelper.FontSizeHeaderCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Accent);

                if (!string.IsNullOrEmpty(data.Filtri.CausaleCiclo))
                {
                    var cicloLabel = data.Filtri.CausaleCiclo == "ATTIVO" ? "Entrate (Clienti)" : "Uscite (Fornitori)";
                    col.Item().Text(cicloLabel)
                        .FontSize(10).FontColor(ReportHeaderHelper.BrandColors.Secondary);
                }
            });

            // Filtri applicati
            if (data.Filtri.HasAnyFilter)
            {
                column.Item().PaddingTop(5).Background(ReportHeaderHelper.BrandColors.LightGray).Padding(5).Row(row =>
                {
                    row.RelativeItem().Text(text =>
                    {
                        text.Span("Filtri: ").Bold().FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                        var filters = new List<string>();

                        if (!string.IsNullOrEmpty(data.Filtri.Controparte))
                            filters.Add($"Controparte: {data.Filtri.Controparte}");
                        if (!string.IsNullOrEmpty(data.Filtri.Urgenza))
                            filters.Add($"Urgenza: {data.Filtri.Urgenza}");
                        if (!string.IsNullOrEmpty(data.Filtri.DataScadenzaDal) || !string.IsNullOrEmpty(data.Filtri.DataScadenzaAl))
                            filters.Add($"Scadenza: {data.Filtri.DataScadenzaDal ?? "..."} - {data.Filtri.DataScadenzaAl ?? "..."}");
                        if (!string.IsNullOrEmpty(data.Filtri.Viaggio))
                            filters.Add($"Viaggio: {data.Filtri.Viaggio}");
                        if (data.Filtri.Checkbox.Any())
                            filters.AddRange(data.Filtri.Checkbox);

                        text.Span(string.Join(" | ", filters)).FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                    });
                });
            }

            column.Item().PaddingTop(5).LineHorizontal(1).LineColor(ReportHeaderHelper.BrandColors.Border);
        });
    }

    private static void ComposeContent(IContainer container, ScadenzarioPrintData data)
    {
        container.PaddingTop(5).Column(column =>
        {
            if (!data.Dettagli.Any())
            {
                column.Item().AlignCenter().Padding(50).Text("Nessuna scadenza trovata con i filtri applicati.")
                    .FontSize(ReportHeaderHelper.FontSizeSubHeaderCompact).Italic().FontColor(ReportHeaderHelper.BrandColors.Secondary);
                return;
            }

            // Raggruppa per GruppoChiave e itera
            var gruppi = data.Dettagli.GroupBy(d => new { d.GruppoChiave, d.GruppoDisplay, d.GruppoOrdine })
                .OrderBy(g => g.Key.GruppoOrdine)
                .ThenBy(g => g.Key.GruppoChiave);

            foreach (var gruppo in gruppi)
            {
                ComposeGroupTable(column, gruppo.Key.GruppoDisplay, gruppo.ToList(), data);
            }

            // Totali generali
            column.Item().PaddingTop(10);
            ComposeTotaliGenerali(column, data);

            // Legenda colori
            ComposeLegenda(column);
        });
    }

    private static void ComposeGroupTable(ColumnDescriptor column, string gruppoDisplay, List<ScadenzarioItem> items, ScadenzarioPrintData data)
    {
        column.Item().Table(table =>
        {
            // Definizione colonne
            table.ColumnsDefinition(columns =>
            {
                columns.ConstantColumn(55);  // Data Scadenza
                columns.RelativeColumn(1.5f); // Controparte
                columns.ConstantColumn(50);  // Causale
                columns.ConstantColumn(70);  // Num. Doc
                columns.ConstantColumn(60);  // Ciclo
                columns.ConstantColumn(70);  // Importo Orig
                columns.ConstantColumn(70);  // Residuo
                columns.ConstantColumn(45);  // Giorni
                columns.ConstantColumn(50);  // Stato
                columns.RelativeColumn(1.0f); // Viaggio
            });

            // Header
            table.Header(header =>
            {
                // Riga 1: Nome Gruppo
                header.Cell().ColumnSpan(10).Background(ReportHeaderHelper.BrandColors.GroupHeader).Padding(4)
                    .Text(gruppoDisplay ?? "-").FontSize(ReportHeaderHelper.FontSizeSubHeaderCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);

                // Riga 2: Intestazioni colonne
                var headerStyle = QuestPDF.Infrastructure.TextStyle.Default.FontSize(ReportHeaderHelper.FontSizeSmallCompact).Bold().FontColor(Colors.White);

                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Scadenza").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Controparte").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Causale").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Doc N°").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Tipo").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignRight().Text("Importo").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignRight().Text("Residuo").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignCenter().Text("Gg").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Stato").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Viaggio").Style(headerStyle);
            });

            // Righe dati
            int rowIndex = 0;
            foreach (var item in items)
            {
                var bgColor = rowIndex % 2 == 0 ? Colors.White : ReportHeaderHelper.BrandColors.LightGray;
                var urgenzaColor = GetUrgenzaColor(item.Urgenza);
                var cicloColor = item.CausaleCiclo == "ATTIVO" ? ReportHeaderHelper.BrandColors.Success : ReportHeaderHelper.BrandColors.Accent;

                // Data Scadenza (con colore urgenza)
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2)
                    .Text(item.DataScadenza?.ToString("dd/MM/yy") ?? "-")
                    .FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold().FontColor(urgenzaColor);

                // Controparte
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2)
                    .Text(item.ControparteRagioneSociale).FontSize(ReportHeaderHelper.FontSizeBodyCompact);

                // Causale
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2)
                    .Text(TruncateText(item.CausaleDescrizione, 8)).FontSize(ReportHeaderHelper.FontSizeSmallCompact);

                // Numero Documento
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2)
                    .Text(item.NumeroDocumento ?? "-").FontSize(ReportHeaderHelper.FontSizeBodyCompact);

                // Ciclo (ATTIVO/PASSIVO)
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2)
                    .Text(item.CausaleCiclo == "ATTIVO" ? "Entrata" : "Uscita")
                    .FontSize(ReportHeaderHelper.FontSizeSmallCompact).FontColor(cicloColor).Bold();

                // Importo Originale
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).AlignRight()
                    .Text($"{Math.Abs(item.ImportoOriginale):N2}").FontSize(ReportHeaderHelper.FontSizeBodyCompact);

                // Residuo (evidenziato)
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).AlignRight()
                    .Text($"{Math.Abs(item.Residuo):N2}").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold().FontColor(cicloColor);

                // Giorni a Scadenza (con segno e colore)
                var giorniText = item.GiorniAScadenza >= 0 ? $"+{item.GiorniAScadenza}" : item.GiorniAScadenza.ToString();
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).AlignCenter()
                    .Text(giorniText).FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold().FontColor(urgenzaColor);

                // Stato
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2)
                    .Text(GetStatoDisplay(item.Stato)).FontSize(ReportHeaderHelper.FontSizeSmallCompact);

                // Viaggio
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2)
                    .Text(TruncateText(item.ViaggioDescrizione, 20)).FontSize(ReportHeaderHelper.FontSizeSmallCompact);

                rowIndex++;
            }
        });

        // Subtotali del gruppo
        var subtotale = data.Subtotali.FirstOrDefault(s => s.GruppoDisplay == gruppoDisplay);
        if (subtotale != null)
        {
            ComposeGroupSubtotals(column, subtotale);
        }

        column.Item().PaddingVertical(3);
    }

    private static void ComposeGroupSubtotals(ColumnDescriptor column, ScadenzarioSubTotale subtotale)
    {
        column.Item().Background(ReportHeaderHelper.BrandColors.SubTotal).Padding(4).Row(row =>
        {
            row.RelativeItem().Column(col =>
            {
                col.Item().Text($"Riepilogo {subtotale.GruppoDisplay}").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();
                col.Item().Text($"{subtotale.ConteggioTransazioni} scadenze").FontSize(ReportHeaderHelper.FontSizeSmallCompact).Italic();
            });

            row.RelativeItem().AlignRight().Table(t =>
            {
                t.ColumnsDefinition(c =>
                {
                    c.ConstantColumn(120);
                    c.ConstantColumn(90);
                });

                // Entrate previste
                t.Cell().Text("Entrate previste (+):").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                t.Cell().AlignRight().Text($"{subtotale.TotaleAttivo:N2}").FontSize(ReportHeaderHelper.FontSizeSmallCompact)
                    .FontColor(ReportHeaderHelper.BrandColors.Success).Bold();

                // Uscite previste
                t.Cell().Text("Uscite previste (-):").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                t.Cell().AlignRight().Text($"{subtotale.TotalePassivo:N2}").FontSize(ReportHeaderHelper.FontSizeSmallCompact)
                    .FontColor(ReportHeaderHelper.BrandColors.Accent).Bold();

                // Saldo netto
                t.Cell().PaddingTop(2).Text("Saldo netto:").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();
                var saldoColor = subtotale.SaldoNetto >= 0 ? ReportHeaderHelper.BrandColors.Success : ReportHeaderHelper.BrandColors.Danger;
                t.Cell().PaddingTop(2).AlignRight().Text($"{subtotale.SaldoNetto:N2}").FontSize(ReportHeaderHelper.FontSizeBodyCompact)
                    .FontColor(saldoColor).Bold();
            });
        });
    }

    private static void ComposeTotaliGenerali(ColumnDescriptor column, ScadenzarioPrintData data)
    {
        var totaleGen = data.Subtotali.FirstOrDefault(s => s.IsTotaleGenerale);
        if (totaleGen == null) return;

        column.Item().Background(ReportHeaderHelper.BrandColors.Total).Border(1).BorderColor(ReportHeaderHelper.BrandColors.Primary).Padding(5).Column(totCol =>
        {
            totCol.Item().Text("CASH FLOW - PREVISIONE FINANZIARIA")
                .FontSize(ReportHeaderHelper.FontSizeSubHeaderCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);

            totCol.Item().PaddingTop(5).Row(row =>
            {
                // Colonna Entrate
                row.RelativeItem().Column(col =>
                {
                    col.Item().Text("Entrate Previste").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Success);
                    col.Item().Text($"{data.TotaleGeneraleAttivo:N2} {data.ValutaTargetCodiceIso}")
                        .FontSize(ReportHeaderHelper.FontSizeHeaderCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Success);
                });

                // Colonna Uscite
                row.RelativeItem().Column(col =>
                {
                    col.Item().Text("Uscite Previste").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Accent);
                    col.Item().Text($"{data.TotaleGeneralePassivo:N2} {data.ValutaTargetCodiceIso}")
                        .FontSize(ReportHeaderHelper.FontSizeHeaderCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Accent);
                });

                // Colonna Saldo Netto
                row.RelativeItem().Column(col =>
                {
                    col.Item().Text("Saldo Netto").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();
                    var saldoColor = data.SaldoNetto >= 0 ? ReportHeaderHelper.BrandColors.Success : ReportHeaderHelper.BrandColors.Danger;
                    col.Item().Text($"{data.SaldoNetto:N2} {data.ValutaTargetCodiceIso}")
                        .FontSize(ReportHeaderHelper.FontSizeHeaderCompact).Bold().FontColor(saldoColor);

                    var label = data.SaldoNetto >= 0 ? "Disponibilità positiva" : "Scoperto previsto";
                    col.Item().Text(label).FontSize(ReportHeaderHelper.FontSizeSmallCompact).Italic().FontColor(saldoColor);
                });
            });

            totCol.Item().PaddingTop(3).Text($"Totale {totaleGen.ConteggioTransazioni} scadenze analizzate")
                .FontSize(ReportHeaderHelper.FontSizeSmallCompact).Italic().FontColor(ReportHeaderHelper.BrandColors.Secondary);
        });
    }

    private static void ComposeLegenda(ColumnDescriptor column)
    {
        column.Item().PaddingTop(10).Row(row =>
        {
            row.RelativeItem().Text(text =>
            {
                text.Span("Legenda urgenza: ").FontSize(ReportHeaderHelper.FontSizeSmallCompact).Bold();
                text.Span("SCADUTO ").FontSize(ReportHeaderHelper.FontSizeSmallCompact).FontColor(ReportHeaderHelper.BrandColors.Danger).Bold();
                text.Span("| ").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                text.Span("URGENTE (≤7gg) ").FontSize(ReportHeaderHelper.FontSizeSmallCompact).FontColor(ReportHeaderHelper.BrandColors.Warning).Bold();
                text.Span("| ").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                text.Span("IN_SCADENZA (≤30gg) ").FontSize(ReportHeaderHelper.FontSizeSmallCompact).FontColor(ReportHeaderHelper.BrandColors.Secondary).Bold();
                text.Span("| ").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                text.Span("NORMALE ").FontSize(ReportHeaderHelper.FontSizeSmallCompact).FontColor(ReportHeaderHelper.BrandColors.Success).Bold();
            });
        });
    }

    private static void ComposeFooter(IContainer container, ScadenzarioPrintData data)
    {
        container.AlignCenter().Row(row =>
        {
            row.RelativeItem().Text(text =>
            {
                text.Span("Documento generato con ").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                text.Span("GestioneViaggi").FontSize(ReportHeaderHelper.FontSizeSmallCompact).Bold();
            });

            row.ConstantItem(100).AlignRight().Text(t =>
            {
                t.Span("Pagina ").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                t.CurrentPageNumber().FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                t.Span(" di ").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                t.TotalPages().FontSize(ReportHeaderHelper.FontSizeSmallCompact);
            });
        });
    }

    private static string TruncateText(string? text, int maxLength)
    {
        if (string.IsNullOrEmpty(text)) return "-";
        return text.Length <= maxLength ? text : text.Substring(0, maxLength - 1) + "…";
    }

    private static string GetStatoDisplay(string stato)
    {
        return stato switch
        {
            "DA_PAGARE" => "Da Pag.",
            "PARZIALMENTE_PAGATO" => "Parziale",
            "PAGATO" => "Pagato",
            _ => stato
        };
    }
}
