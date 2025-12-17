namespace GestioneViaggi.Models;
using System.ComponentModel.DataAnnotations;

public class LoginRequest
{
    [Required(ErrorMessage = "L'email è obbligatoria")]
    [EmailAddress(ErrorMessage = "L'email non è in formato valido")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "La password è obbligatoria")]
    [StringLength(int.MaxValue, MinimumLength = 8, ErrorMessage = "La password deve contenere almeno 8 caratteri")]
    [RegularExpression(@"(?=.*[A-Z])(?=.*[!@#$%^&*()_+\-=\[\]{};':""\\|,.<>\/?])", 
        ErrorMessage = "La password deve contenere almeno una maiuscola e un carattere speciale")]
    public string Password { get; set; } = string.Empty;

    public bool RememberMe { get; set; }
}
