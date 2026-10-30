namespace GestioneViaggi.Services.Shared.Storage;

/// <summary>Astrazione upload/URL dei media web (Supabase Storage). storage_path = sorgente di verità.</summary>
public interface IWebMediaStorage
{
    Task<string> UploadAsync(string storagePath, Stream content, string contentType, CancellationToken ct = default);
    string BuildPublicUrl(string storagePath);            // ricompone l'URL dal base-URL d'ambiente
    Task DeleteAsync(string storagePath, CancellationToken ct = default);

    // L27: gli originali non sono più pubblici (script 709, poi Task 7).

    /// <summary>L'originale, letto con la chiave; null se non c'è.</summary>
    Task<byte[]?> DownloadAsync(string storagePath, CancellationToken ct = default);

    /// <summary>Un indirizzo firmato dell'originale, valido <paramref name="secondi"/> secondi; null se non si ottiene.</summary>
    Task<string?> SignedUrlAsync(string storagePath, int secondi, CancellationToken ct = default);

    /// <summary>Il percorso nell'archivio degli originali di un indirizzo salvato nel database; null se non è suo.</summary>
    string? StoragePathFromUrl(string? url);

    /// <summary>Carica un'immagine preparata per le newsletter nell'archivio pubblico delle newsletter; ne torna l'URL.</summary>
    Task<string> UploadNewsletterAsync(string storagePath, Stream content, string contentType, CancellationToken ct = default);
}
