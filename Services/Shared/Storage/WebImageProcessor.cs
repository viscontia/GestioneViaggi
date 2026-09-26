using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Webp;
using SixLabors.ImageSharp.Processing;
// Alias per risolvere i clash con i global using di MAUI (Microsoft.Maui.Graphics/Controls).
using Image = SixLabors.ImageSharp.Image;
using Size = SixLabors.ImageSharp.Size;
using ResizeMode = SixLabors.ImageSharp.Processing.ResizeMode;

namespace GestioneViaggi.Services.Shared.Storage;

/// <summary>
/// Ottimizzazione immagini web (Blocco 7): ridimensiona il lato lungo a max <see cref="MaxEdge"/>px
/// (solo downscale, mai upscale) e converte in WebP qualità <see cref="Quality"/>. Un solo file per immagine.
/// </summary>
public static class WebImageProcessor
{
    public const int MaxEdge = 2000;

    /// <summary>Messaggio per chi carica un formato che nessun decodificatore legge.</summary>
    public const string MessaggioFormatoNonLetto =
        "formato non leggibile. Salva la foto come JPEG o PNG e riprova.";

    /// <summary>
    /// Apre un'immagine con ImageSharp; se il formato non lo conosce (HEIC/HEIF delle foto
    /// iPhone) la converte prima in PNG con il decodificatore della piattaforma.
    /// </summary>
    /// <remarks>
    /// ImageSharp non legge l'HEIC, e le foto passate da iPhone a un PC Windows arrivano spesso
    /// cosi' (trovato il 2026-09-26: «Image cannot be loaded. Available decoders: …»).
    /// Su Windows decodifica Magick.NET, sul Mac ImageIO. Un formato che non legge nessuno
    /// dei due finisce in <see cref="MessaggioFormatoNonLetto"/>, non nell'elenco dei
    /// decodificatori di ImageSharp.
    /// </remarks>
    private static async Task<Image> CaricaAsync(Stream input, CancellationToken ct)
    {
        // Serve rileggere lo stream dall'inizio se ImageSharp lo rifiuta.
        using var copia = input is MemoryStream ? null : new MemoryStream();
        if (copia is not null) await input.CopyToAsync(copia, ct);
        var ms = copia ?? (MemoryStream)input;
        ms.Position = 0;

        try
        {
            return await Image.LoadAsync(ms, ct);
        }
        catch (UnknownImageFormatException)
        {
            ms.Position = 0;
            var png = ConvertiInPngDallaPiattaforma(ms.ToArray())
                      ?? throw new InvalidOperationException(MessaggioFormatoNonLetto);
            return Image.Load(png);
        }
    }

    /// <summary>PNG ottenuto dal decodificatore della piattaforma, o null se non ci riesce.</summary>
    private static byte[]? ConvertiInPngDallaPiattaforma(byte[] originale)
    {
#if WINDOWS
        try
        {
            using var magick = new ImageMagick.MagickImage(originale);
            magick.AutoOrient();   // la rotazione dello scatto diventa pixel: ImageSharp non la rileggerebbe
            magick.Format = ImageMagick.MagickFormat.Png;
            return magick.ToByteArray();
        }
        catch (ImageMagick.MagickException)
        {
            return null;
        }
#elif MACCATALYST || IOS
        using var dati = Foundation.NSData.FromArray(originale);
        using var sorgente = ImageIO.CGImageSource.FromData(dati);
        if (sorgente is null || sorgente.ImageCount == 0) return null;
        // La miniatura «con trasformazione» applica la rotazione dello scatto; il lato
        // massimo e' largo abbastanza da non toccare la risoluzione delle foto di un telefono.
        using var immagine = sorgente.CreateThumbnail(0, new ImageIO.CGImageThumbnailOptions
        {
            CreateThumbnailFromImageAlways = true,
            CreateThumbnailWithTransform = true,
            MaxPixelSize = 10000
        });
        if (immagine is null) return null;
        var uscita = new Foundation.NSMutableData();
        using (var destinazione = ImageIO.CGImageDestination.Create(uscita, "public.png", 1))
        {
            if (destinazione is null) return null;
            destinazione.AddImage(immagine, (Foundation.NSDictionary?)null);
            if (!destinazione.Close()) return null;
        }
        return uscita.ToArray();
#else
        return null;
#endif
    }
    public const int Quality = 80;
    public const string Mime = "image/webp";

    public static async Task<ProcessedImage> ToOptimizedWebpAsync(Stream input, CancellationToken ct = default)
    {
        using var image = await CaricaAsync(input, ct);

        if (Math.Max(image.Width, image.Height) > MaxEdge)
        {
            image.Mutate(x => x.Resize(new ResizeOptions
            {
                Mode = ResizeMode.Max,           // fit nel box mantenendo l'aspect
                Size = new Size(MaxEdge, MaxEdge)
            }));
        }

        using var ms = new MemoryStream();
        await image.SaveAsWebpAsync(ms, new WebpEncoder { Quality = Quality }, ct);
        return new ProcessedImage(ms.ToArray(), image.Width, image.Height, Mime);
    }

    // --- Email -------------------------------------------------------------
    // Le immagini delle newsletter NON possono essere WebP: Outlook per Windows usa il motore di
    // rendering di Word, che non lo supporta, e mostrerebbe un riquadro vuoto. Servono JPEG (o PNG)
    // e una larghezza contenuta, perche' il riquadro di lettura sicuro e' 600px.

    public const int MaxEdgeEmail = 1200;
    public const int QualityEmail = 82;
    public const string MimeEmail = "image/jpeg";

    /// <summary>
    /// Deriva la versione da email di un'immagine: JPEG, lato lungo max <see cref="MaxEdgeEmail"/>px.
    /// Il JPEG non ha canale alfa: le trasparenze vengono appiattite su bianco, che e' lo sfondo
    /// del corpo della newsletter (senza, diventerebbero nere).
    /// </summary>
    public static async Task<ProcessedImage> ToEmailJpegAsync(Stream input, CancellationToken ct = default)
    {
        using var image = await CaricaAsync(input, ct);

        if (Math.Max(image.Width, image.Height) > MaxEdgeEmail)
        {
            image.Mutate(x => x.Resize(new ResizeOptions
            {
                Mode = ResizeMode.Max,
                Size = new Size(MaxEdgeEmail, MaxEdgeEmail)
            }));
        }

        image.Mutate(x => x.BackgroundColor(SixLabors.ImageSharp.Color.White));

        using var ms = new MemoryStream();
        await image.SaveAsJpegAsync(ms, new SixLabors.ImageSharp.Formats.Jpeg.JpegEncoder { Quality = QualityEmail }, ct);
        return new ProcessedImage(ms.ToArray(), image.Width, image.Height, MimeEmail);
    }

    // --- Icone -------------------------------------------------------------

    public const int MaxEdgeIcona = 128;
    public const string MimeIcona = "image/png";

    /// <summary>
    /// Versione da email di un'<b>icona</b>: PNG, lato lungo max <see cref="MaxEdgeIcona"/>px,
    /// con la <b>trasparenza conservata</b>.
    /// </summary>
    /// <remarks>
    /// Non usa <see cref="ToEmailJpegAsync"/> di proposito: il JPEG non ha canale alfa e
    /// appiattirebbe il fondo su bianco. Su un pulsante colorato — un social, per esempio — il
    /// risultato sarebbe un riquadro bianco attorno al logo. Il PNG e' supportato da tutti i
    /// client di posta, Outlook compreso, quindi non c'e' motivo di convertire.
    /// Le icone restano piccole, quindi il PNG non pesa: 128px e' gia' il doppio di quanto serve
    /// per una resa a 18px su schermi ad alta densita'.
    /// </remarks>
    public static Task<ProcessedImage> ToEmailIconPngAsync(Stream input, CancellationToken ct = default)
        => ToEmailPngAsync(input, MaxEdgeIcona, ct);

    /// <summary>PNG ridimensionato, con la trasparenza conservata.</summary>
    public static async Task<ProcessedImage> ToEmailPngAsync(Stream input, int maxEdge, CancellationToken ct = default)
    {
        using var image = await CaricaAsync(input, ct);

        if (Math.Max(image.Width, image.Height) > maxEdge)
        {
            image.Mutate(x => x.Resize(new ResizeOptions
            {
                Mode = ResizeMode.Max,
                Size = new Size(maxEdge, maxEdge)
            }));
        }

        using var ms = new MemoryStream();
        await image.SaveAsPngAsync(ms, ct);
        return new ProcessedImage(ms.ToArray(), image.Width, image.Height, MimeIcona);
    }

    /// <summary>
    /// Versione da email di un'immagine di libreria: <b>PNG se l'originale è PNG</b>, altrimenti
    /// JPEG.
    /// </summary>
    /// <remarks>
    /// La libreria contiene due cose diverse: icone, che vivono di trasparenza e vanno lasciate in
    /// PNG, e immagini generiche, per cui il JPEG pesa meno. Convertire tutto in JPEG
    /// appiattirebbe le trasparenze su bianco — è l'errore già commesso con le icone social — e
    /// tenere tutto in PNG farebbe pesare inutilmente le fotografie.
    /// </remarks>
    public static Task<ProcessedImage> ToEmailLibreriaAsync(Stream input, bool originalePng, CancellationToken ct = default)
        => originalePng
            ? ToEmailPngAsync(input, MaxEdgeEmail, ct)
            : ToEmailJpegAsync(input, ct);
}

/// <summary>Risultato dell'ottimizzazione: bytes WebP + dimensioni finali + mime.</summary>
public readonly record struct ProcessedImage(byte[] Bytes, int Width, int Height, string Mime);
