using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using Microsoft.AspNetCore.Components.Authorization;
using MudBlazor.Services;
using MudBlazor;
using GestioneViaggi.Components;
using GestioneViaggi.Components.Shared;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Authentication;
using GestioneViaggi.Services.Session;
using GestioneViaggi.Services.Navigation;
using GestioneViaggi.Services.UI;
using GestioneViaggi.Services.CRUD;

namespace GestioneViaggi;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
            });

        // ==========================================================
        // MUDBLAZOR
        // ==========================================================
        builder.Services.AddMudServices();

        // REGISTRAZIONE LOCALIZZAZIONE ITALIANA (GRID, PAGER, ECC.)
        builder.Services.AddTransient<MudLocalizer, ItalianMudLocalizer>();

        // ==========================================================
        // AUTHENTICATION & DATABASE
        // ==========================================================

        var inMemorySettings = new Dictionary<string, string>
        {
            {"ConnectionStrings:PostgreSQL", "Host=127.0.0.1;Port=5432;Database=gestione_viaggi;Username=postgres;Password=postgres;Pooling=true;MinPoolSize=1;MaxPoolSize=20;Timeout=30;CommandTimeout=30;"}
        };
        builder.Configuration.AddInMemoryCollection(inMemorySettings!);

        builder.Services.AddSingleton<IDatabaseConnectionManager, DatabaseConnectionManager>();
        builder.Services.AddSingleton<IDatabaseService, PostgreSqlService>();

        builder.Services.AddSingleton<ISecureStorageProvider, FileStorageProvider>();

        builder.Services.AddSingleton<ISessionManager, SessionManager>();

        builder.Services.AddScoped<IAuthenticationService, AuthenticationService>();
        builder.Services.AddScoped<AuthenticationStateProvider, CustomAuthStateProvider>();
        builder.Services.AddAuthorizationCore();

        builder.Services.AddScoped<ITabManagerService, TabManagerService>();
        builder.Services.AddScoped<IStatusBarService, StatusBarService>();

        // ==========================================================
        // CRUD SERVICES
        // ==========================================================
        builder.Services.AddScoped<CapoluogoService>();
        builder.Services.AddScoped<RipartizioneGeograficaService>();
        builder.Services.AddScoped<RegioneService>();
        builder.Services.AddScoped<ProvinciaService>();

        builder.Services.AddMauiBlazorWebView();

#if DEBUG
        // Questo abilita l'Ispeziona Elemento (tasto destro)
        builder.Services.AddBlazorWebViewDeveloperTools();
        builder.Logging.AddDebug();
#endif

        return builder.Build();
    }
}
