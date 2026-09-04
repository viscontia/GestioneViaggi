
using GestioneViaggi.Helpers;
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

        /// <summary>
        /// I dati dell'iscrizione con i nomi delle colonne come chiavi: e' il formato che
        /// le funzioni si aspettano, lo stesso che manda il sito. Le chiavi nulle si
        /// omettono, cosi' in aggiornamento non si spegne un campo che nessuno ha toccato.
        /// </summary>
        private static string ComeJson(MovClientiViaggi e)
        {
            var d = new Dictionary<string, object?>
            {
                ["viaggio_id_fk"] = e.ViaggioIdFk,
                ["data_viaggio_id_fk"] = e.DataViaggioIdFk,
                ["cliente_id_fk"] = e.ClienteIdFk,
                ["tipo_partecipante_id_fk"] = e.TipoPartecipanteIdFk,
                ["ana_mezzi_id_fk"] = e.AnaMezziIdFk,
                ["mezzo_modello_id_fk"] = e.MezzoModelloIdFk,
                ["cliente_pilota_id_fk"] = e.ClientePilotaIdFk,
                ["mov_cliente_viaggio_scontoval_totale"] = e.MovClienteViaggioScontovalTotale,
                ["mov_cliente_viaggio_targa_mezzo"] = e.MovClienteViaggioTargaMezzo,
                ["mov_cliente_viaggio_cane_sino"] = e.MovClienteViaggioCaneSino,
                ["mov_cliente_viaggio_note"] = e.MovClienteViaggioNote,
            };
            foreach (var k in d.Where(x => x.Value is null).Select(x => x.Key).ToList()) d.Remove(k);
            return System.Text.Json.JsonSerializer.Serialize(d);
        }

        /// <summary>
        /// Perche' a questa partenza non ci si puo' iscrivere, o <c>null</c> se si puo'.
        ///
        /// La regola sta in <c>fn_partenza_iscrivibile</c> (SqlScripts/584), la stessa che
        /// rifiuta l'inserimento e che decide cosa il sito propone: l'interfaccia non se la
        /// ricalcola per conto suo, altrimenti un pulsante attivo prometterebbe cio' che il
        /// database rifiuta.
        ///
        /// Il MOTIVO arriva dal database e non si compone qui: a un viaggio gia' cominciato
        /// non ci si iscrive, ma «si e' concluso» sarebbe falso — e chi legge un messaggio
        /// che non riconosce pensa a un guasto.
        /// </summary>
        public async Task<string?> MotivoNonIscrivibileAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                await using var cmd = new NpgsqlCommand(
                    "SELECT fn_partenza_motivo_non_iscrivibile(@id)", conn);
                cmd.Parameters.AddWithValue("id", dataViaggioId);
                var esito = await cmd.ExecuteScalarAsync();
                return esito as string;
            }
            catch
            {
                // Nel dubbio si lascia lavorare: il blocco vero e' a database, e sbagliare
                // qui puo' al massimo far comparire un pulsante che poi si rifiuta.
                return null;
            }
        }

        /// <summary>
        /// Chiede al database di validare l'iscrizione senza scriverla. Restituisce gli esiti
        /// con la loro gravita': e' cio' che permette alla form di chiedere l'email mancante
        /// prima di rifiutare, invece di limitarsi a dire di no.
        /// </summary>
        public async Task<List<EsitoValidazione>> ValidaAsync(MovClientiViaggi entity, bool modifica = false)
        {
            var esiti = new List<EsitoValidazione>();
            await using var conn = await _connectionManager.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT gravita, esito, messaggio, riferimento FROM fn_mov_clienti_viaggi_valida(@dati::jsonb, @modifica)", conn);
            cmd.Parameters.AddWithValue("dati", ComeJson(entity));
            cmd.Parameters.AddWithValue("modifica", modifica);

            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                esiti.Add(new EsitoValidazione
                {
                    Gravita = reader.GetString(0),
                    Esito = reader.GetString(1),
                    Messaggio = reader.GetString(2),
                    Riferimento = reader.IsDBNull(3) ? null : reader.GetInt32(3)
                });
            }
            return esiti;
        }

        /// <summary>
        /// Iscrive un partecipante chiamando <c>fn_mov_clienti_viaggi_insert</c>.
        ///
        /// Fino ad agosto 2026 qui si chiamava <c>sp_mov_clienti_viaggi_create</c>, che non
        /// controllava nulla: l'email obbligatoria per chi guida e i dati del mezzo quando il
        /// ruolo li richiede erano regole che **solo il sito** applicava. Il gestionale, cioe'
        /// lo strumento di chi lavora tutti i giorni, ne era scoperto — ed e' cosi' che si sono
        /// iscritti 11 piloti senza email.
        /// </summary>
        public async Task<int> AddParticipantAsync(MovClientiViaggi entity, bool conferme = false)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                await using var cmd = new NpgsqlCommand(
                    "SELECT fn_mov_clienti_viaggi_insert(@dati::jsonb, @conferme)", conn);
                cmd.Parameters.AddWithValue("dati", ComeJson(entity));
                cmd.Parameters.AddWithValue("conferme", conferme);

                return Convert.ToInt32(await cmd.ExecuteScalarAsync());
            }
            catch (PostgresException ex) when (ex.SqlState == "P0001")
            {
                // Rifiuto deliberato della validazione: il messaggio lo ha scritto il
                // database, in italiano, ed e' l'unico posto dove la regola vive.
                throw new InvalidOperationException(ex.MessageText, ex);
            }
            catch (PostgresException ex)
            {
                throw DatabaseExceptionHelper.WrapException(ex, "mov_clienti_viaggi");
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante l'aggiunta del partecipante. Riprova.", ex);
            }
        }

        public async Task UpdateParticipantAsync(MovClientiViaggi entity, bool conferme = false)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                await using var cmd = new NpgsqlCommand(
                    "SELECT fn_mov_clienti_viaggi_update(@dati::jsonb, @conferme)", conn);
                cmd.Parameters.AddWithValue("dati", ComeJson(entity));
                cmd.Parameters.AddWithValue("conferme", conferme);

                await cmd.ExecuteNonQueryAsync();
            }
            catch (PostgresException ex) when (ex.SqlState == "P0001")
            {
                // Rifiuto deliberato della validazione: il messaggio lo ha scritto il
                // database, in italiano, ed e' l'unico posto dove la regola vive.
                throw new InvalidOperationException(ex.MessageText, ex);
            }
            catch (PostgresException ex)
            {
                throw DatabaseExceptionHelper.WrapException(ex, "mov_clienti_viaggi");
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
                await using var cmd = new NpgsqlCommand(
                    "SELECT fn_mov_clienti_viaggi_delete(@p_viaggio_id, @p_data_viaggio_id, @p_cliente_id)", conn);
                cmd.Parameters.AddWithValue("p_viaggio_id", viaggioId);
                cmd.Parameters.AddWithValue("p_data_viaggio_id", dataId);
                cmd.Parameters.AddWithValue("p_cliente_id", clienteId);

                await cmd.ExecuteNonQueryAsync();
            }
            catch (PostgresException ex) when (ex.SqlState == "23503")
            {
                throw new InvalidOperationException("Impossibile rimuovere il partecipante: è collegato ad altri dati (es. alloggi). Rimuovi prima i collegamenti.", ex);
            }
            catch (PostgresException ex)
            {
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
