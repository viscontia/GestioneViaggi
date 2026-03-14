namespace GestioneViaggi.Models;

public enum DatabaseStatus
{
    Connected,
    Warning,
    Disconnected
}

public enum DbEnvironment
{
    Test,
    Prod
}

public class StatusBarInfo
{
    public DatabaseStatus DbStatus { get; set; } = DatabaseStatus.Disconnected;
    public DbEnvironment Environment { get; set; } = DbEnvironment.Prod;
    public string UserFullName { get; set; } = string.Empty;
    public string UserRole { get; set; } = string.Empty;
    public string CompanyName { get; set; } = "Tutte le Aziende";
    public DateTime CurrentDateTime { get; set; } = DateTime.Now;
    public string? CurrentTableName { get; set; }
    public string AppVersion { get; set; } = string.Empty;
}
