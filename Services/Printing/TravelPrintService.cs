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

            // Get viaggio_descrizione_breve directly from ana_viaggi for file naming
            var descBreveSql = "SELECT viaggio_descrizione_breve FROM ana_viaggi WHERE viaggio_id = @ViaggioId";
            var descBreve = await conn.QueryFirstOrDefaultAsync<string>(descBreveSql, new { ViaggioId = (int)headerRaw.viaggio_id }) ?? "";

            var header = new TravelHeaderInfo
            {
                DataViaggioId = (int)headerRaw.data_viaggio_id,
                ViaggioId = (int)headerRaw.viaggio_id,
                Titolo = (string)headerRaw.titolo,
                Descrizione = (string)headerRaw.descrizione_estesa, // Using descrizione_estesa as strictly mapped
                DescrizioneBreve = descBreve, // Direct from ana_viaggi for file naming
                Destinazione = (string)headerRaw.nazione,
                DataInizio = (DateTime?)headerRaw.data_inizio,
                DataFine = (DateTime?)headerRaw.data_fine,
                Note = (string)headerRaw.note_data_viaggio,
                // Characteristics
                TipoViaggio = (string)headerRaw.tipo,
                Giorni = (int)headerRaw.giorni,
                Notti = (int)headerRaw.notti,
                Trattamento = (string)headerRaw.trattamento,
                PastiSacco = (string)headerRaw.pasti_al_sacco == "Y" || (string)headerRaw.pasti_al_sacco == "S",
                Km = (int)headerRaw.km
            };

            // 1b. Fetch Company Info
            // We need to find the AziendaId for this trip. 
            // Since get_all_travel_detail doesn't return it (according to schema check), we fetch it from ana_viaggi.
            var aziendaIdSql = "SELECT azienda_id FROM ana_viaggi WHERE viaggio_id = @ViaggioId";
            int aziendaId = await conn.QueryFirstOrDefaultAsync<int>(aziendaIdSql, new { ViaggioId = header.ViaggioId });

            if (aziendaId > 0)
            {
                var companySql = "SELECT * FROM get_company_print_info(@AziendaId)";
                var companyRaw = await conn.QueryFirstOrDefaultAsync<dynamic>(companySql, new { AziendaId = aziendaId });

                if (companyRaw != null)
                {
                    data.Company = new CompanyPrintInfo
                    {
                        RagioneSociale = (string)companyRaw.ragione_sociale,
                        Telefono = (string)companyRaw.telefono,
                        Email = (string)companyRaw.email, // This maps to PEC in the function
                        SitoWeb = (string)companyRaw.sito_web,
                        Piva = (string)companyRaw.piva,
                        LogoData = companyRaw.logo_data != null ? (byte[])companyRaw.logo_data : Array.Empty<byte>()
                    };
                }
            }

            // 2. Fetch Participants
            var partSql = "SELECT * FROM get_participants_sorted(@DataViaggioId)";
            var participantsRaw = await conn.QueryAsync<dynamic>(partSql, new { DataViaggioId = dataViaggioId });

            var participants = participantsRaw.Select(p => new ParticipantPrintInfo
            {
                ViaggioId = (int)p.viaggio_id,
                DataId = (int)p.data_id,
                ClienteId = (int)p.cliente_id,
                Nominativo = (string)p.nominativo,
                TipoPartecipanteId = (int)p.tipo_partecipante_id,
                Ruolo = (string)p.ruolo,
                Note = p.note as string ?? string.Empty,
                CaneSino = (string)p.cane_sino,
                Intolleranze = p.intolleranze as string ?? string.Empty,
                MezzoDettagli = p.mezzo_dettagli as string ?? string.Empty,
                ClientePilotaId = p.cliente_pilota_id as int?,
                GroupingKey = (int)p.grouping_key,
                IsPilot = (bool)p.is_pilot,
                
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
                data.Header.TotalParticipants = (int)statsRaw.total_participants;
                data.Header.TotalCrews = (int)statsRaw.total_crews;
                data.Header.TotalVehicles = (int)statsRaw.total_vehicles;
            }

            return data;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero dei dati per la stampa scheda viaggio {DataViaggioId}", dataViaggioId);
            throw;
        }
    }
}
