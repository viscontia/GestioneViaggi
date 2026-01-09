namespace GestioneViaggi.Models.DTOs;

public class DuplicateTripDTO
{
    public int Id { get; set; }
    public string Descrizione { get; set; } = string.Empty;
    public string MatchingWords { get; set; } = string.Empty;
}
