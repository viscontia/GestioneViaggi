using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

public class ResetPasswordRequest
{
    [Required(ErrorMessage = "L'email è obbligatoria")]
    [EmailAddress(ErrorMessage = "Formato email non valido")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Il codice di verifica è obbligatorio")]
    [StringLength(6, MinimumLength = 6, ErrorMessage = "Il codice deve essere di 6 cifre")]
    [RegularExpression(@"^\d{6}$", ErrorMessage = "Il codice deve contenere solo cifre")]
    public string ResetCode { get; set; } = string.Empty;

    [Required(ErrorMessage = "La nuova password è obbligatoria")]
    [StringLength(int.MaxValue, MinimumLength = 8, ErrorMessage = "La password deve avere almeno 8 caratteri")]
    [RegularExpression(@"^(?=.*[A-Z])(?=.*[!@#$%^&*()\-_=+\[\]{};':""\\|,.<>\/?]).{8,}$",
        ErrorMessage = "La password deve contenere almeno una lettera maiuscola e un carattere speciale")]
    public string NewPassword { get; set; } = string.Empty;

    [Required(ErrorMessage = "La conferma password è obbligatoria")]
    [Compare(nameof(NewPassword), ErrorMessage = "Le password non corrispondono")]
    public string ConfirmPassword { get; set; } = string.Empty;
}
