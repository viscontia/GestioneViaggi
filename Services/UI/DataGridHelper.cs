namespace GestioneViaggi.Services.UI;

/// <summary>
/// Helper per semplificare la configurazione delle DataGrid con auto-sizing
/// </summary>
public class DataGridHelper<T> where T : class
{
    private readonly IEnumerable<T> _items;
    private readonly int _sampleSize;
    private readonly int _minWidth;
    private readonly int _maxWidth;

    public DataGridHelper(
        IEnumerable<T> items,
        int sampleSize = 50,
        int minWidth = 80,
        int maxWidth = 400)
    {
        _items = items;
        _sampleSize = sampleSize;
        _minWidth = minWidth;
        _maxWidth = maxWidth;
    }

    /// <summary>
    /// Calcola la larghezza ottimale per una colonna
    /// </summary>
    public int GetColumnWidth(string propertyName, string? headerText = null)
    {
        return ColumnSizeCalculator.CalculateOptimalWidth(
            _items,
            propertyName,
            headerText ?? propertyName,
            _sampleSize,
            _minWidth,
            _maxWidth);
    }

    /// <summary>
    /// Genera lo stile CSS completo per una colonna
    /// </summary>
    public string GetColumnStyle(string propertyName, string? headerText = null)
    {
        var width = GetColumnWidth(propertyName, headerText);
        var isNumeric = ColumnSizeCalculator.IsNumericType<T>(propertyName);
        var shouldCenter = ColumnSizeCalculator.ShouldCenterAlign(width);

        return ColumnSizeCalculator.GenerateColumnStyle(width, isNumeric, shouldCenter);
    }

    /// <summary>
    /// Ottiene solo la parte di min-width dello stile
    /// </summary>
    public string GetMinWidth(string propertyName, string? headerText = null)
    {
        var width = GetColumnWidth(propertyName, headerText);
        return $"{width}px";
    }

    /// <summary>
    /// Ottiene l'allineamento appropriato per una colonna
    /// </summary>
    public string GetTextAlign(string propertyName)
    {
        var width = GetColumnWidth(propertyName);
        var isNumeric = ColumnSizeCalculator.IsNumericType<T>(propertyName);
        var shouldCenter = ColumnSizeCalculator.ShouldCenterAlign(width);

        if (isNumeric) return "right";
        if (shouldCenter) return "center";
        return "left";
    }
}
