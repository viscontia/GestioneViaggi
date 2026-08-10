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
    public const int Quality = 80;
    public const string Mime = "image/webp";

    public static async Task<ProcessedImage> ToOptimizedWebpAsync(Stream input, CancellationToken ct = default)
    {
        using var image = await Image.LoadAsync(input, ct);

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
        using var image = await Image.LoadAsync(input, ct);

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
    public static async Task<ProcessedImage> ToEmailIconPngAsync(Stream input, CancellationToken ct = default)
    {
        using var image = await Image.LoadAsync(input, ct);

        if (Math.Max(image.Width, image.Height) > MaxEdgeIcona)
        {
            image.Mutate(x => x.Resize(new ResizeOptions
            {
                Mode = ResizeMode.Max,
                Size = new Size(MaxEdgeIcona, MaxEdgeIcona)
            }));
        }

        using var ms = new MemoryStream();
        await image.SaveAsPngAsync(ms, ct);
        return new ProcessedImage(ms.ToArray(), image.Width, image.Height, MimeIcona);
    }
}

/// <summary>Risultato dell'ottimizzazione: bytes WebP + dimensioni finali + mime.</summary>
public readonly record struct ProcessedImage(byte[] Bytes, int Width, int Height, string Mime);
