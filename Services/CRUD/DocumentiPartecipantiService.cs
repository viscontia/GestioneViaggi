using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;
using NpgsqlTypes;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Chi, fra i partecipanti di una partenza, ha un documento che non arriva valido alla
/// fine del viaggio.
///
/// È l'unica porta verso <c>fn_partecipanti_documento_non_valido</c> (SqlScripts/575), e la
/// regola non sta qui: sta nel database, dov'è raggiungibile anche dal sito di iscrizione.
/// Qui c'è solo il modo di chiederla.
///
/// Serve a tre punti diversi del gestionale — la lista dei partecipanti, l'avviso prima
/// delle stampe di partenza, e la nota in fondo a quelle stampe — perché il problema si
/// vede in momenti diversi: ci si iscrive mesi prima, e un documento valido allora può
/// non esserlo più al momento di partire.
/// </summary>
public class DocumentiPartecipantiService
{
    private readonly IDatabaseService _databaseService;
    private readonly ILogger<DocumentiPartecipantiService> _logger;

    public DocumentiPartecipantiService(IDatabaseService databaseService,
                                        ILogger<DocumentiPartecipantiService> logger)
    {
        _databaseService = databaseService;
        _logger = logger;
    }

    /// <summary>
    /// I partecipanti da sistemare per quella partenza. Lista vuota = tutti a posto.
    /// </summary>
    public async Task<List<DocumentoNonValido>> DaSistemareAsync(int dataViaggioId)
    {
        var esito = new List<DocumentoNonValido>();
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand(
                "SELECT * FROM fn_partecipanti_documento_non_valido(@dataViaggio)", connection);
            command.Parameters.Add(new NpgsqlParameter("dataViaggio", NpgsqlDbType.Integer)
            {
                Value = dataViaggioId
            });

            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                esito.Add(new DocumentoNonValido
                {
                    ClienteId = reader.GetInt32(reader.GetOrdinal("cliente_id")),
                    Cognome = reader.GetString(reader.GetOrdinal("cognome")),
                    Nome = reader.GetString(reader.GetOrdinal("nome")),
                    Email = Leggi(reader, "email"),
                    Prefisso = Leggi(reader, "prefisso"),
                    Telefono = Leggi(reader, "telefono"),
                    DocumentoScadenza = LeggiData(reader, "documento_scadenza"),
                    Stato = reader.GetString(reader.GetOrdinal("stato")),
                    ViaggioEstero = reader.GetBoolean(reader.GetOrdinal("viaggio_estero")),
                    Messaggio = reader.GetString(reader.GetOrdinal("messaggio"))
                });
            }
        }
        catch (Exception ex)
        {
            // Un controllo che non riesce non deve impedire di stampare: si registra e si
            // prosegue. Meglio una rooming list senza avviso che nessuna rooming list.
            _logger.LogError(ex, "Controllo documenti non riuscito per la partenza {DataViaggioId}", dataViaggioId);
        }
        return esito;
    }

    private static string? Leggi(NpgsqlDataReader reader, string colonna)
    {
        var i = reader.GetOrdinal(colonna);
        return reader.IsDBNull(i) ? null : reader.GetString(i);
    }

    private static DateTime? LeggiData(NpgsqlDataReader reader, string colonna)
    {
        var i = reader.GetOrdinal(colonna);
        return reader.IsDBNull(i) ? null : reader.GetDateTime(i);
    }
}
