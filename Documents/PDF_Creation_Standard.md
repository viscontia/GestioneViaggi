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
Su MacCatalyst, i font non vengono sempre caricati automaticamente dal bundle.
**Best Practice:**
1. Includere i font (es. Lato) in `Resources/Fonts`.
2. Nel servizio di generazione PDF, implementare un **fallback** che:
   - Controlla se i font sono nella `BaseDirectory`.
   - Se mancano, li cerca in `Resources` e li **copia** nella `BaseDirectory`.
   - Registra manualmente i font con `FontManager.RegisterFont(stream)`.

```csharp
// Esempio registrazione manuale
foreach (var fontFile in fontFiles)
{
    using var stream = File.OpenRead(fontFile);
    QuestPDF.Drawing.FontManager.RegisterFont(stream);
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
