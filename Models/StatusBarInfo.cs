namespace GestioneViaggi.Models;

public enum DatabaseStatus
{
    Connected,
    Warning,
    Disconnected
}

public class StatusBarInfo
{
    public DatabaseStatus DbStatus { get; set; } = DatabaseStatus.Disconnected;
    public string UserFullName { get; set; } = string.Empty;
    public string UserRole { get; set; } = string.Empty;
    public string CompanyName { get; set; } = "Tutte le Aziende";
    public DateTime CurrentDateTime { get; set; } = DateTime.Now;
}
