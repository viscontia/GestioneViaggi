using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class AziendaSedeService : BaseCrudService<AziendaSede>
{
    protected override string TableName => "ana_aziende_sedi";
    protected override string IdColumnName => "sede_id";

    public AziendaSedeService(IDatabaseService databaseService, ILogger<AziendaSedeService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<AziendaSede> CreateAsync(AziendaSede entity)
    {
        // Normalizza stringhe nullable (converte "" in NULL)
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_aziende_sedi (
                    azienda_fk, tipo_sede_fk, indirizzo, numero_civico, comune_fk,
                    telefono, email, note, is_principale, coordinate_lat, coordinate_lng
                )
                VALUES (@aziendaFk, @tipoSedeFk, @indirizzo, @numeroCivico, @comuneFk,
                        @telefono, @email, @note, @isPrincipale, @coordinateLat, @coordinateLng)
                RETURNING sede_id, azienda_fk, tipo_sede_fk, indirizzo, numero_civico, comune_fk,
                          telefono, email, note, is_principale, coordinate_lat, coordinate_lng,
                          data_creazione, data_ultima_modifica";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaFk", entity.AziendaIdFk);
            command.Parameters.AddWithValue("tipoSedeFk", entity.TipoSedeIdFk);
            command.Parameters.AddWithValue("indirizzo", entity.Indirizzo);
            command.Parameters.AddWithValue("numeroCivico", (object?)entity.NumeroCivico ?? DBNull.Value);
            command.Parameters.AddWithValue("comuneFk", entity.ComuneIdFk);
            command.Parameters.AddWithValue("telefono", entity.Telefono);
            command.Parameters.AddWithValue("email", entity.Email);
            command.Parameters.AddWithValue("note", (object?)entity.Note ?? DBNull.Value);
            command.Parameters.AddWithValue("isPrincipale", entity.IsPrincipale);
            command.Parameters.AddWithValue("coordinateLat", entity.CoordinateLat);
            command.Parameters.AddWithValue("coordinateLng", entity.CoordinateLng);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare la sede");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della sede");
            throw;
        }
    }

    public override async Task<AziendaSede> UpdateAsync(AziendaSede entity)
    {
        // Normalizza stringhe nullable (converte "" in NULL)
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_aziende_sedi
                SET tipo_sede_fk = @tipoSedeFk,
                    indirizzo = @indirizzo,
                    numero_civico = @numeroCivico,
                    comune_fk = @comuneFk,
                    telefono = @telefono,
                    email = @email,
                    note = @note,
                    is_principale = @isPrincipale,
                    coordinate_lat = @coordinateLat,
                    coordinate_lng = @coordinateLng
                WHERE sede_id = @id
                RETURNING sede_id, azienda_fk, tipo_sede_fk, indirizzo, numero_civico, comune_fk,
                          telefono, email, note, is_principale, coordinate_lat, coordinate_lng,
                          data_creazione, data_ultima_modifica";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("tipoSedeFk", entity.TipoSedeIdFk);
            command.Parameters.AddWithValue("indirizzo", entity.Indirizzo);
            command.Parameters.AddWithValue("numeroCivico", (object?)entity.NumeroCivico ?? DBNull.Value);
            command.Parameters.AddWithValue("comuneFk", entity.ComuneIdFk);
            command.Parameters.AddWithValue("telefono", entity.Telefono);
            command.Parameters.AddWithValue("email", entity.Email);
            command.Parameters.AddWithValue("note", (object?)entity.Note ?? DBNull.Value);
            command.Parameters.AddWithValue("isPrincipale", entity.IsPrincipale);
            command.Parameters.AddWithValue("coordinateLat", entity.CoordinateLat);
            command.Parameters.AddWithValue("coordinateLng", entity.CoordinateLng);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Sede con ID {entity.Id} non trovata");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della sede");
            throw;
        }
    }

    protected override AziendaSede MapFromReader(NpgsqlDataReader reader)
    {
        return new AziendaSede
        {
            Id = ReadInt(reader, "sede_id"),
            AziendaIdFk = ReadInt(reader, "azienda_fk"),
            TipoSedeIdFk = ReadInt(reader, "tipo_sede_fk"),
            Indirizzo = reader.GetString(reader.GetOrdinal("indirizzo")),
            NumeroCivico = ReadNullableString(reader, "numero_civico"),
            ComuneIdFk = ReadInt(reader, "comune_fk"),
            Telefono = reader.GetString(reader.GetOrdinal("telefono")),
            Email = reader.GetString(reader.GetOrdinal("email")),
            Note = ReadNullableString(reader, "note"),
            IsPrincipale = reader.GetBoolean(reader.GetOrdinal("is_principale")),
            CoordinateLat = reader.GetDecimal(reader.GetOrdinal("coordinate_lat")),
            CoordinateLng = reader.GetDecimal(reader.GetOrdinal("coordinate_lng")),
            DataCreazione = reader.GetDateTime(reader.GetOrdinal("data_creazione")),
            DataUltimaModifica = ReadNullableDateTime(reader, "data_ultima_modifica")
        };
    }

    /// <summary>
    /// Ottiene tutte le sedi di una specifica azienda con JOIN per lookup
    /// </summary>
    public async Task<List<AziendaSede>> GetByAziendaIdAsync(int aziendaId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT
                    s.sede_id, s.azienda_fk, s.tipo_sede_fk, s.indirizzo, s.numero_civico, s.comune_fk,
                    s.telefono, s.email, s.note, s.is_principale, s.coordinate_lat, s.coordinate_lng,
                    s.data_creazione, s.data_ultima_modifica,
                    ts.descrizione as tipo_sede_descrizione,
                    c.comune_descrizione as comune_nome,
                    p.provincia_sigla as provincia_sigla
                FROM ana_aziende_sedi s
                INNER JOIN ana_tipo_sedi ts ON s.tipo_sede_fk = ts.tipo_sede_id
                INNER JOIN ana_geo_comuni c ON s.comune_fk = c.comune_id
                INNER JOIN ana_geo_province p ON c.comune_provincia_fk = p.provincia_id
                WHERE s.azienda_fk = @aziendaId
                ORDER BY s.is_principale DESC, ts.descrizione ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaId", aziendaId);
            await using var reader = await command.ExecuteReaderAsync();

            var sedi = new List<AziendaSede>();
            while (await reader.ReadAsync())
            {
                var sede = MapFromReader(reader);
                sede.TipoSedeDescrizione = ReadNullableString(reader, "tipo_sede_descrizione");
                sede.ComuneNome = ReadNullableString(reader, "comune_nome");
                sede.ProvinciaSigla = ReadNullableString(reader, "provincia_sigla");
                sedi.Add(sede);
            }

            return sedi;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento delle sedi per azienda {AziendaId}", aziendaId);
            throw;
        }
    }
}
