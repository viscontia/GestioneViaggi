namespace GestioneViaggi.Validation.Core;

public class ValidationResult
{
    public bool IsValid { get; init; }
    public string ErrorMessage { get; init; }
    public string ErrorCode { get; init; }

    private ValidationResult(bool isValid, string errorMessage = "", string errorCode = "")
    {
        IsValid = isValid;
        ErrorMessage = errorMessage;
        ErrorCode = errorCode;
    }

    public static ValidationResult Success() => new(true);

    public static ValidationResult Failure(string errorMessage, string errorCode = "") 
        => new(false, errorMessage, errorCode);
}
