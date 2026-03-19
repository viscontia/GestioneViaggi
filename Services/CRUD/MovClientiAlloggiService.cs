
using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Npgsql;
using System.Data;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.CRUD
{
    public class MovClientiAlloggiService
    {
        private readonly IDatabaseConnectionManager _connectionManager;
        private readonly Microsoft.Extensions.Logging.ILogger<MovClientiAlloggiService> _logger;

        public MovClientiAlloggiService(IDatabaseConnectionManager connectionManager, Microsoft.Extensions.Logging.ILogger<MovClientiAlloggiService> logger)
        {
            _connectionManager = connectionManager;
            _logger = logger;
        }

        public async Task<int> AddAccommodationAsync(MovClientiAlloggi entity)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();

                // PostgreSQL FUNCTION (not PROCEDURE), use SELECT instead of CALL
                string sql = @"
                    SELECT sp_mov_clienti_alloggi_create(
                        @p_viaggio_id,
                        @p_data_viaggio_id,
                        @p_tipo_alloggio_id,
                        @p_cliente_id1,
                        @p_cliente_id2,
                        @p_cliente_id3,
                        @p_cliente_id4,
                        @p_cliente_id5,
                        @p_cliente_id6
                    )";

                var parameters = new DynamicParameters();
                parameters.Add("p_viaggio_id", entity.ViaggioIdFk);
                parameters.Add("p_data_viaggio_id", entity.DataViaggioIdFk);
                parameters.Add("p_tipo_alloggio_id", entity.TipoAlloggioIdFk);
                parameters.Add("p_cliente_id1", entity.ClienteId1Fk);
                parameters.Add("p_cliente_id2", entity.ClienteId2Fk);
                parameters.Add("p_cliente_id3", entity.ClienteId3Fk);
                parameters.Add("p_cliente_id4", entity.ClienteId4Fk);
                parameters.Add("p_cliente_id5", entity.ClienteId5Fk);
                parameters.Add("p_cliente_id6", entity.ClienteId6Fk);
                return await conn.QuerySingleAsync<int>(sql, parameters);
            }
            catch (PostgresException ex) when (ex.SqlState == "23503")
            {
                throw new InvalidOperationException("Impossibile assegnare l'alloggio: alcuni dati riferiti (viaggio, tipo alloggio o clienti) non sono validi.", ex);
            }
            catch (PostgresException ex) when (ex.SqlState == "23505")
            {
                throw new InvalidOperationException("Questo alloggio risulta già assegnato. Verifica i dati.", ex);
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante l'assegnazione dell'alloggio: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante l'assegnazione dell'alloggio. Riprova.", ex);
            }
        }

        public async Task UpdateAccommodationAsync(MovClientiAlloggi entity)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();

                // PostgreSQL FUNCTION (not PROCEDURE), use SELECT instead of CALL
                string sql = @"
                    SELECT sp_mov_clienti_alloggi_update(
                        @p_pk,
                        @p_viaggio_id,
                        @p_data_viaggio_id,
                        @p_tipo_alloggio_id,
                        @p_cliente_id1,
                        @p_cliente_id2,
                        @p_cliente_id3,
                        @p_cliente_id4,
                        @p_cliente_id5,
                        @p_cliente_id6
                    )";

                var parameters = new DynamicParameters();
                parameters.Add("p_pk", entity.MovClientiAlloggioPk);
                parameters.Add("p_viaggio_id", entity.ViaggioIdFk);
                parameters.Add("p_data_viaggio_id", entity.DataViaggioIdFk);
                parameters.Add("p_tipo_alloggio_id", entity.TipoAlloggioIdFk);
                parameters.Add("p_cliente_id1", entity.ClienteId1Fk);
                parameters.Add("p_cliente_id2", entity.ClienteId2Fk);
                parameters.Add("p_cliente_id3", entity.ClienteId3Fk);
                parameters.Add("p_cliente_id4", entity.ClienteId4Fk);
                parameters.Add("p_cliente_id5", entity.ClienteId5Fk);
                parameters.Add("p_cliente_id6", entity.ClienteId6Fk);
                await conn.ExecuteAsync(sql, parameters);
            }
            catch (PostgresException ex) when (ex.SqlState == "23503")
            {
                throw new InvalidOperationException("Impossibile modificare l'alloggio: alcuni dati riferiti (tipo alloggio o clienti) non sono validi.", ex);
            }
            catch (PostgresException ex) when (ex.Message.Contains("Record Alloggio non trovato"))
            {
                throw new InvalidOperationException("L'alloggio che stai cercando di modificare non esiste più. Ricarica la pagina.", ex);
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante la modifica dell'alloggio: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante la modifica dell'alloggio. Riprova.", ex);
            }
        }

        public async Task RemoveAccommodationAsync(int pk)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();

                // PostgreSQL FUNCTION (not PROCEDURE), use SELECT instead of CALL
                string sql = "SELECT sp_mov_clienti_alloggi_delete(@p_pk)";

                var parameters = new DynamicParameters();
                parameters.Add("p_pk", pk);
                await conn.ExecuteAsync(sql, parameters);
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante la rimozione dell'alloggio: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante la rimozione dell'alloggio. Riprova.", ex);
            }
        }

        /// <summary>
        /// DB Function: fn_get_mov_clienti_alloggi_by_date(p_data_viaggio_id INTEGER)
        /// Input: ID della data viaggio
        /// Output: Tutti gli alloggi (camere) assegnati con i 6 slot clienti (dati raw)
        /// </summary>
        public async Task<IEnumerable<MovClientiAlloggi>> GetByDateIdAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                // Usa Npgsql diretto invece di Dapper per compatibilità AOT (Reflection.Emit non supportato)
                await using var cmd = new NpgsqlCommand("SELECT * FROM fn_get_mov_clienti_alloggi_by_date(@dataId)", conn);
                cmd.Parameters.AddWithValue("dataId", dataViaggioId);

                var result = new List<MovClientiAlloggi>();
                await using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    // La funzione SQL non restituisce le colonne audit
                    result.Add(new MovClientiAlloggi
                    {
                        MovClientiAlloggioPk = reader.GetInt32(reader.GetOrdinal("mov_clienti_alloggio_pk")),
                        ViaggioIdFk = reader.GetInt32(reader.GetOrdinal("viaggio_id_fk")),
                        DataViaggioIdFk = reader.GetInt32(reader.GetOrdinal("data_viaggio_id_fk")),
                        TipoAlloggioIdFk = reader.GetInt32(reader.GetOrdinal("tipo_alloggio_id_fk")),
                        ClienteId1Fk = reader.IsDBNull(reader.GetOrdinal("cliente_id1_fk")) ? null : reader.GetInt32(reader.GetOrdinal("cliente_id1_fk")),
                        ClienteId2Fk = reader.IsDBNull(reader.GetOrdinal("cliente_id2_fk")) ? null : reader.GetInt32(reader.GetOrdinal("cliente_id2_fk")),
                        ClienteId3Fk = reader.IsDBNull(reader.GetOrdinal("cliente_id3_fk")) ? null : reader.GetInt32(reader.GetOrdinal("cliente_id3_fk")),
                        ClienteId4Fk = reader.IsDBNull(reader.GetOrdinal("cliente_id4_fk")) ? null : reader.GetInt32(reader.GetOrdinal("cliente_id4_fk")),
                        ClienteId5Fk = reader.IsDBNull(reader.GetOrdinal("cliente_id5_fk")) ? null : reader.GetInt32(reader.GetOrdinal("cliente_id5_fk")),
                        ClienteId6Fk = reader.IsDBNull(reader.GetOrdinal("cliente_id6_fk")) ? null : reader.GetInt32(reader.GetOrdinal("cliente_id6_fk"))
                    });
                }
                return result;
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento degli alloggi: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante il caricamento degli alloggi. Riprova.", ex);
            }
        }

        /// <summary>
        /// DB Function: get_rooms_with_occupants(p_data_viaggio_id INTEGER)
        /// Input: ID della data viaggio
        /// Output: Camere con array aggregati di occupanti (ARRAY_AGG di nomi e IDs, DISTINCT applicato)
        ///         Elimina necessità di loop su 6 slot ClienteIdXFk + lookup partecipanti in memoria
        /// </summary>
        public async Task<IEnumerable<GestioneViaggi.Models.DTOs.RoomWithOccupantsDTO>> GetRoomsWithOccupantsAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                // Usa Npgsql diretto per compatibilità AOT (Reflection.Emit non supportato)
                await using var cmd = new NpgsqlCommand("SELECT * FROM get_rooms_with_occupants(@dataId)", conn);
                cmd.Parameters.AddWithValue("dataId", dataViaggioId);

                var result = new List<GestioneViaggi.Models.DTOs.RoomWithOccupantsDTO>();
                await using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    result.Add(new GestioneViaggi.Models.DTOs.RoomWithOccupantsDTO
                    {
                        AlloggioPk = reader.GetInt32(reader.GetOrdinal("alloggio_pk")),
                        TipoAlloggio = reader.GetString(reader.GetOrdinal("tipo_alloggio")),
                        MaxOccupants = reader.GetInt32(reader.GetOrdinal("max_occupants")),
                        CurrentOccupants = reader.GetInt32(reader.GetOrdinal("current_occupants")),
                        OccupantNames = reader.IsDBNull(reader.GetOrdinal("occupant_names"))
                            ? Array.Empty<string>()
                            : reader.GetFieldValue<string[]>(reader.GetOrdinal("occupant_names")),
                        OccupantIds = reader.IsDBNull(reader.GetOrdinal("occupant_ids"))
                            ? Array.Empty<int>()
                            : reader.GetFieldValue<int[]>(reader.GetOrdinal("occupant_ids")),
                        HasSupplement = reader.GetBoolean(reader.GetOrdinal("has_supplement"))
                    });
                }
                return result;
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento camere con occupanti: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante il caricamento camere. Riprova.", ex);
            }
        }

        /// <summary>
        /// DB Stored Procedure: sp_assign_to_first_free_slot(p_alloggio_pk INTEGER, p_cliente_id INTEGER)
        /// Input: ID camera, ID cliente da assegnare
        /// Output: BOOLEAN - TRUE se assegnato con successo, FALSE se camera piena
        /// Logica: Trova primo slot libero (ClienteId1Fk...ClienteId6Fk), valida capacità, assegna atomicamente
        /// </summary>
        public async Task<bool> AssignToFirstFreeSlotAsync(int alloggioPk, int clienteId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                // Usa Npgsql diretto per compatibilità AOT
                await using var cmd = new NpgsqlCommand("SELECT sp_assign_to_first_free_slot(@pk, @clienteId)", conn);
                cmd.Parameters.AddWithValue("pk", alloggioPk);
                cmd.Parameters.AddWithValue("clienteId", clienteId);
                var result = await cmd.ExecuteScalarAsync();
                return result != null && Convert.ToBoolean(result);
            }
            catch (PostgresException ex) when (ex.Message.Contains("Camera non trovata"))
            {
                throw new InvalidOperationException($"Camera non trovata: ID {alloggioPk}", ex);
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante l'assegnazione alla camera: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante l'assegnazione. Riprova.", ex);
            }
        }

        /// <summary>
        /// DB Function: get_rooms_count(p_data_viaggio_id INTEGER)
        /// Input: ID della data viaggio
        /// Output: Conteggio totale camere (più efficiente di Count() in memoria)
        /// </summary>
        public async Task<int> GetRoomsCountAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                // Usa Npgsql diretto per compatibilità AOT
                await using var cmd = new NpgsqlCommand("SELECT get_rooms_count(@dataId)", conn);
                cmd.Parameters.AddWithValue("dataId", dataViaggioId);
                var result = await cmd.ExecuteScalarAsync();
                return result != null ? Convert.ToInt32(result) : 0;
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il conteggio camere: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Errore generico durante il conteggio camere");
                throw;
            }
        }

    
    // --- Room Consistency & Violation Handling ---

    public class RoomConsistencyCheckResult
    {
        public bool ViolationDetected { get; set; }
        public int RoomId { get; set; }
        public string? RoomTypeDesc { get; set; }
        public int RequiredSeats { get; set; }
        public int CurrentOccupantsCount { get; set; }
        public int RemainingOccupantsCount { get; set; }
        public int[]? SurvivorIds { get; set; }
    }

    public async Task<RoomConsistencyCheckResult> CheckRoomConsistencyOnDeleteAsync(int dataViaggioId, int clienteIdToRemove)
    {
        try
        {
            await using var conn = await _connectionManager.GetConnectionAsync();
            // Usa Npgsql diretto per compatibilità AOT (Reflection.Emit non supportato)
            await using var cmd = new NpgsqlCommand("SELECT * FROM chk_room_consistency_on_delete(@dataId, @clienteId)", conn);
            cmd.Parameters.AddWithValue("dataId", dataViaggioId);
            cmd.Parameters.AddWithValue("clienteId", clienteIdToRemove);

            await using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return new RoomConsistencyCheckResult
                {
                    ViolationDetected = reader.GetBoolean(reader.GetOrdinal("violation_detected")),
                    RoomId = reader.GetInt32(reader.GetOrdinal("room_id")),
                    RoomTypeDesc = reader.IsDBNull(reader.GetOrdinal("room_type_desc")) ? null : reader.GetString(reader.GetOrdinal("room_type_desc")),
                    RequiredSeats = reader.GetInt32(reader.GetOrdinal("required_seats")),
                    CurrentOccupantsCount = reader.GetInt32(reader.GetOrdinal("current_occupants_count")),
                    RemainingOccupantsCount = reader.GetInt32(reader.GetOrdinal("remaining_occupants_count")),
                    SurvivorIds = reader.IsDBNull(reader.GetOrdinal("survivor_ids"))
                        ? null
                        : reader.GetFieldValue<int[]>(reader.GetOrdinal("survivor_ids"))
                };
            }
            return new RoomConsistencyCheckResult { ViolationDetected = false };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore during check room consistency for Client {ClientId}", clienteIdToRemove);
            throw;
        }
    }

    public async Task ResolveRoomViolationMoveAsync(int oldRoomId, int newTipoAlloggioId, int[] survivorIds)
    {
        try
        {
            await using var conn = await _connectionManager.GetConnectionAsync();
            var sql = "SELECT sp_resolve_room_violation_move(@oldRoomId, @newTipo, @survivors)";
            
            var parameters = new DynamicParameters();
            parameters.Add("oldRoomId", oldRoomId);
            parameters.Add("newTipo", newTipoAlloggioId);
            parameters.Add("survivors", survivorIds);
            await conn.ExecuteAsync(sql, parameters);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore resolving violation (MOVE) for Room {RoomId}", oldRoomId);
            throw;
        }
    }

    public async Task ResolveRoomViolationParkAsync(int roomId, int[] survivorIds)
    {
        try
        {
            await using var conn = await _connectionManager.GetConnectionAsync();
            var sql = "SELECT sp_resolve_room_violation_park(@roomId, @survivors)";
            
            var parameters = new DynamicParameters();
            parameters.Add("roomId", roomId);
            parameters.Add("survivors", survivorIds);
            await conn.ExecuteAsync(sql, parameters);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore resolving violation (PARK) for Room {RoomId}", roomId);
            throw;
        }
    }
    }
}
