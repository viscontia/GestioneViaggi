namespace GestioneViaggi.Services.Shared.Storage;

/// <summary>Astrazione upload/URL dei media web (Supabase Storage). storage_path = sorgente di verità.</summary>
public interface IWebMediaStorage
{
    Task<string> UploadAsync(string storagePath, Stream content, string contentType, CancellationToken ct = default);
    string BuildPublicUrl(string storagePath);            // ricompone l'URL dal base-URL d'ambiente
    Task DeleteAsync(string storagePath, CancellationToken ct = default);
}
