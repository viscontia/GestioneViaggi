
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

                return await conn.QuerySingleAsync<int>(sql, new
                {
                    p_viaggio_id = entity.ViaggioIdFk,
                    p_data_viaggio_id = entity.DataViaggioIdFk,
                    p_tipo_alloggio_id = entity.TipoAlloggioIdFk,
                    p_cliente_id1 = entity.ClienteId1Fk,
                    p_cliente_id2 = entity.ClienteId2Fk,
                    p_cliente_id3 = entity.ClienteId3Fk,
                    p_cliente_id4 = entity.ClienteId4Fk,
                    p_cliente_id5 = entity.ClienteId5Fk,
                    p_cliente_id6 = entity.ClienteId6Fk
                });
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

                await conn.ExecuteAsync(sql, new
                {
                    p_pk = entity.MovClientiAlloggioPk,
                    p_viaggio_id = entity.ViaggioIdFk,
                    p_data_viaggio_id = entity.DataViaggioIdFk,
                    p_tipo_alloggio_id = entity.TipoAlloggioIdFk,
                    p_cliente_id1 = entity.ClienteId1Fk,
                    p_cliente_id2 = entity.ClienteId2Fk,
                    p_cliente_id3 = entity.ClienteId3Fk,
                    p_cliente_id4 = entity.ClienteId4Fk,
                    p_cliente_id5 = entity.ClienteId5Fk,
                    p_cliente_id6 = entity.ClienteId6Fk
                });
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
                return await conn.QueryAsync<MovClientiAlloggi>(
                    "SELECT * FROM fn_get_mov_clienti_alloggi_by_date(@dataId)",
                    new { dataId = dataViaggioId });
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
                // CRITICAL: Usa alias espliciti per garantire il corretto mapping Dapper snake_case → PascalCase
                var parameters = new DynamicParameters();
                parameters.Add("dataId", dataViaggioId);
                return await conn.QueryAsync<GestioneViaggi.Models.DTOs.RoomWithOccupantsDTO>(@"
                    SELECT
                        alloggio_pk as AlloggioPk,
                        tipo_alloggio as TipoAlloggio,
                        max_occupants as MaxOccupants,
                        current_occupants as CurrentOccupants,
                        occupant_names as OccupantNames,
                        occupant_ids as OccupantIds,
                        has_supplement as HasSupplement
                    FROM get_rooms_with_occupants(@dataId)",
                    parameters);
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
                return await conn.QuerySingleAsync<bool>(
                    "SELECT sp_assign_to_first_free_slot(@pk, @clienteId)",
                    new { pk = alloggioPk, clienteId });
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
                return await conn.QuerySingleAsync<int>(
                    "SELECT get_rooms_count(@dataId)",
                    new { dataId = dataViaggioId });
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
            
            // Use aliases to map snake_case columns to PascalCase properties automatically with Dapper
            var sql = @"
                SELECT 
                    violation_detected as ViolationDetected,
                    room_id as RoomId,
                    room_type_desc as RoomTypeDesc,
                    required_seats as RequiredSeats,
                    current_occupants_count as CurrentOccupantsCount,
                    remaining_occupants_count as RemainingOccupantsCount,
                    survivor_ids as SurvivorIds
                FROM chk_room_consistency_on_delete(@dataId, @clienteId)";

            return await conn.QuerySingleOrDefaultAsync<RoomConsistencyCheckResult>(sql, new 
            { 
                dataId = dataViaggioId, 
                clienteId = clienteIdToRemove 
            }) ?? new RoomConsistencyCheckResult { ViolationDetected = false };
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
            
            await conn.ExecuteAsync(sql, new 
            { 
                oldRoomId = oldRoomId, 
                newTipo = newTipoAlloggioId, 
                survivors = survivorIds 
            });
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
            
            await conn.ExecuteAsync(sql, new 
            { 
                roomId = roomId, 
                survivors = survivorIds 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore resolving violation (PARK) for Room {RoomId}", roomId);
            throw;
        }
    }
    }
}
