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

		// LA ROTELLA DEL MOUSE NON DEVE CAMBIARE PAGINA.
		//
		// Sintomo: con una scheda aperta e il lavoro non salvato, una rotellata riportava
		// alla dashboard. Non e' codice nostro: il motore della WebView legge lo scroll che
		// sfonda il bordo della pagina — la rotella inclinabile, due dita sul trackpad — come
		// il gesto «indietro» del browser, e «indietro» qui significa abbandonare la scheda.
		//
		// Si chiude da due lati: qui (il gesto non arriva nemmeno alla pagina) e nel CSS
		// (`overscroll-behavior: none`, che vale su ogni piattaforma). Nessuno dei due da
		// solo copre tutti i casi.
		//
		// Insieme si tolgono anche le scorciatoie da browser: F5 e Ctrl+R ricaricavano
		// l'applicazione da zero, Alt+Freccia faceva lo stesso danno della rotella. In un
		// gestionale non servono e possono solo far perdere quello che si sta scrivendo.
		blazorWebView.BlazorWebViewInitialized += (_, e) =>
		{
#if WINDOWS
			var impostazioni = e.WebView?.CoreWebView2?.Settings;
			if (impostazioni is not null)
			{
				impostazioni.IsSwipeNavigationEnabled = false;
				impostazioni.AreBrowserAcceleratorKeysEnabled = false;
			}
#endif
		};

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
			// Con la pila delle chiamate, perche' e' l'unica cosa che risponde a "chi l'ha chiesto".
			//
			// Sappiamo che la pagina viene caricata da capo su una rotta dell'applicazione
			// (dashboard-admin, anagrafiche/clienti, tabelle/comuni), che il tipo di caricamento e'
			// "navigate" e non "reload", e che dalla pagina non parte alcun evento di abbandono:
			// nessun collegamento cliccato, quindi l'ordine arriva da questo lato. Se e' codice .NET
			// a chiederlo, il chiamante e' qui dentro; se la pila contiene solo il delegato della
			// WebView, allora e' il sistema a rinavigare e la ricerca va spostata altrove.
			Registro?.LogWarning("Navigazione WebView: {Indirizzo} -> {Strategia}\nChiamata da:\n{Pila}",
								 indirizzo, e.UrlLoadingStrategy, Environment.StackTrace);
		};
	}
}
