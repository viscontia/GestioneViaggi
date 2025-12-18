using System.Globalization;
using System.Reflection;

namespace GestioneViaggi.Services.UI;

/// <summary>
/// Calcola automaticamente la larghezza ottimale delle colonne di una DataGrid
/// basandosi sul contenuto dei dati
/// </summary>
public static class ColumnSizeCalculator
{
    private const int CharWidthPx = 8;  // Larghezza media carattere in px
    private const int PaddingPx = 32;   // Padding totale della cella
    private const int DefaultMinWidth = 80;
    private const int DefaultMaxWidth = 400;
    private const int HeaderExtraPadding = 20; // Spazio extra per header

    /// <summary>
    /// Calcola la larghezza ottimale per una colonna basandosi su un campione di dati
    /// </summary>
    public static int CalculateOptimalWidth<T>(
        IEnumerable<T> items,
        string propertyName,
        string? headerText,
        int sampleSize = 50,
        int minWidth = DefaultMinWidth,
        int maxWidth = DefaultMaxWidth)
    {
        var sample = items.Take(sampleSize).ToList();
        if (!sample.Any())
        {
            return minWidth;
        }

        // Calcola larghezza basata sul contenuto dei dati
        var maxContentLength = 0;
        foreach (var item in sample)
        {
            var value = GetPropertyValue(item, propertyName);
            var displayText = FormatValueForDisplay(value);
            var length = displayText?.Length ?? 0;
            if (length > maxContentLength)
            {
                maxContentLength = length;
            }
        }

        // Considera anche la lunghezza dell'header
        var headerLength = (headerText?.Length ?? 0) + HeaderExtraPadding / CharWidthPx;
        var maxLength = Math.Max(maxContentLength, headerLength);

        // Calcola larghezza in pixel
        var calculatedWidth = maxLength * CharWidthPx + PaddingPx;

        // Applica vincoli min/max
        return Math.Max(minWidth, Math.Min(calculatedWidth, maxWidth));
    }

    /// <summary>
    /// Determina se una proprietà è di tipo numerico
    /// </summary>
    public static bool IsNumericType<T>(string propertyName)
    {
        var propertyInfo = typeof(T).GetProperty(propertyName, BindingFlags.Public | BindingFlags.Instance);
        if (propertyInfo == null) return false;

        var type = Nullable.GetUnderlyingType(propertyInfo.PropertyType) ?? propertyInfo.PropertyType;

        return type == typeof(int) ||
               type == typeof(long) ||
               type == typeof(short) ||
               type == typeof(byte) ||
               type == typeof(decimal) ||
               type == typeof(double) ||
               type == typeof(float);
    }

    /// <summary>
    /// Determina se una colonna dovrebbe essere centrata (testo corto: sigla, codice, ecc.)
    /// </summary>
    public static bool ShouldCenterAlign(int calculatedWidth)
    {
        return calculatedWidth < 100; // Colonne sotto 100px vengono centrate
    }

    /// <summary>
    /// Ottiene il valore di una proprietà da un oggetto usando reflection
    /// </summary>
    private static object? GetPropertyValue<T>(T item, string propertyName)
    {
        if (item == null) return null;

        var propertyInfo = typeof(T).GetProperty(propertyName, BindingFlags.Public | BindingFlags.Instance);
        return propertyInfo?.GetValue(item);
    }

    /// <summary>
    /// Formatta un valore per la visualizzazione, applicando formattazione per numeri
    /// </summary>
    private static string? FormatValueForDisplay(object? value)
    {
        if (value == null) return null;

        // Formatta numeri con separatore migliaia (formato italiano)
        if (value is int intValue)
            return intValue.ToString("N0", new CultureInfo("it-IT"));

        if (value is long longValue)
            return longValue.ToString("N0", new CultureInfo("it-IT"));

        if (value is decimal decimalValue)
            return decimalValue.ToString("N2", new CultureInfo("it-IT"));

        if (value is double doubleValue)
            return doubleValue.ToString("N2", new CultureInfo("it-IT"));

        if (value is float floatValue)
            return floatValue.ToString("N2", new CultureInfo("it-IT"));

        return value.ToString();
    }

    /// <summary>
    /// Genera lo stile CSS per una colonna
    /// </summary>
    public static string GenerateColumnStyle(int width, bool isNumeric, bool shouldCenter)
    {
        var styles = new List<string>
        {
            $"min-width: {width}px"
        };

        if (isNumeric)
        {
            styles.Add("text-align: right");
        }
        else if (shouldCenter)
        {
            styles.Add("text-align: center");
        }

        return string.Join("; ", styles) + ";";
    }
}
