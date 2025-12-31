using System.Reflection;

namespace GestioneViaggi.Helpers;

/// <summary>
/// Normalizza le entità prima del salvataggio in database per garantire
/// che le stringhe nullable vuote siano convertite in NULL.
/// Previene violazioni di constraint DB (es. check_email_format).
/// </summary>
public static class EntityNormalizer
{
    /// <summary>
    /// Normalizza tutte le proprietà string? dell'entità:
    /// - Converte stringhe vuote o whitespace in NULL
    /// - Mantiene NULL come NULL
    /// - Mantiene valori non-vuoti invariati
    /// </summary>
    /// <typeparam name="T">Tipo di entità</typeparam>
    /// <param name="entity">Entità da normalizzare</param>
    public static void NormalizeNullableStrings<T>(T entity) where T : class
    {
        if (entity == null)
            return;

        var properties = typeof(T).GetProperties(BindingFlags.Public | BindingFlags.Instance)
            .Where(p => p.PropertyType == typeof(string) && p.CanRead && p.CanWrite);

        foreach (var property in properties)
        {
            var value = property.GetValue(entity) as string;
            
            // Se la stringa è vuota o solo whitespace, imposta NULL
            if (string.IsNullOrWhiteSpace(value))
            {
                property.SetValue(entity, null);
            }
        }
    }

    /// <summary>
    /// Normalizza ricorsivamente anche le collection di entità correlate.
    /// Usa questo metodo per entità complesse con navigation properties.
    /// </summary>
    public static void NormalizeDeep<T>(T entity) where T : class
    {
        if (entity == null)
            return;

        // Normalizza l'entità principale
        NormalizeNullableStrings(entity);

        // TODO: Aggiungere logica per normalizzare collection se necessario
        // Es: se un'entità ha List<Child>, normalizzare anche i children
    }
}
