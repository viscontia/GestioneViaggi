using Dapper;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Printing;

public interface IRoomingListPrintService
{
    Task<RoomingListPrintDTO> GetRoomingListDataAsync(int dataViaggioId);
}

public class RoomingListPrintService : IRoomingListPrintService
{
    private readonly IDatabaseConnectionManager _connectionManager;
    private readonly ILogger<RoomingListPrintService> _logger;

    public RoomingListPrintService(IDatabaseConnectionManager connectionManager, ILogger<RoomingListPrintService> logger)
    {
        _connectionManager = connectionManager;
        _logger = logger;
    }

    public async Task<RoomingListPrintDTO> GetRoomingListDataAsync(int dataViaggioId)
    {
        try
        {
            using var conn = await _connectionManager.GetConnectionAsync();
            var data = new RoomingListPrintDTO();

            // 1. Fetch Header Info (reuse same function as Travel Print)
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
                Descrizione = (string)headerRaw.descrizione_estesa ?? "",
                DescrizioneBreve = (string)headerRaw.titolo ?? "N/D",
                Destinazione = (string)headerRaw.nazione ?? "",
                DataInizio = (DateTime?)headerRaw.data_inizio,
                DataFine = (DateTime?)headerRaw.data_fine,
                Note = (string)headerRaw.note_data_viaggio ?? "",
                TipoViaggio = (string)headerRaw.tipo ?? "",
                Giorni = (int?)headerRaw.giorni ?? 0,
                Notti = (int?)headerRaw.notti ?? 0,
                Trattamento = (string)headerRaw.trattamento ?? "",
                PastiSacco = ((string)headerRaw.pasti_al_sacco ?? "N") == "Y" || ((string)headerRaw.pasti_al_sacco ?? "N") == "S",
                Km = (int?)headerRaw.km ?? 0
            };

            data.Header = header;

            // 2. Fetch Company Info
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
                        Email = (string)companyRaw.email ?? "",
                        SitoWeb = (string)companyRaw.sito_web ?? "",
                        Piva = (string)companyRaw.piva ?? "",
                        LogoData = companyRaw.logo_data != null ? (byte[])companyRaw.logo_data : Array.Empty<byte>()
                    };
                }
            }

            // 3. Fetch Rooming List Data
            var roomingListSql = "SELECT * FROM get_rooming_list_data(@DataViaggioId)";
            var participantsRaw = await conn.QueryAsync<dynamic>(roomingListSql, new { DataViaggioId = dataViaggioId });

            var participants = participantsRaw.Select(p => new RoomingListParticipant
            {
                ClienteId = (int?)p.cliente_id ?? 0,
                RoomId = (int?)p.room_id ?? 0,
                Nominativo = (string)p.nominativo ?? "N/D",
                Eta = (int?)p.eta ?? 0,
                DataNascita = p.data_nascita as DateTime?,
                LuogoNascita = (string)p.luogo_nascita ?? "",
                IndirizzoResidenza = (string)p.indirizzo_residenza ?? "",
                CittaResidenza = (string)p.citta_residenza ?? "",
                ResidenzaCompleta = (string)p.residenza_completa ?? "",
                CountryCode = (string)p.country_code ?? "IT",
                CountryName = (string)p.country_name ?? "ITALY",
                Nationality = (string)p.nationality ?? "ITALIAN",
                TipoDocumento = (string)p.tipo_documento ?? "",
                NumeroDocumento = (string)p.numero_documento ?? "",
                EnteRilascio = (string)p.ente_rilascio ?? "",
                DataRilascio = p.data_rilascio as DateTime?,
                DataScadenza = p.data_scadenza as DateTime?,
                Intolleranze = (string)p.intolleranze ?? "",
                TipoAlloggioId = (int?)p.tipo_alloggio_id ?? 0,
                TipoAlloggioDescrizione = (string)p.tipo_alloggio_descrizione ?? "NESSUNA CAMERA ASSEGNATA",
                MaxOccupanti = (int?)p.max_occupanti ?? 0
            }).ToList();

            // 4. Group by Room Type
            var roomGroups = participants
                .GroupBy(p => new
                {
                    p.TipoAlloggioId,
                    p.TipoAlloggioDescrizione,
                    p.MaxOccupanti
                })
                .Select(g => new RoomTypeGroup
                {
                    TipoAlloggioId = g.Key.TipoAlloggioId,
                    TipoAlloggioDescrizione = g.Key.TipoAlloggioDescrizione,
                    MaxOccupanti = g.Key.MaxOccupanti,
                    Participants = g.OrderBy(p => p.RoomId).ThenBy(p => p.Nominativo).ToList(),
                    RoomCount = g.Select(p => p.RoomId).Distinct().Count()
                })
                .OrderBy(g => g.TipoAlloggioId)
                .ToList();

            data.RoomGroups = roomGroups;

            // 5. Calculate totals
            data.TotalParticipants = participants.Count;
            data.TotalRooms = participants.Where(p => p.RoomId > 0).Select(p => p.RoomId).Distinct().Count();

            return data;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei dati per la Rooming List {DataViaggioId}", dataViaggioId);
            throw;
        }
    }
}
