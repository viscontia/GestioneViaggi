using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;
using NpgsqlTypes;
using GestioneViaggi.Models.DTOs;
using GestioneViaggi.Services.Session;

namespace GestioneViaggi.Services.CRUD;

public class AnaViaggiService : BaseCrudService<AnaViaggi>
{
    protected override string TableName => "ana_viaggi";
    protected override string IdColumnName => "viaggio_id";

    private static readonly System.Text.Json.JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase
    };

    public AnaViaggiService(IDatabaseService databaseService, ILogger<AnaViaggiService> logger, ITenantContext tenantContext)
        : base(databaseService, logger, tenantContext)
    {
    }

    public async Task<List<ViaggioPartecipantiGruppoDTO>> GetPartecipantiAsync(int dateId)
    {
        var result = new List<ViaggioPartecipantiGruppoDTO>();
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM get_viaggio_partecipanti(@dateId)";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("dateId", dateId);

            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(new ViaggioPartecipantiGruppoDTO
                {
                    GruppoId = reader.IsDBNull(reader.GetOrdinal("gruppo_id"))
                        ? 0
                        : reader.GetInt32(reader.GetOrdinal("gruppo_id")),
                    PilotaNominativo = reader.IsDBNull(reader.GetOrdinal("pilota_nominativo"))
                        ? "Sconosciuto"
                        : reader.GetString(reader.GetOrdinal("pilota_nominativo")),
                    PasseggeriNominativi = reader.IsDBNull(reader.GetOrdinal("passeggeri_nominativi"))
                        ? string.Empty
                        : reader.GetString(reader.GetOrdinal("passeggeri_nominativi"))
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore recupero partecipanti per data {DateId}", dateId);
            // Non rilanciamo eccezione bloccante, restituiamo lista vuota e logghiamo
        }
        return result;
    }

    public async Task<List<AnaViaggi>> GetAllAsync(int? aziendaId = null, int? filterYear = null, bool? onlyCompleted = null, bool? futureOnly = null)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM fn_ana_viaggi_get_all(@aziendaId, @filterYear, @onlyCompleted, @futureOnly)";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.Add(new NpgsqlParameter("aziendaId", NpgsqlDbType.Integer)
            {
                Value = aziendaId.HasValue && aziendaId.Value > 0 ? aziendaId.Value : (object)DBNull.Value,
                IsNullable = true
            });
            command.Parameters.Add(new NpgsqlParameter("filterYear", NpgsqlDbType.Integer)
            {
                Value = (object?)filterYear ?? DBNull.Value,
                IsNullable = true
            });
            command.Parameters.Add(new NpgsqlParameter("onlyCompleted", NpgsqlDbType.Boolean)
            {
                Value = (object?)onlyCompleted ?? DBNull.Value,
                IsNullable = true
            });
            command.Parameters.Add(new NpgsqlParameter("futureOnly", NpgsqlDbType.Boolean)
            {
                Value = (object?)futureOnly ?? DBNull.Value,
                IsNullable = true
            });

            await using var reader = await command.ExecuteReaderAsync();

            var list = new List<AnaViaggi>();
            while (await reader.ReadAsync())
            {
                var item = MapFromReader(reader);
                // Map the transient count
                if (HasColumn(reader, "matching_dates_count"))
                {
                    item.MatchingDatesCount = reader.GetInt32(reader.GetOrdinal("matching_dates_count"));
                }
                list.Add(item);
            }
            return list;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore recupero lista viaggi");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public async Task<List<AnaViaggi>> GetViaggiWithTransactionsAsync(int? aziendaId = null)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM fn_get_viaggi_with_transactions(@aziendaId)";

            await using var command = new NpgsqlCommand(sql, connection);
            // Explicitly define type to avoid 42P08 when value is NULL
            var param = new NpgsqlParameter("aziendaId", NpgsqlDbType.Integer)
            {
                Value = (object?)aziendaId ?? DBNull.Value,
                IsNullable = true
            };
            command.Parameters.Add(param);

            await using var reader = await command.ExecuteReaderAsync();

            var list = new List<AnaViaggi>();
            while (await reader.ReadAsync())
            {
                var item = MapFromReader(reader);
                // Map the transient count
                if (HasColumn(reader, "matching_dates_count"))
                {
                    item.MatchingDatesCount = reader.GetInt32(reader.GetOrdinal("matching_dates_count"));
                }
                list.Add(item);
            }
            return list;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore recupero lista viaggi con transazioni");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<AnaViaggi?> GetByIdAsync(int id)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            // Use NpgsqlDataReader instead of Dapper to handle prefixed column names correctly
            var sql = "SELECT * FROM fn_ana_viaggi_get_by_id(@p_viaggio_id)";
            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("p_viaggio_id", id);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore recupero viaggio per id {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<AnaViaggi> CreateAsync(AnaViaggi entity)
    {
        await PopulateAuditFieldsAsync(entity, true);
        return await CreateAsyncInternal(entity);
    }

    private async Task<AnaViaggi> CreateAsyncInternal(AnaViaggi entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            string sql = "SELECT sp_ana_viaggi_create(@p_viaggio_descrizione_breve, @p_viaggio_descrizione_estesa, " +
                "@p_viaggio_numero_giorni, @p_viaggio_numero_notti, @p_viaggio_pasti_al_sacco, " +
                "@p_viaggio_num_km, @p_viaggio_difficolta::VARCHAR, @p_viaggio_tipo_avvicinamento_fk, @p_viaggio_note, @p_viaggio_link, " +
                "@p_viaggio_nazione_fk, @p_viaggio_tipo_viaggio_fk, @p_viaggio_tipo_trattamento_fk, " +
                "@p_viaggio_tipo_pernottamento_fk, @p_azienda_id, @p_created_by::VARCHAR, @p_created, " +
                "@p_updated_by::VARCHAR, @p_updated)";

            await using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("p_viaggio_descrizione_breve", entity.DescrizioneBreve.ToUpper());
            cmd.Parameters.AddWithValue("p_viaggio_descrizione_estesa", entity.DescrizioneEstesa.ToUpper());
            cmd.Parameters.AddWithValue("p_viaggio_numero_giorni", entity.NumeroGiorni);
            cmd.Parameters.AddWithValue("p_viaggio_numero_notti", entity.NumeroNotti);
            cmd.Parameters.AddWithValue("p_viaggio_pasti_al_sacco", entity.PastiAlSacco);
            cmd.Parameters.AddWithValue("p_viaggio_num_km", entity.Km);
            cmd.Parameters.AddWithValue("p_viaggio_difficolta", (object?)entity.Difficolta ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_viaggio_tipo_avvicinamento_fk", entity.TipoAvvicinamentoIdFk);
            cmd.Parameters.AddWithValue("p_viaggio_note", (object?)entity.Note?.ToUpper() ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_viaggio_link", (object?)entity.Link ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_viaggio_nazione_fk", entity.NazioneIdFk);
            cmd.Parameters.AddWithValue("p_viaggio_tipo_viaggio_fk", entity.TipoViaggioIdFk);
            cmd.Parameters.AddWithValue("p_viaggio_tipo_trattamento_fk", entity.TipoTrattamentoIdFk);
            cmd.Parameters.AddWithValue("p_viaggio_tipo_pernottamento_fk", entity.TipoPernottamentoIdFk);
            cmd.Parameters.AddWithValue("p_azienda_id", entity.AziendaId);
            cmd.Parameters.AddWithValue("p_created_by", (object?)entity.CreatedBy ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_created", (object?)entity.Created ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_updated_by", (object?)entity.UpdatedBy ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_updated", (object?)entity.Updated ?? DBNull.Value);

            var result = await cmd.ExecuteScalarAsync();
            entity.Id = Convert.ToInt32(result);

            return entity;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore creazione viaggio");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<AnaViaggi> UpdateAsync(AnaViaggi entity)
    {
        await PopulateAuditFieldsAsync(entity, false);
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            string sql = "SELECT sp_ana_viaggi_update(@p_viaggio_id, @p_viaggio_descrizione_breve, " +
                "@p_viaggio_descrizione_estesa, @p_viaggio_numero_giorni, @p_viaggio_numero_notti, " +
                "@p_viaggio_pasti_al_sacco, @p_viaggio_num_km, @p_viaggio_difficolta::VARCHAR, @p_viaggio_tipo_avvicinamento_fk, " +
                "@p_viaggio_note, @p_viaggio_link, @p_viaggio_nazione_fk, @p_viaggio_tipo_viaggio_fk, " +
                "@p_viaggio_tipo_trattamento_fk, @p_viaggio_tipo_pernottamento_fk, @p_azienda_id, " +
                "@p_updated_by::VARCHAR, @p_updated)";

            await using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("p_viaggio_id", entity.Id);
            cmd.Parameters.AddWithValue("p_viaggio_descrizione_breve", entity.DescrizioneBreve.ToUpper());
            cmd.Parameters.AddWithValue("p_viaggio_descrizione_estesa", entity.DescrizioneEstesa.ToUpper());
            cmd.Parameters.AddWithValue("p_viaggio_numero_giorni", entity.NumeroGiorni);
            cmd.Parameters.AddWithValue("p_viaggio_numero_notti", entity.NumeroNotti);
            cmd.Parameters.AddWithValue("p_viaggio_pasti_al_sacco", entity.PastiAlSacco);
            cmd.Parameters.AddWithValue("p_viaggio_num_km", entity.Km);
            cmd.Parameters.AddWithValue("p_viaggio_difficolta", (object?)entity.Difficolta ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_viaggio_tipo_avvicinamento_fk", entity.TipoAvvicinamentoIdFk);
            cmd.Parameters.AddWithValue("p_viaggio_note", (object?)entity.Note?.ToUpper() ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_viaggio_link", (object?)entity.Link ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_viaggio_nazione_fk", entity.NazioneIdFk);
            cmd.Parameters.AddWithValue("p_viaggio_tipo_viaggio_fk", entity.TipoViaggioIdFk);
            cmd.Parameters.AddWithValue("p_viaggio_tipo_trattamento_fk", entity.TipoTrattamentoIdFk);
            cmd.Parameters.AddWithValue("p_viaggio_tipo_pernottamento_fk", entity.TipoPernottamentoIdFk);
            cmd.Parameters.AddWithValue("p_azienda_id", entity.AziendaId);
            cmd.Parameters.AddWithValue("p_updated_by", (object?)entity.UpdatedBy ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_updated", (object?)entity.Updated ?? DBNull.Value);

            await cmd.ExecuteNonQueryAsync();

            return entity;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore aggiornamento viaggio {Id}", entity.Id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<bool> DeleteAsync(int id)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            await using var cmd = new NpgsqlCommand("SELECT * FROM sp_ana_viaggi_delete(@p_viaggio_id)", connection);
            cmd.Parameters.AddWithValue("p_viaggio_id", id);

            await using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                bool deleted = reader.GetBoolean(reader.GetOrdinal("deleted"));
                string error_message = reader.IsDBNull(reader.GetOrdinal("error_message")) ? string.Empty : reader.GetString(reader.GetOrdinal("error_message"));

                if (!deleted && !string.IsNullOrEmpty(error_message))
                {
                    throw new InvalidOperationException(error_message);
                }

                return deleted;
            }

            return false;
        }
        catch (InvalidOperationException)
        {
            // Re-throw validation errors as-is for UI to display nicely
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore eliminazione viaggio {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
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
        command.Parameters.AddWithValue("difficolta", (object?)entity.Difficolta ?? DBNull.Value);
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
            Difficolta = ReadNullableString(reader, "viaggio_difficolta"),

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



    public async Task<List<AnaDataViaggio>> GetDatesByTripIdAsync(int tripId, int? filterYear = null, bool? onlyCompleted = null, bool? futureOnly = null)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            // Modified to filter manually since the function get_datetrips_fromtrip is simple
            // Or we can filter in C# easily since typically trips don't have thousands of dates
            // But doing it in SQL is cleaner if we modify the SQL or just WHERE clause on result
            // Since get_datetrips_fromtrip returns a set, we can select from it.

            var sql = @"
                SELECT * FROM get_datetrips_fromtrip(@id) d
                WHERE (@filterYear IS NULL OR EXTRACT(YEAR FROM d.data_viaggio_data_inizio) = @filterYear)
                AND (@onlyCompleted IS NULL 
                    OR (@onlyCompleted = TRUE AND d.data_viaggio_effettuato_sino = 'Y')
                    OR (@onlyCompleted = FALSE AND d.data_viaggio_effettuato_sino = 'N'))
                AND (@futureOnly IS NULL OR (@futureOnly = TRUE AND d.data_viaggio_data_inizio >= CURRENT_DATE))
                ORDER BY d.data_viaggio_data_inizio DESC";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", tripId);
            command.Parameters.Add(new NpgsqlParameter("filterYear", NpgsqlDbType.Integer) { Value = (object?)filterYear ?? DBNull.Value, IsNullable = true });
            command.Parameters.Add(new NpgsqlParameter("onlyCompleted", NpgsqlDbType.Boolean) { Value = (object?)onlyCompleted ?? DBNull.Value, IsNullable = true });
            command.Parameters.Add(new NpgsqlParameter("futureOnly", NpgsqlDbType.Boolean) { Value = (object?)futureOnly ?? DBNull.Value, IsNullable = true });

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
            TotMezzi = ReadInt(reader, "tot_mezzi"),
            TotClienti = ReadInt(reader, "tot_clienti")
        };
    }
    public async Task<int> CreateTripWithDatesAsync(AnaViaggi trip, List<AnaDataViaggio> dates)
    {
        if (dates == null || dates.Count == 0)
        {
            throw new ArgumentException("Almeno una data è obbligatoria per creare un viaggio.");
        }

        await using var connection = await _databaseService.GetConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        try
        {
            await PopulateAuditFieldsAsync(trip, true);
            // 1. Insert Trip
            var sqlTrip = @"
                INSERT INTO ana_viaggi (
                    viaggio_descrizione_breve, viaggio_descrizione_estesa,
                    viaggio_numero_giorni, viaggio_numero_notti,
                    viaggio_pasti_al_sacco, viaggio_num_km,
                    viaggio_difficolta,
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
                    @difficolta,
                    @avvicinamento,
                    @note, @link,
                    @nazione, @tipo,
                    @trattamento, @pernottamento,
                    @aziendaId,
                    @createdBy, @created, @updatedBy, @updated
                )
                RETURNING viaggio_id";

            await using var cmdTrip = new NpgsqlCommand(sqlTrip, connection, transaction);
            AddParameters(cmdTrip, trip);

            var tripIdObj = await cmdTrip.ExecuteScalarAsync();
            int tripId = Convert.ToInt32(tripIdObj);
            trip.Id = tripId;

            // 2. Insert Dates
            foreach (var date in dates)
            {
                date.ViaggioIdFk = tripId; // Link to new trip
                date.AziendaId = trip.AziendaId; // Inherit company
                await InsertDateInternalAsync(date, connection, transaction);
            }

            await transaction.CommitAsync();
            return tripId;
        }
        catch (PostgresException ex) when (ex.SqlState == "42P01" && ex.Message.Contains("ana_viaggi_seq"))
        {
            // If sequence missing for main table, rollback is automatic on error but we are in C# transaction block.
            await transaction.RollbackAsync();
            _logger.LogWarning("Sequence missing during atomic create. Attempting fix and retry manually not implemented for complex transaction yet.");
            throw;
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync();
            _logger.LogError(ex, "Errore nella creazione atomica del viaggio con date.");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public async Task UpdateDateAsync(AnaDataViaggio date)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            // Get current user from context
            var user = _tenantContext != null ? await _tenantContext.GetCurrentUserAsync() : null;
            var currentUser = user?.Username ?? "SYSTEM";

            string sql = "SELECT sp_ana_date_viaggi_update(@p_data_viaggio_id, @p_data_viaggio_data_inizio::DATE, " +
                "@p_data_viaggio_data_fine::DATE, @p_data_viaggio_effettuato_sino, @p_data_viaggio_costo_pilota, " +
                "@p_data_viaggio_costo_passeggero, @p_data_viaggio_costo_passeggero_auto_guida, " +
                "@p_data_viaggio_costo_bambino_0_2, @p_data_viaggio_costo_bambino_2_6, " +
                "@p_data_viaggio_costo_bambino_6_12, @p_data_viaggio_note::VARCHAR, @p_azienda_id, " +
                "@p_updated_by::VARCHAR, @p_updated)";

            await using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("p_data_viaggio_id", date.Id);
            cmd.Parameters.AddWithValue("p_data_viaggio_data_inizio", (object?)date.DataInizio ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_data_viaggio_data_fine", (object?)date.DataFine ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_data_viaggio_effettuato_sino", (object?)date.EffettuatoSino ?? "N");
            cmd.Parameters.AddWithValue("p_data_viaggio_costo_pilota", date.CostoPilota.HasValue ? (int)date.CostoPilota.Value : 0);
            cmd.Parameters.AddWithValue("p_data_viaggio_costo_passeggero", date.CostoPasseggero.HasValue ? (int)date.CostoPasseggero.Value : 0);
            cmd.Parameters.AddWithValue("p_data_viaggio_costo_passeggero_auto_guida", date.CostoPasseggeroAutoGuida.HasValue ? (object)((int)date.CostoPasseggeroAutoGuida.Value) : DBNull.Value);
            cmd.Parameters.AddWithValue("p_data_viaggio_costo_bambino_0_2", date.CostoBambino02.HasValue ? (object)((int)date.CostoBambino02.Value) : DBNull.Value);
            cmd.Parameters.AddWithValue("p_data_viaggio_costo_bambino_2_6", date.CostoBambino26.HasValue ? (object)((int)date.CostoBambino26.Value) : DBNull.Value);
            cmd.Parameters.AddWithValue("p_data_viaggio_costo_bambino_6_12", date.CostoBambino612.HasValue ? (object)((int)date.CostoBambino612.Value) : DBNull.Value);
            cmd.Parameters.AddWithValue("p_data_viaggio_note", (object?)date.Note ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_azienda_id", date.AziendaId);
            cmd.Parameters.AddWithValue("p_updated_by", currentUser);
            cmd.Parameters.AddWithValue("p_updated", DateTime.UtcNow);

            await cmd.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore aggiornamento data viaggio {Id}", date.Id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "data di viaggio");
        }
    }

    public async Task CreateDateAsync(AnaDataViaggio date)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            // Get current user from context
            var user = _tenantContext != null ? await _tenantContext.GetCurrentUserAsync() : null;
            var currentUser = user?.Username ?? "SYSTEM";

            string sql = "SELECT sp_ana_date_viaggi_create(@p_viaggio_id_fk, @p_data_viaggio_data_inizio::DATE, " +
                "@p_data_viaggio_data_fine::DATE, @p_data_viaggio_effettuato_sino, @p_data_viaggio_costo_pilota, " +
                "@p_data_viaggio_costo_passeggero, @p_data_viaggio_costo_passeggero_auto_guida, " +
                "@p_data_viaggio_costo_bambino_0_2, @p_data_viaggio_costo_bambino_2_6, " +
                "@p_data_viaggio_costo_bambino_6_12, @p_data_viaggio_note::VARCHAR, @p_azienda_id, " +
                "@p_created_by::VARCHAR)";

            await using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("p_viaggio_id_fk", date.ViaggioIdFk);
            cmd.Parameters.AddWithValue("p_data_viaggio_data_inizio", (object?)date.DataInizio ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_data_viaggio_data_fine", (object?)date.DataFine ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_data_viaggio_effettuato_sino", (object?)date.EffettuatoSino ?? "N");
            cmd.Parameters.AddWithValue("p_data_viaggio_costo_pilota", date.CostoPilota.HasValue ? (int)date.CostoPilota.Value : 0);
            cmd.Parameters.AddWithValue("p_data_viaggio_costo_passeggero", date.CostoPasseggero.HasValue ? (int)date.CostoPasseggero.Value : 0);
            cmd.Parameters.AddWithValue("p_data_viaggio_costo_passeggero_auto_guida", date.CostoPasseggeroAutoGuida.HasValue ? (object)((int)date.CostoPasseggeroAutoGuida.Value) : DBNull.Value);
            cmd.Parameters.AddWithValue("p_data_viaggio_costo_bambino_0_2", date.CostoBambino02.HasValue ? (object)((int)date.CostoBambino02.Value) : DBNull.Value);
            cmd.Parameters.AddWithValue("p_data_viaggio_costo_bambino_2_6", date.CostoBambino26.HasValue ? (object)((int)date.CostoBambino26.Value) : DBNull.Value);
            cmd.Parameters.AddWithValue("p_data_viaggio_costo_bambino_6_12", date.CostoBambino612.HasValue ? (object)((int)date.CostoBambino612.Value) : DBNull.Value);
            cmd.Parameters.AddWithValue("p_data_viaggio_note", (object?)date.Note ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_azienda_id", date.AziendaId);
            cmd.Parameters.AddWithValue("p_created_by", currentUser);

            var newId = await cmd.ExecuteScalarAsync();
            date.Id = Convert.ToInt32(newId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore creazione data viaggio");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "data di viaggio");
        }
    }

    public async Task DeleteDateAsync(int dateId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            await using var cmd = new NpgsqlCommand("SELECT * FROM sp_ana_date_viaggi_delete(@p_data_viaggio_id)", connection);
            cmd.Parameters.AddWithValue("p_data_viaggio_id", dateId);

            await using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                bool deleted = reader.GetBoolean(reader.GetOrdinal("deleted"));
                string error_message = reader.IsDBNull(reader.GetOrdinal("error_message")) ? string.Empty : reader.GetString(reader.GetOrdinal("error_message"));

                if (!deleted && !string.IsNullOrEmpty(error_message))
                {
                    throw new InvalidOperationException(error_message);
                }
            }
        }
        catch (InvalidOperationException)
        {
            // Re-throw validation errors as-is for UI to display nicely
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore eliminazione data viaggio {Id}", dateId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "data di viaggio");
        }
    }

    private async Task InsertDateInternalAsync(AnaDataViaggio date, NpgsqlConnection connection, NpgsqlTransaction? transaction)
    {
        var sql = @"
            INSERT INTO ana_date_viaggi (
                viaggio_id_fk,
                data_viaggio_data_inizio,
                data_viaggio_data_fine,
                data_viaggio_effettuato_sino,
                data_viaggio_costo_pilota,
                data_viaggio_costo_passeggero,
                data_viaggio_costo_passeggero_auto_guida,
                data_viaggio_costo_bambino_0_2,
                data_viaggio_costo_bambino_2_6,
                data_viaggio_costo_bambino_6_12,
                data_viaggio_note,
                azienda_id
            ) VALUES (
                @viaggioId,
                @inizio,
                @fine,
                @effettuato,
                @costoPilota,
                @costoPass,
                @costoPassAuto,
                @costoB02,
                @costoB26,
                @costoB612,
                @note,
                @aziendaId
            )";

        await using var cmd = new NpgsqlCommand(sql, connection, transaction);
        AddDateParameters(cmd, date);
        await cmd.ExecuteNonQueryAsync();
    }

    private void AddDateParameters(NpgsqlCommand cmd, AnaDataViaggio date)
    {
        cmd.Parameters.AddWithValue("viaggioId", date.ViaggioIdFk);
        cmd.Parameters.AddWithValue("inizio", (object?)date.DataInizio ?? DBNull.Value);
        cmd.Parameters.AddWithValue("fine", (object?)date.DataFine ?? DBNull.Value);
        cmd.Parameters.AddWithValue("effettuato", (object?)date.EffettuatoSino ?? "N");
        cmd.Parameters.AddWithValue("costoPilota", (object?)date.CostoPilota ?? DBNull.Value);
        cmd.Parameters.AddWithValue("costoPass", (object?)date.CostoPasseggero ?? DBNull.Value);
        cmd.Parameters.AddWithValue("costoPassAuto", (object?)date.CostoPasseggeroAutoGuida ?? DBNull.Value);
        cmd.Parameters.AddWithValue("costoB02", (object?)date.CostoBambino02 ?? DBNull.Value);
        cmd.Parameters.AddWithValue("costoB26", (object?)date.CostoBambino26 ?? DBNull.Value);
        cmd.Parameters.AddWithValue("costoB612", (object?)date.CostoBambino612 ?? DBNull.Value);
        cmd.Parameters.AddWithValue("note", (object?)date.Note ?? DBNull.Value);
        cmd.Parameters.AddWithValue("aziendaId", date.AziendaId);
    }

    public async Task<List<DuplicateTripDTO>> CheckDuplicatesAsync(string description, int aziendaId)
    {
        var result = new List<DuplicateTripDTO>();
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM check_possible_duplicate_travels(@desc, @aziendaId)";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("desc", description);
            command.Parameters.AddWithValue("aziendaId", aziendaId);

            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(new DuplicateTripDTO
                {
                    Id = ReadInt(reader, "viaggio_id"),
                    Descrizione = reader.GetString(reader.GetOrdinal("viaggio_descrizione_breve")),
                    MatchingWords = reader.GetString(reader.GetOrdinal("matching_words"))
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore during duplicate check for description: {Description}", description);
            // Non-blocking error: return empty list
        }
        return result;
    }

    /// <summary>
    /// Recupera dati per TreeView: viaggi e date raggruppati per anno
    /// </summary>
    /// <param name="aziendaId">ID azienda (0 o null per tutte - solo SuperAdmin)</param>
    /// <returns>Lista di TravelTreeData ordinata per anno DESC, viaggio ASC, data ASC</returns>
    public async Task<List<TravelTreeData>> GetTravelTreeDataAsync(int? aziendaId = null)
    {
        var result = new List<TravelTreeData>();
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM get_viaggi_grouped_by_year(@aziendaId)";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.Add(new NpgsqlParameter("aziendaId", NpgsqlDbType.Integer)
            {
                Value = aziendaId.HasValue && aziendaId.Value > 0 ? aziendaId.Value : (object)DBNull.Value,
                IsNullable = true
            });

            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(new TravelTreeData
                {
                    Anno = ReadInt(reader, "anno"),
                    ViaggioId = ReadInt(reader, "viaggio_id"),
                    ViaggioDescrizione = reader.GetString(reader.GetOrdinal("viaggio_descrizione")),
                    DataViaggioId = ReadInt(reader, "data_viaggio_id"),
                    DataInizio = ReadNullableDateTime(reader, "data_inizio"),
                    DataFine = ReadNullableDateTime(reader, "data_fine"),
                    EffettuatoSino = reader.GetString(reader.GetOrdinal("effettuato_sino"))[0]
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore recupero dati TreeView per azienda {AziendaId}", aziendaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }

        return result;
    }

    public async Task<GestioneViaggi.Models.DTOs.ViaggiInitData> GetViaggiInitDataAsync(int? viaggioId = null)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            // PostgreSQL logic: call fn_get_viaggi_init_data which returns a single JSON string
            using var command = new NpgsqlCommand("SELECT fn_get_viaggi_init_data(@vid)", connection);
            command.Parameters.AddWithValue("vid", (object?)viaggioId ?? DBNull.Value);

            var json = await command.ExecuteScalarAsync() as string;

            if (string.IsNullOrEmpty(json))
            {
                _logger.LogWarning("fn_get_viaggi_init_data returned empty JSON for viaggioId {ViaggioId}", viaggioId);
                return new GestioneViaggi.Models.DTOs.ViaggiInitData();
            }

            // DEBUG: Log JSON snippet for dates section
            var datesIndex = json.IndexOf("\"dates\"");
            if (datesIndex > 0)
            {
                var datesSnippet = json.Substring(datesIndex, Math.Min(500, json.Length - datesIndex));
                _logger.LogInformation("JSON dates section: {DatesSnippet}", datesSnippet);
            }

            var result = System.Text.Json.JsonSerializer.Deserialize<GestioneViaggi.Models.DTOs.ViaggiInitData>(json, JsonOptions)
                ?? new GestioneViaggi.Models.DTOs.ViaggiInitData();

            // DEBUG: Log deserialized result
            _logger.LogInformation("Deserialized {DateCount} dates for viaggioId {ViaggioId}", result.Dates?.Count ?? 0, viaggioId);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento dei dati di inizializzazione viaggi per ID {ViaggioId}", viaggioId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Recupera i dati dei viaggi per il calendario mensile
    /// </summary>
    /// <param name="year">Anno del calendario</param>
    /// <param name="month">Mese del calendario (1-12)</param>
    /// <param name="aziendaId">ID azienda (obbligatorio per caricare i dati)</param>
    /// <returns>Lista di CalendarTravelDTO per il mese specificato</returns>
    public async Task<List<CalendarTravelDTO>> GetCalendarDataAsync(int year, int month, int aziendaId)
    {
        var result = new List<CalendarTravelDTO>();
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT * FROM fn_get_calendar_data(@year, @month, @aziendaId)";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("year", year);
            command.Parameters.AddWithValue("month", month);
            command.Parameters.AddWithValue("aziendaId", aziendaId);

            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                var dataInizio = reader.GetDateTime(reader.GetOrdinal("data_inizio"));
                var effettuatoSino = reader.GetChar(reader.GetOrdinal("effettuato_sino"));

                result.Add(new CalendarTravelDTO
                {
                    DataViaggioId = ReadInt(reader, "data_viaggio_id"),
                    ViaggioId = ReadInt(reader, "viaggio_id"),
                    DescrizioneViaggio = reader.GetString(reader.GetOrdinal("descrizione_viaggio")),
                    DataInizio = dataInizio,
                    DataFine = reader.GetDateTime(reader.GetOrdinal("data_fine")),
                    TotClienti = ReadInt(reader, "tot_clienti"),
                    Status = CalendarTravelDTO.ComputeStatus(effettuatoSino, dataInizio),
                    AziendaId = ReadInt(reader, "azienda_id"),
                    AziendaNome = reader.GetString(reader.GetOrdinal("azienda_nome"))
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore recupero dati calendario per {Year}/{Month} azienda {AziendaId}", year, month, aziendaId);
            // Non-blocking: restituisce lista vuota in caso di errore
        }

        return result;
    }
}

