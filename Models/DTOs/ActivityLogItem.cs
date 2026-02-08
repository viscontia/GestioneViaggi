namespace GestioneViaggi.Models.DTOs;

public class ActivityLogItem
{
    public int EventId { get; set; }
    public string EventType { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string EntityTable { get; set; } = string.Empty;
    public int EntityId { get; set; }
    public int? AziendaId { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? CreatedBy { get; set; }

    // Helper for UI
    public string TimeAgo
    {
        get
        {
            var diff = DateTime.Now - CreatedAt;
            if (diff.TotalMinutes < 1) return "adesso";
            if (diff.TotalMinutes < 60) return $"{(int)diff.TotalMinutes} minuti fa";
            if (diff.TotalHours < 24) return $"{(int)diff.TotalHours} ore fa";
            return $"{(int)diff.TotalDays} giorni fa";
        }
    }
}
