using Microsoft.Extensions.Logging;
using MudBlazor.Services; // <--- Se manca questo using, non compila
using MudBlazor;
using GestioneViaggi.Components;
using GestioneViaggi.Components.Shared;

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
        // QUESTA È LA RIGA CHE FA FUNZIONARE LA GRIGLIA
        // Se questa manca, appena apri la pagina esplode tutto.
        // ==========================================================
        builder.Services.AddMudServices();
        
        // REGISTRAZIONE LOCALIZZAZIONE ITALIANA (GRID, PAGER, ECC.)
        builder.Services.AddTransient<MudLocalizer, ItalianMudLocalizer>();

        builder.Services.AddMauiBlazorWebView();

#if DEBUG
        // Questo abilita l'Ispeziona Elemento (tasto destro)
        builder.Services.AddBlazorWebViewDeveloperTools();
        builder.Logging.AddDebug();
#endif

        return builder.Build();
    }
}
