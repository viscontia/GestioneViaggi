# Standard Creazione PDF in MAUI (QuestPDF)

Questo documento definisce gli standard di progetto per la generazione di file PDF, basati sull'esperienza maturata per garantire compatibilità Cross-Platform (MacCatalyst, Windows, Android).

## 1. Librerie e Versioni
Per evitare conflitti di inizializzazione nativa (specialmente su MacCatalyst), utilizzare **tassativamente** queste versioni:

- **QuestPDF**: `2023.12.6` (Ultima versione pienamente compatibile con MAUI senza conflitti Skia 3.x)
- **SkiaSharp**: `2.88.8`
- **HarfBuzzSharp**: `7.3.0.2`
- **SkiaSharp.NativeAssets.MacCatalyst**: `2.88.8`
- **HarfBuzzSharp.NativeAssets.MacCatalyst**: `7.3.0.2`
- **SkiaSharp.Views.Maui.Controls**: `2.88.8`

## 2. Configurazione Iniziale (`MauiProgram.cs`)
È fondamentale inizializzare il motore nativo di SkiaSharp nel builder dell'app per evitare eccezioni di tipo `TypeInitializationException`.

```csharp
// In MauiProgram.cs
builder
    .UseMauiApp<App>()
    .UseSkiaSharp() // <--- FONDAMENTALE
    .ConfigureFonts(...);
```

## 3. Gestione Font (Critical)
Su MacCatalyst e altre piattaforme, QuestPDF necessità di accesso diretto allo stream del file font.
**Best Practice:**

1. **Inclusione nel Progetto**:
   In `GestioneViaggi.csproj`, includere i font sia come `MauiFont` (per la UI) sia come `MauiAsset` (per l'accesso stream):
   ```xml
   <MauiFont Include="Resources\Fonts\*" />
   <MauiAsset Include="Resources\Fonts\*" LogicalName="%(Filename)%(Extension)" />
   ```

2. **Inizializzazione Thread-Safe**:
   Utilizzare un pattern `SemaphoreSlim` statico per registrare i font una sola volta all'avvio del servizio di stampa.

3. **Caricamento Stream**:
   Usare `FileSystem.OpenAppPackageFileAsync` per leggere il font dal pacchetto app.

```csharp
private static bool _questPdfInitialized = false;
private static readonly SemaphoreSlim _initLock = new SemaphoreSlim(1, 1);

private async Task EnsureQuestPdfInitializedAsync()
{
    if (_questPdfInitialized) return;

    await _initLock.WaitAsync();
    try
    {
        if (_questPdfInitialized) return;

        // Configurazione Base
        QuestPDF.Settings.License = LicenseType.Community;
        QuestPDF.Settings.CheckIfAllTextGlyphsAreAvailable = false;

        // Registrazione Font da Asset
        var fonts = new[] { "Lato-Regular.ttf", "Lato-Bold.ttf", "Lato-Italic.ttf" };
        foreach (var font in fonts)
        {
            try
            {
                using var stream = await FileSystem.OpenAppPackageFileAsync(font);
                using var ms = new MemoryStream();
                await stream.CopyToAsync(ms);
                ms.Position = 0; // Reset position
                QuestPDF.Drawing.FontManager.RegisterFont(ms);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[QuestPDF] Failed to load font {font}: {ex.Message}");
            }
        }
        
        _questPdfInitialized = true;
    }
    finally
    {
        _initLock.Release();
    }
}
```

## 4. Percorso di Salvataggio
Non salvare mai nella cartella dell'applicazione (problemi di permessi e cache).
**Standard:** Cartella **Downloads** dell'utente.

```csharp
var targetFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads");
var fullPath = Path.Combine(targetFolder, "NomeFile.pdf");
```

## 5. Sovrascrittura File
Prima di generare il PDF, verificare sempre l'esistenza del file e cancellarlo per evitare errori di I/O o duplicati.

```csharp
if (File.Exists(fullPath))
{
    File.Delete(fullPath);
}
// Procedere con la generazione...
```

## 6. Apertura File (Cross-Platform)
Dopo la generazione, chiedere all'utente conferma ("Vuoi aprire il file?").
L'apertura deve gestire le differenze tra le piattaforme per garantire l'uso del viewer predefinito.

```csharp
if (result == true)
{
#if MACCATALYST
    // MacCatalyst: Usa comando nativo 'open' per evitare il share sheet inutile
    Process.Start("open", $"\"{fullPath}\"");
#else
    // Windows/Android/iOS: Usa il Launcher standard di MAUI
    await Launcher.Default.OpenAsync(new OpenFileRequest
    {
        Title = "Apri Documento",
        File = new ReadOnlyFile(fullPath)
    });
#endif
}
```
