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
    private static class BrandColors
    {
        public static readonly string Primary = "#2B3A42";    // Dark Slate
        public static readonly string Secondary = "#8D99AE";  // Cool Grey
        public static readonly string Accent = "#E74C3C";     // Red (Urgente/Scaduto)
        public static readonly string Text = "#000000";
        public static readonly string LightGray = "#F0F0F0";
        public static readonly string Border = "#CCCCCC";
        public static readonly string GroupHeader = "#D5E8D4"; // Verde chiaro
        public static readonly string SubTotal = "#FFF2CC";    // Giallo chiaro
        public static readonly string Total = "#DAE8FC";       // Blu chiaro
        public static readonly string Success = "#27AE60";     // Verde (Entrate)
        public static readonly string Warning = "#F39C12";     // Arancione (Urgente)
        public static readonly string Danger = "#C0392B";      // Rosso scuro (Scaduto)
    }

    private const float FontSizeHeader = 16;
    private const float FontSizeSubHeader = 11;
    private const float FontSizeBody = 8;
    private const float FontSizeSmall = 7;

    /// <summary>
    /// Determina il colore dell'urgenza
    /// </summary>
    private static string GetUrgenzaColor(string urgenza)
    {
        return urgenza switch
        {
            "SCADUTO" => BrandColors.Danger,
            "URGENTE" => BrandColors.Warning,
            "IN_SCADENZA" => BrandColors.Secondary,
            "NORMALE" => BrandColors.Success,
            _ => BrandColors.Text
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
                page.DefaultTextStyle(x => x.FontSize(FontSizeBody).FontFamily("Lato").FontColor(BrandColors.Text));

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
                            .FontSize(FontSizeHeader).Bold().FontColor(BrandColors.Primary);
                    }

                    var infoParts = new List<string>();
                    if (!string.IsNullOrEmpty(data.Azienda.RagioneSociale)) infoParts.Add(data.Azienda.RagioneSociale);
                    if (!string.IsNullOrEmpty(data.Azienda.Piva)) infoParts.Add($"P.IVA: {data.Azienda.Piva}");
                    if (!string.IsNullOrEmpty(data.Azienda.Telefono)) infoParts.Add(data.Azienda.Telefono);

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
                    col.Item().Text($"Valuta: {data.ValutaTargetCodiceIso}")
                        .FontSize(FontSizeSmall).Bold();
                });
            });

            // Titolo centrato
            column.Item().PaddingVertical(10).AlignCenter().Column(col =>
            {
                col.Item().Text("SCADENZARIO PAGAMENTI/INCASSI")
                    .FontSize(FontSizeHeader).Bold().FontColor(BrandColors.Accent);

                if (!string.IsNullOrEmpty(data.Filtri.CausaleCiclo))
                {
                    var cicloLabel = data.Filtri.CausaleCiclo == "ATTIVO" ? "Entrate (Clienti)" : "Uscite (Fornitori)";
                    col.Item().Text(cicloLabel)
                        .FontSize(10).FontColor(BrandColors.Secondary);
                }
            });

            // Filtri applicati
            if (data.Filtri.HasAnyFilter)
            {
                column.Item().PaddingTop(5).Background(BrandColors.LightGray).Padding(5).Row(row =>
                {
                    row.RelativeItem().Text(text =>
                    {
                        text.Span("Filtri: ").Bold().FontSize(FontSizeSmall);
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

                        text.Span(string.Join(" | ", filters)).FontSize(FontSizeSmall);
                    });
                });
            }

            column.Item().PaddingTop(5).LineHorizontal(1).LineColor(BrandColors.Border);
        });
    }

    private static void ComposeContent(IContainer container, ScadenzarioPrintData data)
    {
        container.PaddingTop(5).Column(column =>
        {
            if (!data.Dettagli.Any())
            {
                column.Item().AlignCenter().Padding(50).Text("Nessuna scadenza trovata con i filtri applicati.")
                    .FontSize(FontSizeSubHeader).Italic().FontColor(BrandColors.Secondary);
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
                header.Cell().ColumnSpan(10).Background(BrandColors.GroupHeader).Padding(4)
                    .Text(gruppoDisplay ?? "-").FontSize(FontSizeSubHeader).Bold().FontColor(BrandColors.Primary);

                // Riga 2: Intestazioni colonne
                var headerStyle = QuestPDF.Infrastructure.TextStyle.Default.FontSize(FontSizeSmall).Bold().FontColor(Colors.White);

                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Scadenza").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Controparte").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Causale").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Doc N°").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Tipo").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("Importo").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("Residuo").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignCenter().Text("Gg").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Stato").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Viaggio").Style(headerStyle);
            });

            // Righe dati
            int rowIndex = 0;
            foreach (var item in items)
            {
                var bgColor = rowIndex % 2 == 0 ? Colors.White : BrandColors.LightGray;
                var urgenzaColor = GetUrgenzaColor(item.Urgenza);
                var cicloColor = item.CausaleCiclo == "ATTIVO" ? BrandColors.Success : BrandColors.Accent;

                // Data Scadenza (con colore urgenza)
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2)
                    .Text(item.DataScadenza?.ToString("dd/MM/yy") ?? "-")
                    .FontSize(FontSizeBody).Bold().FontColor(urgenzaColor);

                // Controparte
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2)
                    .Text(item.ControparteRagioneSociale).FontSize(FontSizeBody);

                // Causale
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2)
                    .Text(TruncateText(item.CausaleDescrizione, 8)).FontSize(FontSizeSmall);

                // Numero Documento
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2)
                    .Text(item.NumeroDocumento ?? "-").FontSize(FontSizeBody);

                // Ciclo (ATTIVO/PASSIVO)
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2)
                    .Text(item.CausaleCiclo == "ATTIVO" ? "Entrata" : "Uscita")
                    .FontSize(FontSizeSmall).FontColor(cicloColor).Bold();

                // Importo Originale
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).AlignRight()
                    .Text($"{Math.Abs(item.ImportoOriginale):N2}").FontSize(FontSizeBody);

                // Residuo (evidenziato)
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).AlignRight()
                    .Text($"{Math.Abs(item.Residuo):N2}").FontSize(FontSizeBody).Bold().FontColor(cicloColor);

                // Giorni a Scadenza (con segno e colore)
                var giorniText = item.GiorniAScadenza >= 0 ? $"+{item.GiorniAScadenza}" : item.GiorniAScadenza.ToString();
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).AlignCenter()
                    .Text(giorniText).FontSize(FontSizeBody).Bold().FontColor(urgenzaColor);

                // Stato
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2)
                    .Text(GetStatoDisplay(item.Stato)).FontSize(FontSizeSmall);

                // Viaggio
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2)
                    .Text(TruncateText(item.ViaggioDescrizione, 20)).FontSize(FontSizeSmall);

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
        column.Item().Background(BrandColors.SubTotal).Padding(4).Row(row =>
        {
            row.RelativeItem().Column(col =>
            {
                col.Item().Text($"Riepilogo {subtotale.GruppoDisplay}").FontSize(FontSizeBody).Bold();
                col.Item().Text($"{subtotale.ConteggioTransazioni} scadenze").FontSize(FontSizeSmall).Italic();
            });

            row.RelativeItem().AlignRight().Table(t =>
            {
                t.ColumnsDefinition(c =>
                {
                    c.ConstantColumn(120);
                    c.ConstantColumn(90);
                });

                // Entrate previste
                t.Cell().Text("Entrate previste (+):").FontSize(FontSizeSmall);
                t.Cell().AlignRight().Text($"{subtotale.TotaleAttivo:N2}").FontSize(FontSizeSmall)
                    .FontColor(BrandColors.Success).Bold();

                // Uscite previste
                t.Cell().Text("Uscite previste (-):").FontSize(FontSizeSmall);
                t.Cell().AlignRight().Text($"{subtotale.TotalePassivo:N2}").FontSize(FontSizeSmall)
                    .FontColor(BrandColors.Accent).Bold();

                // Saldo netto
                t.Cell().PaddingTop(2).Text("Saldo netto:").FontSize(FontSizeBody).Bold();
                var saldoColor = subtotale.SaldoNetto >= 0 ? BrandColors.Success : BrandColors.Danger;
                t.Cell().PaddingTop(2).AlignRight().Text($"{subtotale.SaldoNetto:N2}").FontSize(FontSizeBody)
                    .FontColor(saldoColor).Bold();
            });
        });
    }

    private static void ComposeTotaliGenerali(ColumnDescriptor column, ScadenzarioPrintData data)
    {
        var totaleGen = data.Subtotali.FirstOrDefault(s => s.IsTotaleGenerale);
        if (totaleGen == null) return;

        column.Item().Background(BrandColors.Total).Border(1).BorderColor(BrandColors.Primary).Padding(5).Column(totCol =>
        {
            totCol.Item().Text("CASH FLOW - PREVISIONE FINANZIARIA")
                .FontSize(FontSizeSubHeader).Bold().FontColor(BrandColors.Primary);

            totCol.Item().PaddingTop(5).Row(row =>
            {
                // Colonna Entrate
                row.RelativeItem().Column(col =>
                {
                    col.Item().Text("Entrate Previste").FontSize(FontSizeBody).Bold().FontColor(BrandColors.Success);
                    col.Item().Text($"{data.TotaleGeneraleAttivo:N2} {data.ValutaTargetCodiceIso}")
                        .FontSize(FontSizeHeader).Bold().FontColor(BrandColors.Success);
                });

                // Colonna Uscite
                row.RelativeItem().Column(col =>
                {
                    col.Item().Text("Uscite Previste").FontSize(FontSizeBody).Bold().FontColor(BrandColors.Accent);
                    col.Item().Text($"{data.TotaleGeneralePassivo:N2} {data.ValutaTargetCodiceIso}")
                        .FontSize(FontSizeHeader).Bold().FontColor(BrandColors.Accent);
                });

                // Colonna Saldo Netto
                row.RelativeItem().Column(col =>
                {
                    col.Item().Text("Saldo Netto").FontSize(FontSizeBody).Bold();
                    var saldoColor = data.SaldoNetto >= 0 ? BrandColors.Success : BrandColors.Danger;
                    col.Item().Text($"{data.SaldoNetto:N2} {data.ValutaTargetCodiceIso}")
                        .FontSize(FontSizeHeader).Bold().FontColor(saldoColor);

                    var label = data.SaldoNetto >= 0 ? "Disponibilità positiva" : "Scoperto previsto";
                    col.Item().Text(label).FontSize(FontSizeSmall).Italic().FontColor(saldoColor);
                });
            });

            totCol.Item().PaddingTop(3).Text($"Totale {totaleGen.ConteggioTransazioni} scadenze analizzate")
                .FontSize(FontSizeSmall).Italic().FontColor(BrandColors.Secondary);
        });
    }

    private static void ComposeLegenda(ColumnDescriptor column)
    {
        column.Item().PaddingTop(10).Row(row =>
        {
            row.RelativeItem().Text(text =>
            {
                text.Span("Legenda urgenza: ").FontSize(FontSizeSmall).Bold();
                text.Span("SCADUTO ").FontSize(FontSizeSmall).FontColor(BrandColors.Danger).Bold();
                text.Span("| ").FontSize(FontSizeSmall);
                text.Span("URGENTE (≤7gg) ").FontSize(FontSizeSmall).FontColor(BrandColors.Warning).Bold();
                text.Span("| ").FontSize(FontSizeSmall);
                text.Span("IN_SCADENZA (≤30gg) ").FontSize(FontSizeSmall).FontColor(BrandColors.Secondary).Bold();
                text.Span("| ").FontSize(FontSizeSmall);
                text.Span("NORMALE ").FontSize(FontSizeSmall).FontColor(BrandColors.Success).Bold();
            });
        });
    }

    private static void ComposeFooter(IContainer container, ScadenzarioPrintData data)
    {
        container.AlignCenter().Row(row =>
        {
            row.RelativeItem().Text(text =>
            {
                text.Span("Documento generato con ").FontSize(FontSizeSmall);
                text.Span("GestioneViaggi").FontSize(FontSizeSmall).Bold();
            });

            row.ConstantItem(100).AlignRight().Text(t =>
            {
                t.Span("Pagina ").FontSize(FontSizeSmall);
                t.CurrentPageNumber().FontSize(FontSizeSmall);
                t.Span(" di ").FontSize(FontSizeSmall);
                t.TotalPages().FontSize(FontSizeSmall);
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
