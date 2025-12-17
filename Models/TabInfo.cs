namespace GestioneViaggi.Models;

public class TabInfo
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Route { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public bool IsDirty { get; set; } = false;
    public string Icon { get; set; } = string.Empty;
    public bool IsCloseable { get; set; } = true;
    public DateTime OpenedAt { get; set; } = DateTime.Now;
}
