using System.Collections.Generic;
using GestioneViaggi.Models;

namespace GestioneViaggi.Models.DTOs
{
    public class ViaggiInitData
    {
        public List<Country> Nazioni { get; set; } = new();
        public List<TipoViaggio> TipiViaggio { get; set; } = new();
        public List<TipoTrattamento> TipiTrattamento { get; set; } = new();
        public List<TipoPernottamento> TipiPernottamento { get; set; } = new();
        public List<TipoAvvicinamento> TipiAvvicinamento { get; set; } = new();
        public List<Azienda> Aziende { get; set; } = new();
        public List<AnaDataViaggio> Dates { get; set; } = new();
    }

    public class CountryLookupDTO
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
    }

    public class TipoViaggioLookupDTO
    {
        public int Id { get; set; }
        public string Descrizione { get; set; } = string.Empty;
    }

    public class GenericLookupDTO
    {
        public int Id { get; set; }
        public string Descrizione { get; set; } = string.Empty;
    }

    public class AziendaLookupDTO
    {
        public int AziendaId { get; set; }
        public string RagioneSociale { get; set; } = string.Empty;
    }
}
