using Microsoft.Extensions.Logging;
using SkiaSharp.Views.Maui.Controls.Hosting;
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
using GestioneViaggi.Services;
using GestioneViaggi.Repositories;
using GestioneViaggi.Repositories.Interfaces;

using GestioneViaggi.Statistics;
using GestioneViaggi.Migrazione_Dati_Oracle;

namespace GestioneViaggi;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .UseSkiaSharp()
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
            });

        // ==========================================================
        // MUDBLAZOR - PREMIUM SAAS THEME
        // ==========================================================
        builder.Services.AddMudServices(config =>
        {
            config.SnackbarConfiguration.PositionClass = Defaults.Classes.Position.BottomRight;
            config.SnackbarConfiguration.PreventDuplicates = false;
            config.SnackbarConfiguration.NewestOnTop = true;
            config.SnackbarConfiguration.ShowCloseIcon = true;
            config.SnackbarConfiguration.VisibleStateDuration = 4000;
            config.SnackbarConfiguration.HideTransitionDuration = 500;
            config.SnackbarConfiguration.ShowTransitionDuration = 500;
            config.SnackbarConfiguration.SnackbarVariant = Variant.Filled;
        });

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
        builder.Services.AddScoped<ITenantContext, TenantContext>();

        builder.Services.AddScoped<IAuthenticationService, AuthenticationService>();
        builder.Services.AddScoped<AuthenticationStateProvider, CustomAuthStateProvider>();
        builder.Services.AddAuthorizationCore();

        builder.Services.AddScoped<ITabManagerService, TabManagerService>();
        builder.Services.AddScoped<IStatusBarService, StatusBarService>();

        // ==========================================================
        // REPOSITORIES
        // ==========================================================
        builder.Services.AddScoped<AuditLoginService>();
        builder.Services.AddScoped<IClienteRepository, ClienteRepository>();

        // ==========================================================
        // CRUD SERVICES
        // ==========================================================
        builder.Services.AddScoped<IClienteService, ClienteService>();
        builder.Services.AddScoped<CountryService>();
        builder.Services.AddScoped<CountryRegionService>();
        builder.Services.AddScoped<CountrySubRegionService>();
        builder.Services.AddScoped<CountryIntermediateService>();
        builder.Services.AddScoped<CountryOrganizationService>();
        builder.Services.AddScoped<CapoluogoService>();
        builder.Services.AddScoped<RipartizioneGeograficaService>();
        builder.Services.AddScoped<RegioneService>();
        builder.Services.AddScoped<ProvinciaService>();
        builder.Services.AddScoped<ComuneService>();
        builder.Services.AddScoped<AziendaService>();
        builder.Services.AddScoped<AziendaSedeService>();
        builder.Services.AddScoped<AziendaContattoService>();
        builder.Services.AddScoped<AziendaBancaService>();
        builder.Services.AddScoped<AziendaEmailService>();
        builder.Services.AddScoped<AziendaSmtpService>();
        builder.Services.AddScoped<AziendaLogoService>();
        builder.Services.AddScoped<TipoSedeService>();
        builder.Services.AddScoped<RepartoAziendaleService>();
        builder.Services.AddScoped<TipoViaggioService>();
        builder.Services.AddScoped<TipoPartecipanteService>();
        builder.Services.AddScoped<TipoTrattamentoService>();
        builder.Services.AddScoped<TipoAlloggioService>();
        builder.Services.AddScoped<TipoPernottamentoService>();
        builder.Services.AddScoped<TipoMezzoService>();
        builder.Services.AddScoped<MarcaVeicoloService>();
        builder.Services.AddScoped<MezzoModelloService>();
        builder.Services.AddScoped<AnaViaggiService>();
        builder.Services.AddScoped<TipoAvvicinamentoService>();
        builder.Services.AddScoped<MovClientiViaggiService>();
        builder.Services.AddScoped<MovClientiAlloggiService>();

        builder.Services.AddScoped<IUserService, UserService>();
        builder.Services.AddScoped<IRoleService, RoleService>();

        // ==========================================================
        // STATISTICS SERVICES
        // ==========================================================
        builder.Services.AddScoped<StatisticCountAziende>();
        builder.Services.AddScoped<StatisticCountClienti>();
        builder.Services.AddScoped<StatisticCountViaggi>();
        builder.Services.AddScoped<StatisticCountViaggiFatti>();
        builder.Services.AddScoped<StatisticCountViaggiDaFare>();
        builder.Services.AddScoped<StatisticRevenue>();
        builder.Services.AddScoped<StatisticYearService>();

        builder.Services.AddMauiBlazorWebView();

#if DEBUG
        // Questo abilita l'Ispeziona Elemento (tasto destro)
        builder.Services.AddBlazorWebViewDeveloperTools();
        builder.Logging.AddDebug();
        builder.Logging.SetMinimumLevel(LogLevel.Information);

        // Servizio per le migrazioni DB (eseguito una tantum in MainLayout)
        builder.Services.AddScoped<DbMigrationService>();
#endif

        builder.Services.AddTransient<OracleClientiImportService>();
        builder.Services.AddTransient<OracleViaggiImportService>();
        builder.Services.AddTransient<OracleDateViaggiImportService>();
        builder.Services.AddTransient<OracleMovClientiViaggiImportService>();
        builder.Services.AddTransient<OracleMovClientiAlloggiImportService>();
        builder.Services.AddTransient<ExcelAnaMezziImportService>();
        builder.Services.AddTransient<ExcelAnaMezziModelliImportService>();
        
        builder.Services.AddScoped<Services.Shared.IRecentActivityService, Services.Shared.RecentActivityService>();


        // Tool Documentazione DB
        builder.Services.AddScoped<GestioneViaggi.Services.Tools.IDatabaseDocumentationService, GestioneViaggi.Services.Tools.DatabaseDocumentationService>();

        return builder.Build();
    }
}
