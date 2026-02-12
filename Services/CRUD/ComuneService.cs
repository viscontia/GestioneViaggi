using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class ComuneService : BaseCrudService<Comune>
{
    protected override string TableName => "ana_geo_comuni";
    protected override string IdColumnName => "comune_id";

    public ComuneService(IDatabaseService databaseService, ILogger<ComuneService> logger)
        : base(databaseService, logger)
    {
    }

    /// <summary>
    /// Override di GetAllAsync per includere JOIN con province, ripartizioni geografiche e capoluoghi
    /// </summary>
    public override async Task<List<Comune>> GetAllAsync()
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT
                    c.comune_id,
                    c.comune_descrizione,
                    c.comune_istat,
                    c.comune_preftel,
                    c.comune_cap,
                    c.comune_codfisc,
                    c.comune_num_abitanti,
                    c.comune_link,
                    c.comune_estero,
                    c.comune_provincia_fk,
                    c.comune_ripgeo_fk,
                    c.comune_capoluogo_fk,
                    p.provincia_descrizione,
                    p.provincia_sigla,
                    r.ripgeo_descrizione,
                    reg.regione_descrizione,
                    cap.capoluogo_descrizione
                FROM ana_geo_comuni c
                LEFT JOIN ana_geo_province p ON c.comune_provincia_fk = p.provincia_id
                LEFT JOIN ana_geo_regioni_ita reg ON p.regione_id_fk = reg.regione_id
                LEFT JOIN ana_geo_ita_ripgeo r ON c.comune_ripgeo_fk = r.ripgeo_id
                LEFT JOIN ana_geo_capoluogo cap ON c.comune_capoluogo_fk = cap.capoluogo_id
                ORDER BY c.comune_descrizione ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var comuni = new List<Comune>();
            while (await reader.ReadAsync())
            {
                comuni.Add(MapFromReaderWithJoins(reader));
            }

            return comuni;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento dei comuni");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Override di GetByIdAsync per includere i JOIN (necessari per la visualizzazione dettagliata)
    /// </summary>
    public override async Task<Comune?> GetByIdAsync(int id)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            // Stessa query di GetAll ma filtrata per ID, senza ORDER BY
            var sql = @"
                SELECT
                    c.comune_id,
                    c.comune_descrizione,
                    c.comune_istat,
                    c.comune_preftel,
                    c.comune_cap,
                    c.comune_codfisc,
                    c.comune_num_abitanti,
                    c.comune_link,
                    c.comune_estero,
                    c.comune_provincia_fk,
                    c.comune_ripgeo_fk,
                    c.comune_capoluogo_fk,
                    p.provincia_descrizione,
                    p.provincia_sigla,
                    r.ripgeo_descrizione,
                    reg.regione_descrizione,
                    cap.capoluogo_descrizione
                FROM ana_geo_comuni c
                LEFT JOIN ana_geo_province p ON c.comune_provincia_fk = p.provincia_id
                LEFT JOIN ana_geo_regioni_ita reg ON p.regione_id_fk = reg.regione_id
                LEFT JOIN ana_geo_ita_ripgeo r ON c.comune_ripgeo_fk = r.ripgeo_id
                LEFT JOIN ana_geo_capoluogo cap ON c.comune_capoluogo_fk = cap.capoluogo_id
                WHERE c.comune_id = @id";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", id);
            
            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReaderWithJoins(reader);
            }

            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero del comune {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<Comune> CreateAsync(Comune entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_geo_comuni (
                    comune_descrizione,
                    comune_istat,
                    comune_preftel,
                    comune_cap,
                    comune_codfisc,
                    comune_num_abitanti,
                    comune_link,
                    comune_estero,
                    comune_provincia_fk,
                    comune_ripgeo_fk,
                    comune_capoluogo_fk
                )
                VALUES (@nome, @codIstat, @prefTel, @cap, @codFiscale, @numAbitanti, @link, @comuneEstero, @provinciaFk, @ripGeoFk, @capoluogoFk)
                RETURNING comune_id, comune_descrizione, comune_istat, comune_preftel, comune_cap, comune_codfisc, comune_num_abitanti, comune_link, comune_estero, comune_provincia_fk, comune_ripgeo_fk, comune_capoluogo_fk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("nome", entity.Nome);
            command.Parameters.AddWithValue("codIstat", (object?)entity.CodIstat ?? DBNull.Value);
            command.Parameters.AddWithValue("prefTel", (object?)entity.PrefTel ?? DBNull.Value);
            command.Parameters.AddWithValue("cap", (object?)entity.Cap ?? DBNull.Value);
            command.Parameters.AddWithValue("codFiscale", (object?)entity.CodFiscale ?? DBNull.Value);
            command.Parameters.AddWithValue("numAbitanti", (object?)entity.NumAbitanti ?? 0);
            command.Parameters.AddWithValue("link", (object?)entity.Link ?? DBNull.Value);
            command.Parameters.AddWithValue("comuneEstero", entity.ComuneEstero ? "Y" : "N");
            command.Parameters.AddWithValue("provinciaFk", (object?)entity.ProvinciaIdFk ?? DBNull.Value);
            command.Parameters.AddWithValue("ripGeoFk", (object?)entity.RipGeoIdFk ?? DBNull.Value);
            command.Parameters.AddWithValue("capoluogoFk", (object?)entity.CapoluogoIdFk ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare il comune");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del comune {Nome}", entity.Nome);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<Comune> UpdateAsync(Comune entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_geo_comuni
                SET comune_descrizione = @nome,
                    comune_istat = @codIstat,
                    comune_preftel = @prefTel,
                    comune_cap = @cap,
                    comune_codfisc = @codFiscale,
                    comune_num_abitanti = @numAbitanti,
                    comune_link = @link,
                    comune_estero = @comuneEstero,
                    comune_provincia_fk = @provinciaFk,
                    comune_ripgeo_fk = @ripGeoFk,
                    comune_capoluogo_fk = @capoluogoFk
                WHERE comune_id = @id
                RETURNING comune_id, comune_descrizione, comune_istat, comune_preftel, comune_cap, comune_codfisc, comune_num_abitanti, comune_link, comune_estero, comune_provincia_fk, comune_ripgeo_fk, comune_capoluogo_fk";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("nome", entity.Nome);
            command.Parameters.AddWithValue("codIstat", (object?)entity.CodIstat ?? DBNull.Value);
            command.Parameters.AddWithValue("prefTel", (object?)entity.PrefTel ?? DBNull.Value);
            command.Parameters.AddWithValue("cap", (object?)entity.Cap ?? DBNull.Value);
            command.Parameters.AddWithValue("codFiscale", (object?)entity.CodFiscale ?? DBNull.Value);
            command.Parameters.AddWithValue("numAbitanti", (object?)entity.NumAbitanti ?? 0);
            command.Parameters.AddWithValue("link", (object?)entity.Link ?? DBNull.Value);
            command.Parameters.AddWithValue("comuneEstero", entity.ComuneEstero ? "Y" : "N");
            command.Parameters.AddWithValue("provinciaFk", (object?)entity.ProvinciaIdFk ?? DBNull.Value);
            command.Parameters.AddWithValue("ripGeoFk", (object?)entity.RipGeoIdFk ?? DBNull.Value);
            command.Parameters.AddWithValue("capoluogoFk", (object?)entity.CapoluogoIdFk ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Comune con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del comune");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    protected override Comune MapFromReader(NpgsqlDataReader reader)
    {
        return new Comune
        {
            Id = ReadInt(reader, "comune_id"),
            Nome = reader.GetString(reader.GetOrdinal("comune_descrizione")),
            CodIstat = ReadNullableString(reader, "comune_istat"),
            PrefTel = ReadNullableString(reader, "comune_preftel"),
            Cap = ReadNullableString(reader, "comune_cap"),
            CodFiscale = ReadNullableString(reader, "comune_codfisc"),
            NumAbitanti = ReadNullableInt(reader, "comune_num_abitanti"),
            Link = ReadNullableString(reader, "comune_link"),
            ComuneEstero = ReadBooleanFromChar(reader, "comune_estero"),
            ProvinciaIdFk = ReadNullableInt(reader, "comune_provincia_fk"),
            RipGeoIdFk = ReadNullableInt(reader, "comune_ripgeo_fk"),
            CapoluogoIdFk = ReadNullableInt(reader, "comune_capoluogo_fk")
        };
    }

    /// <summary>
    /// Mapper specifico per query con JOIN che include le descrizioni delle FK
    /// </summary>
    private Comune MapFromReaderWithJoins(NpgsqlDataReader reader)
    {
        var comune = MapFromReader(reader);
        comune.ProvinciaDescrizione = ReadNullableString(reader, "provincia_descrizione");
        comune.ProvinciaSigla = ReadNullableString(reader, "provincia_sigla");
        comune.RipGeoDescrizione = ReadNullableString(reader, "ripgeo_descrizione");
        comune.RegioneDescrizione = ReadNullableString(reader, "regione_descrizione");
        comune.CapoluogoDescrizione = ReadNullableString(reader, "capoluogo_descrizione");
        return comune;
    }

    /// <summary>
    /// Helper per leggere un campo char(1) 'Y'/'N' come boolean
    /// </summary>
    private bool ReadBooleanFromChar(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        if (reader.IsDBNull(ordinal))
            return false;

        var value = reader.GetString(ordinal);
        return value.Equals("Y", StringComparison.OrdinalIgnoreCase);
    }
}
