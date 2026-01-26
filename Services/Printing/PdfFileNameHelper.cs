namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Helper class per la generazione dei nomi file PDF delle stampe
/// </summary>
public static class PdfFileNameHelper
{
    /// <summary>
    /// Genera il nome file per la stampa "Scheda Viaggio"
    /// </summary>
    /// <param name="header">Informazioni header del viaggio</param>
    /// <returns>Nome file nel formato: SchedaViaggio_{Titolo}_Dal_{DataInizio}_al_{DataFine}.pdf</returns>
    public static string GetTravelSheetFileName(TravelHeaderInfo header)
    {
        var safeTitle = SanitizeFileName(header.DescrizioneBreve, maxLength: 40);
        var dateStart = header.DataInizio?.ToString("dd-MM-yyyy") ?? "ND";
        var dateEnd = header.DataFine?.ToString("dd-MM-yyyy") ?? "ND";
        return $"SchedaViaggio_{safeTitle}_Dal_{dateStart}_al_{dateEnd}.pdf";
    }

    /// <summary>
    /// Genera il nome file per la stampa "Rooming List"
    /// </summary>
    /// <param name="header">Informazioni header del viaggio</param>
    /// <returns>Nome file nel formato: RoomingList_{Titolo}_Dal_{DataInizio}_al_{DataFine}.pdf</returns>
    public static string GetRoomingListFileName(TravelHeaderInfo header)
    {
        var safeTitle = SanitizeFileName(header.DescrizioneBreve, maxLength: 40);
        var dateStart = header.DataInizio?.ToString("dd-MM-yyyy") ?? "ND";
        var dateEnd = header.DataFine?.ToString("dd-MM-yyyy") ?? "ND";
        return $"RoomingList_{safeTitle}_Dal_{dateStart}_al_{dateEnd}.pdf";
    }

    /// <summary>
    /// Sanitizza un nome file rimuovendo caratteri non validi e limitando la lunghezza
    /// </summary>
    /// <param name="fileName">Nome file da sanitizzare</param>
    /// <param name="maxLength">Lunghezza massima (default: 50)</param>
    /// <returns>Nome file sanitizzato</returns>
    private static string SanitizeFileName(string fileName, int maxLength = 50)
    {
        // Remove invalid characters
        var invalidChars = Path.GetInvalidFileNameChars();
        var sanitized = new string(fileName.Where(c => !invalidChars.Contains(c)).ToArray());

        // Replace common problematic characters
        sanitized = sanitized.Replace("/", "-").Replace("\\", "-").Replace(":", "-");

        // Trim and limit length
        sanitized = sanitized.Trim();
        if (sanitized.Length > maxLength)
        {
            sanitized = sanitized.Substring(0, maxLength).TrimEnd();
        }

        return string.IsNullOrWhiteSpace(sanitized) ? "Viaggio" : sanitized;
    }
}
