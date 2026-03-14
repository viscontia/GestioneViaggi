using System.Collections.Generic;
using GestioneViaggi.Models;

namespace GestioneViaggi.Models.DTOs
{
    public class ViaggioPartecipantiInitData
    {
        public List<ParticipantsViewDTO> Participants { get; set; } = new();
        public List<ParticipantsViewDTO> ParticipantsWithoutRoom { get; set; } = new();
        public string SummaryTitle { get; set; } = string.Empty;
        public int ParticipantsCount { get; set; }
        public List<RoomWithOccupantsDTO> Rooms { get; set; } = new();
        public int RoomsCount { get; set; }
        public string HeaderTitle { get; set; } = string.Empty;
        public List<TipoPartecipante> TipoPartecipanti { get; set; } = new();
        public List<TipoAlloggio> TipoAlloggi { get; set; } = new();
    }

}
