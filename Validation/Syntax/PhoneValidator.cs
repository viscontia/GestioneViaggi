using System;
using System.Linq;
using PhoneNumbers;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Validation.Syntax;

public class PhoneValidationResult
{
    public bool IsValid { get; set; }
    public string FormattedNumber { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public PhoneNumberType Type { get; set; }
}

public static partial class PhoneValidator
{
    private static readonly PhoneNumberUtil _phoneUtil = PhoneNumberUtil.GetInstance();

    /// <summary>
    /// Punto di ingresso statico per la validazione nel progetto.
    /// Mantiene la compatibilità con l'architettura esistente.
    /// </summary>
    public static ValidationResult CheckTelefonoItaly(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return ValidationResult.Failure("Il numero di telefono è obbligatorio", "CHK_TEL_001");
        }

        var result = Validate(input);
        if (!result.IsValid)
        {
            return ValidationResult.Failure(result.Message, "CHK_TEL_ERR");
        }

        return ValidationResult.Success();
    }

    /// <summary>
    /// Validazione avanzata utilizzando libphonenumber-csharp.
    /// </summary>
    public static PhoneValidationResult Validate(string input)
    {
        // 1. Accetta solo numeri (permettendo il + iniziale o 00)
        string cleanInput = CleanInput(input);
        if (string.IsNullOrWhiteSpace(cleanInput) || !IsNumeric(cleanInput))
        {
            return Error("Il numero deve contenere solo cifre decimali.");
        }

        try
        {
            // Se il numero non inizia con + o 00, proviamo a capire se è un numero italiano
            // o se manca il prefisso internazionale.
            if (!input.Trim().StartsWith("+") && !input.Trim().StartsWith("00"))
            {
                return HandleNoPrefix(cleanInput);
            }

            // Tentativo di parsing internazionale
            // Gestione "00" trasformato in "+" in CleanInput
            PhoneNumber numberProto = _phoneUtil.Parse(cleanInput, null);
            bool isValid = _phoneUtil.IsValidNumber(numberProto);

            if (!isValid)
            {
                return Error("Il numero inserito non è valido per il paese di origine indicato dal prefisso.");
            }

            var type = _phoneUtil.GetNumberType(numberProto);
            string formatted = _phoneUtil.Format(numberProto, PhoneNumberFormat.INTERNATIONAL);

            return new PhoneValidationResult
            {
                IsValid = true,
                FormattedNumber = formatted,
                Type = type,
                Message = "Numero valido."
            };
        }
        catch (NumberParseException e)
        {
            return Error($"Errore di validazione: {e.ErrorType}. Assicurati di aver inserito il prefisso internazionale.");
        }
    }

    private static PhoneValidationResult HandleNoPrefix(string digits)
    {
        // Logica specifica per l'Italia (Default)
        // Se inizia con 3, è probabilmente un cellulare italiano
        if (digits.StartsWith("3") && (digits.Length >= 9 && digits.Length <= 10))
        {
            return ValidateAsItalian(digits);
        }
        
        // Se inizia con 0, è un fisso italiano
        if (digits.StartsWith("0"))
        {
            if (digits.Length < 6) return Error("Numero fisso troppo corto. Digita il prefisso locale completo.");
            return ValidateAsItalian(digits);
        }

        // Se non inizia con 0 o 3, chiediamo il prefisso
        return Error("Prefisso non riconosciuto. Per numeri esteri, inserisci il prefisso internazionale (es. 0033 o +33).");
    }

    private static PhoneValidationResult ValidateAsItalian(string digits)
    {
        try
        {
            PhoneNumber numberProto = _phoneUtil.Parse(digits, "IT");
            if (_phoneUtil.IsValidNumber(numberProto))
            {
                return new PhoneValidationResult
                {
                    IsValid = true,
                    FormattedNumber = _phoneUtil.Format(numberProto, PhoneNumberFormat.INTERNATIONAL),
                    Type = _phoneUtil.GetNumberType(numberProto),
                    Message = "Numero italiano valido."
                };
            }
            return Error("Numero italiano non valido. Controlla il prefisso o la lunghezza.");
        }
        catch { return Error("Errore nella validazione del numero italiano."); }
    }

    private static string CleanInput(string input)
    {
        if (string.IsNullOrEmpty(input)) return "";
        // Rimuove spazi, trattini e punti, mantiene il + iniziale
        string result = input.Trim().Replace(" ", "").Replace("-", "").Replace(".", "");
        if (result.StartsWith("00")) result = "+" + result.Substring(2);
        return result;
    }

    private static bool IsNumeric(string val)
    {
        string check = val.StartsWith("+") ? val.Substring(1) : val;
        return check.All(char.IsDigit);
    }

    private static PhoneValidationResult Error(string msg)
    {
        return new PhoneValidationResult { IsValid = false, Message = msg };
    }
}
