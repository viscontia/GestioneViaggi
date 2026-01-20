namespace GestioneViaggi.Models.DTOs;

/// <summary>
/// DTO che mappa il risultato della DB function get_rooms_with_occupants(p_data_viaggio_id)
/// Restituisce camere con occupanti aggregati (ARRAY_AGG di nomi e IDs)
/// Documentazione: Documents/Funzioni_DB.md
/// </summary>
public class RoomWithOccupantsDTO
{
    public int AlloggioPk { get; set; }
    public string TipoAlloggio { get; set; } = string.Empty;
    public int MaxOccupants { get; set; }
    public int CurrentOccupants { get; set; }
    public string[] OccupantNames { get; set; } = Array.Empty<string>();
    public int[] OccupantIds { get; set; } = Array.Empty<int>();
    public bool HasSupplement { get; set; }
}
