using System.Collections.Generic;

namespace GestioneViaggi.Models.DTOs
{
    public class ControparteInitData
    {
        public List<Comune> Comuni { get; set; } = new();
        public List<Azienda> Aziende { get; set; } = new();
        public List<AnaTipoFornitore> TipiFornitore { get; set; } = new();
        public Comune? Comune { get; set; }
    }
}
