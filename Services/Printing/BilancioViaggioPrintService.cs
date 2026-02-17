using GestioneViaggi.Models.DTOs;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;
using NpgsqlTypes;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Colors = QuestPDF.Helpers.Colors;
using IContainer = QuestPDF.Infrastructure.IContainer;

namespace GestioneViaggi.Services.Printing;

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

    public async Task<byte[]> GeneratePdfAsync(List<BilancioViaggioDTO> data, string aziendaNome)
    {
        return await Task.Run(() =>
        {
            // Group data by trip
            var trips = data.GroupBy(x => x.ViaggioId).ToList();
            
            // Calculate global totals if multiple trips
            var globalTotals = new BilancioTotals
            {
                TotalRevenue = data.Where(x => x.CategoriaTipo == "RICAVO").Sum(x => x.ImportoNettoEur),
                TotalCost = data.Where(x => x.CategoriaTipo == "COSTO").Sum(x => x.ImportoNettoEur)
            };

            var document = Document.Create(container =>
            {
                container.Page(page =>
                {
                    page.Size(PageSizes.A4);
                    page.Margin(1, Unit.Centimetre);
                    page.PageColor(Colors.White);
                    
                    page.Header().Element(ComposeHeader);
                    
                    page.Content().Element(ComposeContent);

                    page.Footer().AlignCenter().Text(x =>
                    {
                        x.CurrentPageNumber();
                        x.Span(" / ");
                        x.TotalPages();
                    });
                });

                void ComposeHeader(IContainer container)
                {
                    container.Row(row =>
                    {
                        row.RelativeItem().Column(column =>
                        {
                            column.Item().Text(aziendaNome).FontSize(20).SemiBold().FontColor(Colors.Blue.Medium);
                            column.Item().Text("Bilancio di Viaggio").FontSize(16).SemiBold();
                            column.Item().Text($"Generato il: {DateTime.Now:dd/MM/yyyy HH:mm}");
                        });
                    });
                }

                void ComposeContent(IContainer container)
                {
                    container.Column(column =>
                    {
                        foreach (var trip in trips)
                        {
                            var tripData = trip.ToList();
                            var first = tripData.First();
                            
                            var tripTotals = new BilancioTotals
                            {
                                TotalRevenue = tripData.Where(x => x.CategoriaTipo == "RICAVO").Sum(x => x.ImportoNettoEur),
                                TotalCost = tripData.Where(x => x.CategoriaTipo == "COSTO").Sum(x => x.ImportoNettoEur),
                                Participants = first.ViaggioNumeroPartecipanti
                            };

                             // Page break logic: if not first trip, add page break.
                            if (trip != trips.First()) column.Item().PageBreak();

                            // Trip Header
                            column.Item().BorderBottom(1).BorderColor(Colors.Grey.Lighten2).PaddingBottom(5).Row(row => 
                            {
                                row.RelativeItem().Column(c => 
                                { 
                                    c.Item().Text(first.ViaggioDescrizione).FontSize(14).Bold();
                                    if (first.ViaggioDataInizio.HasValue)
                                        c.Item().Text($"{first.ViaggioDataInizio:dd/MM/yyyy} - {first.ViaggioDataFine:dd/MM/yyyy}").FontSize(10).FontColor(Colors.Grey.Medium);
                                });
                                 if (tripTotals.Participants > 0)
                                {
                                    row.ConstantItem(100).AlignRight().Text($"Pax: {tripTotals.Participants}").FontSize(11);
                                }
                            });


                            column.Item().PaddingTop(10);
                            
                            // REVENUES Section
                            var revenues = tripData.Where(x => x.CategoriaTipo == "RICAVO").OrderBy(x => x.DataDocumento).ToList();
                            RenderSection(column, "RICAVI (Vendite)", revenues, tripTotals.TotalRevenue, isCost: false, totalCostForIncidence: 0); 

                            column.Item().PaddingTop(15);
                            
                            // COSTS Section
                            var costs = tripData.Where(x => x.CategoriaTipo == "COSTO").OrderBy(x => x.CategoriaNome).ThenBy(x => x.DataDocumento).ToList();
                            RenderSection(column, "COSTI (Acquisti)", costs, tripTotals.TotalCost, isCost: true, totalCostForIncidence: tripTotals.TotalCost);

                            column.Item().PaddingTop(20);
                            
                            // SUMMARY Box for Trip
                            RenderSummaryBox(column, tripTotals);
                        }

                        // Global Summary if multiple trips
                        if (trips.Count > 1)
                        {
                            column.Item().PageBreak();
                            column.Item().Text("RIEPILOGO GENERALE").FontSize(16).Bold();
                            RenderSummaryBox(column, globalTotals);
                        }
                    });
                }

                void RenderSection(ColumnDescriptor column, string title, List<BilancioViaggioDTO> items, decimal sectionTotal, bool isCost, decimal totalCostForIncidence)
                {
                    column.Item().Text(title).FontSize(12).Bold().FontColor(isCost ? Colors.Red.Darken1 : Colors.Green.Darken1);
                    
                    if (!items.Any())
                    {
                        column.Item().Text("Nessuna transazione registrata.").FontSize(10).Italic();
                        return;
                    }

                    column.Item().Table(table =>
                    {
                        table.ColumnsDefinition(columns =>
                        {
                            columns.RelativeColumn(3); // Categoria/Descrizione
                            columns.RelativeColumn(2); // Controparte
                            columns.RelativeColumn(2); // Documento
                            columns.RelativeColumn(2); // Data
                            columns.RelativeColumn(2); // Importo
                            if (isCost) columns.RelativeColumn(1); // % Inc.
                        });

                        // Header
                        table.Header(header =>
                        {
                            header.Cell().Text(isCost ? "Categoria" : "Descrizione").Bold();
                            header.Cell().Text("Controparte").Bold();
                            header.Cell().Text("Doc. N.").Bold();
                            header.Cell().Text("Data").Bold();
                            header.Cell().AlignRight().Text("Importo (€)").Bold();
                            if (isCost) header.Cell().AlignRight().Text("% Inc.").Bold();
                        });

                        // Group by Categoria if Cost
                        if (isCost)
                        {
                            foreach (var group in items.GroupBy(x => x.CategoriaNome))
                            {
                                decimal groupTotal = group.Sum(x => x.ImportoNettoEur);
                                decimal incidence = totalCostForIncidence != 0 ? (groupTotal / totalCostForIncidence) * 100 : 0;

                                foreach (var item in group)
                                {
                                    RenderRow(table, item, isCost, totalCostForIncidence);
                                }
                                
                                // Category Subtotal
                                table.Cell().ColumnSpan(4).AlignRight().Text($"{group.Key} Totale:").FontSize(9).Bold();
                                table.Cell().AlignRight().Text($"{groupTotal:N2}").FontSize(9).Bold();
                                table.Cell().AlignRight().Text($"{incidence:N1}%").FontSize(9).Italic();
                            }
                        }
                        else
                        {
                            foreach (var item in items)
                            {
                                RenderRow(table, item, isCost, 0);
                            }
                        }

                        // Section Total
                        table.Cell().ColumnSpan(4).AlignRight().PaddingTop(5).Text("TOTALE SEZIONE:").Bold();
                        table.Cell().AlignRight().PaddingTop(5).BorderTop(1).Text($"{sectionTotal:N2}").Bold();
                        if (isCost) table.Cell().Text("");
                    });
                }

                void RenderRow(TableDescriptor table, BilancioViaggioDTO item, bool isCost, decimal totalCost)
                {
                    table.Cell().BorderBottom(1).BorderColor(Colors.Grey.Lighten3).PaddingVertical(2).Text(isCost ? item.CategoriaNome : item.TransazioneDescrizione).FontSize(9);
                    table.Cell().BorderBottom(1).BorderColor(Colors.Grey.Lighten3).PaddingVertical(2).Text(item.ControparteRagioneSociale).FontSize(9);
                    table.Cell().BorderBottom(1).BorderColor(Colors.Grey.Lighten3).PaddingVertical(2).Text(item.NumeroDocumento).FontSize(9);
                    table.Cell().BorderBottom(1).BorderColor(Colors.Grey.Lighten3).PaddingVertical(2).Text(item.DataDocumento?.ToString("dd/MM/yyyy") ?? "-").FontSize(9);
                    
                    table.Cell().BorderBottom(1).BorderColor(Colors.Grey.Lighten3).AlignRight().PaddingVertical(2).Text($"{item.ImportoNettoEur:N2}").FontSize(9);
                    
                    if (isCost)
                    {
                        table.Cell().Text(""); 
                    }
                }

                void RenderSummaryBox(ColumnDescriptor column, BilancioTotals totals)
                {
                    column.Item().Background(Colors.Grey.Lighten4).Padding(10).Column(c =>
                    {
                        c.Item().Text("RIEPILOGO MARGINI").Bold();
                        
                        c.Item().Table(t => 
                        {
                            t.ColumnsDefinition(cols => 
                            {
                                cols.RelativeColumn();
                                cols.ConstantColumn(100);
                            });

                            t.Cell().Text("Totale Ricavi:");
                            t.Cell().AlignRight().Text($"{totals.TotalRevenue:N2} €").Bold().FontColor(Colors.Green.Darken2);

                            t.Cell().Text("Totale Costi:");
                            t.Cell().AlignRight().Text($"{totals.TotalCost:N2} €").Bold().FontColor(Colors.Red.Darken2);

                            t.Cell().PaddingTop(5).BorderTop(1).Text("MARGINE OPERATIVO:").Bold();
                            t.Cell().PaddingTop(5).BorderTop(1).AlignRight().Text($"{totals.Margin:N2} €").FontSize(12).Bold();

                            t.Cell().Text("Margine %:");
                            t.Cell().AlignRight().Text($"{totals.MarginPercentage:N2}%").Bold();

                            if (totals.Participants > 0)
                            {
                                t.Cell().PaddingTop(5).Text("Costo Medio per Pax:").Italic();
                                t.Cell().PaddingTop(5).AlignRight().Text($"{(totals.TotalCost / totals.Participants):N2} €").Italic();
                            }
                        });
                    });
                }
            });

            return document.GeneratePdf();
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
