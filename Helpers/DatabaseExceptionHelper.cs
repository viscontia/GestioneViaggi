using Npgsql;
using GestioneViaggi.Models.Exceptions;
using System.Text.RegularExpressions;

namespace GestioneViaggi.Helpers;

public static class DatabaseExceptionHelper
{
    /// <summary>
    /// Analizza un'eccezione e restituisce una versione amichevole per l'utente.
    /// </summary>
    public static Exception WrapException(Exception ex, string? entityName = null)
    {
        if (ex is PostgresException pgEx)
        {
            return TranslatePostgresException(pgEx, entityName);
        }

        return ex; // Restituisce l'originale se non è del DB o non sappiamo gestirla
    }

    private static GestioneViaggiException TranslatePostgresException(PostgresException ex, string? entityName)
    {
        string message = "Si è verificato un errore imprevisto nel database.";
        string label = entityName ?? "questo elemento";

        switch (ex.SqlState)
        {
            case "23503": // foreign_key_violation
                string relatedTable = ExtractTableNameFromDetail(ex.Detail);
                message = $"Non è possibile eliminare {label} perché è utilizzato in altre parti del sistema";
                if (!string.IsNullOrEmpty(relatedTable))
                {
                    message += $" (es. {TranslateTableName(relatedTable)})";
                }
                message += ".";
                break;

            case "23505": // unique_violation
                message = $"Esiste già un record con questi dati. {label} non può essere duplicato.";
                break;

            case "23502": // not_null_violation
                message = $"Uno o più campi obbligatori di {label} non sono stati compilati.";
                break;

            case "22001": // string_data_right_truncation
                message = "Uno dei testi inseriti è troppo lungo. Riduci la lunghezza e riprova.";
                break;

            default:
                message = $"Errore database ({ex.SqlState}): {ex.MessageText}";
                break;
        }

        return new GestioneViaggiException(message, ex.SqlState, ex.TableName) { };
    }

    private static string ExtractTableNameFromDetail(string? detail)
    {
        if (string.IsNullOrEmpty(detail)) return string.Empty;

        // Esempio: Key (causale_id)=(10) is still referenced from table "mov_transazioni".
        var match = Regex.Match(detail, "table \"([^\"]+)\"");
        if (match.Success)
        {
            return match.Groups[1].Value;
        }

        return string.Empty;
    }

    private static string TranslateTableName(string tableName)
    {
        return tableName.ToLower() switch
        {
            "mov_transazioni" => "transazioni contabili",
            "ana_controparti" => "anagrafica controparti",
            "ana_viaggi" => "viaggi",
            "ana_date_viaggi" => "date di viaggio",
            "ana_clienti" => "anagrafica clienti",
            "ana_valute" => "valute",
            "ana_aliquote_iva" => "aliquote IVA",
            "ana_tipi_causali" => "causali contabili",
            "azienda_sede" => "sedi aziendali",
            "mov_clienti_viaggi" => "prenotazioni clienti",
            _ => tableName // Fallback al nome tecnico se non mappato
        };
    }
}
