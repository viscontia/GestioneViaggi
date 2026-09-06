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
        // ⚠️ PRIMA di tradurre: il messaggio potrebbe essere GIA' scritto per l'operatore.
        //
        // Le nostre guardie (trigger e funzioni) sollevano `RAISE EXCEPTION` con un testo
        // pensato per chi legge — «le sistemazioni già assegnate su questo viaggio non
        // sarebbero più ammesse. Vanno cambiate prima» — e spesso con il conto di quante
        // righe sono coinvolte e su quali viaggi. Tradurlo in un generico «un valore non
        // rispetta le regole di validità» butta via l'unica cosa utile: cosa fare adesso.
        //
        // Si riconoscono dal fatto che NON portano il nome di un vincolo: PostgreSQL lo
        // valorizza sempre quando a fallire è un CHECK vero, mai su un RAISE nostro.
        // Provato il 2026-09-06: `RAISE EXCEPTION … USING ERRCODE='check_violation'`
        // arriva con ConstraintName vuoto.
        if (string.IsNullOrEmpty(ex.ConstraintName) && ScrittoDaNoi(ex.SqlState))
        {
            return new GestioneViaggiException(SenzaPrefissoTecnico(ex.MessageText), ex.SqlState, ex.TableName);
        }

        string message = "Si è verificato un errore imprevisto nel database.";
        // entityName è il nome tecnico della tabella: contestualizzalo sempre in italiano
        // (GetItalianPrefixFor si aspetta l'etichetta tradotta, non il nome grezzo).
        string label = entityName != null ? TranslateTableName(entityName) : "questo elemento";

        switch (ex.SqlState)
        {
            case "23503": // foreign_key_violation
                // Distingui tra DELETE (elemento usato altrove) e INSERT/UPDATE (riferimento non valido)
                bool isDeleteOperation = ex.Detail?.Contains("is still referenced from table") == true;

                if (isDeleteOperation)
                {
                    // DELETE: l'elemento è referenziato da altre tabelle
                    string relatedTable = ExtractTableNameFromDetail(ex.Detail);
                    string prefix = GetItalianPrefixFor(label);
                    message = $"Non è possibile eliminare {prefix}{label} perché è utilizzato in altre parti del sistema";
                    if (!string.IsNullOrEmpty(relatedTable))
                    {
                        message += $" (es. {TranslateTableName(relatedTable)})";
                    }
                    message += ".";
                }
                else
                {
                    // INSERT/UPDATE: riferimento a chiave esterna non valido
                    string constraintName = ExtractConstraintNameFromMessage(ex.MessageText);
                    string fieldName = ExtractFieldNameFromConstraint(constraintName);
                    string prefix = GetItalianPrefixFor(label);

                    if (!string.IsNullOrEmpty(fieldName))
                    {
                        message = $"Il valore selezionato per '{fieldName}' non è valido o non esiste più nel sistema.";
                    }
                    else
                    {
                        message = $"Uno dei valori selezionati per {prefix}{label} non è valido o non esiste più nel sistema.";
                    }
                }
                break;

            case "23505": // unique_violation
                // Messaggio specifico per constraint noti (dice ALL'utente quale campo è duplicato);
                // altrimenti fallback generico contestualizzato sull'elemento.
                string duplicateMsg = DescribeUniqueConstraint(ex.ConstraintName);
                message = !string.IsNullOrEmpty(duplicateMsg)
                    ? duplicateMsg
                    : $"Esiste già un record per {GetItalianPrefixFor(label)}{label}. Non sono ammessi duplicati.";
                break;

            case "23502": // not_null_violation
                message = $"Uno o più campi obbligatori per {GetItalianPrefixFor(label)}{label} non sono stati compilati.";
                break;

            case "22001": // string_data_right_truncation
                message = "Uno dei testi inseriti supera la lunghezza massima consentita. Riduci il testo e riprova.";
                break;

            case "23514": // check_violation
                string checkMsg = DescribeCheckConstraint(ex.ConstraintName);
                message = !string.IsNullOrEmpty(checkMsg)
                    ? checkMsg
                    : $"Un valore inserito per {GetItalianPrefixFor(label)}{label} non rispetta le regole di validità.";
                break;

            default:
                message = $"Errore database ({ex.SqlState}): {ex.MessageText}";
                break;
        }

        return new GestioneViaggiException(message, ex.SqlState, ex.TableName) { };
    }

    /// <summary>
    /// Toglie il codice tecnico che alcune guardie premettono al messaggio
    /// (<c>NOT_FOUND: Causale con ID 5 non trovata</c> → <c>Causale con ID 5 non trovata</c>).
    /// Serve solo per chi legge: quei prefissi erano per chi programma.
    /// </summary>
    private static string SenzaPrefissoTecnico(string messaggio)
    {
        var match = Regex.Match(messaggio, @"^[A-Z][A-Z0-9_]{2,}:\s*(?<testo>.+)$", RegexOptions.Singleline);
        return match.Success ? match.Groups["testo"].Value : messaggio;
    }

    /// <summary>
    /// I codici che una nostra guardia può sollevare deliberatamente.
    ///
    /// <c>P0001</c> è il codice di un <c>RAISE EXCEPTION</c> senza <c>ERRCODE</c>: PostgreSQL
    /// non lo usa mai per conto suo, quindi il messaggio è per forza nostro.
    /// <c>23514</c> lo usiamo di proposito dove il rifiuto È una regola di validità — ma lì
    /// serve il controllo sul nome del vincolo, perché un CHECK vero usa lo stesso codice.
    /// </summary>
    private static bool ScrittoDaNoi(string sqlState) =>
        sqlState is "P0001" or "23514";

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

    private static string ExtractConstraintNameFromMessage(string? message)
    {
        if (string.IsNullOrEmpty(message)) return string.Empty;

        // Esempio: insert or update on table "ana_aziende" violates foreign key constraint "ana_aziende_regime_fiscale_fk_fkey"
        var match = Regex.Match(message, "constraint \"([^\"]+)\"", RegexOptions.IgnoreCase);
        if (match.Success)
        {
            return match.Groups[1].Value;
        }

        return string.Empty;
    }

    private static string ExtractFieldNameFromConstraint(string constraintName)
    {
        if (string.IsNullOrEmpty(constraintName)) return string.Empty;

        // Mapping dei constraint comuni ai nomi user-friendly
        var fieldMappings = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "regime_fiscale_fk", "Regime Fiscale" },
            { "rea_provincia_fk", "Provincia REA" },
            { "azienda_fk", "Azienda" },
            { "causale_fk", "Causale" },
            { "valuta_fk", "Valuta" },
            { "aliquota_iva_fk", "Aliquota IVA" },
            { "paese_fk", "Paese" },
            { "provincia_fk", "Provincia" },
            { "comune_fk", "Comune" },
            { "reparto_fk", "Reparto" }
        };

        // Prova a trovare un match nel nome del constraint
        foreach (var mapping in fieldMappings)
        {
            if (constraintName.Contains(mapping.Key, StringComparison.OrdinalIgnoreCase))
            {
                return mapping.Value;
            }
        }

        return string.Empty;
    }

    /// <summary>
    /// Messaggio user-friendly per unique constraint noti, così l'utente sa QUALE campo è
    /// duplicato (es. lo slug) invece del generico "esiste già un record". Vuoto se sconosciuto.
    /// </summary>
    private static string DescribeUniqueConstraint(string? constraintName)
    {
        if (string.IsNullOrEmpty(constraintName)) return string.Empty;

        var uniqueMessages = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "uq_web_tour_contenuti_slug", "Esiste già un tour con questo indirizzo web. Scegline uno diverso." },
            { "web_tour_contenuti_viaggio_id_fk_key", "Questo viaggio ha già una scheda di contenuti web." },
            { "uq_web_tipi_viaggio_descrizioni_ordine", "Esiste già una descrizione web con questo ordine. Scegline uno diverso." },
            { "uq_web_tipi_viaggio_descrizioni_slug", "Esiste già una descrizione web con questo slug. Scegline uno diverso." },
            { "uq_web_tour_mappa_giornata", "Questa giornata ha già una mappa. Elimina quella esistente prima di caricarne un'altra." },
            { "uq_web_tour_mappa_insieme", "Questa edizione ha già una mappa dell'intero viaggio. Elimina quella esistente prima di caricarne un'altra." },
            { "uq_web_tour_mappa_gpx_dedup", "Questo file GPX è già stato caricato per questa edizione (stesso nome e stessa dimensione)." },
            { "uq_web_newsletter_soppressioni_email", "Questo indirizzo è già soppresso per questa azienda." },
            { "uq_web_indirizzi_descrizione", "Esiste già un indirizzo web con questo nome. Scegline uno diverso: il nome serve a riconoscerlo nell'elenco." }
        };

        foreach (var mapping in uniqueMessages)
        {
            if (constraintName.Contains(mapping.Key, StringComparison.OrdinalIgnoreCase))
            {
                return mapping.Value;
            }
        }

        return string.Empty;
    }

    /// <summary>Messaggio user-friendly per CHECK constraint noti. Vuoto se sconosciuto.</summary>
    private static string DescribeCheckConstraint(string? constraintName)
    {
        if (string.IsNullOrEmpty(constraintName)) return string.Empty;

        var checkMessages = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "ck_web_tipi_viaggio_descrizioni_descrizione_min", "La descrizione deve avere almeno 3 caratteri." },
            { "ck_web_tipi_viaggio_descrizioni_ordine_min", "L'ordine deve essere almeno 1." },
            { "ck_web_tour_mappa_descrizione_insieme", "La mappa dell'intero viaggio richiede una descrizione." },
            { "chk_web_indirizzi_url", "L'indirizzo deve iniziare con https:// (o http://). Copialo dalla barra del browser." },
            { "chk_web_indirizzi_descrizione", "Il nome dell'indirizzo deve avere almeno 2 caratteri." },

            // Invarianti di ana_clienti scesi nel DB (SqlScripts/541): valgono per il gestionale
            // e per il sito di iscrizione, quindi il messaggio deve essere leggibile in entrambi.
            { "ana_clienti_email_formato_check", "L'indirizzo email non è scritto in modo valido." },
            { "ana_clienti_cognome_minimo_check", "Il cognome deve avere almeno 2 caratteri." },
            { "ana_clienti_nome_minimo_check", "Il nome deve avere almeno 2 caratteri." },
            { "ana_clienti_rilascio_dopo_nascita_check", "La data di rilascio del documento è precedente alla data di nascita." },
            { "ana_clienti_scadenza_dopo_rilascio_check", "Il documento risulta scadere prima di essere stato rilasciato." },
            { "ana_clienti_iban_formato_check", "L'IBAN non è valido: servono da 15 a 34 caratteri e due lettere di paese iniziali." },
            { "ana_clienti_cliente_sesso_check", "Il sesso può essere solo M o F." },
            { "ana_clienti_telefono_caratteri_check", "Il telefono può contenere solo cifre, spazi e i simboli + ( ) - . /" },
            { "ana_clienti_codicefiscale_lunghezza_check", "Il codice fiscale deve essere di 16 caratteri." },
            { "ana_clienti_indirizzo_minimo_check", "L'indirizzo di residenza deve avere almeno 5 caratteri." }
        };

        foreach (var mapping in checkMessages)
        {
            if (constraintName.Contains(mapping.Key, StringComparison.OrdinalIgnoreCase))
            {
                return mapping.Value;
            }
        }

        return string.Empty;
    }

    private static string TranslateTableName(string tableName)
    {
        return tableName.ToLower() switch
        {
            "mov_transazioni" => "transazione",
            "ana_controparti" => "controparte",
            "ana_viaggi" => "viaggio",
            "ana_date_viaggi" => "data di viaggio",
            "ana_clienti" => "anagrafica cliente",
            "ana_valute" => "valuta",
            "ana_aliquote_iva" => "aliquota IVA",
            "ana_tipi_causali" => "causale contabile",
            "ana_aziende" => "azienda",
            "ana_regimi_fiscali" => "regime fiscale",
            "azienda_sede" => "sede aziendale",
            "mov_clienti_viaggi" => "prenotazione cliente",
            "web_tour_contenuti" => "scheda contenuti web del tour",
            "web_tipi_viaggio_descrizioni" => "descrizione web del tipo di viaggio",
            "web_tour_itinerario" => "giornata dell'itinerario",
            "web_tour_mappa" => "mappa del percorso",
            _ => tableName // Fallback al nome tecnico se non mappato
        };
    }

    private static string GetItalianPrefixFor(string label)
    {
        string l = label.ToLower().Trim();
        
        // Se ha già un articolo, non aggiungerne un altro
        if (l.StartsWith("la ") || l.StartsWith("il ") || l.StartsWith("l'"))
            return "";

        if (l.StartsWith("a") || l.StartsWith("e") || l.StartsWith("i") || l.StartsWith("o") || l.StartsWith("u"))
            return "l'";
        
        if (l.StartsWith("transazione") || l.StartsWith("causale") || l.StartsWith("controparte") || l.StartsWith("valuta") || l.StartsWith("data") || l.StartsWith("prenotazione") || l.StartsWith("sede") || l.StartsWith("aliquota") || l.StartsWith("anagrafica") || l.StartsWith("scheda"))
            return "la ";
            
        if (l.StartsWith("viaggio") || l.StartsWith("regime"))
            return "il ";

        return ""; // Fallback
    }
}
