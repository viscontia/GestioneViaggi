using GestioneViaggi.Models;
using Microsoft.AspNetCore.Components;

namespace GestioneViaggi.Services.Navigation;

public class TabManagerService : ITabManagerService
{
    private readonly NavigationManager _navigationManager;
    private readonly List<TabInfo> _activeTabs;

    public int MaxTabs => 5;
    public IReadOnlyList<TabInfo> ActiveTabs => _activeTabs.AsReadOnly();
    public int ActiveTabIndex { get; private set; }

    public event Action? OnTabsChanged;

    public TabManagerService(NavigationManager navigationManager)
    {
        _navigationManager = navigationManager;
        _activeTabs = new List<TabInfo>
        {
            // Home tab (fixed, non-closeable)
            new TabInfo
            {
                Route = "/",
                Title = "Home",
                Icon = "home",
                IsCloseable = false
            }
        };
        ActiveTabIndex = 0;
    }

    public bool CanOpenTab()
    {
        return _activeTabs.Count < MaxTabs;
    }

    public bool OpenTab(string route, string title, string icon = "")
    {
        // Check if tab already exists
        var existingTab = _activeTabs.FirstOrDefault(t => t.Route == route);
        if (existingTab != null)
        {
            var index = _activeTabs.IndexOf(existingTab);
            SwitchToTab(index);
            return true;
        }

        // Check max tabs limit
        if (!CanOpenTab())
        {
            return false;
        }

        // Create new tab
        var newTab = new TabInfo
        {
            Route = route,
            Title = title,
            Icon = icon,
            IsCloseable = true
        };

        _activeTabs.Add(newTab);
        ActiveTabIndex = _activeTabs.Count - 1;

        _navigationManager.NavigateTo(route);
        OnTabsChanged?.Invoke();

        return true;
    }

    public void CloseTab(Guid tabId)
    {
        var tab = _activeTabs.FirstOrDefault(t => t.Id == tabId);
        if (tab == null || !tab.IsCloseable) return;

        var index = _activeTabs.IndexOf(tab);
        CloseTab(index);
    }

    public void CloseTab(int index)
    {
        if (index < 0 || index >= _activeTabs.Count) return;

        var tab = _activeTabs[index];
        if (!tab.IsCloseable) return;

        _activeTabs.RemoveAt(index);

        // Adjust active tab index
        if (ActiveTabIndex >= _activeTabs.Count)
        {
            ActiveTabIndex = _activeTabs.Count - 1;
        }
        else if (ActiveTabIndex >= index)
        {
            ActiveTabIndex = Math.Max(0, ActiveTabIndex - 1);
        }

        // Navigate to active tab
        if (_activeTabs.Count > 0 && ActiveTabIndex >= 0)
        {
            _navigationManager.NavigateTo(_activeTabs[ActiveTabIndex].Route);
        }

        OnTabsChanged?.Invoke();
    }

    public void SwitchToTab(int index)
    {
        if (index < 0 || index >= _activeTabs.Count) return;

        ActiveTabIndex = index;
        _navigationManager.NavigateTo(_activeTabs[index].Route);
        OnTabsChanged?.Invoke();
    }

    public TabInfo? GetActiveTab()
    {
        if (ActiveTabIndex >= 0 && ActiveTabIndex < _activeTabs.Count)
        {
            return _activeTabs[ActiveTabIndex];
        }
        return null;
    }

    public void SetTabDirty(Guid tabId, bool isDirty)
    {
        var tab = _activeTabs.FirstOrDefault(t => t.Id == tabId);
        if (tab != null)
        {
            tab.IsDirty = isDirty;
            OnTabsChanged?.Invoke();
        }
    }

    public void ClearAllTabs()
    {
        // Remove all tabs except Home
        _activeTabs.RemoveAll(t => t.IsCloseable);
        ActiveTabIndex = 0;
        // Don't navigate here - caller will handle navigation
        OnTabsChanged?.Invoke();
    }
}
