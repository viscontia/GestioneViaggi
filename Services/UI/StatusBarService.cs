using GestioneViaggi.Models;
using GestioneViaggi.Services.Authentication;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.UI;

public class StatusBarService : IStatusBarService, IDisposable
{
    private readonly IAuthenticationService _authService;
    private readonly ILogger<StatusBarService> _logger;
    private CancellationTokenSource? _cts;
    private Task? _refreshTask;
    private Task? _clockTask;

    public StatusBarInfo CurrentStatus { get; private set; } = new();
    public event Action? OnStatusChanged;

    public StatusBarService(
        IAuthenticationService authService,
        ILogger<StatusBarService> logger)
    {
        _authService = authService;
        _logger = logger;
    }

    public async Task InitializeAsync()
    {
        await RefreshStatusAsync();
        StartAutoRefresh();
    }

    public async Task RefreshStatusAsync()
    {
        try
        {
            // Get current user
            var user = await _authService.GetCurrentUserAsync();
            if (user != null)
            {
                CurrentStatus.UserFullName = $"{user.Cognome} {user.Nome}".Trim();
                CurrentStatus.UserRole = user.RoleName ?? user.RoleCode ?? "Utente";
                CurrentStatus.CompanyName = user.AziendaId.HasValue && user.AziendaId > 0
                    ? $"Azienda ID: {user.AziendaId}"
                    : "Tutte le Aziende";

                // Simple DB check without heavy query
                CurrentStatus.DbStatus = DatabaseStatus.Connected;
            }
            else
            {
                CurrentStatus.UserFullName = "Guest";
                CurrentStatus.UserRole = "N/A";
                CurrentStatus.CompanyName = "N/A";
                CurrentStatus.DbStatus = DatabaseStatus.Disconnected;
            }

            CurrentStatus.CurrentDateTime = DateTime.Now;
            OnStatusChanged?.Invoke();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error refreshing status bar");
            CurrentStatus.DbStatus = DatabaseStatus.Warning;
            CurrentStatus.UserFullName = "Error";
            OnStatusChanged?.Invoke();
        }
    }

    public void StartAutoRefresh()
    {
        _cts = new CancellationTokenSource();

        // Refresh DB status every 30 seconds
        _refreshTask = Task.Run(async () =>
        {
            while (!_cts.Token.IsCancellationRequested)
            {
                try
                {
                    await Task.Delay(30000, _cts.Token);
                    await RefreshStatusAsync();
                }
                catch (TaskCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in refresh task");
                }
            }
        }, _cts.Token);

        // Update clock every second
        _clockTask = Task.Run(async () =>
        {
            while (!_cts.Token.IsCancellationRequested)
            {
                try
                {
                    await Task.Delay(1000, _cts.Token);
                    CurrentStatus.CurrentDateTime = DateTime.Now;
                    OnStatusChanged?.Invoke();
                }
                catch (TaskCanceledException)
                {
                    break;
                }
            }
        }, _cts.Token);
    }

    public void StopAutoRefresh()
    {
        _cts?.Cancel();
    }

    public void SetCurrentTable(string? tableName)
    {
        CurrentStatus.CurrentTableName = tableName;
        OnStatusChanged?.Invoke();
    }

    public void Dispose()
    {
        StopAutoRefresh();
        _cts?.Dispose();
    }
}
