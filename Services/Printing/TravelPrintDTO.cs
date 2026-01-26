using System.Globalization;

namespace GestioneViaggi.Services.Printing;

public class TravelPrintDTO
{
    public TravelHeaderInfo Header { get; set; } = new();
    public List<ParticipantPrintInfo> Participants { get; set; } = new();
    public CompanyPrintInfo Company { get; set; } = new();
    public List<VehicleGroupInfo> VehicleGroups { get; set; } = new();
}

public class TravelHeaderInfo
{
    public int DataViaggioId { get; set; }
    public int ViaggioId { get; set; }
    public string Titolo { get; set; } = string.Empty;
    public string Descrizione { get; set; } = string.Empty;
    public string DescrizioneBreve { get; set; } = string.Empty; // For file naming
    public string Destinazione { get; set; } = string.Empty; // e.g., "Tunisia" from description or tags? Or simply Country
    public DateTime? DataInizio { get; set; }
    public DateTime? DataFine { get; set; }
    public string Note { get; set; } = string.Empty;
    public int TotalParticipants { get; set; }
    public int TotalVehicles { get; set; }
    public int TotalCrews { get; set; }
    
    // Characteristics
    public string TipoViaggio { get; set; } = string.Empty;
    public int Giorni { get; set; }
    public int Notti { get; set; }
    public string Trattamento { get; set; } = string.Empty;
    public bool PastiSacco { get; set; }
    public int Km { get; set; }

    public string DateFormatted
    {
        get
        {
            var italianCulture = new CultureInfo("it-IT");
            if (!DataInizio.HasValue) return "N/D";
            if (!DataFine.HasValue || DataInizio.Value.Date == DataFine.Value.Date)
            {
                return $"{CapitalizeFirst(DataInizio.Value.ToString("dddd", italianCulture))} {DataInizio.Value:dd/MM/yyyy}";
            }
            return $"da {CapitalizeFirst(DataInizio.Value.ToString("dddd", italianCulture))} {DataInizio.Value:dd/MM/yyyy} a {CapitalizeFirst(DataFine.Value.ToString("dddd", italianCulture))} {DataFine.Value:dd/MM/yyyy}";
        }
    }

    private static string CapitalizeFirst(string s)
    {
        if (string.IsNullOrEmpty(s)) return s;
        return char.ToUpper(s[0]) + s.Substring(1);
    }
}

public class CompanyPrintInfo
{
    public string RagioneSociale { get; set; } = string.Empty;
    public string Telefono { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string SitoWeb { get; set; } = string.Empty;
    public string Piva { get; set; } = string.Empty;
    public byte[] LogoData { get; set; } = Array.Empty<byte>();
}

public class ParticipantPrintInfo
{
    // Maps to result of get_participants_sorted
    public int ViaggioId { get; set; }
    public int DataId { get; set; }
    public int ClienteId { get; set; }
    public string Nominativo { get; set; } = string.Empty;
    public int TipoPartecipanteId { get; set; }
    public string Ruolo { get; set; } = string.Empty; // "Pilota" or "Passeggero"
    public string Note { get; set; } = string.Empty;
    public string CaneSino { get; set; } = "N";
    public string Intolleranze { get; set; } = string.Empty;
    public string MezzoDettagli { get; set; } = string.Empty;
    public int? ClientePilotaId { get; set; }
    public int GroupingKey { get; set; } // Key for grouping crews
    public bool IsPilot { get; set; }

    // Personal Details
    public string Telefono { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Residenza { get; set; } = string.Empty;
    public string CodiceFiscale { get; set; } = string.Empty;
    public DateTime? DataNascita { get; set; }
    public string LuogoNascita { get; set; } = string.Empty;
    
    public string LuogoDataNascitaFormatted
    {
        get
        {
             var u = !string.IsNullOrEmpty(LuogoNascita) ? LuogoNascita : "";
             var d = DataNascita.HasValue ? DataNascita.Value.ToString("dd/MM/yy") : "";
             if(!string.IsNullOrEmpty(u) && !string.IsNullOrEmpty(d)) return $"{u}\n{d}";
             return u + d;
        }
    }
}

public class PilotVehicleInfo
{
    // Maps to result of get_pilots_grouped_by_vehicle
    public int ViaggioId { get; set; }
    public int DataId { get; set; }
    public int ClienteId { get; set; }
    public string Nominativo { get; set; } = string.Empty;
    public string Marca { get; set; } = string.Empty;
    public string Modello { get; set; } = string.Empty;
    public string Targa { get; set; } = string.Empty;

    // Personal Details
    public string Telefono { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Residenza { get; set; } = string.Empty;
    public string CodiceFiscale { get; set; } = string.Empty;
    public DateTime? DataNascita { get; set; }
    public string LuogoNascita { get; set; } = string.Empty;

    public string LuogoDataNascitaFormatted
    {
        get
        {
             var u = !string.IsNullOrEmpty(LuogoNascita) ? LuogoNascita : "";
             var d = DataNascita.HasValue ? DataNascita.Value.ToString("dd/MM/yy") : "";
             if(!string.IsNullOrEmpty(u) && !string.IsNullOrEmpty(d)) return $"{u}\n{d}";
             return u + d;
        }
    }
}

public class VehicleGroupInfo
{
    public string Marca { get; set; } = string.Empty;
    public string Modello { get; set; } = string.Empty;
    public int Count { get; set; }
    public List<PilotVehicleInfo> Pilots { get; set; } = new();

    public string DisplayName => $"{Marca} {Modello} ({Count})";
}

// ==================== ROOMING LIST DTOs ====================

public class RoomingListPrintDTO
{
    public TravelHeaderInfo Header { get; set; } = new();
    public CompanyPrintInfo Company { get; set; } = new();
    public List<RoomTypeGroup> RoomGroups { get; set; } = new();
    public int TotalRooms { get; set; }
    public int TotalParticipants { get; set; }
}

public class RoomTypeGroup
{
    public int TipoAlloggioId { get; set; }
    public string TipoAlloggioDescrizione { get; set; } = string.Empty;
    public int MaxOccupanti { get; set; }
    public int RoomCount { get; set; }
    public List<RoomingListParticipant> Participants { get; set; } = new();

    public string DisplayHeader => $"{TipoAlloggioDescrizione} (Max {MaxOccupanti} pers.)";
}

public class RoomingListParticipant
{
    // Identificatori
    public int ClienteId { get; set; }
    public int RoomId { get; set; }

    // Dati anagrafici base
    public string Nominativo { get; set; } = string.Empty;
    public int Eta { get; set; }
    public DateTime? DataNascita { get; set; }
    public string LuogoNascita { get; set; } = string.Empty;

    // Residenza
    public string IndirizzoResidenza { get; set; } = string.Empty;
    public string CittaResidenza { get; set; } = string.Empty;
    public string ResidenzaCompleta { get; set; } = string.Empty;

    // Nazionalità
    public string CountryCode { get; set; } = string.Empty;
    public string CountryName { get; set; } = string.Empty;
    public string Nationality { get; set; } = string.Empty;

    // Documento
    public string TipoDocumento { get; set; } = string.Empty;
    public string NumeroDocumento { get; set; } = string.Empty;
    public string EnteRilascio { get; set; } = string.Empty;
    public DateTime? DataRilascio { get; set; }
    public DateTime? DataScadenza { get; set; }

    // Intolleranze
    public string Intolleranze { get; set; } = string.Empty;

    // Tipo Camera (for grouping)
    public int TipoAlloggioId { get; set; }
    public string TipoAlloggioDescrizione { get; set; } = string.Empty;
    public int MaxOccupanti { get; set; }

    // Formatted strings for PDF
    public string DataNascitaFormatted => DataNascita.HasValue ? DataNascita.Value.ToString("dd/MM/yyyy") : "";
    public string DataRilascioFormatted => DataRilascio.HasValue ? DataRilascio.Value.ToString("dd/MM/yyyy") : "";
    public string DataScadenzaFormatted => DataScadenza.HasValue ? DataScadenza.Value.ToString("dd/MM/yyyy") : "";

    public string InformazioniCompleteFormatted
    {
        get
        {
            var parts = new List<string>();

            // Nome (età) - Nato il [data] a [luogo] e residente a [città] in [indirizzo]
            var natoIl = DataNascita.HasValue ? $"il {DataNascitaFormatted}" : "";
            var natoA = !string.IsNullOrEmpty(LuogoNascita) ? $"a {LuogoNascita}" : "";
            var residente = !string.IsNullOrEmpty(ResidenzaCompleta) ? $"e residente a {ResidenzaCompleta}" : "";

            parts.Add($"{Nominativo} ({Eta} Anni) - Nato {natoIl} {natoA} {residente}");

            // Nazionalità [code] - [name] Tipo Doc.: [tipo] Num. [num] Ril.da: [ente] Il: [data] Scad.: [data]
            var nazionalita = !string.IsNullOrEmpty(CountryCode) ? $"Nazionalità {CountryCode} - {CountryName}" : "";
            var tipoDoc = !string.IsNullOrEmpty(TipoDocumento) ? $"Tipo Doc.: {TipoDocumento}" : "";
            var numDoc = !string.IsNullOrEmpty(NumeroDocumento) ? $"Num. {NumeroDocumento}" : "";
            var rilDa = !string.IsNullOrEmpty(EnteRilascio) ? $"Ril.da: {EnteRilascio}" : "";
            var rilIl = DataRilascio.HasValue ? $"Il: {DataRilascioFormatted}" : "";
            var scad = DataScadenza.HasValue ? $"Scad.: {DataScadenzaFormatted}" : "";

            parts.Add($"{nazionalita} {tipoDoc} {numDoc} {rilDa} {rilIl} {scad}");

            // Intolleranze (se presenti)
            if (!string.IsNullOrEmpty(Intolleranze))
            {
                parts.Add($"** INT. ALIMENTARE: {Intolleranze.ToUpper()} **");
            }

            return string.Join("\n", parts.Where(p => !string.IsNullOrWhiteSpace(p)));
        }
    }
}
