
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

        /// <summary>
        /// Salva una sistemazione e, nella STESSA transazione, toglie i suoi occupanti dalle
        /// altre sistemazioni della stessa partenza, eliminando quelle che restano vuote.
        /// Torna la chiave della sistemazione salvata.
        ///
        /// ⚠️ È una chiamata sola di proposito. Farne due — scrivi la camera nuova, poi
        /// libera quella vecchia — significa che fra l'una e l'altra può succedere qualcosa
        /// che non dipende dal codice: la rete che cade, PgBouncer che chiude, l'app che va
        /// giù. Si resterebbe con una persona in due camere, o con una camera vuota mai
        /// eliminata: nessuna delle due dà errore, sono dati che sembrano buoni, e si
        /// scoprirebbero in albergo davanti al cliente.
        /// DB Function: fn_alloggi_salva_camera (SqlScripts/612)
        /// </summary>
        public async Task<int> SalvaCameraAsync(MovClientiAlloggi entity, IEnumerable<int> occupanti,
                                               string adeguamentiJson = "[]")
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                await using var cmd = new NpgsqlCommand(
                    "SELECT fn_alloggi_salva_camera(@pk, @viaggio, @partenza, @tipo, @clienti, @adeguamenti::jsonb)", conn);
                cmd.Parameters.AddWithValue("pk", entity.MovClientiAlloggioPk);
                cmd.Parameters.AddWithValue("viaggio", entity.ViaggioIdFk);
                cmd.Parameters.AddWithValue("partenza", entity.DataViaggioIdFk);
                cmd.Parameters.AddWithValue("tipo", entity.TipoAlloggioIdFk);
                cmd.Parameters.AddWithValue("clienti", occupanti.ToArray());
                // ⛔️ Che cosa diventa una sistemazione da cui qualcuno se ne va lo decide chi
                // lavora, non il programma: qui arriva già scelto. Senza, il database rifiuta.
                cmd.Parameters.AddWithValue("adeguamenti", adeguamentiJson);

                return Convert.ToInt32(await cmd.ExecuteScalarAsync());
            }
            catch (PostgresException ex)
            {
                // Il messaggio lo scrive il database: è lì che vive la regola.
                throw new InvalidOperationException(ex.MessageText, ex);
            }
        }



        public async Task RemoveAccommodationAsync(int pk)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();

                // PostgreSQL FUNCTION (not PROCEDURE), use SELECT instead of CALL
                string sql = "SELECT sp_mov_clienti_alloggi_delete(@p_pk)";

                await using var cmd = new NpgsqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("p_pk", pk);
                await cmd.ExecuteNonQueryAsync();
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
                        HasSupplement = reader.GetBoolean(reader.GetOrdinal("has_supplement")),
                        PilotCognome = reader.IsDBNull(reader.GetOrdinal("pilot_cognome"))
                            ? "ZZZZZ"
                            : reader.GetString(reader.GetOrdinal("pilot_cognome"))
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

    /// <summary>Un rilievo della validazione di una sistemazione.</summary>
    public record EsitoAlloggio(string Gravita, string Esito, string Messaggio);

    /// <summary>
    /// Verifica un'assegnazione con le stesse regole che usa il sito di iscrizione:
    /// tipo ammesso dal viaggio, capienza rispettata, nessuno ripetuto, nessuno dimenticato.
    ///
    /// ⚠️ Esiste anche se l'interfaccia impedisce già di sbagliare: l'interfaccia è il modo
    /// comodo di rispettare la regola, non la regola. È la stessa funzione chiamata dal
    /// sito — una regola sola, due interfacce.
    /// DB Function: fn_alloggi_assegnazione_valida (SqlScripts/600)
    /// </summary>
    public async Task<List<EsitoAlloggio>> ValidaAssegnazioneAsync(int dataViaggioId, string assegnazioniJson)
    {
        var esiti = new List<EsitoAlloggio>();
        await using var conn = await _connectionManager.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT * FROM fn_alloggi_assegnazione_valida(@dataViaggioId, @dati::jsonb)", conn);
        cmd.Parameters.AddWithValue("dataViaggioId", dataViaggioId);
        cmd.Parameters.AddWithValue("dati", assegnazioniJson);

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            esiti.Add(new EsitoAlloggio(
                reader.GetString(reader.GetOrdinal("gravita")),
                reader.GetString(reader.GetOrdinal("esito")),
                reader.GetString(reader.GetOrdinal("messaggio"))));
        }
        return esiti;
    }

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
                    RoomId = reader.IsDBNull(reader.GetOrdinal("room_id")) ? 0 : reader.GetInt32(reader.GetOrdinal("room_id")),
                    RoomTypeDesc = reader.IsDBNull(reader.GetOrdinal("room_type_desc")) ? null : reader.GetString(reader.GetOrdinal("room_type_desc")),
                    RequiredSeats = reader.IsDBNull(reader.GetOrdinal("required_seats")) ? 0 : reader.GetInt32(reader.GetOrdinal("required_seats")),
                    CurrentOccupantsCount = reader.IsDBNull(reader.GetOrdinal("current_occupants_count")) ? 0 : reader.GetInt32(reader.GetOrdinal("current_occupants_count")),
                    RemainingOccupantsCount = reader.IsDBNull(reader.GetOrdinal("remaining_occupants_count")) ? 0 : reader.GetInt32(reader.GetOrdinal("remaining_occupants_count")),
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


    }
}
