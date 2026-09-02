using System.Globalization;
using System.Text.Json.Serialization;

namespace GestioneViaggi.Services.Printing;

public class TravelPrintDTO
{
    public TravelHeaderInfo Header { get; set; } = new();
    public List<ParticipantPrintInfo> Participants { get; set; } = new();
    public CompanyPrintInfo Company { get; set; } = new();
    public List<VehicleGroupInfo> VehicleGroups { get; set; } = new();

    /// <summary>
    /// Chi parte con un documento che non arriva valido alla fine del viaggio. Finisce in
    /// una nota in fondo al PDF: chi legge il foglio puo' non essere chi ha lanciato la
    /// stampa, e l'avviso a schermo a quel punto e' stato chiuso da un pezzo.
    /// </summary>
    public List<GestioneViaggi.Models.DocumentoNonValido> DocumentiDaSistemare { get; set; } = new();
}

public class TravelHeaderInfo
{
    [JsonPropertyName("data_viaggio_id")]
    public int DataViaggioId { get; set; }

    [JsonPropertyName("viaggio_id")]
    public int ViaggioId { get; set; }

    [JsonPropertyName("azienda_id")]
    public int AziendaId { get; set; }

    [JsonPropertyName("titolo")]
    public string Titolo { get; set; } = string.Empty;

    [JsonPropertyName("descrizione_estesa")]
    public string Descrizione { get; set; } = string.Empty;

    // DescrizioneBreve can be set explicitly or defaults to Titolo
    public string DescrizioneBreve { get; set; } = string.Empty;

    [JsonPropertyName("nazione")]
    public string Destinazione { get; set; } = string.Empty;

    [JsonPropertyName("data_inizio")]
    public DateTime? DataInizio { get; set; }

    [JsonPropertyName("data_fine")]
    public DateTime? DataFine { get; set; }

    [JsonPropertyName("note_viaggio")]
    public string Note { get; set; } = string.Empty;

    public int TotalParticipants { get; set; }
    public int TotalVehicles { get; set; }
    public int TotalCrews { get; set; }

    // Characteristics
    [JsonPropertyName("tipo")]
    public string TipoViaggio { get; set; } = string.Empty;

    [JsonPropertyName("giorni")]
    public int Giorni { get; set; }

    [JsonPropertyName("notti")]
    public int Notti { get; set; }

    [JsonPropertyName("trattamento")]
    public string Trattamento { get; set; } = string.Empty;

    [JsonPropertyName("pasti_al_sacco")]
    public string? PastiAlSaccoRaw { get; set; }

    // Computed property: converts "Y" or "S" to true, "N" to false
    public bool PastiSacco => (PastiAlSaccoRaw ?? "N") == "Y" || (PastiAlSaccoRaw ?? "N") == "S";

    [JsonPropertyName("km")]
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

/// <summary>
/// Company print info - inherits from base class with logo conversion.
/// </summary>
public class CompanyPrintInfo : CompanyPrintInfoBase
{
    // All properties and logo conversion inherited from CompanyPrintInfoBase
}

public class ParticipantPrintInfo
{
    // Maps to result of get_participants_sorted
    [JsonPropertyName("viaggio_id")]
    public int ViaggioId { get; set; }

    [JsonPropertyName("data_id")]
    public int DataId { get; set; }

    [JsonPropertyName("cliente_id")]
    public int ClienteId { get; set; }

    [JsonPropertyName("nominativo")]
    public string Nominativo { get; set; } = string.Empty;

    [JsonPropertyName("tipo_partecipante_id")]
    public int TipoPartecipanteId { get; set; }

    [JsonPropertyName("ruolo")]
    public string Ruolo { get; set; } = string.Empty; // "Pilota" or "Passeggero"

    [JsonPropertyName("note")]
    public string Note { get; set; } = string.Empty;

    [JsonPropertyName("cane_sino")]
    public string CaneSino { get; set; } = "N";

    [JsonPropertyName("intolleranze")]
    public string Intolleranze { get; set; } = string.Empty;

    [JsonPropertyName("mezzo_dettagli")]
    public string MezzoDettagli { get; set; } = string.Empty;

    [JsonPropertyName("cliente_pilota_id")]
    public int? ClientePilotaId { get; set; }

    [JsonPropertyName("grouping_key")]
    public int GroupingKey { get; set; } // Key for grouping crews

    [JsonPropertyName("is_pilot")]
    public bool IsPilot { get; set; }

    // Personal Details
    [JsonPropertyName("telefono")]
    public string Telefono { get; set; } = string.Empty;

    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    [JsonPropertyName("residenza")]
    public string Residenza { get; set; } = string.Empty;

    [JsonPropertyName("codice_fiscale")]
    public string CodiceFiscale { get; set; } = string.Empty;

    [JsonPropertyName("data_nascita")]
    public DateTime? DataNascita { get; set; }

    [JsonPropertyName("luogo_nascita")]
    public string LuogoNascita { get; set; } = string.Empty;

    // Detailed Info (Scheda Dettagliata)
    [JsonPropertyName("nazionalita")]
    public string Nazionalita { get; set; } = string.Empty;

    [JsonPropertyName("tipo_documento")]
    public string TipoDocumento { get; set; } = string.Empty;

    [JsonPropertyName("numero_documento")]
    public string NumeroDocumento { get; set; } = string.Empty;

    [JsonPropertyName("rilasciato_da")]
    public string EnteRilascio { get; set; } = string.Empty;

    [JsonPropertyName("data_rilascio")]
    public DateTime? DataRilascio { get; set; }

    [JsonPropertyName("data_scadenza")]
    public DateTime? DataScadenza { get; set; }

    public string DataRilascioFormatted => DataRilascio.HasValue ? DataRilascio.Value.ToString("dd/MM/yyyy") : "";
    public string DataScadenzaFormatted => DataScadenza.HasValue ? DataScadenza.Value.ToString("dd/MM/yyyy") : "";

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
    [JsonPropertyName("viaggio_id")]
    public int ViaggioId { get; set; }

    [JsonPropertyName("data_id")]
    public int DataId { get; set; }

    [JsonPropertyName("cliente_id")]
    public int ClienteId { get; set; }

    [JsonPropertyName("nominativo")]
    public string Nominativo { get; set; } = string.Empty;

    [JsonPropertyName("marca")]
    public string Marca { get; set; } = string.Empty;

    [JsonPropertyName("modello")]
    public string Modello { get; set; } = string.Empty;

    [JsonPropertyName("targa")]
    public string Targa { get; set; } = string.Empty;

    // Personal Details
    [JsonPropertyName("telefono")]
    public string Telefono { get; set; } = string.Empty;

    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    [JsonPropertyName("residenza")]
    public string Residenza { get; set; } = string.Empty;

    [JsonPropertyName("codice_fiscale")]
    public string CodiceFiscale { get; set; } = string.Empty;

    [JsonPropertyName("data_nascita")]
    public DateTime? DataNascita { get; set; }

    [JsonPropertyName("luogo_nascita")]
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

    /// <summary>
    /// Partecipanti senza camera assegnata (<c>RoomId = 0</c>).
    /// </summary>
    /// <remarks>
    /// Il dato esisteva già nei partecipanti ma non lo guardava nessuno: una rooming list senza
    /// alcun abbinamento veniva stampata lo stesso, con l'elenco dei nominativi e nessuna camera.
    /// Averlo qui permette di decidere <b>prima</b> se ha senso stampare, e di dirlo <b>dentro</b>
    /// il prospetto quando si stampa comunque.
    /// </remarks>
    public int ClientiNonAbbinati { get; set; }

    /// <summary>Nessun cliente è abbinato a una camera: il prospetto non avrebbe contenuto.</summary>
    public bool NessunAbbinamento => TotalParticipants > 0 && ClientiNonAbbinati == TotalParticipants;

    /// <summary>Alcuni abbinati e altri no: si può stampare, ma va detto.</summary>
    public bool AbbinamentiParziali => ClientiNonAbbinati > 0 && ClientiNonAbbinati < TotalParticipants;

    /// <summary>
    /// Chi parte con un documento che non arriva valido alla fine del viaggio. Finisce in
    /// una nota in fondo al PDF: chi legge il foglio puo' non essere chi ha lanciato la
    /// stampa, e l'avviso a schermo a quel punto e' stato chiuso da un pezzo.
    /// </summary>
    public List<GestioneViaggi.Models.DocumentoNonValido> DocumentiDaSistemare { get; set; } = new();

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

    // Ordinamento pilota/passeggeri
    public int PositionNumber { get; set; }
    public bool IsPilot { get; set; }

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
