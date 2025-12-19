using GestioneViaggi.Models;

namespace GestioneViaggi.Services.UI;

public interface IStatusBarService
{
    StatusBarInfo CurrentStatus { get; }
    event Action? OnStatusChanged;

    Task InitializeAsync();
    Task RefreshStatusAsync();
    void StartAutoRefresh();
    void StopAutoRefresh();
    void SetCurrentTable(string? tableName);
}
