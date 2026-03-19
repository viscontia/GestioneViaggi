using GestioneViaggi.Models.DTOs;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;
using NpgsqlTypes;
using Dapper;
using System.Text.Json;
using System.Text.Json.Serialization;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using SkiaSharp;
using Colors = QuestPDF.Helpers.Colors;
using IContainer = QuestPDF.Infrastructure.IContainer;

namespace GestioneViaggi.Services.Printing;

public class BilancioViaggioPrintData
{
    public CompanyPrintInfo Azienda { get; set; } = new();
    public List<BilancioViaggioDTO> Dettagli { get; set; } = new();
    public string UtenteStampa { get; set; } = string.Empty;
    public DateTime DataStampa { get; set; } = DateTime.Now;
    public string? FiltriDisplay { get; set; }
}

public class BilancioViaggioPrintService
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<BilancioViaggioPrintService> _logger;

    public BilancioViaggioPrintService(
        IDatabaseService databaseService,
        ILogger<BilancioViaggioPrintService> logger)
    {
        _databaseService = databaseService;
        _logger = logger;
    }

    public async Task<BilancioViaggioPrintData> GetBilancioPrintDataAsync(int aziendaId, int viaggioId, int? dataViaggioId, DateTime? dataDa, DateTime? dataA, string utenteStampa, int? valutaTargetId = null)
    {
        _logger.LogInformation("Inizio estrazione Bilancio Viaggio (Fat Init). Viaggio: {ViaggioId}", viaggioId);
        
        var data = new BilancioViaggioPrintData
        {
            UtenteStampa = utenteStampa,
            DataStampa = DateTime.Now
        };

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT fn_get_bilancio_viaggio_print_data(@AziendaId, @ViaggioId, @DataViaggioId, @DataDa, @DataA, @Anno, @ValutaTargetId)";

            var jsonResponse = await connection.QueryFirstOrDefaultAsync<string>(sql, new
            {
                AziendaId = aziendaId,
                ViaggioId = viaggioId,
                DataViaggioId = dataViaggioId,
                DataDa = dataDa,
                DataA = dataA,
                Anno = (int?)null,
                ValutaTargetId = valutaTargetId
            });

            if (!string.IsNullOrEmpty(jsonResponse))
            {
                var rawData = JsonSerializer.Deserialize<BilancioRawResponse>(jsonResponse, PrintJsonHelper.GetDefaultOptions());

                if (rawData != null)
                {
                    if (rawData.Azienda != null)
                    {
                        data.Azienda = new CompanyPrintInfo
                        {
                            RagioneSociale = rawData.Azienda.RagioneSociale ?? "",
                            Telefono = rawData.Azienda.Telefono ?? "",
                            Email = rawData.Azienda.Email ?? "",
                            SitoWeb = rawData.Azienda.SitoWeb ?? "",
                            Piva = rawData.Azienda.Piva ?? "",
                            LogoData = rawData.Azienda.LogoData ?? Array.Empty<byte>()
                        };
                    }
                    data.Dettagli = rawData.Dettagli ?? new List<BilancioViaggioDTO>();
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore Fat Init Bilancio Viaggio");
            throw;
        }

        return data;
    }

    public async Task<BilancioViaggioPrintData> GetBilancioAnnualePrintDataAsync(int aziendaId, int anno, string utenteStampa, int? valutaTargetId = null)
    {
        _logger.LogInformation("Inizio estrazione Bilancio Annuale (Fat Init). Anno: {Anno}", anno);

        var data = new BilancioViaggioPrintData
        {
            UtenteStampa = utenteStampa,
            DataStampa = DateTime.Now
        };

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT fn_get_bilancio_viaggio_print_data(@AziendaId, @ViaggioId, @DataViaggioId, @DataDa, @DataA, @Anno, @ValutaTargetId)";

            var jsonResponse = await connection.QueryFirstOrDefaultAsync<string>(sql, new
            {
                AziendaId = aziendaId,
                ViaggioId = (int?)null,
                DataViaggioId = (int?)null,
                DataDa = (DateTime?)null,
                DataA = (DateTime?)null,
                Anno = anno,
                ValutaTargetId = valutaTargetId
            });

            if (!string.IsNullOrEmpty(jsonResponse))
            {
                var rawData = JsonSerializer.Deserialize<BilancioRawResponse>(jsonResponse, PrintJsonHelper.GetDefaultOptions());

                if (rawData != null)
                {
                    if (rawData.Azienda != null)
                    {
                        data.Azienda = new CompanyPrintInfo
                        {
                            RagioneSociale = rawData.Azienda.RagioneSociale ?? "",
                            Telefono = rawData.Azienda.Telefono ?? "",
                            Email = rawData.Azienda.Email ?? "",
                            SitoWeb = rawData.Azienda.SitoWeb ?? "",
                            Piva = rawData.Azienda.Piva ?? "",
                            LogoData = rawData.Azienda.LogoData ?? Array.Empty<byte>()
                        };
                    }
                    data.Dettagli = rawData.Dettagli ?? new List<BilancioViaggioDTO>();
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore Fat Init Bilancio Annuale");
            throw;
        }

        return data;
    }

    public async Task<List<AnnoBilancioDTO>> GetAnniBilancioDisponibiliAsync(int aziendaId)
    {
        var result = new List<AnnoBilancioDTO>();
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var parameters = new DynamicParameters();
            parameters.Add("aziendaId", aziendaId);
            result = (await connection.QueryAsync<AnnoBilancioDTO>("SELECT * FROM fn_get_anni_bilancio_viaggi(@aziendaId)", parameters)).ToList();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore recupero anni disponibili per bilancio");
            result.Add(new AnnoBilancioDTO { Anno = DateTime.Now.Year, NumeroViaggi = 0 });
        }
        return result;
    }

    // JSON Raw Classes
    private class BilancioRawResponse
    {
        public BilancioAziendaRaw? Azienda { get; set; }
        public List<BilancioViaggioDTO>? Dettagli { get; set; }
    }

    private class BilancioAziendaRaw
    {
        [JsonPropertyName("ragione_sociale")] public string? RagioneSociale { get; set; }
        [JsonPropertyName("telefono")] public string? Telefono { get; set; }
        [JsonPropertyName("email")] public string? Email { get; set; }
        [JsonPropertyName("sito_web")] public string? SitoWeb { get; set; }
        [JsonPropertyName("piva")] public string? Piva { get; set; }
        [JsonPropertyName("logo_data")] public byte[]? LogoData { get; set; }
    }


    public async Task<byte[]> GeneratePdfAsync(BilancioViaggioPrintData printData)
    {
        return await Task.Run(() =>
        {
            var data = printData.Dettagli;

            var document = Document.Create(container =>
            {
                container.Page(page =>
                {
                    page.Size(PageSizes.A4.Landscape());
                    page.Margin(1, Unit.Centimetre);
                    page.PageColor(Colors.White);
                    page.DefaultTextStyle(x => x.FontSize(10).FontFamily(Fonts.Arial));

                    page.Header().Element(header => ComposeHeader(header, printData));
                    
                    page.Content().PaddingVertical(10).Column(column =>
                    {
                        if (data.Any())
                        {
                            var tripInfo = data.First();
                            ComposeTripSection(column, tripInfo, data.ToList());
                        }
                    });

                    page.Footer().Element(ReportHeaderHelper.ComposeFooter);
                });
            });

            return document.GeneratePdf();
        });
    }

    public async Task<byte[]> GenerateAnnualePdfAsync(BilancioViaggioPrintData printData, int anno)
    {
        return await Task.Run(() =>
        {
            var data = printData.Dettagli;

            // Global Totals (Livello 3)
            var globalTotals = new BilancioTotals
            {
                TotalRevenue = data.Where(x => x.CategoriaTipo == "RICAVO").Sum(x => x.ImportoNettoEur),
                TotalCost = data.Where(x => x.CategoriaTipo == "COSTO").Sum(x => x.ImportoNettoEur),
                Participants = data.GroupBy(x => x.DataViaggioId).Sum(g => g.First().DataViaggioNumeroPartecipanti)
            };

            var document = Document.Create(container =>
            {
                container.Page(page =>
                {
                    page.Size(PageSizes.A4.Landscape());
                    page.Margin(1, Unit.Centimetre);
                    page.PageColor(Colors.White);
                    page.DefaultTextStyle(x => x.FontSize(10).FontFamily(Fonts.Arial));

                    page.Header().Element(header => 
                        ReportHeaderHelper.ComposeCompanyHeader(
                            header, 
                            printData.Azienda, 
                            $"BILANCIO ANNUALE VIAGGI {anno}", 
                            printData.DataStampa, 
                            printData.UtenteStampa
                        )
                    );
                    
                    page.Content().PaddingVertical(10).Column(column =>
                    {
                        var trips = data.GroupBy(x => x.ViaggioId).ToList();

                        foreach (var trip in trips)
                        {
                            var tripDates = trip.GroupBy(x => x.DataViaggioId).ToList();
                            var tripInfo = trip.First();

                            // Group the Trip Header and the FIRST Trip Date block together so they don't break across pages
                            column.Item().ShowEntire().Column(sc =>
                            {
                                // Livello 2: Intestazione Viaggio
                                sc.Item().Background(Colors.Blue.Lighten4).Padding(10).Column(c =>
                                {
                                    c.Item().Text($"VIAGGIO: {tripInfo.ViaggioDescrizione}").FontSize(14).Bold().FontColor(Colors.Blue.Darken3);
                                });

                                if (tripDates.Any())
                                {
                                    var firstDateInfo = tripDates.First().First();
                                    sc.Item().Column(dsc => 
                                    {
                                        ComposeAnnualeDateSection(dsc, firstDateInfo, tripDates.First().ToList());
                                    });
                                }
                            });
                            
                            column.Item().PaddingBottom(15);

                            // Process any remaining Trip Dates
                            foreach (var tripDate in tripDates.Skip(1))
                            {
                                var dateInfo = tripDate.First();
                                
                                // Livello 1: Dettaglio Data Viaggio (Ensure section is kept together if possible)
                                column.Item().ShowEntire().Column(sc => 
                                {
                                    ComposeAnnualeDateSection(sc, dateInfo, tripDate.ToList());
                                });
                                column.Item().PaddingBottom(15);
                            }

                            // Livello 2: Totali Viaggio
                            column.Item().ShowEntire().Column(sc => 
                            {
                                ComposeAnnualeTripTotals(sc, tripInfo.ViaggioDescrizione, trip.ToList());
                            });
                            
                            // Non forzare PageBreak a fine viaggio se possibile tenerlo unito,
                            // o forzarlo se si desidera ogni viaggio su pagina separata.
                            // Per flessibilità lasciamo che QuestPDF gestisca il salto, 
                            // a meno che non ci sia molto spazio.
                            column.Item().PaddingBottom(20);
                        }

                        // Livello 3: Riepilogo Finale su Nuova Pagina
                        if (data.Any())
                        {
                            column.Item().PageBreak();
                            ComposeGlobalSummary(column, globalTotals);
                        }
                    });

                    page.Footer().Element(ReportHeaderHelper.ComposeFooter);
                });
            });

            return document.GeneratePdf();
        });
    }

    private void ComposeAnnualeDateSection(ColumnDescriptor column, BilancioViaggioDTO dateInfo, List<BilancioViaggioDTO> transactions)
    {
        column.Item().PaddingTop(10).Background(Colors.Grey.Lighten3).Padding(10).Column(c =>
        {
            var dataFine = dateInfo.DataViaggioDataFine.HasValue ? $" Al {dateInfo.DataViaggioDataFine.Value:dd/MM/yyyy}" : "";
            c.Item().Text($"Partenza: Dal {dateInfo.DataViaggioDataInizio:dd/MM/yyyy}{dataFine}").FontSize(12).Bold().FontColor(Colors.Blue.Medium);
            c.Item().Text($"Mezzi: {dateInfo.DataViaggioNumeroMezzi} - Persone: {dateInfo.DataViaggioNumeroPartecipanti}").FontSize(10).Bold();
        });

        column.Item().PaddingTop(5);

        var revenueTransactions = transactions.Where(x => x.CategoriaTipo == "RICAVO").ToList();
        var costTransactions = transactions.Where(x => x.CategoriaTipo == "COSTO").ToList();

        var revenue = revenueTransactions.Sum(x => x.ImportoNettoEur);
        var cost = costTransactions.Sum(x => x.ImportoNettoEur);

        if (revenueTransactions.Any())
        {
            ComposeTransactionTable(column, "RICAVI", revenueTransactions, revenue, 0, true); 
        }

        if (costTransactions.Any())
        {
            column.Item().PaddingTop(10);
            ComposeTransactionTable(column, "COSTI", costTransactions, cost, revenue, false);
        }

        // Totali Data Viaggio
        column.Item().PaddingTop(10).Background(Colors.Grey.Lighten4).Padding(10).Column(c =>
        {
            c.Item().Text("Totali Partenza").Bold().FontSize(11);
            c.Item().PaddingTop(5).LineHorizontal(1).LineColor(Colors.Grey.Lighten2);
            c.Item().PaddingTop(5);
            ComposeAnnualeTotalsRow(c, revenue, cost, dateInfo.DataViaggioNumeroPartecipanti, false);
        });
    }

    private void ComposeAnnualeTripTotals(ColumnDescriptor column, string viaggioDescrizione, List<BilancioViaggioDTO> tripTransactions)
    {
        var revenue = tripTransactions.Where(x => x.CategoriaTipo == "RICAVO").Sum(x => x.ImportoNettoEur);
        var cost = tripTransactions.Where(x => x.CategoriaTipo == "COSTO").Sum(x => x.ImportoNettoEur);
        var participants = tripTransactions.GroupBy(x => x.DataViaggioId).Sum(g => g.First().DataViaggioNumeroPartecipanti);

        column.Item().PaddingTop(5).PaddingBottom(10).Background(Colors.Blue.Lighten5).Border(1).BorderColor(Colors.Blue.Lighten2).Padding(10).Column(c =>
        {
            c.Item().Text($"RIEPILOGO VIAGGIO: {viaggioDescrizione}").Bold().FontSize(12).FontColor(Colors.Blue.Darken2);
            c.Item().PaddingTop(5).LineHorizontal(1).LineColor(Colors.Blue.Lighten1);
            c.Item().PaddingTop(5);
            ComposeAnnualeTotalsRow(c, revenue, cost, participants, true);
        });
    }

    private void ComposeAnnualeTotalsRow(ColumnDescriptor c, decimal revenue, decimal cost, int participants, bool showPieChart)
    {
        var margin = revenue - cost;
        var marginPercent = revenue > 0 ? (margin / revenue) * 100 : 0;
        var costPercent = revenue > 0 ? (cost / revenue) * 100 : 0;
        
        c.Item().Row(row =>
        {
            row.RelativeItem().Column(col =>
            {
                col.Item().Text($"Totale Ricavi").FontSize(10);
                col.Item().Text($"{revenue:N2} €").FontSize(12).Bold().FontColor(Colors.Green.Medium);
            });
            row.RelativeItem().Column(col =>
            {
                col.Item().Text($"Totale Costi").FontSize(10);
                col.Item().Text($"{cost:N2} €").FontSize(12).Bold().FontColor(Colors.Red.Medium);
                col.Item().Text($"{costPercent:N2} %").FontSize(9);
                
                if (participants > 0)
                {
                     var avgCost = cost / participants;
                     col.Item().PaddingTop(2).Text($"Costo medio/pax: {avgCost:N2} €").FontSize(9).Italic();
                }
            });
            row.RelativeItem().Column(col =>
            {
                col.Item().Text($"Margine").FontSize(10);
                col.Item().Text($"{margin:N2} €").FontSize(12).Bold().FontColor(Colors.Blue.Darken2);
                col.Item().Text($"{marginPercent:N2} %").FontSize(9);

                if (participants > 0)
                {
                     var avgMargin = margin / participants;
                     col.Item().PaddingTop(2).Text($"Guadagno medio/pax: {avgMargin:N2} €").FontSize(9).Italic();
                }
            });
            
            if (showPieChart && (revenue > 0 || cost > 0))
            {
                row.RelativeItem().AlignRight().Width(60).Height(60).Image(GeneratePieChart(revenue, cost));
            }
        });
    }

    private void ComposeHeader(IContainer container, BilancioViaggioPrintData data)
    {
        ReportHeaderHelper.ComposeCompanyHeader(
            container, 
            data.Azienda, 
            "BILANCIO DI VIAGGIO", 
            data.DataStampa, 
            data.UtenteStampa
        );
    }

    private void ComposeTripSection(ColumnDescriptor column, BilancioViaggioDTO tripInfo, List<BilancioViaggioDTO> transactions)
    {
        // Trip Header
        column.Item().Background(Colors.Grey.Lighten3).Padding(10).Column(c =>
        {
            c.Item().Text($"{tripInfo.ViaggioDescrizione}").FontSize(14).Bold().FontColor(Colors.Blue.Medium);
            c.Item().Text($"Dal: {tripInfo.ViaggioDataInizio:dd/MM/yyyy} Al: {tripInfo.ViaggioDataFine:dd/MM/yyyy}").FontSize(10);
            c.Item().Text($"Mezzi: {tripInfo.ViaggioNumeroMezzi} - Persone: {tripInfo.ViaggioNumeroPartecipanti}").FontSize(10).Bold();
        });

        column.Item().PaddingTop(10);

        // Calculate Trip Totals
        var revenueTransactions = transactions.Where(x => x.CategoriaTipo == "RICAVO").ToList();
        var costTransactions = transactions.Where(x => x.CategoriaTipo == "COSTO").ToList();

        var revenue = revenueTransactions.Sum(x => x.ImportoNettoEur);
        var cost = costTransactions.Sum(x => x.ImportoNettoEur);
        var margin = revenue - cost;
        var marginPercent = revenue > 0 ? (margin / revenue) * 100 : 0;
        var costPercent = revenue > 0 ? (cost / revenue) * 100 : 0;
        
        var totals = new BilancioTotals
        {
            TotalRevenue = revenue,
            TotalCost = cost,
            Participants = tripInfo.ViaggioNumeroPartecipanti
        };
        
        column.Item().PaddingBottom(5).Text("Tutti gli importi sono da intendersi IVA esclusa").FontSize(10).Italic().FontColor(Colors.Black);

        // REVENUE SECTION
        if (revenueTransactions.Any())
        {
            ComposeTransactionTable(column, "RICAVI", revenueTransactions, revenue, 0, true); 
        }

        // COST SECTION
        if (costTransactions.Any())
        {
            column.Item().PaddingTop(15);
            ComposeTransactionTable(column, "COSTI", costTransactions, cost, revenue, false);
        }

        // Trip Summary
        column.Item().PaddingTop(10).Background(Colors.Grey.Lighten4).Padding(10).Column(c =>
        {
            c.Item().Text("Riepilogo Viaggio").Bold().FontSize(12);
            c.Item().PaddingTop(5).LineHorizontal(1).LineColor(Colors.Grey.Lighten2);
            c.Item().PaddingTop(5).Row(row =>
            {
                row.RelativeItem().Column(col =>
                {
                    col.Item().Text($"Totale Ricavi").FontSize(10);
                    col.Item().Text($"{revenue:N2} €").FontSize(12).Bold().FontColor(Colors.Green.Medium);
                });
                row.RelativeItem().Column(col =>
                {
                    col.Item().Text($"Totale Costi").FontSize(10);
                    col.Item().Text($"{cost:N2} €").FontSize(12).Bold().FontColor(Colors.Red.Medium);
                    col.Item().Text($"{costPercent:N2} %").FontSize(9);
                    
                    if (tripInfo.ViaggioNumeroPartecipanti > 0)
                    {
                         var avgCost = cost / tripInfo.ViaggioNumeroPartecipanti;
                         col.Item().PaddingTop(2).Text($"Costo medio/pax: {avgCost:N2} €").FontSize(9).Italic();
                    }
                });
                row.RelativeItem().Column(col =>
                {
                    col.Item().Text($"Margine").FontSize(10);
                    col.Item().Text($"{margin:N2} €").FontSize(12).Bold().FontColor(Colors.Blue.Darken2);
                    col.Item().Text($"{marginPercent:N2} %").FontSize(9);

                    if (tripInfo.ViaggioNumeroPartecipanti > 0)
                    {
                         var avgMargin = margin / tripInfo.ViaggioNumeroPartecipanti;
                         col.Item().PaddingTop(2).Text($"Guadagno medio/pax: {avgMargin:N2} €").FontSize(9).Italic();
                    }
                });
                
                // PIE CHART
                if (revenue > 0 || cost > 0)
                {
                    row.RelativeItem().AlignRight().Width(60).Height(60).Image(GeneratePieChart(revenue, cost));
                }
            });
        });
    }

    private void ComposeTransactionTable(ColumnDescriptor column, string title, List<BilancioViaggioDTO> transactions, decimal totalAmount, decimal totalRevenue, bool isRevenue)
    {
        column.Item().Text(title).Bold().FontSize(12).FontColor(isRevenue ? Colors.Green.Darken2 : Colors.Red.Darken2);
        
        column.Item().Table(table =>
        {
            table.ColumnsDefinition(columns =>
            {
                columns.ConstantColumn(80); // Data
                columns.RelativeColumn(3);  // Descrizione
                columns.RelativeColumn(2);  // Controparte
                columns.RelativeColumn(2);  // Categoria
                // Removed Type column as it's redundant now
                columns.RelativeColumn(1.5f); // Importo
            });

            table.Header(header =>
            {
                header.Cell().Element(CellStyle).Text("Data").SemiBold();
                header.Cell().Element(CellStyle).Text("Descrizione").SemiBold();
                header.Cell().Element(CellStyle).Text("Controparte").SemiBold();
                header.Cell().Element(CellStyle).Text("Categoria").SemiBold();
                header.Cell().Element(CellStyle).AlignRight().Text("Importo (€)").SemiBold();

                IContainer CellStyle(IContainer container) => container.BorderBottom(1).BorderColor(Colors.Grey.Lighten2).Padding(2);
            });

            foreach (var transaction in transactions.OrderBy(x => x.DataRegistrazione))
            {
                table.Cell().Element(CellStyle).Text($"{transaction.DataRegistrazione:dd/MM/yyyy}");
                table.Cell().Element(CellStyle).Text(transaction.TransazioneDescrizione);
                table.Cell().Element(CellStyle).Text(transaction.ControparteRagioneSociale);
                table.Cell().Element(CellStyle).Text(transaction.CategoriaNome);
                
                var color = isRevenue ? Colors.Green.Medium : Colors.Red.Medium;
                table.Cell().Element(CellStyle).AlignRight().Text($"{transaction.ImportoNettoEur:N2}").FontColor(color);

                IContainer CellStyle(IContainer container) => container.BorderBottom(0.5f).BorderColor(Colors.Grey.Lighten4).Padding(2);
            }
            
            // Section Total
            table.Footer(footer =>
            {
                 footer.Cell().ColumnSpan(4).Element(CellStyle).AlignRight().Text("Totale " + title).Bold();
                 footer.Cell().Element(CellStyle).AlignRight().Text($"{totalAmount:N2} €").Bold().FontColor(isRevenue ? Colors.Green.Darken2 : Colors.Red.Darken2);
                 
                 IContainer CellStyle(IContainer container) => container.BorderTop(1).BorderColor(Colors.Grey.Lighten2).Padding(2);
            });
        });
        
        if (!isRevenue && totalRevenue > 0)
        {
             var percent = (totalAmount / totalRevenue) * 100;
             column.Item().AlignRight().Text($"Incidenza sui Ricavi: {percent:N2} %").FontSize(9).Italic();
        }
    }

    private void ComposeGlobalSummary(ColumnDescriptor column, BilancioTotals totals)
    {
        column.Item().Background(Colors.Blue.Lighten5).Padding(20).Column(c =>
        {
            c.Item().AlignCenter().Text("RIEPILOGO GENERALE").FontSize(16).Bold().FontColor(Colors.Blue.Darken2);
            c.Item().PaddingTop(10).LineHorizontal(1).LineColor(Colors.Blue.Darken2);
            c.Item().PaddingTop(10).Row(row =>
            {
                row.RelativeItem().AlignCenter().Column(col =>
                {
                    col.Item().Text("Totale Ricavi").FontSize(12);
                    col.Item().Text($"{totals.TotalRevenue:N2} €").FontSize(14).Bold().FontColor(Colors.Green.Darken2);
                });
                row.RelativeItem().AlignCenter().Column(col =>
                {
                    col.Item().Text("Totale Costi").FontSize(12);
                    col.Item().Text($"{totals.TotalCost:N2} €").FontSize(14).Bold().FontColor(Colors.Red.Darken2);
                    col.Item().Text($"{totals.CostPercentage:N2} %").FontSize(10);
                    
                    if (totals.Participants > 0)
                    {
                        var avgCost = totals.TotalCost / totals.Participants;
                        col.Item().PaddingTop(2).Text($"Costo medio/pax: {avgCost:N2} €").FontSize(10).Italic();
                    }
                });
                row.RelativeItem().AlignCenter().Column(col =>
                {
                    col.Item().Text("Margine Totale").FontSize(12);
                    col.Item().Text($"{totals.Margin:N2} €").FontSize(14).Bold().FontColor(Colors.Blue.Darken2);
                    col.Item().Text($"{totals.MarginPercentage:N2} %").FontSize(10);
                    
                    if (totals.Participants > 0)
                    {
                        var avgMargin = totals.Margin / totals.Participants;
                        col.Item().PaddingTop(2).Text($"Guadagno medio/pax: {avgMargin:N2} €").FontSize(10).Italic();
                    }
                });
                
                if (totals.TotalRevenue > 0 || totals.TotalCost > 0)
                {
                    row.RelativeItem().AlignRight().Width(80).Height(80).Image(GeneratePieChart(totals.TotalRevenue, totals.TotalCost));
                }
            });
        });
    }

    private byte[] GeneratePieChart(decimal revenue, decimal cost)
    {
        int width = 300;
        int height = 300;

        using var surface = SKSurface.Create(new SKImageInfo(width, height));
        var canvas = surface.Canvas;

        canvas.Clear(SKColors.Transparent);
        
        if (revenue <= 0) return Array.Empty<byte>();

        // Total is always Revenue (100%)
        float total = (float)revenue;
        
        // Calculate angles
        // If Cost > Revenue, it's a loss, fill 100% red
        float costPercentage = (float)(cost / revenue);
        float costAngle = Math.Min(costPercentage * 360f, 360f);
        float marginAngle = 360f - costAngle;

        float startAngle = -90; // Start at top

        var rect = new SKRect(10, 10, width - 10, height - 10);
        float centerX = width / 2f;
        float centerY = height / 2f;
        float radius = (width - 20) / 2f;

        // Draw Cost Slice (Red) - First slice
        using (var paint = new SKPaint { Color = SKColors.IndianRed, Style = SKPaintStyle.Fill, IsAntialias = true })
        {
            if (costAngle >= 360)
            {
                 canvas.DrawOval(rect, paint);
            }
            else
            {
                 canvas.DrawArc(rect, startAngle, costAngle, true, paint);
            }
        }
        
        // Draw Cost Text (White)
        if (costAngle > 15)
        {
             DrawPercentageText(canvas, costPercentage * 100, startAngle, costAngle, centerX, centerY, radius, SKColors.White);
        }

        // Draw Margin Slice (Green) - Remaining part
        if (marginAngle > 0)
        {
            using (var paint = new SKPaint { Color = SKColors.LightGreen, Style = SKPaintStyle.Fill, IsAntialias = true })
            {
                canvas.DrawArc(rect, startAngle + costAngle, marginAngle, true, paint);
            }
            
            // Draw Margin Text (Black)
            if (marginAngle > 15) 
            {
                float marginPercentage = 100f - (costPercentage * 100f);
                DrawPercentageText(canvas, marginPercentage, startAngle + costAngle, marginAngle, centerX, centerY, radius, SKColors.Black);
            }
        }
        
        // Draw Border
        using (var paint = new SKPaint { Color = SKColors.White, Style = SKPaintStyle.Stroke, StrokeWidth = 3, IsAntialias = true })
        {
             canvas.DrawOval(rect, paint);
             if (costAngle < 360 && costAngle > 0)
             {
                 // Draw line separating slices
                 // Not strictly necessary with DrawArc stroke but good for clean look if using DrawOval
                 // But DrawArc with Stroke on top of whole circle is easier:
             }
             // Re-draw arcs for stroke
             if (costAngle < 360)
             {
                 canvas.DrawArc(rect, startAngle, costAngle, true, paint); // Red border
                 canvas.DrawArc(rect, startAngle + costAngle, marginAngle, true, paint); // Green border
             }
        }

        using var image = surface.Snapshot();
        using var data = image.Encode(SKEncodedImageFormat.Png, 100);
        return data.ToArray();
    }

    private void DrawPercentageText(SKCanvas canvas, float percentage, float startAngle, float sweepAngle, float cx, float cy, float radius, SKColor textColor)
    {
        float midAngle = startAngle + sweepAngle / 2;
        float angleRad = midAngle * (float)Math.PI / 180f;
        
        // Position at 60% of radius
        float tx = cx + (radius * 0.6f) * (float)Math.Cos(angleRad);
        float ty = cy + (radius * 0.6f) * (float)Math.Sin(angleRad);
        
        using var textPaint = new SKPaint
        {
            Color = textColor,
            TextSize = 32, // Larger text for 300x300 canvas
            IsAntialias = true,
            TextAlign = SKTextAlign.Center,
            Typeface = SKTypeface.FromFamilyName("Arial", SKFontStyle.Bold)
        };
        
        // Adjust vertically
        var textBounds = new SKRect();
        string text = $"{percentage:F0}%";
        textPaint.MeasureText(text, ref textBounds);
        ty += textBounds.Height / 2;
        
        // Add outline for better contrast? Maybe not needed if we enforce contrast colors.
        // User asked for White text on Red.
        // Let's keep a subtle shadow or outline if needed, but simple color is cleaner.
        // I will remove the strong white outline I added previously since we are setting specific text colors now.
        // Maybe a subtle black outline for White text, and white outline for Black text?
        // Let's stick to simple contrast first as requested.
        
        canvas.DrawText(text, tx, ty, textPaint);
    }

    private class BilancioTotals
    {
        public decimal TotalRevenue { get; set; }
        public decimal TotalCost { get; set; }
        public int Participants { get; set; }
        public decimal Margin => TotalRevenue - TotalCost;
        public decimal MarginPercentage => TotalRevenue != 0 ? (Margin / TotalRevenue) * 100 : 0;
        public decimal CostPercentage => TotalRevenue != 0 ? (TotalCost / TotalRevenue) * 100 : 0;
    }
}
