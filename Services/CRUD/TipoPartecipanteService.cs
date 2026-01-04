using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class TipoPartecipanteService : BaseCrudService<TipoPartecipante>
{
    protected override string TableName => "ANA_TIPO_PARTECIPANTE";
    protected override string IdColumnName => "TIPO_PARTECIPANTE_ID";

    public TipoPartecipanteService(IDatabaseService databaseService, ILogger<TipoPartecipanteService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<TipoPartecipante> CreateAsync(TipoPartecipante entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ANA_TIPO_PARTECIPANTE (
                    TIPO_PARTECIPANTE_DESCRIZIONE,
                    TIPO_PARTECIPANTE_DATI_MEZZO_OBB,
                    TIPO_PARTECIPANTE_PILOTA
                )
                VALUES (@descrizione, @datiMezzoObb, @pilota)
                RETURNING TIPO_PARTECIPANTE_ID, TIPO_PARTECIPANTE_DESCRIZIONE, TIPO_PARTECIPANTE_DATI_MEZZO_OBB, TIPO_PARTECIPANTE_PILOTA";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("datiMezzoObb", entity.DatiMezzoObbligatori ? "Y" : "N");
            command.Parameters.AddWithValue("pilota", entity.Pilota);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il tipo partecipante");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del tipo partecipante");
            throw;
        }
    }

    public override async Task<TipoPartecipante> UpdateAsync(TipoPartecipante entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ANA_TIPO_PARTECIPANTE
                SET TIPO_PARTECIPANTE_DESCRIZIONE = @descrizione,
                    TIPO_PARTECIPANTE_DATI_MEZZO_OBB = @datiMezzoObb,
                    TIPO_PARTECIPANTE_PILOTA = @pilota
                WHERE TIPO_PARTECIPANTE_ID = @id
                RETURNING TIPO_PARTECIPANTE_ID, TIPO_PARTECIPANTE_DESCRIZIONE, TIPO_PARTECIPANTE_DATI_MEZZO_OBB, TIPO_PARTECIPANTE_PILOTA";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("datiMezzoObb", entity.DatiMezzoObbligatori ? "Y" : "N");
            command.Parameters.AddWithValue("pilota", entity.Pilota);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Tipo partecipante con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del tipo partecipante");
            throw;
        }
    }

    protected override TipoPartecipante MapFromReader(NpgsqlDataReader reader)
    {
        return new TipoPartecipante
        {
            Id = ReadInt(reader, "TIPO_PARTECIPANTE_ID"),
            Descrizione = reader.GetString(reader.GetOrdinal("TIPO_PARTECIPANTE_DESCRIZIONE")),
            DatiMezzoObbligatori = reader.GetString(reader.GetOrdinal("TIPO_PARTECIPANTE_DATI_MEZZO_OBB")) == "Y",
            Pilota = reader.GetBoolean(reader.GetOrdinal("TIPO_PARTECIPANTE_PILOTA"))
        };
    }
}
