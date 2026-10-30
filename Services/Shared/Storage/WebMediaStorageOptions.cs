namespace GestioneViaggi.Services.Shared.Storage;

/// <summary>Opzioni di configurazione dello storage media web (Supabase Storage).</summary>
public sealed class WebMediaStorageOptions
{
    public string BaseUrl { get; set; } = "";     // es. https://<ref>.supabase.co/storage/v1/object/public
    /// <summary>Gli originali di foto e video: privato (L27), si leggono con la chiave o con un indirizzo firmato.</summary>
    public string Bucket { get; set; } = "tour-media";
    /// <summary>
    /// Le immagini preparate per le newsletter (L27, script 709): pubblico, perché un programma di posta non può
    /// chiedere permessi. In sviluppo lo stesso archivio di prova degli originali.
    /// </summary>
    public string NewsletterBucket { get; set; } = "newsletter-media";
    public string ServiceKey { get; set; } = "";   // solo per upload/delete lato server
}
