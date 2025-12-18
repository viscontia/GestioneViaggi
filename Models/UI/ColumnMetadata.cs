namespace GestioneViaggi.Models.UI;

/// <summary>
/// Metadata per configurazione automatica colonne DataGrid
/// </summary>
public class ColumnMetadata
{
    /// <summary>
    /// Nome della proprietà da visualizzare
    /// </summary>
    public string PropertyName { get; set; } = string.Empty;

    /// <summary>
    /// Titolo dell'header della colonna
    /// </summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>
    /// Formato di visualizzazione (es: N0, N2, C2)
    /// </summary>
    public string? Format { get; set; }

    /// <summary>
    /// Larghezza calcolata automaticamente (settata dal sistema)
    /// </summary>
    public int CalculatedWidth { get; set; }

    /// <summary>
    /// Stile CSS calcolato automaticamente (settato dal sistema)
    /// </summary>
    public string? CalculatedStyle { get; set; }

    /// <summary>
    /// Override manuale della larghezza (opzionale)
    /// </summary>
    public int? ManualWidth { get; set; }

    /// <summary>
    /// Override manuale dello stile (opzionale)
    /// </summary>
    public string? ManualStyle { get; set; }

    /// <summary>
    /// Indica se la colonna è numerica
    /// </summary>
    public bool IsNumeric { get; set; }
}
