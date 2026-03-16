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

    /// <summary>
    /// Determina il colore del saldo.
    /// - Se Contesto PASSIVO (Fornitori): Saldo > 0 = DEBITO (Rosso), Saldo < 0 = CREDITO (Verde)
    /// - Se Contesto ATTIVO o MISTO: Saldo > 0 = CREDITO/RICAVO (Verde), Saldo < 0 = DEBITO/USCITA (Rosso)
    /// </summary>
    private static string GetSaldoColor(decimal saldo, bool isCicloPassivo)
    {
        if (saldo == 0) return ReportHeaderHelper.BrandColors.Text;

        if (isCicloPassivo)
        {
            // Logica Fornitori: POSITIVO = DEBITO (Rosso)
            const decimal sogliaCredito = -10.0m;
            if (saldo > 0) return ReportHeaderHelper.BrandColors.Accent;      // ROSSO: Devo soldi
            if (saldo >= sogliaCredito) return ReportHeaderHelper.BrandColors.Success; // VERDE: Pari o credito
            return ReportHeaderHelper.BrandColors.Warning; // ARANCIONE: Credito significativo
        }
        else
        {
            // Logica Clienti/Mista: POSITIVO = CREDITO/ENTRATA (Verde)
            if (saldo > 0) return ReportHeaderHelper.BrandColors.Success;     // VERDE: Entrata/Credito
            return ReportHeaderHelper.BrandColors.Accent;      // ROSSO: Uscita/Debito
        }
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
                page.DefaultTextStyle(x => x.FontSize(ReportHeaderHelper.FontSizeBodyCompact).FontFamily("Lato").FontColor(ReportHeaderHelper.BrandColors.Text));

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
            // 1. Header Standard Aziendale + Titolo
             ReportHeaderHelper.ComposeCompanyHeader(
                column.Item(),
                data.Azienda,
                "STAMPA MOVIMENTI CONTABILI" + (string.IsNullOrEmpty(data.Filtri.CausaleCiclo) ? "" : $" ({data.Filtri.CausaleCiclo})"),
                data.DataStampa,
                data.UtenteStampa,
                $"Valuta target: {data.ValutaTargetCodiceIso}\nOrdinamento: {data.TipoOrdinamentoDisplay}"
            );

            // 2. Filtri applicati (se presenti)
            if (data.Filtri.HasAnyFilter)
            {
                column.Item().PaddingTop(5).Background(ReportHeaderHelper.BrandColors.LightGray).Padding(5).Row(row =>
                {
                    row.RelativeItem().Text(text =>
                    {
                        text.Span("Filtri: ").Bold().FontSize(ReportHeaderHelper.FontSizeSmallCompact);
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
                        
                        text.Span(string.Join(" | ", filters)).FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                    });
                });
            }

            column.Item().PaddingTop(5).LineHorizontal(1).LineColor(ReportHeaderHelper.BrandColors.Border);
        });
    }

    private static void ComposeContent(IContainer container, TransazioniPrintData data)
    {
        container.PaddingTop(5).Column(column =>
        {
            if (!data.Dettagli.Any())
            {
                column.Item().AlignCenter().Padding(50).Text("Nessuna transazione trovata con i filtri applicati.")
                    .FontSize(ReportHeaderHelper.FontSizeSubHeaderCompact).Italic().FontColor(ReportHeaderHelper.BrandColors.Secondary);
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
                header.Cell().ColumnSpan(12).Background(ReportHeaderHelper.BrandColors.GroupHeader).Padding(4).Row(row =>
                {
                    var title = firstItem.GruppoDisplay ?? firstItem.GruppoChiave ?? "-";
                    row.RelativeItem().Text(title).FontSize(ReportHeaderHelper.FontSizeSubHeaderCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);
                });

                // Riga 2: Intestazioni Colonne (Sfondo Blu Navy)
                var headerStyle = QuestPDF.Infrastructure.TextStyle.Default.FontSize(ReportHeaderHelper.FontSizeSmallCompact).Bold().FontColor(Colors.White);

                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Data Doc").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Controparte").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Tipo").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Causale").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Viaggio / Info").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Stato").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Num. Doc").Style(headerStyle);
                
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).Text("Aliq.").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignRight().Text("Imponibile").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignRight().Text("IVA").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignRight().Text($"Lordo ({data.ValutaTargetCodiceIso})").Style(headerStyle);
                header.Cell().Background(ReportHeaderHelper.BrandColors.Primary).Padding(3).AlignRight().Text("Saldo Prog.").Style(headerStyle);
            });

            // Righe transizioni con calcolo saldo progressivo
            int rowIndex = 0;
            decimal currentSaldo = 0;
            foreach (var item in groupItems)
            {
                currentSaldo += item.ImportoAlgebricoTarget;
                item.SaldoProgressivo = currentSaldo;

                var bgColor = rowIndex % 2 == 0 ? Colors.White : ReportHeaderHelper.BrandColors.LightGray;
                var isDaPagare = item.Stato == "DA_PAGARE" || item.Stato == "PARZIALMENTE_PAGATO";
                
                // Logica colore riga basata su Ciclo (NON su TipoMovimento strict perché potrebbero esserci eccezioni)
                // Se Ciclo == PASSIVO -> Rosso standard
                // Se Ciclo == ATTIVO -> Verde standard
                var rowTextColor = item.IsCicloAttivo ? ReportHeaderHelper.BrandColors.Success : (item.IsCicloPassivo ? ReportHeaderHelper.BrandColors.Accent : ReportHeaderHelper.BrandColors.Text);
                if (isDaPagare) rowTextColor = ReportHeaderHelper.BrandColors.Warning; // Evidenzia scadenze
                
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).Text(item.DataDocumentoFormatted).FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).Text(item.ControparteRagioneSociale).FontSize(ReportHeaderHelper.FontSizeBodyCompact); // ex Fornitore
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).Text(item.TipoMovimentoDisplay).FontSize(ReportHeaderHelper.FontSizeBodyCompact).FontColor(rowTextColor);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).Text(item.Causale ?? "-").FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).Text(item.ViaggioFullDisplay).FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                var stateCell = table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).Text(item.StatoDisplay).FontSize(ReportHeaderHelper.FontSizeBodyCompact).FontColor(isDaPagare ? ReportHeaderHelper.BrandColors.Warning : ReportHeaderHelper.BrandColors.Text);
                if (isDaPagare) stateCell.Bold();
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).Text(item.NumeroDocumento ?? "-").FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                
                // Sezione Valori
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).Text(item.AliquotaDisplay).FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                
                // Imponibile
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).AlignRight()
                    .Text(item.ImponibileFormatted).FontSize(ReportHeaderHelper.FontSizeBodyCompact);

                // IVA
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).AlignRight()
                    .Text(item.IvaFormatted).FontSize(ReportHeaderHelper.FontSizeBodyCompact);
                
                // Lordo / Importo Target
                // Qui mostriamo il valore convertito nella valuta target del report, per coerenza col totale
                var sign = item.TipoMovimento == "USCITA" ? "-" : "";
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).AlignRight()
                    .Text($"{sign}{item.ImportoValutaTarget:N2}").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold().FontColor(rowTextColor);

                // Saldo Progressivo
                table.Cell().Background(bgColor).BorderBottom(0.5f).BorderColor(ReportHeaderHelper.BrandColors.Border).Padding(2).AlignRight()
                    .Text($"{item.SaldoProgressivo:N2}").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();
                
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

        column.Item().Background(ReportHeaderHelper.BrandColors.SubTotal).Padding(4).Column(subCol =>
        {
            foreach (var sub in subtotali)
            {
                subCol.Item().Row(row =>
                {
                    row.RelativeItem().PaddingRight(10).Column(col => 
                    {
                        col.Item().Text($"Riepilogo {sub.GruppoDisplay} ({sub.ValutaCodiceIso}):").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();
                        col.Item().Text($"{sub.ConteggioTransazioni} movimenti inclusi").FontSize(ReportHeaderHelper.FontSizeSmallCompact).Italic();
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
                        t.Cell().ColumnSpan(1).AlignRight().Text("Tot. Imponibile:").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                        t.Cell().ColumnSpan(2).AlignRight().Text(sub.TotaleImponibileFormatted).FontSize(ReportHeaderHelper.FontSizeSmallCompact);

                        // Riga 2: IVA Totale
                         t.Cell().ColumnSpan(1).AlignRight().Text("Tot. IVA:").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                        t.Cell().ColumnSpan(2).AlignRight().Text(sub.TotaleIvaFormatted).FontSize(ReportHeaderHelper.FontSizeSmallCompact);

                        // Riga 3: Fatturato vs Pagato (Cash Flow)
                         t.Cell().ColumnSpan(3).PaddingTop(2).LineHorizontal(0.5f).LineColor(ReportHeaderHelper.BrandColors.Border);
                         
                         t.Cell().Text("Fatturato/Entrate (+):").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                         t.Cell().ColumnSpan(2).AlignRight().Text(sub.TotaleFatturatoTargetFormatted).FontSize(ReportHeaderHelper.FontSizeSmallCompact).FontColor(ReportHeaderHelper.BrandColors.Success);

                         t.Cell().Text("Pagato/Uscite (-):").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                         t.Cell().ColumnSpan(2).AlignRight().Text($"-{sub.TotalePagatoTargetFormatted}").FontSize(ReportHeaderHelper.FontSizeSmallCompact).FontColor(ReportHeaderHelper.BrandColors.Accent);

                        // Saldo Finale
                        t.Cell().ColumnSpan(3).PaddingTop(2).LineHorizontal(0.5f).LineColor(ReportHeaderHelper.BrandColors.Border);
                        t.Cell().BorderTop(0.5f).PaddingTop(2).Text("SALDO FINALE:").FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();
                        t.Cell().ColumnSpan(2).BorderTop(0.5f).PaddingTop(2).AlignRight().Text(sub.TotaleTargetFormatted).FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold()
                            .FontColor(GetSaldoColor(sub.TotaleValutaTarget, data.Filtri.CausaleCiclo == "PASSIVO"));
                    });
                });
            }
        });
    }

    private static void ComposeTotaliGenerali(ColumnDescriptor column, TransazioniPrintData data)
    {
        var totali = data.TotaliGenerali.ToList();
        
        if (!totali.Any()) return;

        bool isPassivo = data.Filtri.CausaleCiclo == "PASSIVO";

        column.Item().Background(ReportHeaderHelper.BrandColors.Total).Border(1).BorderColor(ReportHeaderHelper.BrandColors.Primary).Padding(5).Column(totCol =>
        {
            totCol.Item().Text("TOTALI GENERALI ALGEBRICI")
                .FontSize(ReportHeaderHelper.FontSizeSubHeaderCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);
            
            totCol.Item().PaddingTop(3);

            foreach (var tot in totali)
            {
                totCol.Item().Row(row =>
                {
                    row.RelativeItem().Text($"Saldo Netto {tot.ValutaCodiceIso}:")
                        .FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold();
                    
                    row.ConstantItem(150).AlignRight().Text(tot.TotaleOriginaleFormatted)
                        .FontSize(ReportHeaderHelper.FontSizeSubHeaderCompact).Bold();
                    
                    row.ConstantItem(150).AlignRight().Text($"-> {tot.TotaleTargetFormatted}")
                        .FontSize(ReportHeaderHelper.FontSizeSubHeaderCompact).Bold().FontColor(GetSaldoColor(tot.TotaleValutaTarget, isPassivo));
                    
                    row.ConstantItem(80).AlignRight().Text($"({tot.ConteggioTransazioni} mov.)")
                        .FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                });
            }

            // Totale complessivo nella valuta target
            var totaleComplessivo = totali.Sum(t => t.TotaleValutaTarget);
            var conteggioComplessivo = totali.Sum(t => t.ConteggioTransazioni);
            
            totCol.Item().PaddingTop(5).BorderTop(1).BorderColor(ReportHeaderHelper.BrandColors.Primary).PaddingTop(3).Row(row =>
            {
                row.RelativeItem().Text($"TOTALE COMPLESSIVO ({data.ValutaTargetCodiceIso}):")
                    .FontSize(ReportHeaderHelper.FontSizeSubHeaderCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);
                row.ConstantItem(150).AlignRight().Text($"{totaleComplessivo:N2} {data.ValutaTargetCodiceIso}")
                    .FontSize(ReportHeaderHelper.FontSizeHeaderCompact).Bold().FontColor(GetSaldoColor(totaleComplessivo, isPassivo));
                row.ConstantItem(80).AlignRight().Text($"({conteggioComplessivo} mov.)")
                    .FontSize(ReportHeaderHelper.FontSizeSmallCompact);
            });
        });
    }

    private static void ComposeLegenda(ColumnDescriptor column)
    {
        column.Item().PaddingTop(10).Border(1).BorderColor(ReportHeaderHelper.BrandColors.Border).Background(ReportHeaderHelper.BrandColors.LightGray).Padding(5).Column(legCol =>
        {
            legCol.Item().Text("LEGENDA COLORI E FORMATI")
                .FontSize(ReportHeaderHelper.FontSizeBodyCompact).Bold().FontColor(ReportHeaderHelper.BrandColors.Primary);

            legCol.Item().PaddingTop(3).Row(row =>
            {
                row.RelativeItem().Column(c => {
                    c.Item().Row(r => {
                         r.ConstantItem(15).Height(10).Background(ReportHeaderHelper.BrandColors.Accent);
                         r.ConstantItem(5);
                         r.RelativeItem().Text("Rosso: Ciclo Passivo / Uscita / Debito").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                    });
                     c.Item().PaddingTop(2).Row(r => {
                         r.ConstantItem(15).Height(10).Background(ReportHeaderHelper.BrandColors.Success);
                         r.ConstantItem(5);
                         r.RelativeItem().Text("Verde: Ciclo Attivo / Entrata / Credito").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                    });
                });
                
                row.RelativeItem().Column(c => {
                      c.Item().Row(r => {
                         r.ConstantItem(15).Height(10).Background(ReportHeaderHelper.BrandColors.Warning);
                         r.ConstantItem(5);
                         r.RelativeItem().Text("Arancione: Scaduto / Da Pagare").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
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
                    .FontSize(ReportHeaderHelper.FontSizeSmallCompact).FontColor(ReportHeaderHelper.BrandColors.Secondary);
            });

            row.RelativeItem().AlignRight().Text(text =>
            {
                text.Span("Pagina ").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                text.CurrentPageNumber().FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                text.Span(" di ").FontSize(ReportHeaderHelper.FontSizeSmallCompact);
                text.TotalPages().FontSize(ReportHeaderHelper.FontSizeSmallCompact);
            });
        });
    }
}
