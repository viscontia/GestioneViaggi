namespace GestioneViaggi.Models
{
    /// <summary>
    /// DTO per il risultato del dialog "Paga Ora"
    /// </summary>
    public class PagaOraDialogResult
    {
        /// <summary>
        /// Importo del pagamento in EUR
        /// </summary>
        public decimal ImportoPagamento { get; set; }

        /// <summary>
        /// Data in cui è avvenuto il pagamento
        /// </summary>
        public DateTime DataPagamento { get; set; }

        /// <summary>
        /// Note opzionali sul pagamento
        /// </summary>
        public string? Note { get; set; }
    }
}
