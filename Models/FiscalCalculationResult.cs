namespace GestioneViaggi.Models
{
    public class FiscalCalculationResult
    {
        public List<MovTransazioniRighe> Righe { get; set; } = new();
        public bool Success { get; set; }
        public string? ErrorMessage { get; set; }

        public static FiscalCalculationResult Ok(List<MovTransazioniRighe> righe) => new()
        {
            Righe = righe,
            Success = true
        };

        public static FiscalCalculationResult Error(string message) => new()
        {
            Success = false,
            ErrorMessage = message
        };
    }
}
