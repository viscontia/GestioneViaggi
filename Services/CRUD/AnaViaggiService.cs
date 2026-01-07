using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class AnaViaggiService : BaseCrudService<AnaViaggi>
{
    protected override string TableName => "ana_viaggi";
    protected override string IdColumnName => "viaggio_id";

    public AnaViaggiService(IDatabaseService databaseService, ILogger<AnaViaggiService> logger)
        : base(databaseService, logger)
    {
    }

    public override async Task<List<AnaViaggi>> GetAllAsync()
    {
        // Override to include JOINs for descriptions
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT v.*,
                       c.name as nazione_nome,
                       t.tipo_viaggi_descrizione,
                       tr.tipo_trattamento_descrizione,
                       p.ana_tipo_pernottamento_descrizione,
                       a.tipo_avvicinamento_descrizione,
                       az.ragione_sociale as azienda_nome
                FROM ana_viaggi v
                LEFT JOIN eba_countries c ON v.viaggio_nazione_fk = c.country_id
                LEFT JOIN ana_tipo_viaggi t ON v.viaggio_tipo_viaggio_fk = t.tipo_viaggi_id
                LEFT JOIN ana_tipo_trattamento tr ON v.viaggio_tipo_trattamento_fk = tr.tipo_trattamento_id
                LEFT JOIN ana_tipo_pernottamento p ON v.viaggio_tipo_pernottamento_fk = p.ana_tipo_pernottamento_id
                LEFT JOIN ana_tipo_avvicinamento a ON v.viaggio_tipo_avvicinamento_fk = a.tipo_avvicinamento_id
                LEFT JOIN ana_aziende az ON v.azienda_id = az.azienda_id
                ORDER BY c.name, t.tipo_viaggi_descrizione, v.viaggio_descrizione_breve";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var list = new List<AnaViaggi>();
            while (await reader.ReadAsync())
            {
                list.Add(MapFromReader(reader));
            }
            return list;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore recupero lista viaggi");
            throw;
        }
    }

    public override async Task<AnaViaggi> CreateAsync(AnaViaggi entity)
    {
        return await CreateAsyncInternal(entity, true);
    }

    private async Task<AnaViaggi> CreateAsyncInternal(AnaViaggi entity, bool allowRetry)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_viaggi (
                    viaggio_descrizione_breve, viaggio_descrizione_estesa,
                    viaggio_numero_giorni, viaggio_numero_notti,
                    viaggio_pasti_al_sacco, viaggio_num_km,
                    viaggio_tipo_avvicinamento_fk,
                    viaggio_note, viaggio_link,
                    viaggio_nazione_fk, viaggio_tipo_viaggio_fk,
                    viaggio_tipo_trattamento_fk, viaggio_tipo_pernottamento_fk,
                    azienda_id,
                    created_by, created, updated_by, updated
                ) VALUES (
                    @descBreve, @descEstesa,
                    @giorni, @notti,
                    @pasti, @km,
                    @avvicinamento,
                    @note, @link,
                    @nazione, @tipo,
                    @trattamento, @pernottamento,
                    @aziendaId,
                    @createdBy, @created, @updatedBy, @updated
                )
                RETURNING viaggio_id";

            await using var command = new NpgsqlCommand(sql, connection);

            AddParameters(command, entity);

            entity.Id = (int)(await command.ExecuteScalarAsync() ?? 0);
            return entity;
        }
        catch (PostgresException ex) when (allowRetry && ex.SqlState == "42P01" && ex.Message.Contains("ana_viaggi_seq"))
        {
            _logger.LogWarning(ex, "Sequence ana_viaggi_seq mancante. Tentativo fix.");
            await FixSequenceAsync();
            return await CreateAsyncInternal(entity, false);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore creazione viaggio");
            throw;
        }
    }

    public override async Task<AnaViaggi> UpdateAsync(AnaViaggi entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_viaggi SET
                    viaggio_descrizione_breve = @descBreve,
                    viaggio_descrizione_estesa = @descEstesa,
                    viaggio_numero_giorni = @giorni,
                    viaggio_numero_notti = @notti,
                    viaggio_pasti_al_sacco = @pasti,
                    viaggio_num_km = @km,
                    viaggio_tipo_avvicinamento_fk = @avvicinamento,
                    viaggio_note = @note,
                    viaggio_link = @link,
                    viaggio_nazione_fk = @nazione,
                    viaggio_tipo_viaggio_fk = @tipo,
                    viaggio_tipo_trattamento_fk = @trattamento,
                    viaggio_tipo_pernottamento_fk = @pernottamento,
                    azienda_id = @aziendaId,
                    updated_by = @updatedBy,
                    updated = @updated
                WHERE viaggio_id = @id";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            AddParameters(command, entity);

            await command.ExecuteNonQueryAsync();
            return entity;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore aggiornamento viaggio {Id}", entity.Id);
            throw;
        }
    }

    private void AddParameters(NpgsqlCommand command, AnaViaggi entity)
    {
        command.Parameters.AddWithValue("descBreve", entity.DescrizioneBreve.ToUpper()); // Uppercase enforced
        command.Parameters.AddWithValue("descEstesa", entity.DescrizioneEstesa.ToUpper()); // Uppercase enforced
        command.Parameters.AddWithValue("giorni", entity.NumeroGiorni);
        command.Parameters.AddWithValue("notti", entity.NumeroNotti);
        command.Parameters.AddWithValue("pasti", entity.PastiAlSacco);
        command.Parameters.AddWithValue("km", entity.Km);
        command.Parameters.AddWithValue("avvicinamento", entity.TipoAvvicinamentoIdFk);
        command.Parameters.AddWithValue("note", (object?)entity.Note?.ToUpper() ?? DBNull.Value); // Uppercase enforced
        command.Parameters.AddWithValue("link", (object?)entity.Link ?? DBNull.Value);

        command.Parameters.AddWithValue("nazione", entity.NazioneIdFk);
        command.Parameters.AddWithValue("tipo", entity.TipoViaggioIdFk);
        command.Parameters.AddWithValue("trattamento", entity.TipoTrattamentoIdFk);
        command.Parameters.AddWithValue("pernottamento", entity.TipoPernottamentoIdFk);

        command.Parameters.AddWithValue("aziendaId", entity.AziendaId);

        // Audit handled by caller or defaults? 
        // Typically service shouldn't override Audit triggers if they exist, 
        // BUT logic often passes user.
        // If DB has triggers, we might pass NULL to let them work, or pass explicit values.
        // Assuming current pattern where we pass them:
        command.Parameters.AddWithValue("createdBy", (object?)entity.CreatedBy ?? DBNull.Value);
        command.Parameters.AddWithValue("created", (object?)entity.Created ?? DBNull.Value);
        command.Parameters.AddWithValue("updatedBy", (object?)entity.UpdatedBy ?? DBNull.Value);
        command.Parameters.AddWithValue("updated", (object?)entity.Updated ?? DBNull.Value);
    }

    protected override AnaViaggi MapFromReader(NpgsqlDataReader reader)
    {
        var v = new AnaViaggi
        {
            Id = ReadInt(reader, "viaggio_id"),
            DescrizioneBreve = reader.GetString(reader.GetOrdinal("viaggio_descrizione_breve")),
            DescrizioneEstesa = reader.GetString(reader.GetOrdinal("viaggio_descrizione_estesa")),
            NumeroGiorni = ReadInt(reader, "viaggio_numero_giorni"),
            NumeroNotti = ReadInt(reader, "viaggio_numero_notti"),
            PastiAlSacco = reader.GetString(reader.GetOrdinal("viaggio_pasti_al_sacco")),
            Km = ReadInt(reader, "viaggio_num_km"),

            Note = ReadNullableString(reader, "viaggio_note"),
            Link = ReadNullableString(reader, "viaggio_link"),

            NazioneIdFk = ReadInt(reader, "viaggio_nazione_fk"),
            TipoViaggioIdFk = ReadInt(reader, "viaggio_tipo_viaggio_fk"),
            TipoTrattamentoIdFk = ReadInt(reader, "viaggio_tipo_trattamento_fk"),
            TipoPernottamentoIdFk = ReadInt(reader, "viaggio_tipo_pernottamento_fk"),
            TipoAvvicinamentoIdFk = ReadInt(reader, "viaggio_tipo_avvicinamento_fk"),

            AziendaId = ReadInt(reader, "azienda_id"),

            CreatedBy = ReadNullableString(reader, "created_by"),
            Created = ReadNullableDateTime(reader, "created"),
            UpdatedBy = ReadNullableString(reader, "updated_by"),
            Updated = ReadNullableDateTime(reader, "updated")
        };

        // Map description fields if available (from JOINs)
        if (HasColumn(reader, "nazione_nome")) v.NazioneNome = ReadNullableString(reader, "nazione_nome");
        if (HasColumn(reader, "tipo_viaggi_descrizione")) v.TipoViaggioDescrizione = ReadNullableString(reader, "tipo_viaggi_descrizione");
        if (HasColumn(reader, "tipo_trattamento_descrizione")) v.TipoTrattamentoDescrizione = ReadNullableString(reader, "tipo_trattamento_descrizione");
        if (HasColumn(reader, "ana_tipo_pernottamento_descrizione")) v.TipoPernottamentoDescrizione = ReadNullableString(reader, "ana_tipo_pernottamento_descrizione");
        if (HasColumn(reader, "tipo_avvicinamento_descrizione")) v.TipoAvvicinamentoDescrizione = ReadNullableString(reader, "tipo_avvicinamento_descrizione");
        if (HasColumn(reader, "azienda_nome")) v.AziendaRagioneSociale = ReadNullableString(reader, "azienda_nome");

        return v;
    }

    // Helper to check column existence in reader result
    private bool HasColumn(NpgsqlDataReader reader, string columnName)
    {
        for (int i = 0; i < reader.FieldCount; i++)
        {
            if (reader.GetName(i).Equals(columnName, StringComparison.OrdinalIgnoreCase)) return true;
        }
        return false;
    }

    public async Task<List<AnaDataViaggio>> GetDatesByTripIdAsync(int tripId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM get_datetrips_fromtrip(@id)";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", tripId);

            await using var reader = await command.ExecuteReaderAsync();
            var list = new List<AnaDataViaggio>();
            while (await reader.ReadAsync())
            {
                list.Add(MapDateFromReader(reader));
            }
            return list;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore recupero date viaggio {Id}", tripId);
            throw;
        }
    }

    private AnaDataViaggio MapDateFromReader(NpgsqlDataReader reader)
    {
        return new AnaDataViaggio
        {
            Id = ReadInt(reader, "data_viaggio_id"),
            ViaggioIdFk = ReadInt(reader, "viaggio_id_fk"),
            DataInizio = ReadNullableDateTime(reader, "data_viaggio_data_inizio"),
            DataFine = ReadNullableDateTime(reader, "data_viaggio_data_fine"),
            EffettuatoSino = reader.GetString(reader.GetOrdinal("data_viaggio_effettuato_sino")),
            CostoPilota = ReadNullableDecimal(reader, "data_viaggio_costo_pilota"),
            CostoPasseggero = ReadNullableDecimal(reader, "data_viaggio_costo_passeggero"),

            CostoPasseggeroAutoGuida = ReadNullableDecimal(reader, "data_viaggio_costo_passeggero_auto_guida"),
            CostoBambino02 = ReadNullableDecimal(reader, "data_viaggio_costo_bambino_0_2"),
            CostoBambino26 = ReadNullableDecimal(reader, "data_viaggio_costo_bambino_2_6"),
            CostoBambino612 = ReadNullableDecimal(reader, "data_viaggio_costo_bambino_6_12"),

            Note = ReadNullableString(reader, "data_viaggio_note"),
            AziendaId = ReadInt(reader, "azienda_id"),
            TotMezzi = ReadInt(reader, "tot_mezzi")
        };
    }
}
