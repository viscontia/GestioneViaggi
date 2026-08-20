using System.Text.Json;
using System.Text.Json.Nodes;
using GestioneViaggi.Models;

namespace GestioneViaggi.Repositories;

/// <summary>
/// Traduce un <see cref="Cliente"/> nel JSON che le funzioni DB si aspettano.
///
/// Le chiavi sono i <b>nomi esatti delle colonne</b>: è il contratto condiviso con
/// il sito di iscrizione, che costruisce lo stesso oggetto in Python. Non esiste
/// una tabella di corrispondenza da tenere allineata fra i due repository —
/// esistono i nomi delle colonne, che sono già la verità.
/// </summary>
internal static class ClienteJson
{
    /// <summary>
    /// Il cliente come lo vuole il database. Non include <c>cliente_sesso</c> (lo
    /// deriva il titolo) né <c>cliente_titolo</c> (colonna deprecata, la riempie il trigger).
    /// </summary>
    public static string Serializza(Cliente c, bool includiAzienda = true)
    {
        var o = new JsonObject
        {
            ["cliente_titolo_fk"] = c.TitoloFk,
            ["cliente_cognome"] = c.Cognome,
            ["cliente_nome"] = c.Nome,
            ["cliente_comune_residenza_fk"] = c.ComuneResidenzaFk,
            ["cliente_indirizzo_residenza"] = c.IndirizzoResidenza,
            ["cliente_comune_nascita_fk"] = c.ComuneNascitaFk,
            ["cliente_data_nascita"] = Data(c.DataNascita),
            ["cliente_preftelint"] = c.PrefTelInt,
            ["cliente_telefono"] = c.Telefono,
            ["cliente_email"] = c.Email,
            ["cliente_codicefiscale"] = c.CodiceFiscale,
            ["cliente_iban"] = c.Iban,
            ["cliente_tipodoc_identita"] = c.TipoDocIdentita,
            ["cliente_documento_numero"] = c.DocumentoNumero,
            ["cliente_documento_rilasciato_da"] = c.DocumentoRilasciatoDa,
            ["cliente_documento_rilasciato_data"] = Data(c.DocumentoRilasciatoData),
            ["cliente_documento_rilasciato_scadenza"] = Data(c.DocumentoRilasciatoScadenza),
            ["cliente_note"] = c.Note,
            ["cliente_intolleranza"] = c.Intolleranza,
            ["cliente_foto"] = Blob(c.Foto),
            ["cliente_carta_identita"] = Blob(c.CartaIdentita),
            ["cliente_foto_mimetype"] = c.FotoMimeType,
            ["cliente_foto_filename"] = c.FotoFilename,
            ["cliente_foto_charset"] = c.FotoCharset,
            ["cliente_foto_upd_date"] = Data(c.FotoUpdDate),
            ["cliente_documento_mimetype"] = c.DocumentoMimeType,
            ["cliente_documento_filename"] = c.DocumentoFilename,
            ["cliente_documento_chartset"] = c.DocumentoCharset,
            ["cliente_documento_upd_date"] = Data(c.DocumentoUpdDate),
            ["cliente_lingua"] = c.Lingua,
            // Il consenso viaggia con il cliente, non con una chiamata successiva:
            // va raccolto nel momento in cui l'anagrafica nasce, o non e' dimostrabile.
            ["consenso_marketing"] = c.Consenso,
            ["consenso_marketing_fonte"] = c.ConsensoFonte
        };

        if (includiAzienda)
            o["azienda_fk"] = c.AziendaFk;

        return o.ToJsonString(new JsonSerializerOptions { WriteIndented = false });
    }

    /// <summary>Solo la data, senza ora: le colonne sono DATE e un fuso orario le sposterebbe.</summary>
    private static string? Data(DateTime? d) => d?.ToString("yyyy-MM-dd");

    /// <summary>Foto e documento viaggiano in base64: JSON non ha un tipo binario.</summary>
    private static string? Blob(byte[]? b) => b is { Length: > 0 } ? Convert.ToBase64String(b) : null;
}
