using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Semantic;

public static class NumericValidator
{
    public static ValidationResult CheckPositiveOrZeroDecimal(decimal? value)
    {
        if (!value.HasValue)
            return ValidationResult.Success();

        if (value.Value < 0)
            return ValidationResult.Failure(ValidationMessages.CapitaleSocialeNegative, "CHK_NUM_001");

        return ValidationResult.Success();
    }

    public static ValidationResult CheckPositiveDecimal(decimal? value)
    {
        if (!value.HasValue)
            return ValidationResult.Success();

        if (value.Value <= 0)
            return ValidationResult.Failure("Il valore deve essere positivo.", "CHK_NUM_002");

        return ValidationResult.Success();
    }

    public static ValidationResult CheckCapitaleSociale(decimal? capitaleSociale)
    {
        return CheckPositiveOrZeroDecimal(capitaleSociale);
    }
}
