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

#if MACCATALYST || WINDOWS
		window.Width = 1200;
		window.Height = 800;
#endif

		return window;
	}
}
