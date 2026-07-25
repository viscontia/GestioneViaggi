using Microsoft.Extensions.Logging;
using SkiaSharp.Views.Maui.Controls.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.AspNetCore.Components.Authorization;
using MudBlazor.Services;
using Microsoft.Extensions.DependencyInjection;
using MudBlazor;
using GestioneViaggi.Components;
using GestioneViaggi.Components.Shared;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Authentication;
using GestioneViaggi.Services.Printing;
using GestioneViaggi.Services.Session;
using GestioneViaggi.Services.Navigation;
using GestioneViaggi.Services.UI;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Web;
using GestioneViaggi.Services;
using GestioneViaggi.Repositories;
using GestioneViaggi.Repositories.Interfaces;
using GestioneViaggi.Services.Email;

using GestioneViaggi.Statistics;
using GestioneViaggi.Migrazione_Dati_Oracle;

namespace GestioneViaggi;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        // Dapper rimosso per transizione ad AOT nativo con Npgsql

        // Configura licenza QuestPDF (Community)
        QuestPDF.Settings.License = QuestPDF.Infrastructure.LicenseType.Community;

        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .UseSkiaSharp()
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
                fonts.AddFont("Lato-Regular.ttf", "Lato");
                fonts.AddFont("Lato-Bold.ttf", "LatoBold");
                fonts.AddFont("Lato-Italic.ttf", "LatoItalic");
                fonts.AddFont("Lato-BoldItalic.ttf", "LatoBoldItalic");
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

        var assembly = typeof(MauiProgram).Assembly;
        
        // Carica appsettings.json (Base / Produzione)
        using (var stream = assembly.GetManifestResourceStream("GestioneViaggi.appsettings.json"))
        {
            if (stream != null) builder.Configuration.AddJsonStream(stream);
        }

#if DEBUG
        // Carica appsettings.Development.json (Sviluppo)
        using (var stream = assembly.GetManifestResourceStream("GestioneViaggi.appsettings.Development.json"))
        {
            if (stream != null) builder.Configuration.AddJsonStream(stream);
        }
#endif

        builder.Services.AddSingleton<IDatabaseConnectionManager, DatabaseConnectionManager>();
        builder.Services.AddSingleton<IDatabaseService, PostgreSqlService>();

        builder.Services.AddSingleton<ISecureStorageProvider, FileStorageProvider>();

        builder.Services.AddSingleton<ISessionManager, SessionManager>();
        builder.Services.AddScoped<ITenantContext, TenantContext>();

        builder.Services.AddScoped<IAuthenticationService, AuthenticationService>();
        builder.Services.AddScoped<AuthenticationStateProvider, CustomAuthStateProvider>();
        builder.Services.AddAuthorizationCore();

        // Password Reset & Email Services
        builder.Services.AddSingleton<GestioneViaggi.Services.Security.ISecretKeyProvider, GestioneViaggi.Services.Security.SecretKeyProvider>();
        builder.Services.AddHttpClient<ResendEmailSender>();
        builder.Services.AddScoped<EmailSenderFactory>();
        builder.Services.AddScoped<PasswordResetService>();

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
        builder.Services.AddScoped<Services.CRUD.ClienteLinguaService>();
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
        // AnaFornitoriService rimosso (13/02/2026) - utilizzare ContropartiService
        builder.Services.AddScoped<ContropartiService>();
        builder.Services.AddScoped<TipoFornitoreService>();
        builder.Services.AddScoped<AnaValuteService>();
        builder.Services.AddScoped<MovTransazioniService>();
        builder.Services.AddScoped<AnaTassiCambioService>();
        builder.Services.AddScoped<AnaDateViaggiService>();
        builder.Services.AddScoped<AnaTipiCausaliService>();
        builder.Services.AddScoped<AnaAliquoteIvaService>();
        builder.Services.AddScoped<AnaRegimiFiscaliService>();
        builder.Services.AddScoped<FiscalCalculationService>();
        builder.Services.AddScoped<ApiConfigService>();
        builder.Services.AddScoped<UserPreferenzeService>();

        // ==========================================================
        // ESTENSIONE WEB - SERVIZI CMS (Blocco 4)
        // ==========================================================
        builder.Services.AddScoped<WebTourContenutiService>();
        builder.Services.AddScoped<WebTourItinerarioService>();
        builder.Services.AddScoped<WebTourItinerarioPassaggiService>();
        builder.Services.AddScoped<WebTourImmaginiService>();
        builder.Services.AddScoped<WebTourMappaService>();
        builder.Services.AddScoped<WebTipiViaggioDescrizioniService>();
        builder.Services.AddScoped<WebTraduzioniService>();
        builder.Services.AddScoped<WebNewsletterIscrittiService>();
        builder.Services.AddScoped<WebNewsletterInviiService>();
        builder.Services.AddScoped<WebNewsletterInviiDestinatariService>();
        builder.Services.AddScoped<WebNewsletterSoppressioniService>();
        builder.Services.AddScoped<Services.Web.NewsletterSenderService>();
        builder.Services.AddScoped<WebAziendeFunzioniService>();

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

        // Printing Services
        builder.Services.AddScoped<ITravelPrintService, TravelPrintService>();
        builder.Services.AddScoped<IRoomingListPrintService, RoomingListPrintService>();
        builder.Services.AddSingleton<MovTransazioniPrintService>();
        builder.Services.AddSingleton<ScadenzarioPrintService>();
        builder.Services.AddSingleton<BilancioViaggioPrintService>();
        builder.Services.AddSingleton<RegistroIvaPrintService>();
        builder.Services.AddSingleton<FatturaAttivaPrintService>();
        builder.Services.AddScoped<IPdfOpenerService, PdfOpenerService>();

        // File Opener & Export Services
        builder.Services.AddScoped<Services.Shared.IFileOpenerService, Services.Shared.FileOpenerService>();
        builder.Services.AddScoped<Services.Shared.IBrowserLauncherService, Services.Shared.BrowserLauncherService>();
        builder.Services.AddScoped<Services.Export.IExcelExportService, Services.Export.ExcelExportService>();
        builder.Services.AddScoped<Services.Export.IClienteExportService, Services.Export.ClienteExportService>();
        builder.Services.AddScoped<Services.Export.IFatturaElettronicaXmlService, Services.Export.FatturaElettronicaXmlService>();

        // External APIs
        builder.Services.AddHttpClient<GestioneViaggi.Services.ExternalApis.ICurrencyApiService, GestioneViaggi.Services.ExternalApis.CurrencyApiService>();

        // Exchange Rate Service
        builder.Services.AddScoped<Services.Shared.IExchangeRateService, Services.Shared.ExchangeRateService>();

        // Web Media Storage (Supabase) - opzioni + implementazione HTTP REST (Blocco 7)
        var webMediaStorageSection = builder.Configuration.GetSection("WebMediaStorage");
        builder.Services.AddSingleton(new Services.Shared.Storage.WebMediaStorageOptions
        {
            BaseUrl = webMediaStorageSection["BaseUrl"] ?? "",
            Bucket = webMediaStorageSection["Bucket"] ?? "tour-media",
            ServiceKey = webMediaStorageSection["ServiceKey"] ?? ""
        });
        builder.Services.AddHttpClient<Services.Shared.Storage.IWebMediaStorage, Services.Shared.Storage.SupabaseMediaStorage>();

        // Geoapify Static Maps (Blocco 9) - opzioni + client HTTP + pipeline GPX→mappa
        var geoapifySection = builder.Configuration.GetSection("Geoapify");
        var geoapifyOptions = new Services.Shared.Geo.GeoapifyOptions
        {
            ApiKey = geoapifySection["ApiKey"] ?? "",
            Style = string.IsNullOrWhiteSpace(geoapifySection["Style"]) ? "osm-bright" : geoapifySection["Style"]!
        };
        // Budget punti del tracciato: se assente/non valido resta il default della classe.
        if (int.TryParse(geoapifySection["MaxPolylinePoints"], out var maxPolylinePoints) && maxPolylinePoints > 1)
            geoapifyOptions.MaxPolylinePoints = maxPolylinePoints;
        builder.Services.AddSingleton(geoapifyOptions);
        builder.Services.AddHttpClient<Services.Shared.Geo.GeoapifyStaticMapClient>();
        builder.Services.AddScoped<Services.Web.WebTourMappaGeneratorService>();

        // Claude API (Blocco 10) - traduzioni. Chiave PER-AZIENDA (ana_aziende.claude_api_key), non da config.
        var claudeSection = builder.Configuration.GetSection("Claude");
        builder.Services.AddSingleton(new Services.Shared.Ai.ClaudeOptions
        {
            Model = string.IsNullOrWhiteSpace(claudeSection["Model"]) ? "claude-haiku-4-5-20251001" : claudeSection["Model"]!
        });
        builder.Services.AddHttpClient<Services.Shared.Ai.ClaudeTranslationClient>();
        builder.Services.AddScoped<Services.Web.WebTraduzioneOrchestratorService>();

        return builder.Build();
    }
}
