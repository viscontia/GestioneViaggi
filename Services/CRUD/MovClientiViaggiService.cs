
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Npgsql;
using System.Data;

namespace GestioneViaggi.Services.CRUD
{
    public class MovClientiViaggiService
    {
        private readonly IDatabaseConnectionManager _connectionManager;

        public MovClientiViaggiService(IDatabaseConnectionManager connectionManager)
        {
            _connectionManager = connectionManager;
        }

        public async Task<int> AddParticipantAsync(MovClientiViaggi entity)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                string sql = "SELECT sp_mov_clienti_viaggi_create(@p_viaggio_id, @p_data_viaggio_id, @p_cliente_id, @p_tipo_partecipante_id, @p_ana_mezzi_id, @p_mezzo_modello_id, @p_sconto_val_totale, @p_targa_mezzo, @p_cane_sino, @p_note, @p_cliente_pilota_id)";
                await using var cmd = new NpgsqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("p_viaggio_id", entity.ViaggioIdFk);
                cmd.Parameters.AddWithValue("p_data_viaggio_id", entity.DataViaggioIdFk);
                cmd.Parameters.AddWithValue("p_cliente_id", entity.ClienteIdFk);
                cmd.Parameters.AddWithValue("p_tipo_partecipante_id", entity.TipoPartecipanteIdFk);
                cmd.Parameters.AddWithValue("p_ana_mezzi_id", (object?)entity.AnaMezziIdFk ?? DBNull.Value);
                cmd.Parameters.AddWithValue("p_mezzo_modello_id", (object?)entity.MezzoModelloIdFk ?? DBNull.Value);
                cmd.Parameters.AddWithValue("p_sconto_val_totale", (object?)entity.MovClienteViaggioScontovalTotale ?? DBNull.Value);
                cmd.Parameters.AddWithValue("p_targa_mezzo", (object?)entity.MovClienteViaggioTargaMezzo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("p_cane_sino", (object?)entity.MovClienteViaggioCaneSino ?? DBNull.Value);
                cmd.Parameters.AddWithValue("p_note", (object?)entity.MovClienteViaggioNote ?? DBNull.Value);
                cmd.Parameters.AddWithValue("p_cliente_pilota_id", (object?)entity.ClientePilotaIdFk ?? DBNull.Value);

                await cmd.ExecuteNonQueryAsync();
                return 1;
            }
            catch (PostgresException ex) when (ex.SqlState == "23505")
            {
                // Unique violation - Cliente già presente nel viaggio
                throw new InvalidOperationException("Questo cliente è già iscritto a questo viaggio. Non è possibile inserirlo nuovamente.", ex);
            }
            catch (PostgresException ex) when (ex.SqlState == "23503")
            {
                // Foreign key violation - mappa il constraint al campo specifico
                var fieldName = ex.ConstraintName switch
                {
                    "fk_mov_clienti_viaggi_cliente" => "Cliente",
                    "fk_mov_clienti_viaggi_tipo_part" => "Tipo Partecipante",
                    "fk_mov_clienti_viaggi_pilota" => "Pilota assegnato",
                    "fk_mov_clienti_viaggi_viaggio" => "Viaggio",
                    "fk_mov_clienti_viaggi_data" => "Data Viaggio",
                    "mov_clienti_viaggi_ana_mezzi_id_fk_fkey" => "Marca Veicolo",
                    "mov_clienti_viaggi_mezzo_modello_id_fk_fkey" => "Modello Veicolo",
                    _ => $"campo sconosciuto ({ex.ConstraintName})"
                };
                throw new InvalidOperationException($"Impossibile aggiungere il partecipante: il campo '{fieldName}' fa riferimento a un dato non valido o non più presente in archivio.", ex);
            }
            catch (PostgresException ex)
            {
                // Generic PostgreSQL error
                throw new InvalidOperationException($"Errore durante l'aggiunta del partecipante: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante l'aggiunta del partecipante. Riprova.", ex);
            }
        }

        public async Task UpdateParticipantAsync(MovClientiViaggi entity)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                string sql = "SELECT sp_mov_clienti_viaggi_update(@p_viaggio_id, @p_data_viaggio_id, @p_cliente_id, @p_tipo_partecipante_id, @p_ana_mezzi_id, @p_mezzo_modello_id, @p_sconto_val_totale, @p_targa_mezzo, @p_cane_sino, @p_note, @p_cliente_pilota_id)";
                await using var cmd = new NpgsqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("p_viaggio_id", entity.ViaggioIdFk);
                cmd.Parameters.AddWithValue("p_data_viaggio_id", entity.DataViaggioIdFk);
                cmd.Parameters.AddWithValue("p_cliente_id", entity.ClienteIdFk);
                cmd.Parameters.AddWithValue("p_tipo_partecipante_id", entity.TipoPartecipanteIdFk);
                cmd.Parameters.AddWithValue("p_ana_mezzi_id", (object?)entity.AnaMezziIdFk ?? DBNull.Value);
                cmd.Parameters.AddWithValue("p_mezzo_modello_id", (object?)entity.MezzoModelloIdFk ?? DBNull.Value);
                cmd.Parameters.AddWithValue("p_sconto_val_totale", (object?)entity.MovClienteViaggioScontovalTotale ?? DBNull.Value);
                cmd.Parameters.AddWithValue("p_targa_mezzo", (object?)entity.MovClienteViaggioTargaMezzo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("p_cane_sino", (object?)entity.MovClienteViaggioCaneSino ?? DBNull.Value);
                cmd.Parameters.AddWithValue("p_note", (object?)entity.MovClienteViaggioNote ?? DBNull.Value);
                cmd.Parameters.AddWithValue("p_cliente_pilota_id", (object?)entity.ClientePilotaIdFk ?? DBNull.Value);

                await cmd.ExecuteNonQueryAsync();
            }
            catch (PostgresException ex) when (ex.SqlState == "23503")
            {
                // Foreign key violation
                throw new InvalidOperationException("Impossibile modificare il partecipante: alcuni dati riferiti (veicolo, modello o pilota) non sono validi.", ex);
            }
            catch (PostgresException ex) when (ex.Message.Contains("Record non trovato"))
            {
                // Record not found
                throw new InvalidOperationException("Il partecipante che stai cercando di modificare non esiste più. Ricarica la pagina.", ex);
            }
            catch (PostgresException ex)
            {
                // Generic PostgreSQL error
                throw new InvalidOperationException($"Errore durante la modifica del partecipante: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante la modifica del partecipante. Riprova.", ex);
            }
        }

        public async Task RemoveParticipantAsync(int viaggioId, int dataId, int clienteId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                string sql = "SELECT sp_mov_clienti_viaggi_delete(@p_viaggio_id, @p_data_viaggio_id, @p_cliente_id)";
                await using var cmd = new NpgsqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("p_viaggio_id", viaggioId);
                cmd.Parameters.AddWithValue("p_data_viaggio_id", dataId);
                cmd.Parameters.AddWithValue("p_cliente_id", clienteId);

                await cmd.ExecuteNonQueryAsync();
            }
            catch (PostgresException ex) when (ex.SqlState == "23503")
            {
                // Foreign key violation - probably referenced by alloggi
                throw new InvalidOperationException("Impossibile rimuovere il partecipante: è collegato ad altri dati (es. alloggi). Rimuovi prima i collegamenti.", ex);
            }
            catch (PostgresException ex)
            {
                // Generic PostgreSQL error
                throw new InvalidOperationException($"Errore durante la rimozione del partecipante: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante la rimozione del partecipante. Riprova.", ex);
            }
        }

        /// <summary>
        /// DB Function: fn_get_mov_clienti_viaggi_by_date(p_data_viaggio_id INTEGER)
        /// Input: ID della data viaggio
        /// Output: Tutti i partecipanti iscritti (dati raw senza arricchimenti)
        /// </summary>
        public async Task<IEnumerable<MovClientiViaggi>> GetByDateIdAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                // Usa Npgsql diretto invece di Dapper per compatibilità AOT (Reflection.Emit non supportato)
                await using var cmd = new NpgsqlCommand("SELECT * FROM fn_get_mov_clienti_viaggi_by_date(@dataId)", conn);
                cmd.Parameters.AddWithValue("dataId", dataViaggioId);

                var result = new List<MovClientiViaggi>();
                await using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    // La funzione SQL non restituisce le colonne audit (created_by, created, updated_by, updated)
                    result.Add(new MovClientiViaggi
                    {
                        ViaggioIdFk = reader.GetInt32(reader.GetOrdinal("viaggio_id_fk")),
                        DataViaggioIdFk = reader.GetInt32(reader.GetOrdinal("data_viaggio_id_fk")),
                        ClienteIdFk = reader.GetInt32(reader.GetOrdinal("cliente_id_fk")),
                        TipoPartecipanteIdFk = reader.GetInt32(reader.GetOrdinal("tipo_partecipante_id_fk")),
                        AnaMezziIdFk = reader.IsDBNull(reader.GetOrdinal("ana_mezzi_id_fk")) ? null : reader.GetInt32(reader.GetOrdinal("ana_mezzi_id_fk")),
                        MezzoModelloIdFk = reader.IsDBNull(reader.GetOrdinal("mezzo_modello_id_fk")) ? null : reader.GetInt32(reader.GetOrdinal("mezzo_modello_id_fk")),
                        ClientePilotaIdFk = reader.IsDBNull(reader.GetOrdinal("cliente_pilota_id_fk")) ? null : reader.GetInt32(reader.GetOrdinal("cliente_pilota_id_fk")),
                        MovClienteViaggioScontovalTotale = reader.IsDBNull(reader.GetOrdinal("mov_cliente_viaggio_scontoval_totale")) ? null : reader.GetDecimal(reader.GetOrdinal("mov_cliente_viaggio_scontoval_totale")),
                        MovClienteViaggioTargaMezzo = reader.IsDBNull(reader.GetOrdinal("mov_cliente_viaggio_targa_mezzo")) ? null : reader.GetString(reader.GetOrdinal("mov_cliente_viaggio_targa_mezzo")),
                        MovClienteViaggioCaneSino = reader.IsDBNull(reader.GetOrdinal("mov_cliente_viaggio_cane_sino")) ? "N" : reader.GetString(reader.GetOrdinal("mov_cliente_viaggio_cane_sino")),
                        MovClienteViaggioNote = reader.IsDBNull(reader.GetOrdinal("mov_cliente_viaggio_note")) ? null : reader.GetString(reader.GetOrdinal("mov_cliente_viaggio_note"))
                    });
                }
                return result;
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento dei partecipanti: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante il caricamento dei partecipanti. Riprova.", ex);
            }
        }
        /// <summary>
        /// DB Function: fn_get_participants_view(p_data_viaggio_id INTEGER)
        /// Input: ID della data viaggio
        /// Output: Vista arricchita partecipanti con dati anagrafici, ruolo e mezzo, ordinati per equipaggio
        /// </summary>
        public async Task<IEnumerable<GestioneViaggi.Models.DTOs.ParticipantsViewDTO>> GetParticipantsViewAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                // Usa Npgsql diretto per compatibilità AOT (Reflection.Emit non supportato)
                await using var cmd = new NpgsqlCommand("SELECT * FROM fn_get_participants_view(@dataId)", conn);
                cmd.Parameters.AddWithValue("dataId", dataViaggioId);

                var result = new List<GestioneViaggi.Models.DTOs.ParticipantsViewDTO>();
                await using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    result.Add(MapReaderToParticipantsViewDTO(reader));
                }
                return result;
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento della lista partecipanti: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                // DEBUG: mostra errore reale per diagnostica
                throw new InvalidOperationException($"DEBUG: {ex.GetType().Name} - {ex.Message}", ex);
            }
        }

        // Helper method per mapping manuale DataReader -> ParticipantsViewDTO (compatibilità AOT)
        // Gestisce colonne opzionali che potrebbero non essere presenti in tutte le funzioni DB
        private static GestioneViaggi.Models.DTOs.ParticipantsViewDTO MapReaderToParticipantsViewDTO(NpgsqlDataReader reader)
        {
            var dto = new GestioneViaggi.Models.DTOs.ParticipantsViewDTO
            {
                ViaggioId = reader.GetInt32(reader.GetOrdinal("viaggio_id")),
                DataId = reader.GetInt32(reader.GetOrdinal("data_id")),
                ClienteId = reader.GetInt32(reader.GetOrdinal("cliente_id")),
                Nominativo = reader.GetString(reader.GetOrdinal("nominativo")),
                TipoPartecipanteId = reader.GetInt32(reader.GetOrdinal("tipo_partecipante_id")),
                Ruolo = reader.GetString(reader.GetOrdinal("ruolo"))
            };

            // Colonne opzionali - alcune funzioni DB potrebbero non restituirle
            dto.Note = TryGetString(reader, "note");
            dto.CaneSino = TryGetString(reader, "cane_sino");
            dto.Intolleranze = TryGetString(reader, "intolleranze");
            dto.MezzoDettagli = TryGetString(reader, "mezzo_dettagli");
            dto.ClientePilotaId = TryGetNullableInt(reader, "cliente_pilota_id");
            dto.GroupingKey = TryGetInt(reader, "grouping_key", 0);
            dto.IsPilot = TryGetBool(reader, "is_pilot", false);
            dto.Email = TryGetString(reader, "email");

            return dto;
        }

        // Helper per verificare se una colonna esiste nel reader (compatibilità AOT - no exception)
        private static bool HasColumn(NpgsqlDataReader reader, string columnName)
        {
            for (int i = 0; i < reader.FieldCount; i++)
            {
                if (reader.GetName(i).Equals(columnName, StringComparison.OrdinalIgnoreCase))
                    return true;
            }
            return false;
        }

        // Helper per lettura sicura colonne opzionali (no exception per compatibilità AOT)
        private static string? TryGetString(NpgsqlDataReader reader, string columnName)
        {
            if (!HasColumn(reader, columnName)) return null;
            var ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
        }

        private static int? TryGetNullableInt(NpgsqlDataReader reader, string columnName)
        {
            if (!HasColumn(reader, columnName)) return null;
            var ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? null : reader.GetInt32(ordinal);
        }

        private static int TryGetInt(NpgsqlDataReader reader, string columnName, int defaultValue)
        {
            if (!HasColumn(reader, columnName)) return defaultValue;
            var ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? defaultValue : reader.GetInt32(ordinal);
        }

        private static bool TryGetBool(NpgsqlDataReader reader, string columnName, bool defaultValue)
        {
            if (!HasColumn(reader, columnName)) return defaultValue;
            var ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? defaultValue : reader.GetBoolean(ordinal);
        }

        public async Task<string> GetParticipantsSummaryAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                await using var cmd = new NpgsqlCommand("SELECT get_viaggio_partecipanti_summary(@dataId)", conn);
                cmd.Parameters.AddWithValue("dataId", dataViaggioId);
                var result = await cmd.ExecuteScalarAsync();
                return result as string ?? "Nessun partecipante";
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento del riepilogo partecipanti: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante il caricamento del riepilogo. Riprova.", ex);
            }
        }

        /// <summary>
        /// DB Function: fn_get_trip_header_string(p_viaggio_id INTEGER, p_data_viaggio_id INTEGER)
        /// Input: ID viaggio e ID data viaggio
        /// Output: Intestazione formattata "Descrizione (Dal GG/MM/AAAA al GG/MM/AAAA)"
        /// </summary>
        public async Task<string> GetTripHeaderStringAsync(int viaggioId, int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                await using var cmd = new NpgsqlCommand("SELECT fn_get_trip_header_string(@vid, @did)", conn);
                cmd.Parameters.AddWithValue("vid", viaggioId);
                cmd.Parameters.AddWithValue("did", dataViaggioId);
                var result = await cmd.ExecuteScalarAsync();
                return result as string ?? "Intestazione non disponibile";
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento dell'intestazione viaggio: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante il caricamento dell'intestazione. Riprova.", ex);
            }
        }

        /// <summary>
        /// DB Function: get_participants_sorted(p_data_viaggio_id INTEGER)
        /// Input: ID della data viaggio
        /// Output: Partecipanti ordinati per: cognome pilota → pilota prima dei passeggeri → cognome passeggeri
        /// </summary>
        public async Task<IEnumerable<GestioneViaggi.Models.DTOs.ParticipantsViewDTO>> GetParticipantsSortedAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                // Usa Npgsql diretto per compatibilità AOT (Reflection.Emit non supportato)
                await using var cmd = new NpgsqlCommand("SELECT * FROM get_participants_sorted(@dataId)", conn);
                cmd.Parameters.AddWithValue("dataId", dataViaggioId);

                var result = new List<GestioneViaggi.Models.DTOs.ParticipantsViewDTO>();
                await using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    result.Add(MapReaderToParticipantsViewDTO(reader));
                }
                return result;
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento partecipanti ordinati: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante il caricamento partecipanti. Riprova.", ex);
            }
        }

        /// <summary>
        /// DB Function: get_participants_without_accommodation(p_data_viaggio_id INTEGER)
        /// Input: ID della data viaggio
        /// Output: Solo partecipanti senza camera assegnata (LEFT JOIN atomico con mov_clienti_alloggi)
        /// </summary>
        public async Task<IEnumerable<GestioneViaggi.Models.DTOs.ParticipantsViewDTO>> GetParticipantsWithoutAccommodationAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                // Usa Npgsql diretto per compatibilità AOT (Reflection.Emit non supportato)
                await using var cmd = new NpgsqlCommand("SELECT * FROM get_participants_without_accommodation(@dataId)", conn);
                cmd.Parameters.AddWithValue("dataId", dataViaggioId);

                var result = new List<GestioneViaggi.Models.DTOs.ParticipantsViewDTO>();
                await using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    result.Add(MapReaderToParticipantsViewDTO(reader));
                }
                return result;
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento partecipanti senza camera: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto. Riprova.", ex);
            }
        }

        /// <summary>
        /// DB Function: get_participants_count(p_data_viaggio_id INTEGER)
        /// Input: ID della data viaggio
        /// Output: Conteggio totale partecipanti (più efficiente di Count() in memoria)
        /// </summary>
        public async Task<int> GetParticipantsCountAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                // Usa Npgsql diretto per compatibilità AOT
                await using var cmd = new NpgsqlCommand("SELECT get_participants_count(@dataId)", conn);
                cmd.Parameters.AddWithValue("dataId", dataViaggioId);
                var result = await cmd.ExecuteScalarAsync();
                return result != null ? Convert.ToInt32(result) : 0;
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il conteggio partecipanti: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto. Riprova.", ex);
            }
        }

        public async Task<GestioneViaggi.Models.DTOs.ViaggioPartecipantiInitData> GetPartecipantiInitDataAsync(int viaggioId, int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                await using var cmd = new NpgsqlCommand("SELECT fn_get_viaggio_partecipanti_init_data(@vid, @did)", conn);
                cmd.Parameters.AddWithValue("vid", viaggioId);
                cmd.Parameters.AddWithValue("did", dataViaggioId);
                
                var result = await cmd.ExecuteScalarAsync();
                var json = result as string;
                
                if (string.IsNullOrEmpty(json)) 
                {
                    return new GestioneViaggi.Models.DTOs.ViaggioPartecipantiInitData();
                }

                return System.Text.Json.JsonSerializer.Deserialize<GestioneViaggi.Models.DTOs.ViaggioPartecipantiInitData>(json,
                    new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true })
                    ?? new GestioneViaggi.Models.DTOs.ViaggioPartecipantiInitData();
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento consolidato dei partecipanti: {ex.Message}", ex);
            }
        }
    }
}
