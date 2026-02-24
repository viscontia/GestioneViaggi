using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

public class PasswordResetRequest
{
    [Required(ErrorMessage = "L'email è obbligatoria")]
    [EmailAddress(ErrorMessage = "Formato email non valido")]
    public string Email { get; set; } = string.Empty;
}
