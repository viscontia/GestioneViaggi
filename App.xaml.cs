namespace GestioneViaggi;

public partial class App : Application
{
	public App()
	{
		InitializeComponent();
	}

	protected override Window CreateWindow(IActivationState? activationState)
	{
		var window = new Window(new MainPage()) { Title = "GestioneViaggi" };

#if MACCATALYST
		// Massimizza la finestra alle dimensioni dello schermo su Mac
		window.Created += (s, e) =>
		{
			var displayInfo = DeviceDisplay.Current.MainDisplayInfo;
			var density = displayInfo.Density;
			window.Width = displayInfo.Width / density;
			window.Height = displayInfo.Height / density;
			window.X = 0;
			window.Y = 0;
		};
#elif WINDOWS
		window.Created += (s, e) =>
		{
			var displayInfo = DeviceDisplay.Current.MainDisplayInfo;
			var density = displayInfo.Density;
			window.Width = displayInfo.Width / density;
			window.Height = displayInfo.Height / density;
			window.X = 0;
			window.Y = 0;
		};
#endif

		return window;
	}
}
