using Npgsql;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace GestioneViaggi.Services.Printing;

public interface IRoomingListPrintService
{
    Task<RoomingListPrintDTO> GetRoomingListDataAsync(int dataViaggioId);
}

public class RoomingListPrintService : IRoomingListPrintService
{
    private readonly IDatabaseConnectionManager _connectionManager;
    private readonly GestioneViaggi.Services.CRUD.DocumentiPartecipantiService _documenti;
    private readonly ILogger<RoomingListPrintService> _logger;

    public RoomingListPrintService(IDatabaseConnectionManager connectionManager, ILogger<RoomingListPrintService> logger,
        GestioneViaggi.Services.CRUD.DocumentiPartecipantiService documenti)
    {
        _connectionManager = connectionManager;
        _logger = logger;
            _documenti = documenti;
    }

    public async Task<RoomingListPrintDTO> GetRoomingListDataAsync(int dataViaggioId)
    {
        try
        {
            await using var conn = await _connectionManager.GetConnectionAsync();

            // Fat Init: Single call to get everything for Rooming List
            var sql = "SELECT fn_get_rooming_list_print_data(@DataViaggioId)";
            await using var cmd = new NpgsqlCommand(sql, (NpgsqlConnection)conn);
            cmd.Parameters.AddWithValue("DataViaggioId", dataViaggioId);
            var jsonRes = await cmd.ExecuteScalarAsync() as string;

            if (string.IsNullOrEmpty(jsonRes))
            {
                throw new Exception($"Nessun dato trovato per la Rooming List della data viaggio {dataViaggioId}");
            }

            var raw = JsonSerializer.Deserialize<RoomingListRawResponse>(jsonRes, PrintJsonHelper.GetDefaultOptions());
            
            if (raw == null || raw.Header == null)
            {
                throw new Exception("Errore durante la deserializzazione dei dati della Rooming List");
            }

            var data = new RoomingListPrintDTO();

            // 1. Map Header
            data.Header = new TravelHeaderInfo
            {
                DataViaggioId = raw.Header.data_viaggio_id,
                ViaggioId = raw.Header.viaggio_id,
                Titolo = raw.Header.titolo ?? "N/D",
                Descrizione = raw.Header.descrizione_estesa ?? "",
                DescrizioneBreve = raw.Header.titolo ?? "N/D",
                Destinazione = raw.Header.nazione ?? "",
                DataInizio = raw.Header.data_inizio,
                DataFine = raw.Header.data_fine,
                Note = raw.Header.note_data_viaggio ?? "",
                TipoViaggio = raw.Header.tipo ?? "",
                Giorni = raw.Header.giorni ?? 0,
                Notti = raw.Header.notti ?? 0,
                Trattamento = raw.Header.trattamento ?? "",
                PastiAlSaccoRaw = raw.Header.pasti_al_sacco,
                Km = raw.Header.km ?? 0
            };

            // 2. Map Company
            data.Company = raw.Company ?? new CompanyPrintInfo();
            // Handle logo if it was encoded as base64 in SQL (optional, depending on how Dapper/Postgres handles bytea in json_build_object)
            // If it's already a byte array in the DTO from deserialization, it's fine. 
            // Postgres json_build_object typically encodes bytea as base64 string.
            // System.Text.Json automatically handles base64 string to byte[] conversion if the property is byte[].

            // 3. Map Participants
            var participants = (raw.Participants ?? new List<RoomingParticipantRaw>()).Select(p => new RoomingListParticipant
            {
                ClienteId = p.cliente_id ?? 0,
                RoomId = p.room_id ?? 0,
                Nominativo = p.nominativo ?? "N/D",
                Eta = p.eta ?? 0,
                DataNascita = p.data_nascita,
                LuogoNascita = p.luogo_nascita ?? "",
                IndirizzoResidenza = p.indirizzo_residenza ?? "",
                CittaResidenza = p.citta_residenza ?? "",
                ResidenzaCompleta = p.residenza_completa ?? "",
                CountryCode = p.country_code ?? "IT",
                CountryName = p.country_name ?? "ITALY",
                Nationality = p.nationality ?? "ITALIAN",
                TipoDocumento = p.tipo_documento ?? "",
                NumeroDocumento = p.numero_documento ?? "",
                EnteRilascio = p.ente_rilascio ?? "",
                DataRilascio = p.data_rilascio,
                DataScadenza = p.data_scadenza,
                Intolleranze = p.intolleranze ?? "",
                TipoAlloggioId = p.tipo_alloggio_id ?? 0,
                TipoAlloggioDescrizione = p.tipo_alloggio_descrizione ?? "NESSUNA CAMERA ASSEGNATA",
                MaxOccupanti = p.max_occupanti ?? 0,
                PositionNumber = p.position_number ?? 999,
                IsPilot = p.is_pilot ?? false
            }).ToList();

            // 4. Group by Room Type (Keep existing C# logic as it's efficient enough for UI presentation)
            data.RoomGroups = participants
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
                    Participants = g.ToList(), // Il SQL ordina già tutto (DB-First)
                    RoomCount = g.Select(p => p.RoomId).Distinct().Count()
                })
                .OrderBy(g => g.TipoAlloggioId)
                .ToList();

            // 5. Calculate totals
            data.TotalParticipants = participants.Count;
            data.TotalRooms = participants.Where(p => p.RoomId > 0).Select(p => p.RoomId).Distinct().Count();

            // RoomId = 0 significa "nessuna camera assegnata": il dato arrivava gia' cosi' dal DB,
            // mancava solo chi lo contasse.
            data.ClientiNonAbbinati = participants.Count(p => p.RoomId <= 0);

            // Chi parte con un documento che non arriva alla fine del viaggio: finisce
            // nella nota in fondo al PDF. Il foglio lo leggera' anche chi non ha lanciato
            // la stampa, e per lui l'avviso a schermo non c'e' mai stato.
            data.DocumentiDaSistemare = await _documenti.DaSistemareAsync(dataViaggioId);

            return data;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei dati per la Rooming List {DataViaggioId}", dataViaggioId);
            throw;
        }
    }
}

#region Helper Classes for JSON Deserialization

public class RoomingListRawResponse
{
    public RoomingHeaderRaw Header { get; set; } = new();
    public CompanyPrintInfo Company { get; set; } = new();
    public List<RoomingParticipantRaw> Participants { get; set; } = new();
}

public class RoomingHeaderRaw
{
    public int data_viaggio_id { get; set; }
    public int viaggio_id { get; set; }
    public string? titolo { get; set; }
    public string? descrizione_estesa { get; set; }
    public string? nazione { get; set; }
    public DateTime? data_inizio { get; set; }
    public DateTime? data_fine { get; set; }
    public string? note_data_viaggio { get; set; }
    public string? tipo { get; set; }
    public int? giorni { get; set; }
    public int? notti { get; set; }
    public string? trattamento { get; set; }
    public string? pasti_al_sacco { get; set; }
    public int? km { get; set; }
    public int? azienda_id { get; set; }
}

public class RoomingParticipantRaw
{
    public int? cliente_id { get; set; }
    public int? room_id { get; set; }
    public string? nominativo { get; set; }
    public int? eta { get; set; }
    public DateTime? data_nascita { get; set; }
    public string? luogo_nascita { get; set; }
    public string? indirizzo_residenza { get; set; }
    public string? citta_residenza { get; set; }
    public string? residenza_completa { get; set; }
    public string? country_code { get; set; }
    public string? country_name { get; set; }
    public string? nationality { get; set; }
    public string? tipo_documento { get; set; }
    public string? numero_documento { get; set; }
    public string? ente_rilascio { get; set; }
    public DateTime? data_rilascio { get; set; }
    public DateTime? data_scadenza { get; set; }
    public string? intolleranze { get; set; }
    public int? tipo_alloggio_id { get; set; }
    public string? tipo_alloggio_descrizione { get; set; }
    public int? max_occupanti { get; set; }
    public int? position_number { get; set; }
    public bool? is_pilot { get; set; }
}

#endregion
