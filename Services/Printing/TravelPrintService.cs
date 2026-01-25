using Dapper;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Printing;

public interface ITravelPrintService
{
    Task<TravelPrintDTO> GetPrintDataAsync(int dataViaggioId);
}

public class TravelPrintService : ITravelPrintService
{
    private readonly IDatabaseConnectionManager _connectionManager;
    private readonly ILogger<TravelPrintService> _logger;

    public TravelPrintService(IDatabaseConnectionManager connectionManager, ILogger<TravelPrintService> logger)
    {
        _connectionManager = connectionManager;
        _logger = logger;
    }

    public async Task<TravelPrintDTO> GetPrintDataAsync(int dataViaggioId)
    {
        try
        {
            using var conn = await _connectionManager.GetConnectionAsync();
            var data = new TravelPrintDTO();

            // 1. Fetch Header Info
            var headerSql = "SELECT * FROM get_all_travel_detail(@DataViaggioId)";
            var headerRaw = await conn.QueryFirstOrDefaultAsync<dynamic>(headerSql, new { DataViaggioId = dataViaggioId });

            if (headerRaw == null)
            {
                throw new Exception($"Nessun viaggio trovato con ID {dataViaggioId}");
            }

            var header = new TravelHeaderInfo
            {
                DataViaggioId = (int)headerRaw.data_viaggio_id,
                ViaggioId = (int)headerRaw.viaggio_id,
                Titolo = (string)headerRaw.titolo ?? "N/D",
                Descrizione = (string)headerRaw.descrizione_estesa ?? "", // Using descrizione_estesa as strictly mapped
                DescrizioneBreve = (string)headerRaw.titolo ?? "N/D", // Using titolo (viaggio_descrizione_breve) for file naming
                Destinazione = (string)headerRaw.nazione ?? "",
                DataInizio = (DateTime?)headerRaw.data_inizio,
                DataFine = (DateTime?)headerRaw.data_fine,
                Note = (string)headerRaw.note_data_viaggio ?? "",
                // Characteristics
                TipoViaggio = (string)headerRaw.tipo ?? "",
                Giorni = (int?)headerRaw.giorni ?? 0,
                Notti = (int?)headerRaw.notti ?? 0,
                Trattamento = (string)headerRaw.trattamento ?? "",
                PastiSacco = ((string)headerRaw.pasti_al_sacco ?? "N") == "Y" || ((string)headerRaw.pasti_al_sacco ?? "N") == "S",
                Km = (int?)headerRaw.km ?? 0
            };

            // 1b. Fetch Company Info
            int aziendaId = (int?)headerRaw.azienda_id ?? 0;

            if (aziendaId > 0)
            {
                var companySql = "SELECT * FROM get_company_print_info(@AziendaId)";
                var companyRaw = await conn.QueryFirstOrDefaultAsync<dynamic>(companySql, new { AziendaId = aziendaId });

                if (companyRaw != null)
                {
                    data.Company = new CompanyPrintInfo
                    {
                        RagioneSociale = (string)companyRaw.ragione_sociale ?? "",
                        Telefono = (string)companyRaw.telefono ?? "",
                        Email = (string)companyRaw.email ?? "", // This maps to PEC in the function
                        SitoWeb = (string)companyRaw.sito_web ?? "",
                        Piva = (string)companyRaw.piva ?? "",
                        LogoData = companyRaw.logo_data != null ? (byte[])companyRaw.logo_data : Array.Empty<byte>()
                    };
                }
            }

            // 2. Fetch Participants
            var partSql = "SELECT * FROM get_participants_sorted(@DataViaggioId)";
            var participantsRaw = await conn.QueryAsync<dynamic>(partSql, new { DataViaggioId = dataViaggioId });

            var participants = participantsRaw.Select(p => new ParticipantPrintInfo
            {
                ViaggioId = (int?)p.viaggio_id ?? 0,
                DataId = (int?)p.data_id ?? 0,
                ClienteId = (int?)p.cliente_id ?? 0,
                Nominativo = (string)p.nominativo ?? "N/D",
                TipoPartecipanteId = (int?)p.tipo_partecipante_id ?? 0,
                Ruolo = (string)p.ruolo ?? "",
                Note = p.note as string ?? string.Empty,
                CaneSino = (string)p.cane_sino ?? "N",
                Intolleranze = p.intolleranze as string ?? string.Empty,
                MezzoDettagli = p.mezzo_dettagli as string ?? string.Empty,
                ClientePilotaId = p.cliente_pilota_id as int?,
                GroupingKey = (int?)p.grouping_key ?? 0,
                IsPilot = (bool?)p.is_pilot ?? false,
                
                // Personal Details - fixed column names to match SQL query
                Telefono = p.telefono as string ?? string.Empty,
                Email = p.email as string ?? string.Empty,
                Residenza = p.residenza as string ?? string.Empty,
                CodiceFiscale = p.codice_fiscale as string ?? string.Empty,
                DataNascita = p.data_nascita as DateTime?,
                LuogoNascita = p.luogo_nascita as string ?? string.Empty
            }).ToList();

            data.Header = header;
            data.Participants = participants;

            // 3. Fetch Stats from DB
            var statsSql = "SELECT * FROM get_travel_stats(@DataViaggioId)";
            var statsRaw = await conn.QueryFirstOrDefaultAsync<dynamic>(statsSql, new { DataViaggioId = dataViaggioId });

            if (statsRaw != null)
            {
                data.Header.TotalParticipants = (int?)statsRaw.total_participants ?? 0;
                data.Header.TotalCrews = (int?)statsRaw.total_crews ?? 0;
                data.Header.TotalVehicles = (int?)statsRaw.total_vehicles ?? 0;
            }

            // 4. Fetch Pilots Grouped by Vehicle
            var vehicleSql = "SELECT * FROM get_pilots_grouped_by_vehicle(@DataViaggioId)";
            var pilotsRaw = await conn.QueryAsync<dynamic>(vehicleSql, new { DataViaggioId = dataViaggioId });

            var pilotsList = pilotsRaw.Select(p => new PilotVehicleInfo
            {
                ViaggioId = (int?)p.viaggio_id ?? 0,
                DataId = (int?)p.data_id ?? 0,
                ClienteId = (int?)p.cliente_id ?? 0,
                Nominativo = (string)p.nominativo ?? "N/D",
                Marca = (string)p.marca ?? "N/D",
                Modello = (string)p.modello ?? "N/D",
                Targa = (string)p.targa ?? "",
                Telefono = (string)p.telefono ?? "",
                Email = (string)p.email ?? "",
                Residenza = (string)p.residenza ?? "",
                CodiceFiscale = (string)p.codice_fiscale ?? "",
                DataNascita = p.data_nascita as DateTime?,
                LuogoNascita = (string)p.luogo_nascita ?? ""
            }).ToList();

            // Group by Marca and Modello
            data.VehicleGroups = pilotsList
                .GroupBy(p => new { p.Marca, p.Modello })
                .Select(g => new VehicleGroupInfo
                {
                    Marca = g.Key.Marca,
                    Modello = g.Key.Modello,
                    Count = g.Count(),
                    Pilots = g.ToList()
                })
                .OrderBy(g => g.Marca)
                .ThenBy(g => g.Modello)
                .ToList();

            return data;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei dati per la stampa scheda viaggio {DataViaggioId}", dataViaggioId);
            throw;
        }
    }
}
