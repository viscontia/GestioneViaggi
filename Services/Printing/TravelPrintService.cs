using Npgsql;
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
    private readonly GestioneViaggi.Services.CRUD.DocumentiPartecipantiService _documenti;
    private readonly ILogger<TravelPrintService> _logger;

    public TravelPrintService(IDatabaseConnectionManager connectionManager, ILogger<TravelPrintService> logger,
        GestioneViaggi.Services.CRUD.DocumentiPartecipantiService documenti)
    {
        _connectionManager = connectionManager;
        _logger = logger;
            _documenti = documenti;
    }

    public async Task<TravelPrintDTO> GetPrintDataAsync(int dataViaggioId)
    {
        try
        {
            await using var conn = await _connectionManager.GetConnectionAsync();

            var sql = "SELECT fn_get_travel_print_data(@DataViaggioId)";
            await using var cmd = new NpgsqlCommand(sql, (NpgsqlConnection)conn);
            cmd.Parameters.AddWithValue("DataViaggioId", dataViaggioId);
            var json = await cmd.ExecuteScalarAsync() as string;

            if (string.IsNullOrEmpty(json))
            {
                throw new Exception($"Nessun dato trovato per il viaggio con ID {dataViaggioId}");
            }

            // Use centralized JSON options for consistent snake_case handling
            var options = PrintJsonHelper.GetDefaultOptions();

            // Raw response structure from SQL
            var rawData = System.Text.Json.JsonSerializer.Deserialize<TravelPrintRawResponse>(json, options);

            if (rawData == null || rawData.Header == null)
            {
                throw new Exception($"Errore durante la deserializzazione dei dati per il viaggio {dataViaggioId}");
            }

            var data = new TravelPrintDTO
            {
                Header = rawData.Header,
                Company = rawData.Company ?? new CompanyPrintInfo(),
                Participants = rawData.Participants ?? new List<ParticipantPrintInfo>()
            };

            // Merge Stats into Header
            if (rawData.Stats != null)
            {
                data.Header.TotalParticipants = rawData.Stats.TotalParticipants;
                data.Header.TotalCrews = rawData.Stats.TotalCrews;
                data.Header.TotalVehicles = rawData.Stats.TotalVehicles;
            }

            // Map and Group Vehicles
            if (rawData.PilotsByVehicle != null && rawData.PilotsByVehicle.Any())
            {
                data.VehicleGroups = rawData.PilotsByVehicle
                    .GroupBy(p => new { Marca = p.Marca ?? "N/D", Modello = p.Modello ?? "N/D" })
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
            }

            // Chi parte con un documento che non arriva alla fine del viaggio: finisce
            // nella nota in fondo al PDF. Il foglio lo leggera' anche chi non ha lanciato
            // la stampa, e per lui l'avviso a schermo non c'e' mai stato.
            data.DocumentiDaSistemare = await _documenti.DaSistemareAsync(dataViaggioId);

            return data;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei dati Fat Init per la stampa viaggio {DataViaggioId}", dataViaggioId);
            throw;
        }
    }

    // Helper classes for JSON deserialization
    private class TravelPrintRawResponse
    {
        [System.Text.Json.Serialization.JsonPropertyName("Header")]
        public TravelHeaderInfo? Header { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("Company")]
        public CompanyPrintInfo? Company { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("Participants")]
        public List<ParticipantPrintInfo>? Participants { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("Stats")]
        public TravelStatsRaw? Stats { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("PilotsByVehicle")]
        public List<PilotVehicleInfo>? PilotsByVehicle { get; set; }
    }

    private class TravelStatsRaw
    {
        [System.Text.Json.Serialization.JsonPropertyName("total_participants")]
        public int TotalParticipants { get; set; }
        [System.Text.Json.Serialization.JsonPropertyName("total_crews")]
        public int TotalCrews { get; set; }
        [System.Text.Json.Serialization.JsonPropertyName("total_vehicles")]
        public int TotalVehicles { get; set; }
    }
}
