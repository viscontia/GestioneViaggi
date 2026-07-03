namespace GestioneViaggi.Services.Shared.Storage;

/// <summary>Opzioni di configurazione dello storage media web (Supabase Storage).</summary>
public sealed class WebMediaStorageOptions
{
    public string BaseUrl { get; set; } = "";     // es. https://<ref>.supabase.co/storage/v1/object/public
    public string Bucket { get; set; } = "tour-media";
    public string ServiceKey { get; set; } = "";   // solo per upload/delete lato server
}
