using GestioneViaggi.Models.DTOs;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;
using NpgsqlTypes;
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
    private readonly AziendaService _aziendaService;
    private readonly AziendaLogoService _aziendaLogoService;
    private readonly ITenantContext _tenantContext;
    private readonly ILogger<BilancioViaggioPrintService> _logger;

    public BilancioViaggioPrintService(
        IDatabaseService databaseService,
        AziendaService aziendaService,
        AziendaLogoService aziendaLogoService,
        ITenantContext tenantContext,
        ILogger<BilancioViaggioPrintService> logger)
    {
        _databaseService = databaseService;
        _aziendaService = aziendaService;
        _aziendaLogoService = aziendaLogoService;
        _tenantContext = tenantContext;
        _logger = logger;
    }

    public async Task<BilancioViaggioPrintData> GetBilancioPrintDataAsync(int aziendaId, int viaggioId, int? dataViaggioId, DateTime? dataDa, DateTime? dataA, string utenteStampa)
    {
        var data = new BilancioViaggioPrintData
        {
            UtenteStampa = utenteStampa,
            DataStampa = DateTime.Now
        };

        // 1. Fetch Company Info
        var azienda = await _aziendaService.GetByIdAsync(aziendaId);
        if (azienda != null)
        {
            data.Azienda.RagioneSociale = azienda.RagioneSociale;
            data.Azienda.Piva = azienda.PartitaIva;
            data.Azienda.Telefono = azienda.TelefonoPrincipale;
            data.Azienda.Email = azienda.Pec ?? "";
            data.Azienda.SitoWeb = azienda.SitoWeb ?? "";

            // 2. Fetch Logo
            try
            {
                var logos = await _aziendaLogoService.GetByAziendaIdAsync(aziendaId);
                var primaryLogo = logos.FirstOrDefault(l => l.IsDefault) ?? logos.FirstOrDefault();
                if (primaryLogo != null)
                {
                    var logoData = await _aziendaLogoService.GetBinaryDataAsync(primaryLogo.Id);
                    if (logoData != null)
                    {
                        data.Azienda.LogoData = logoData;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Impossibile recuperare il logo per l'azienda {AziendaId}", aziendaId);
            }
        }

        // 3. Fetch Details
        data.Dettagli = await GetBilancioDataAsync(aziendaId, viaggioId, dataViaggioId, dataDa, dataA);

        return data;
    }

    public async Task<List<BilancioViaggioDTO>> GetBilancioDataAsync(int aziendaId, int viaggioId, int? dataViaggioId, DateTime? dataDa, DateTime? dataA)
    {
        var result = new List<BilancioViaggioDTO>();
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM fn_get_bilancio_viaggio(@aziendaId, @viaggioId, @dataViaggioId, @dataDa, @dataA)";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaId", aziendaId);
            command.Parameters.AddWithValue("viaggioId", viaggioId);
            
            var pDataViaggioId = new NpgsqlParameter("dataViaggioId", NpgsqlDbType.Integer) { Value = (object?)dataViaggioId ?? DBNull.Value, IsNullable = true };
            command.Parameters.Add(pDataViaggioId);

            // Handle nullable dates explicitly
            var pDataDa = new NpgsqlParameter("dataDa", NpgsqlDbType.Date) { Value = (object?)dataDa ?? DBNull.Value, IsNullable = true };
            var pDataA = new NpgsqlParameter("dataA", NpgsqlDbType.Date) { Value = (object?)dataA ?? DBNull.Value, IsNullable = true };
            
            command.Parameters.Add(pDataDa);
            command.Parameters.Add(pDataA);

            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(new BilancioViaggioDTO
                {
                    ViaggioId = reader.GetInt32(reader.GetOrdinal("viaggio_id")),
                    ViaggioDescrizione = reader.GetString(reader.GetOrdinal("viaggio_descrizione")),
                    ViaggioDataInizio = reader.IsDBNull(reader.GetOrdinal("viaggio_data_inizio")) ? null : reader.GetDateTime(reader.GetOrdinal("viaggio_data_inizio")),
                    ViaggioDataFine = reader.IsDBNull(reader.GetOrdinal("viaggio_data_fine")) ? null : reader.GetDateTime(reader.GetOrdinal("viaggio_data_fine")),
                    ViaggioNumeroPartecipanti = reader.GetInt32(reader.GetOrdinal("viaggio_numero_partecipanti")),
                    ViaggioNumeroMezzi = reader.GetInt32(reader.GetOrdinal("viaggio_numero_mezzi")),

                    TransazioneId = reader.GetInt32(reader.GetOrdinal("transazione_id")),
                    DataDocumento = reader.IsDBNull(reader.GetOrdinal("data_documento")) ? null : reader.GetDateTime(reader.GetOrdinal("data_documento")),
                    DataRegistrazione = reader.GetDateTime(reader.GetOrdinal("data_registrazione")),
                    NumeroDocumento = reader.GetString(reader.GetOrdinal("numero_documento")),
                    TransazioneDescrizione = reader.GetString(reader.GetOrdinal("transazione_descrizione")),

                    ControparteRagioneSociale = reader.GetString(reader.GetOrdinal("controparte_ragione_sociale")),
                    CategoriaNome = reader.GetString(reader.GetOrdinal("categoria_nome")),
                    CategoriaTipo = reader.GetString(reader.GetOrdinal("categoria_tipo")),

                    ImportoNettoEur = reader.GetDecimal(reader.GetOrdinal("importo_netto_eur")),
                    ImportoIvaEur = reader.GetDecimal(reader.GetOrdinal("importo_iva_eur")),
                    ImportoLordoEur = reader.GetDecimal(reader.GetOrdinal("importo_lordo_eur")),
                    ImportoPagatoEur = reader.GetDecimal(reader.GetOrdinal("importo_pagato_eur")),
                    StatoPagamento = reader.GetString(reader.GetOrdinal("stato_pagamento"))
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore recupero dati bilancio viaggio");
            throw;
        }
        return result;
    }

    public async Task<byte[]> GeneratePdfAsync(BilancioViaggioPrintData printData)
    {
        return await Task.Run(() =>
        {
            var data = printData.Dettagli;

            // Group data by trip
            var trips = data.GroupBy(x => x.ViaggioId).ToList();
            
            // Calculate global totals if multiple trips
            var globalTotals = new BilancioTotals
            {
                TotalRevenue = data.Where(x => x.CategoriaTipo == "RICAVO").Sum(x => x.ImportoNettoEur),
                TotalCost = data.Where(x => x.CategoriaTipo == "COSTO").Sum(x => x.ImportoNettoEur),
                Participants = data.Select(x => x.ViaggioNumeroPartecipanti).FirstOrDefault() // Approximation for global
            };

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
                        foreach (var trip in trips)
                        {
                            var tripInfo = trip.First();
                            ComposeTripSection(column, tripInfo, trip.ToList());
                            
                            // Page break only if not the last trip
                            if (trip != trips.Last())
                            {
                                column.Item().PageBreak(); 
                            }
                        }

                        // Summary Page if more than one trip
                        if (trips.Count > 1)
                        {
                             ComposeGlobalSummary(column, globalTotals);
                        }
                    });

                    page.Footer().Element(ReportHeaderHelper.ComposeFooter);
                });
            });

            return document.GeneratePdf();
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
                });
                row.RelativeItem().Column(col =>
                {
                    col.Item().Text($"Margine").FontSize(10);
                    col.Item().Text($"{margin:N2} €").FontSize(12).Bold().FontColor(Colors.Blue.Darken2);
                    col.Item().Text($"{marginPercent:N2} %").FontSize(9);
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
                });
                row.RelativeItem().AlignCenter().Column(col =>
                {
                    col.Item().Text("Margine Totale").FontSize(12);
                    col.Item().Text($"{totals.Margin:N2} €").FontSize(14).Bold().FontColor(Colors.Blue.Darken2);
                    col.Item().Text($"{totals.MarginPercentage:N2} %").FontSize(10);
                });
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
