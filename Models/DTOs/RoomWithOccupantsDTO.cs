namespace GestioneViaggi.Models.DTOs;

/// <summary>
/// DTO che mappa il risultato della function get_rooms_with_occupants()
/// Sostituisce la costruzione manuale di RoomCardViewModel in LoadRoomsAsync() (88 righe)
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
