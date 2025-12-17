namespace GestioneViaggi.Models;

public class LoginResponse
{
    public bool Success { get; set; }
    public string? Error { get; set; }
    public UserInfo? User { get; set; }
}
