using System.Collections.Generic;

namespace GestioneViaggi.Models.DTOs
{
    public class TransazioneInitData
    {
        public List<AnaTipoCausale> Causali { get; set; } = new();
        public List<AnaAliquotaIva> AliquoteIva { get; set; } = new();
        public List<AnaValute> Valute { get; set; } = new();
        public List<AnaControparte> Controparti { get; set; } = new();
        public List<AnaViaggi> Viaggi { get; set; } = new();
        public bool ShowHelperCalcolo { get; set; }
        public MovTransazioni? Transazione { get; set; }
    }
}
