using Microsoft.AspNetCore.Components.WebView;

namespace GestioneViaggi;

public partial class MainPage : ContentPage
{
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
		};
	}
}
