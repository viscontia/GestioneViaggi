using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Service DB-First per i titoli di cortesia (ana_titolo_persone). Tabella GLOBALE,
/// nessun azienda_id: lo sono tutte le lookup del progetto. Delega a fn_ana_titolo_persone_*.
/// </summary>
public class AnaTitoloPersoneService : BaseCrudService<AnaTitoloPersone>
{
    protected override string TableName => "ana_titolo_persone";
    protected override string IdColumnName => "titolo_persone_cod";

    public AnaTitoloPersoneService(IDatabaseService databaseService, ILogger<AnaTitoloPersoneService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<List<AnaTitoloPersone>> GetAllAsync()
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_ana_titolo_persone_list()", conn);

            var results = new List<AnaTitoloPersone>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
                results.Add(MapFromReader(reader));
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero dei titoli persona");
            return new List<AnaTitoloPersone>();
        }
    }

    public override async Task<AnaTitoloPersone?> GetByIdAsync(int id)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT * FROM fn_ana_titolo_persone_get(@Cod::integer)", conn);
            cmd.Parameters.AddWithValue("Cod", id);

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel recupero del titolo {Cod}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<AnaTitoloPersone> CreateAsync(AnaTitoloPersone entity)
    {
        Normalizza(entity);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_ana_titolo_persone_insert(@Descrizione::varchar, @Sesso::char)", conn);
            cmd.Parameters.AddWithValue("Descrizione", entity.Descrizione);
            cmd.Parameters.AddWithValue("Sesso", entity.Sesso.ToString());

            entity.Id = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Titolo persona creato con codice {Cod} ({Descr})", entity.Id, entity.Descrizione);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del titolo {Descr}", entity.Descrizione);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<AnaTitoloPersone> UpdateAsync(AnaTitoloPersone entity)
    {
        Normalizza(entity);
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT fn_ana_titolo_persone_update(@Cod::integer, @Descrizione::varchar, @Sesso::char)", conn);
            cmd.Parameters.AddWithValue("Cod", entity.Id);
            cmd.Parameters.AddWithValue("Descrizione", entity.Descrizione);
            cmd.Parameters.AddWithValue("Sesso", entity.Sesso.ToString());

            var righe = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            if (righe == 0)
                throw new InvalidOperationException($"Titolo {entity.Id} non trovato.");

            _logger.LogInformation("Titolo persona {Cod} aggiornato", entity.Id);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del titolo {Cod}", entity.Id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Quanti clienti portano questo titolo. Serve ad avvisare PRIMA di chiedere conferma
    /// dell'eliminazione: il rifiuto della function resta comunque la guardia autoritativa.
    /// </summary>
    public async Task<int> ContaClientiAsync(int id)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_ana_titolo_persone_conta_clienti(@Cod::integer)", conn);
            cmd.Parameters.AddWithValue("Cod", id);
            return Convert.ToInt32(await cmd.ExecuteScalarAsync());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nel conteggio clienti per il titolo {Cod}", id);
            // In dubbio non blocco: sara' il DB a rifiutare, con il suo messaggio.
            return 0;
        }
    }

    /// <summary>Elimina un titolo. La function rifiuta se ci sono clienti che lo portano.</summary>
    public override async Task<bool> DeleteAsync(int id)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT fn_ana_titolo_persone_delete(@Cod::integer)", conn);
            cmd.Parameters.AddWithValue("Cod", id);

            var righe = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            _logger.LogInformation("Titolo persona {Cod} eliminato ({Righe} righe)", id, righe);
            return righe > 0;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione del titolo {Cod}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>Maiuscolo forzato: regola UI del progetto per i campi alfanumerici (overview.md §3.3.2).</summary>
    private static void Normalizza(AnaTitoloPersone e)
    {
        e.Descrizione = e.Descrizione?.Trim().ToUpperInvariant() ?? string.Empty;
        e.Sesso = char.ToUpperInvariant(e.Sesso);
    }

    protected override AnaTitoloPersone MapFromReader(NpgsqlDataReader reader)
    {
        return new AnaTitoloPersone
        {
            Id = reader.GetInt32(reader.GetOrdinal("titolo_persone_cod")),
            Descrizione = reader.GetString(reader.GetOrdinal("titolo_persone_descrizione")),
            Sesso = reader.GetString(reader.GetOrdinal("titolo_persone_sesso"))[0]
        };
    }
}
