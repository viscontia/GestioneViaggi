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

        /// <summary>
        /// false quando i dati di apertura NON sono stati caricati (funzione DB assente, errore di
        /// connessione): è diverso da «caricati e vuoti».
        /// </summary>
        /// <remarks>
        /// ⛔️ Serve a non ripetere il 2026-09-20. `fn_get_transazione_init_data` non esisteva, il
        /// metodo raccoglieva l'eccezione e tornava un oggetto vuoto, e la scheda si apriva con la
        /// sola tendina Viaggio morta — senza dire niente a nessuno, per due settimane. Senza questo
        /// flag un fallimento totale è indistinguibile da un'azienda appena creata.
        /// </remarks>
        public bool CaricamentoRiuscito { get; set; } = true;
    }
}
