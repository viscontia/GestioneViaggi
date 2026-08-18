using Microsoft.AspNetCore.Components.WebView;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi;

public partial class MainPage : ContentPage
{
	/// <summary>
	/// Registro per le navigazioni della WebView. Statico perche' MainPage viene costruita a mano
	/// (App.xaml.cs), non dal contenitore: non c'e' un costruttore in cui iniettarlo.
	/// </summary>
	internal static ILogger? Registro { get; set; }

	public MainPage()
	{
		InitializeComponent();

		// L'anteprima della newsletter scrive dentro un <iframe> senza indirizzo. La WebView
		// legge quella scrittura come una NAVIGAZIONE verso "about:blank", e il comportamento
		// predefinito di BlazorWebView per un indirizzo che non riconosce e' aprirlo nel browser
		// di sistema: fallisce con «There was an error trying to open URL: about:blank», e
		// nel farlo l'albero Blazor viene ricostruito da capo — la newsletter aperta si chiudeva
		// e si tornava all'elenco.
		//
		// Qui si dice alla WebView di tenersela: about: e blob: sono indirizzi interni alla
		// pagina, non collegamenti che l'utente ha chiesto di aprire altrove.
		blazorWebView.UrlLoading += (_, e) =>
		{
			var indirizzo = e.Url?.ToString() ?? string.Empty;
			if (indirizzo.StartsWith("about:", StringComparison.OrdinalIgnoreCase) ||
				indirizzo.StartsWith("blob:", StringComparison.OrdinalIgnoreCase))
			{
				e.UrlLoadingStrategy = UrlLoadingStrategy.OpenInWebView;
			}

			// Ogni navigazione finisce nel registro, non solo quelle che dirottiamo.
			//
			// Perche' serve: OpenInWebView dice alla WebView di ANDARE a quell'indirizzo. Sull'iframe
			// dell'anteprima e' quello che vogliamo; se pero' l'evento riguardasse il riquadro
			// principale, la pagina Blazor verrebbe sostituita da about:blank — schermo nero, canale
			// verso .NET morto, i clic che non arrivano piu'. E' esattamente il guasto che stiamo
			// cercando, e questa riga e' cio' che distingue le due cose invece di supporle.
			Registro?.LogWarning("Navigazione WebView: {Indirizzo} -> {Strategia}",
								 indirizzo, e.UrlLoadingStrategy);
		};
	}
}
