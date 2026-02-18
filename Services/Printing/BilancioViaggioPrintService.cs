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
                            column.Item().PageBreak(); 
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
            c.Item().Text($"Dal: {tripInfo.ViaggioDataInizio:dd/MM/yyyy} Al: {tripInfo.ViaggioDataFine:dd/MM/yyyy} - Partecipanti: {tripInfo.ViaggioNumeroPartecipanti}").FontSize(10);
        });

        column.Item().PaddingTop(10);

        // Calculate Trip Totals
        var revenue = transactions.Where(x => x.CategoriaTipo == "RICAVO").Sum(x => x.ImportoNettoEur);
        var cost = transactions.Where(x => x.CategoriaTipo == "COSTO").Sum(x => x.ImportoNettoEur);
        var margin = revenue - cost;
        var marginPercent = revenue > 0 ? (margin / revenue) * 100 : 0;
        
        var totals = new BilancioTotals
        {
            TotalRevenue = revenue,
            TotalCost = cost,
            Participants = tripInfo.ViaggioNumeroPartecipanti
        };

        // Transactions Table
        column.Item().Table(table =>
        {
            table.ColumnsDefinition(columns =>
            {
                columns.ConstantColumn(80); // Data
                columns.RelativeColumn(3);  // Descrizione
                columns.RelativeColumn(2);  // Controparte
                columns.RelativeColumn(2);  // Categoria
                columns.RelativeColumn(1);  // Tipo
                columns.RelativeColumn(1.5f); // Importo
            });

            table.Header(header =>
            {
                header.Cell().Element(CellStyle).Text("Data").SemiBold();
                header.Cell().Element(CellStyle).Text("Descrizione").SemiBold();
                header.Cell().Element(CellStyle).Text("Controparte").SemiBold();
                header.Cell().Element(CellStyle).Text("Categoria").SemiBold();
                header.Cell().Element(CellStyle).Text("Tipo").SemiBold();
                header.Cell().Element(CellStyle).AlignRight().Text("Importo (€)").SemiBold();

                IContainer CellStyle(IContainer container) => container.BorderBottom(1).BorderColor(Colors.Grey.Lighten2).Padding(2);
            });

            foreach (var transaction in transactions.OrderBy(x => x.DataRegistrazione))
            {
                table.Cell().Element(CellStyle).Text($"{transaction.DataRegistrazione:dd/MM/yyyy}");
                table.Cell().Element(CellStyle).Text(transaction.TransazioneDescrizione);
                table.Cell().Element(CellStyle).Text(transaction.ControparteRagioneSociale);
                table.Cell().Element(CellStyle).Text(transaction.CategoriaNome);
                
                var color = transaction.CategoriaTipo == "RICAVO" ? Colors.Green.Medium : Colors.Red.Medium;
                table.Cell().Element(CellStyle).Text(transaction.CategoriaTipo).FontColor(color);
                
                table.Cell().Element(CellStyle).AlignRight().Text($"{transaction.ImportoNettoEur:N2}").FontColor(color);

                IContainer CellStyle(IContainer container) => container.BorderBottom(0.5f).BorderColor(Colors.Grey.Lighten4).Padding(2);
            }
        });

        // Trip Summary
        column.Item().PaddingTop(10).Background(Colors.Grey.Lighten4).Padding(10).Column(c =>
        {
            c.Item().Text("Riepilogo Viaggio").Bold();
            c.Item().Row(row =>
            {
                row.RelativeItem().Column(col =>
                {
                    col.Item().Text($"Totale Ricavi: {revenue:N2} €").FontColor(Colors.Green.Medium);
                    col.Item().Text($"Totale Costi: {cost:N2} €").FontColor(Colors.Red.Medium);
                });
                row.RelativeItem().Column(col =>
                {
                    col.Item().Text($"Margine: {margin:N2} €").Bold();
                    col.Item().Text($"Margine %: {marginPercent:N2} %");
                });
            });
        });
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
                });
                row.RelativeItem().AlignCenter().Column(col =>
                {
                    col.Item().Text("Margine Totale").FontSize(12);
                    col.Item().Text($"{totals.Margin:N2} €").FontSize(14).Bold().FontColor(Colors.Blue.Darken2);
                });
            });
        });
    }

    private class BilancioTotals
    {
        public decimal TotalRevenue { get; set; }
        public decimal TotalCost { get; set; }
        public int Participants { get; set; }
        public decimal Margin => TotalRevenue - TotalCost;
        public decimal MarginPercentage => TotalRevenue != 0 ? (Margin / TotalRevenue) * 100 : 0;
    }
}
