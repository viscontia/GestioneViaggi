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
}

/// <summary>Risultato dell'ottimizzazione: bytes WebP + dimensioni finali + mime.</summary>
public readonly record struct ProcessedImage(byte[] Bytes, int Width, int Height, string Mime);
