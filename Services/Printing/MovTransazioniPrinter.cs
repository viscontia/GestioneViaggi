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
        public static readonly string Accent = "#E74C3C";     // Red (Debito / Passivo / Uscita)
        public static readonly string Text = "#000000";
        public static readonly string LightGray = "#F0F0F0";
        public static readonly string Border = "#CCCCCC";
        public static readonly string GroupHeader = "#D5E8D4"; // Verde chiaro per rotture
        public static readonly string SubTotal = "#FFF2CC";    // Giallo chiaro per sub-totali
        public static readonly string Total = "#DAE8FC";       // Blu chiaro per totali generali
        public static readonly string Success = "#27AE60";     // Verde (Attivo / Entrata)
        public static readonly string Warning = "#F39C12";     // Arancione
        public static readonly string IvaHeader = "#E1F5FE";   // Azzurro chiarissimo per header colonna IVA
    }

    // Costanti layout
    private const float FontSizeHeader = 16;
    private const float FontSizeSubHeader = 11;
    private const float FontSizeBody = 8;
    private const float FontSizeSmall = 7;

    /// <summary>
    /// Determina il colore del saldo in base alla logica "Esposizione Finanziaria":
    /// - ROSSO: Debito verso fornitore (saldo > 0)
    /// - VERDE: Pari o credito minimo (saldo = 0 o leggermente negativo)
    /// - ARANCIONE: Credito significativo da recuperare (saldo molto negativo)
    /// </summary>
    private static string GetSaldoColor(decimal saldo)
    {
        const decimal sogliaCredito = -10.0m; // Oltre -10 unità consideriamo il credito significativo

        if (saldo > 0)
            return BrandColors.Accent;      // ROSSO: Devo soldi al fornitore (DEBITO)
        else if (saldo >= sogliaCredito)
            return BrandColors.Success;     // VERDE: Pari o piccolo credito (OK)
        else
            return BrandColors.Warning;     // ARANCIONE: Credito significativo da recuperare
    }

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
                    if (data.Azienda.LogoData != null && data.Azienda.LogoData.Length > 0)
                    {
                        col.Item().MaxHeight(40).Image(data.Azienda.LogoData).FitArea();
                    }
                    else
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
                    col.Item().Text($"Valuta target: {data.ValutaTargetCodiceIso}")
                        .FontSize(FontSizeSmall).Bold();
                });
            });

            // 2. Riga Titolo: Centrata nel documento su un'unica riga
            column.Item().PaddingVertical(10).AlignCenter().Column(col =>
            {
                col.Item().Text("STAMPA MOVIMENTI CONTABILI" + (string.IsNullOrEmpty(data.Filtri.CausaleCiclo) ? "" : $" ({data.Filtri.CausaleCiclo})"))
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
                        
                        // if (!string.IsNullOrEmpty(data.Filtri.Azienda)) filters.Add($"Azienda: {data.Filtri.Azienda}"); // Ridondante
                        if (!string.IsNullOrEmpty(data.Filtri.Controparte))
                            filters.Add($"Controparte: {data.Filtri.Controparte}");
                        if (!string.IsNullOrEmpty(data.Filtri.CausaleCiclo))
                            filters.Add($"Ciclo: {data.Filtri.CausaleCiclo}");
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

            // Legenda colori
            ComposeLegenda(column);
        });
    }

    private static void ComposeGroupTable(ColumnDescriptor column, string? gruppoChiave, IEnumerable<TransazionePrintItem> groupItems, TransazioniPrintData data)
    {
        var firstItem = groupItems.FirstOrDefault();
        if (firstItem == null) return;

        column.Item().Table(table =>
        {
            // Definizione colonne (pesi ricalibrati per inserire Imponibile, IVA, Lordo)
            table.ColumnsDefinition(columns =>
            {
                columns.ConstantColumn(50);  // Data Doc
                columns.RelativeColumn(1.2f); // Controparte
                columns.ConstantColumn(40);  // Tipo
                columns.RelativeColumn(1.0f); // Causale
                columns.RelativeColumn(1.0f); // Viaggio / Info
                columns.ConstantColumn(45);  // Stato
                columns.ConstantColumn(55);  // Num. Doc
                
                // Sezione Importi (spazio stretto, usiamo small font)
                columns.ConstantColumn(30);  // Aliq %
                columns.ConstantColumn(65);  // Imponibile
                columns.ConstantColumn(50);  // IVA
                columns.ConstantColumn(70);  // Lordo (Orig) / Conv
                columns.ConstantColumn(75);  // Saldo Prog.
            });

            // Header ripetibile (contiene Nome Gruppo + Intestazioni Colonne)
            table.Header(header =>
            {
                // Riga 1: Nome Gruppo (Sfondo Verde)
                header.Cell().ColumnSpan(12).Background(BrandColors.GroupHeader).Padding(4).Row(row =>
                {
                    var title = firstItem.GruppoDisplay ?? firstItem.GruppoChiave ?? "-";
                    row.RelativeItem().Text(title).FontSize(FontSizeSubHeader).Bold().FontColor(BrandColors.Primary);
                });

                // Riga 2: Intestazioni Colonne (Sfondo Blu Navy)
                var headerStyle = QuestPDF.Infrastructure.TextStyle.Default.FontSize(FontSizeSmall).Bold().FontColor(Colors.White);

                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Data Doc").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Controparte").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Tipo").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Causale").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Viaggio / Info").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Stato").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Num. Doc").Style(headerStyle);
                
                header.Cell().Background(BrandColors.Primary).Padding(3).Text("Aliq.").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("Imponibile").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("IVA").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text($"Lordo ({data.ValutaTargetCodiceIso})").Style(headerStyle);
                header.Cell().Background(BrandColors.Primary).Padding(3).AlignRight().Text("Saldo Prog.").Style(headerStyle);
            });

            // Righe transizioni con calcolo saldo progressivo
            int rowIndex = 0;
            decimal currentSaldo = 0;
            foreach (var item in groupItems)
            {
                currentSaldo += item.ImportoAlgebricoTarget;
                item.SaldoProgressivo = currentSaldo;

                var bgColor = rowIndex % 2 == 0 ? Colors.White : BrandColors.LightGray;
                var isDaPagare = item.Stato == "DA_PAGARE" || item.Stato == "PARZIALMENTE_PAGATO";
                
                // Logica colore riga basata su Ciclo (NON su TipoMovimento strict perché potrebbero esserci eccezioni)
                // Se Ciclo == PASSIVO -> Rosso standard
                // Se Ciclo == ATTIVO -> Verde standard
                var rowTextColor = item.IsCicloAttivo ? BrandColors.Success : (item.IsCicloPassivo ? BrandColors.Accent : BrandColors.Text);
                if (isDaPagare) rowTextColor = BrandColors.Warning; // Evidenzia scadenze
                
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.DataDocumentoFormatted).FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.ControparteRagioneSociale).FontSize(FontSizeBody); // ex Fornitore
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.TipoMovimentoDisplay).FontSize(FontSizeBody).FontColor(rowTextColor);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.Causale ?? "-").FontSize(FontSizeBody);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.ViaggioFullDisplay).FontSize(FontSizeBody);
                var stateCell = table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.StatoDisplay).FontSize(FontSizeBody).FontColor(isDaPagare ? BrandColors.Warning : BrandColors.Text);
                if (isDaPagare) stateCell.Bold();
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.NumeroDocumento ?? "-").FontSize(FontSizeBody);
                
                // Sezione Valori
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).Text(item.AliquotaDisplay).FontSize(FontSizeSmall);
                
                // Imponibile
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).AlignRight()
                    .Text(item.ImponibileFormatted).FontSize(FontSizeBody);

                // IVA
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).AlignRight()
                    .Text(item.IvaFormatted).FontSize(FontSizeBody);
                
                // Lordo / Importo Target
                // Qui mostriamo il valore convertito nella valuta target del report, per coerenza col totale
                var sign = item.TipoMovimento == "USCITA" ? "-" : "";
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).AlignRight()
                    .Text($"{sign}{item.ImportoValutaTarget:N2}").FontSize(FontSizeBody).Bold().FontColor(rowTextColor);

                // Saldo Progressivo
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(BrandColors.Border).Padding(2).AlignRight()
                    .Text($"{item.SaldoProgressivo:N2}").FontSize(FontSizeBody).Bold();
                
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

        column.Item().Background(BrandColors.SubTotal).Padding(4).Column(subCol =>
        {
            foreach (var sub in subtotali)
            {
                subCol.Item().Row(row =>
                {
                    row.RelativeItem().PaddingRight(10).Column(col => 
                    {
                        col.Item().Text($"Riepilogo {sub.GruppoDisplay} ({sub.ValutaCodiceIso}):").FontSize(FontSizeBody).Bold();
                        col.Item().Text($"{sub.ConteggioTransazioni} movimenti inclusi").FontSize(FontSizeSmall).Italic();
                    });

                    row.RelativeItem(2).Table(t => 
                    {
                        t.ColumnsDefinition(c => 
                        {
                            c.RelativeColumn();
                            c.ConstantColumn(80); // Etichette
                            c.ConstantColumn(80); // Valori
                        });

                        // Riga 1: Imponibile Totale
                        t.Cell().ColumnSpan(1).AlignRight().Text("Tot. Imponibile:").FontSize(FontSizeSmall);
                        t.Cell().ColumnSpan(2).AlignRight().Text(sub.TotaleImponibileFormatted).FontSize(FontSizeSmall);

                        // Riga 2: IVA Totale
                         t.Cell().ColumnSpan(1).AlignRight().Text("Tot. IVA:").FontSize(FontSizeSmall);
                        t.Cell().ColumnSpan(2).AlignRight().Text(sub.TotaleIvaFormatted).FontSize(FontSizeSmall);

                        // Riga 3: Fatturato vs Pagato (Cash Flow)
                         t.Cell().ColumnSpan(3).PaddingTop(2).LineHorizontal(0.5f).LineColor(BrandColors.Border);
                         
                         t.Cell().Text("Fatturato/Entrate (+):").FontSize(FontSizeSmall);
                         t.Cell().ColumnSpan(2).AlignRight().Text(sub.TotaleFatturatoTargetFormatted).FontSize(FontSizeSmall).FontColor(BrandColors.Success);

                         t.Cell().Text("Pagato/Uscite (-):").FontSize(FontSizeSmall);
                         t.Cell().ColumnSpan(2).AlignRight().Text($"-{sub.TotalePagatoTargetFormatted}").FontSize(FontSizeSmall).FontColor(BrandColors.Accent);

                        // Saldo Finale
                        t.Cell().ColumnSpan(3).PaddingTop(2).LineHorizontal(0.5f).LineColor(BrandColors.Border);
                        t.Cell().BorderTop(0.5f).PaddingTop(2).Text("SALDO FINALE:").FontSize(FontSizeBody).Bold();
                        t.Cell().ColumnSpan(2).BorderTop(0.5f).PaddingTop(2).AlignRight().Text(sub.TotaleTargetFormatted).FontSize(FontSizeBody).Bold()
                            .FontColor(GetSaldoColor(sub.TotaleValutaTarget));
                    });
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
            totCol.Item().Text("TOTALI GENERALI ALGEBRICI")
                .FontSize(FontSizeSubHeader).Bold().FontColor(BrandColors.Primary);
            
            totCol.Item().PaddingTop(3);

            foreach (var tot in totali)
            {
                totCol.Item().Row(row =>
                {
                    row.RelativeItem().Text($"Saldo Netto {tot.ValutaCodiceIso}:")
                        .FontSize(FontSizeBody).Bold();
                    
                    row.ConstantItem(150).AlignRight().Text(tot.TotaleOriginaleFormatted)
                        .FontSize(FontSizeSubHeader).Bold();
                    
                    row.ConstantItem(150).AlignRight().Text($"-> {tot.TotaleTargetFormatted}")
                        .FontSize(FontSizeSubHeader).Bold().FontColor(GetSaldoColor(tot.TotaleValutaTarget));
                    
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
                    .FontSize(FontSizeHeader).Bold().FontColor(GetSaldoColor(totaleComplessivo));
                row.ConstantItem(80).AlignRight().Text($"({conteggioComplessivo} mov.)")
                    .FontSize(FontSizeSmall);
            });
        });
    }

    private static void ComposeLegenda(ColumnDescriptor column)
    {
        column.Item().PaddingTop(10).Border(1).BorderColor(BrandColors.Border).Background(BrandColors.LightGray).Padding(5).Column(legCol =>
        {
            legCol.Item().Text("LEGENDA COLORI E FORMATI")
                .FontSize(FontSizeBody).Bold().FontColor(BrandColors.Primary);

            legCol.Item().PaddingTop(3).Row(row =>
            {
                row.RelativeItem().Column(c => {
                    c.Item().Row(r => {
                         r.ConstantItem(15).Height(10).Background(BrandColors.Accent);
                         r.ConstantItem(5);
                         r.RelativeItem().Text("Rosso: Ciclo Passivo / Uscita / Debito").FontSize(FontSizeSmall);
                    });
                     c.Item().PaddingTop(2).Row(r => {
                         r.ConstantItem(15).Height(10).Background(BrandColors.Success);
                         r.ConstantItem(5);
                         r.RelativeItem().Text("Verde: Ciclo Attivo / Entrata / Credito").FontSize(FontSizeSmall);
                    });
                });
                
                row.RelativeItem().Column(c => {
                      c.Item().Row(r => {
                         r.ConstantItem(15).Height(10).Background(BrandColors.Warning);
                         r.ConstantItem(5);
                         r.RelativeItem().Text("Arancione: Scaduto / Da Pagare").FontSize(FontSizeSmall);
                    });
                });
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
