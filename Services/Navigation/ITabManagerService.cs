using GestioneViaggi.Models;

namespace GestioneViaggi.Services.Navigation;

public interface ITabManagerService
{
    int MaxTabs { get; }
    IReadOnlyList<TabInfo> ActiveTabs { get; }
    int ActiveTabIndex { get; }

    event Action? OnTabsChanged;

    bool CanOpenTab();
    bool OpenTab(string route, string title, string icon = "");
    void CloseTab(Guid tabId);
    void CloseTab(int index);
    void SwitchToTab(int index);
    TabInfo? GetActiveTab();
    void SetTabDirty(Guid tabId, bool isDirty);
    void ClearAllTabs();
}
