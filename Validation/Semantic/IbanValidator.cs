using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Semantic;

/// <summary>
/// Validatore semantico per IBAN - verifica unicità nel database
/// </summary>
public class IbanValidator
{
    private readonly AziendaBancaService _bancaService;

    public IbanValidator(AziendaBancaService bancaService)
    {
        _bancaService = bancaService;
    }

    /// <summary>
    /// Verifica se l'IBAN è già utilizzato da un'altra banca
    /// </summary>
    /// <param name="iban">IBAN da verificare</param>
    /// <param name="currentBancaId">ID della banca corrente (0 per nuove banche)</param>
    /// <returns>ValidationResult con esito verifica</returns>
    public async Task<ValidationResult> CheckIbanUniqueness(string iban, int currentBancaId = 0)
    {
        if (string.IsNullOrWhiteSpace(iban))
            return ValidationResult.Success();

        var cleanIban = iban.Replace(" ", "").ToUpper();

        try
        {
            var allBanche = await _bancaService.GetAllAsync();
            var existingBanca = allBanche.FirstOrDefault(b =>
                b.Iban.Equals(cleanIban, StringComparison.OrdinalIgnoreCase) &&
                b.Id != currentBancaId);

            if (existingBanca != null)
            {
                return ValidationResult.Failure(
                    $"IBAN già utilizzato dalla banca '{existingBanca.NomeBanca}'",
                    "CHK_IBAN_DUPLICATE");
            }

            return ValidationResult.Success();
        }
        catch (Exception ex)
        {
            return ValidationResult.Failure(
                $"Errore verifica unicità IBAN: {ex.Message}",
                "CHK_IBAN_ERROR");
        }
    }
}
