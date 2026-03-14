using System.Collections.Generic;

namespace GestioneViaggi.Models.DTOs
{
    public class ClienteInitData
    {
        public List<Comune> Comuni { get; set; } = new();
        public List<Azienda> Aziende { get; set; } = new();
        public Comune? ComuneNascita { get; set; }
        public Comune? ComuneResidenza { get; set; }
    }
}
